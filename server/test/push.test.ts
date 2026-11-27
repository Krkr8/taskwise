import { afterEach, describe, expect, it, vi } from 'vitest';

import type { PushDeps } from '../src/context.js';
import { deliverPushItem, type PushSender } from '../src/push/deliver.js';
import { queueDueItems, type PushMessage } from '../src/push/schedule.js';
import type { PushSubscriptionRow } from '../src/push/store.js';
import { cronSecret, testApp } from './helpers.js';

const hour = 60 * 60 * 1000;
const day = 24 * hour;

/** Records every queued message with its delay. */
function fakeScheduler() {
  const queued: { msg: PushMessage; delaySeconds: number }[] = [];
  return {
    queued,
    enqueue: async (msg: PushMessage, delaySeconds: number) => {
      queued.push({ msg, delaySeconds });
    },
  };
}

/** Records every push; [results] maps an endpoint to its answer. */
function fakeSender(results: Record<string, 'ok' | 'gone' | 'throw'> = {}) {
  const sent: { endpoint: string; payload: unknown }[] = [];
  const sender: PushSender & { sent: typeof sent } = {
    sent,
    send: async (sub: PushSubscriptionRow, payload: string) => {
      const result = results[sub.endpoint] ?? 'ok';
      if (result === 'throw') throw new Error('push service down');
      if (result === 'ok') sent.push({ endpoint: sub.endpoint, payload: JSON.parse(payload) });
      return result;
    },
  };
  return sender;
}

const subscription = (endpoint = 'https://push.example.com/send/abc') => ({
  endpoint,
  keys: { p256dh: 'BPublicKeyOfTheBrowser', auth: 'authSecret' },
});

async function ready() {
  const scheduler = fakeScheduler();
  const sender = fakeSender();
  const push: PushDeps = { publicKey: 'BVapidPublicKey', scheduler, sender };
  const t = await testApp(undefined, { push });
  await t.setup();
  const laptop = await t.login('laptop', 'linux', { timeZone: 'Asia/Baghdad' });
  const web = await t.login('web', 'web', { timeZone: 'Asia/Baghdad' });
  const item = (key: string, fireAt: number, extra: object = {}) => ({
    key,
    fireAt,
    taskId: `task-${key}`,
    title: `Title ${key}`,
    body: `Body ${key}`,
    ...extra,
  });
  const upload = (items: unknown[], deviceId = 'web', token = laptop) =>
    t.request('PUT', `/push/plan/${deviceId}`, { token, body: { items } });
  const deliver = (msg: PushMessage, at = t.clock.now) =>
    deliverPushItem(t.db, sender, msg, at);
  const rows = async () =>
    (
      await t.db.execute(
        'SELECT key, fire_at, title, queued_at, sent_at FROM push_items ORDER BY fire_at',
      )
    ).rows.map((r) => ({
      key: String(r['key']),
      fireAt: Number(r['fire_at']),
      title: String(r['title']),
      queued: r['queued_at'] !== null,
      sent: r['sent_at'] !== null,
    }));
  return { ...t, scheduler, sender, push, laptop, web, item, upload, deliver, rows };
}

describe('push plans', () => {
  it('queues the items due within 7 days, with their delays', async () => {
    const { upload, item, clock, scheduler } = await ready();
    const now = clock.now;
    const response = await upload([
      item('a', now + hour),
      item('b', now + 3 * day),
      item('c', now + 10 * day),
    ]);
    expect(response.status).toBe(204);
    expect(scheduler.queued).toEqual([
      { msg: { deviceId: 'web', key: 'a', fireAt: now + hour }, delaySeconds: 3600 },
      { msg: { deviceId: 'web', key: 'b', fireAt: now + 3 * day }, delaySeconds: 259200 },
    ]);
  });

  it('the same upload again queues nothing new', async () => {
    const { upload, item, clock, scheduler } = await ready();
    const items = [item('a', clock.now + hour), item('b', clock.now + 3 * day)];
    await upload(items);
    await upload(items);
    expect(scheduler.queued).toHaveLength(2);
  });

  it('a changed fire time queues exactly one new message; the old one sends nothing', async () => {
    const { upload, item, clock, scheduler, deliver, sender, web, request } = await ready();
    await request('PUT', '/push/subscription', { token: web, body: subscription() });
    const now = clock.now;
    await upload([item('a', now + hour), item('b', now + 2 * hour)]);
    await upload([item('a', now + hour), item('b', now + 3 * hour)]);
    expect(scheduler.queued.map((q) => q.msg)).toEqual([
      { deviceId: 'web', key: 'a', fireAt: now + hour },
      { deviceId: 'web', key: 'b', fireAt: now + 2 * hour },
      { deviceId: 'web', key: 'b', fireAt: now + 3 * hour },
    ]);
    const [, old, current] = scheduler.queued;
    expect(await deliver(old!.msg, now + 2 * hour)).toBe('skipped');
    expect(sender.sent).toHaveLength(0);
    expect(await deliver(current!.msg, now + 3 * hour)).toBe('sent');
    expect(sender.sent).toHaveLength(1);
  });

  it('a changed title queues nothing new; the queued message sends the new text', async () => {
    const { upload, item, clock, scheduler, deliver, sender, web, request } = await ready();
    await request('PUT', '/push/subscription', { token: web, body: subscription() });
    await upload([item('a', clock.now + hour)]);
    await upload([item('a', clock.now + hour, { title: 'Renamed', body: 'New body' })]);
    expect(scheduler.queued).toHaveLength(1);
    expect(await deliver(scheduler.queued[0]!.msg, clock.now + hour)).toBe('sent');
    expect(sender.sent[0]!.payload).toEqual({
      title: 'Renamed',
      body: 'New body',
      taskId: 'task-a',
      key: 'a',
    });
  });

  it('an item left out is deleted, and its queued message sends nothing (Review Focus 1)', async () => {
    const { upload, item, clock, scheduler, deliver, sender, web, request, rows } = await ready();
    await request('PUT', '/push/subscription', { token: web, body: subscription() });
    await upload([item('a', clock.now + hour), item('b', clock.now + 2 * hour)]);
    await upload([item('b', clock.now + 2 * hour)]);
    expect((await rows()).map((r) => r.key)).toEqual(['b']);
    expect(await deliver(scheduler.queued[0]!.msg, clock.now + hour)).toBe('skipped');
    expect(sender.sent).toHaveLength(0);
  });

  it('an empty list clears the unsent plan', async () => {
    const { upload, item, clock, rows } = await ready();
    await upload([item('a', clock.now + hour)]);
    expect(await upload([])).toMatchObject({ status: 204 });
    expect(await rows()).toEqual([]);
  });

  it('two uploads of the same list at once queue each item once (Review Focus 2)', async () => {
    const { upload, item, clock, scheduler, rows } = await ready();
    const items = [
      item('a', clock.now + hour),
      item('b', clock.now + 2 * day),
      item('c', clock.now + 3 * day),
    ];
    const [first, second] = await Promise.all([upload(items), upload(items)]);
    expect([first.status, second.status]).toEqual([204, 204]);
    expect(scheduler.queued.map((q) => q.msg.key).sort()).toEqual(['a', 'b', 'c']);
    expect((await rows()).map((r) => r.key)).toEqual(['a', 'b', 'c']);
  });

  it('two different lists at once leave one of them, consistent (Review Focus 2)', async () => {
    const { upload, item, clock, scheduler, rows } = await ready();
    const one = [item('a', clock.now + hour), item('b', clock.now + 2 * hour)];
    const two = [item('b', clock.now + 3 * hour), item('c', clock.now + 4 * hour)];
    await Promise.all([upload(one), upload(two)]);
    const keys = (await rows()).map((r) => r.key);
    expect([['a', 'b'], ['b', 'c']]).toContainEqual(keys);
    // Every stored item has exactly one queued message for its fire time.
    for (const row of await rows()) {
      expect(row.queued).toBe(true);
      expect(
        scheduler.queued.filter(
          (q) => q.msg.key === row.key && q.msg.fireAt === row.fireAt,
        ),
      ).toHaveLength(1);
    }
  });

  it('a sent item uploaded again is not sent again', async () => {
    const { upload, item, clock, scheduler, deliver, sender, web, request } = await ready();
    await request('PUT', '/push/subscription', { token: web, body: subscription() });
    const a = item('a', clock.now + hour);
    await upload([a]);
    clock.now += hour;
    expect(await deliver(scheduler.queued[0]!.msg)).toBe('sent');
    await upload([a]);
    expect(scheduler.queued).toHaveLength(1);
    expect(sender.sent).toHaveLength(1);
  });

  it('rejects plans for unknown, non-web or revoked devices with 404', async () => {
    const { upload, item, clock, request, laptop, login } = await ready();
    const items = [item('a', clock.now + hour)];
    expect((await upload(items, 'nope')).status).toBe(404);
    expect((await upload(items, 'laptop')).status).toBe(404);
    await login('web-2', 'web');
    await request('DELETE', '/devices/web-2', { token: laptop });
    const revoked = await upload(items, 'web-2');
    expect(revoked.status).toBe(404);
    expect(revoked.body.error.code).toBe('not_found');
  });

  it('validates the items', async () => {
    const { upload, item, clock } = await ready();
    const ok = item('a', clock.now + hour);
    const bad = [
      { items: 'x' },
      [{ ...ok, fireAt: 'soon' }],
      [{ ...ok, fireAt: 1.5 }],
      [{ ...ok, key: '' }],
      [{ ...ok, title: 7 }],
      [{ ...ok, taskId: undefined }],
      [ok, ok], // the same key twice
      Array.from({ length: 501 }, (_, i) => item(`k${i}`, clock.now + hour)),
    ];
    for (const items of bad) {
      const response = Array.isArray(items)
        ? await upload(items)
        : await upload(items as never);
      expect(response.status, JSON.stringify(items).slice(0, 80)).toBe(400);
    }
    const max = Array.from({ length: 500 }, (_, i) => item(`k${i}`, clock.now + 8 * day));
    expect((await upload(max)).status).toBe(204);
  });

  it('a web device can upload its own plan', async () => {
    const { upload, item, clock, web, scheduler } = await ready();
    expect((await upload([item('a', clock.now + hour)], 'web', web)).status).toBe(204);
    expect(scheduler.queued).toHaveLength(1);
  });
});

describe('push delivery', () => {
  it('sends once to every subscription, then skips', async () => {
    const { upload, item, clock, scheduler, deliver, sender, web, request } = await ready();
    await request('PUT', '/push/subscription', { token: web, body: subscription('https://push.example.com/1') });
    await request('PUT', '/push/subscription', { token: web, body: subscription('https://push.example.com/2') });
    await upload([item('a', clock.now + hour)]);
    const msg = scheduler.queued[0]!.msg;
    clock.now += hour;
    const [first, second] = await Promise.all([deliver(msg), deliver(msg)]);
    expect([first, second].sort()).toEqual(['sent', 'skipped']);
    expect(await deliver(msg)).toBe('skipped');
    expect(sender.sent.map((s) => s.endpoint)).toEqual([
      'https://push.example.com/1',
      'https://push.example.com/2',
    ]);
    expect(sender.sent[0]!.payload).toEqual({
      title: 'Title a',
      body: 'Body a',
      taskId: 'task-a',
      key: 'a',
    });
  });

  it('a message more than 60 minutes late is stale: marked sent, not pushed', async () => {
    const { upload, item, clock, scheduler, deliver, sender, web, request, rows } = await ready();
    await request('PUT', '/push/subscription', { token: web, body: subscription() });
    await upload([item('a', clock.now + hour)]);
    const msg = scheduler.queued[0]!.msg;
    expect(await deliver(msg, msg.fireAt + 61 * 60 * 1000)).toBe('stale');
    expect(sender.sent).toHaveLength(0);
    expect((await rows())[0]!.sent).toBe(true);
    expect(await deliver(msg, msg.fireAt)).toBe('skipped');
  });

  it('60 minutes late still sends', async () => {
    const { upload, item, clock, scheduler, deliver, sender, web, request } = await ready();
    await request('PUT', '/push/subscription', { token: web, body: subscription() });
    await upload([item('a', clock.now + hour)]);
    const msg = scheduler.queued[0]!.msg;
    expect(await deliver(msg, msg.fireAt + 60 * 60 * 1000)).toBe('sent');
    expect(sender.sent).toHaveLength(1);
  });

  it('deletes a subscription the push service says is gone', async () => {
    const t = await ready();
    const sender = fakeSender({ 'https://push.example.com/old': 'gone' });
    await t.request('PUT', '/push/subscription', { token: t.web, body: subscription('https://push.example.com/old') });
    await t.request('PUT', '/push/subscription', { token: t.web, body: subscription('https://push.example.com/new') });
    await t.upload([t.item('a', t.clock.now + hour)]);
    const msg = t.scheduler.queued[0]!.msg;
    expect(await deliverPushItem(t.db, sender, msg, msg.fireAt)).toBe('sent');
    expect(sender.sent.map((s) => s.endpoint)).toEqual(['https://push.example.com/new']);
    const left = await t.db.execute('SELECT endpoint FROM push_subscriptions');
    expect(left.rows.map((r) => r['endpoint'])).toEqual(['https://push.example.com/new']);
  });

  it('gives the item back when every send fails, so the queue retries', async () => {
    const t = await ready();
    const failing = fakeSender({ 'https://push.example.com/down': 'throw' });
    await t.request('PUT', '/push/subscription', { token: t.web, body: subscription('https://push.example.com/down') });
    await t.upload([t.item('a', t.clock.now + hour)]);
    const msg = t.scheduler.queued[0]!.msg;
    await expect(deliverPushItem(t.db, failing, msg, msg.fireAt)).rejects.toThrow();
    expect((await t.rows())[0]!.sent).toBe(false);
    expect(await deliverPushItem(t.db, t.sender, msg, msg.fireAt)).toBe('sent');
  });

  it('without a subscription the item is marked done and nothing is sent', async () => {
    const { upload, item, clock, scheduler, deliver, sender, rows } = await ready();
    await upload([item('a', clock.now + hour)]);
    expect(await deliver(scheduler.queued[0]!.msg, clock.now + hour)).toBe('skipped');
    expect(sender.sent).toHaveLength(0);
    expect((await rows())[0]!.sent).toBe(true);
  });

  it('logs no titles, bodies, endpoints or keys', async () => {
    const lines: string[] = [];
    const spy = vi.spyOn(console, 'log').mockImplementation((line: string) => {
      lines.push(line);
    });
    const { upload, item, clock, scheduler, deliver, web, request } = await ready();
    await request('PUT', '/push/subscription', { token: web, body: subscription('https://push.example.com/secret-endpoint') });
    await upload([item('a', clock.now + hour, { title: 'Secret title', body: 'Secret body' }), item('b', clock.now + 2 * hour)]);
    await deliver(scheduler.queued[0]!.msg, clock.now + hour);
    await deliver(scheduler.queued[1]!.msg, clock.now + 5 * hour); // stale
    await request('DELETE', '/push/subscription', { token: web, body: { endpoint: 'https://push.example.com/secret-endpoint' } });
    spy.mockRestore();
    const all = lines.join('\n');
    expect(all).toContain('push_');
    for (const secret of ['Secret title', 'Secret body', 'secret-endpoint', 'BPublicKeyOfTheBrowser', 'authSecret']) {
      expect(all).not.toContain(secret);
    }
  });
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe('push subscriptions and devices', () => {
  it('login with a time zone shows it; pushEnabled follows the subscriptions', async () => {
    const { request, laptop, web } = await ready();
    const find = async (id: string) =>
      (await request('GET', '/devices', { token: laptop })).body.devices.find(
        (d: { id: string }) => d.id === id,
      );
    expect(await find('web')).toMatchObject({ timeZone: 'Asia/Baghdad' });
    expect((await find('web')).pushEnabled).toBeUndefined();

    expect((await request('PUT', '/push/subscription', { token: web, body: subscription() })).status).toBe(204);
    expect(await find('web')).toMatchObject({ pushEnabled: true });
    // The same endpoint again (a refreshed subscription) is fine.
    expect((await request('PUT', '/push/subscription', { token: web, body: subscription() })).status).toBe(204);

    expect(
      (await request('DELETE', '/push/subscription', { token: web, body: { endpoint: subscription().endpoint } })).status,
    ).toBe(204);
    expect((await find('web')).pushEnabled).toBeUndefined();
  });

  it('a 1.2.x-style login (no time zone) still works and keeps the old shape', async () => {
    const t = await testApp();
    await t.setup();
    const response = await t.request('POST', '/auth/login', {
      body: { username: 'owner', password: 'a long password', device: { id: 'old', name: 'Old', type: 'ios' } },
    });
    expect(response.status).toBe(200);
    expect(Object.keys(response.body.device).sort()).toEqual(
      ['deleted', 'id', 'lastSeenAt', 'main', 'name', 'type', 'updatedAt', 'updatedByDevice'],
    );
    const list = await t.request('GET', '/devices', { token: response.body.token });
    expect(Object.keys(list.body.devices[0]).sort()).toEqual(
      ['deleted', 'id', 'lastSeenAt', 'main', 'name', 'type', 'updatedAt', 'updatedByDevice'],
    );
  });

  it('logging in again without a time zone keeps the stored one', async () => {
    const { request, login } = await ready();
    const token = await login('web', 'web');
    const me = (await request('GET', '/devices', { token })).body.devices.find(
      (d: { id: string }) => d.id === 'web',
    );
    expect(me.timeZone).toBe('Asia/Baghdad');
  });

  it('rejects an invalid time zone at login', async () => {
    const t = await testApp();
    await t.setup();
    const response = await t.request('POST', '/auth/login', {
      body: { username: 'owner', password: 'a long password', device: { id: 'x', name: 'X', type: 'web', timeZone: 5 } },
    });
    expect(response.status).toBe(400);
  });

  it('a device sets its own time zone with PATCH, but not another device\'s', async () => {
    const { request, laptop, web } = await ready();
    const own = await request('PATCH', '/devices/web', { token: web, body: { timeZone: 'Europe/London' } });
    expect(own.status).toBe(200);
    expect(own.body.timeZone).toBe('Europe/London');
    const other = await request('PATCH', '/devices/web', { token: laptop, body: { timeZone: 'America/New_York' } });
    expect(other.status).toBe(403);
    const cleared = await request('PATCH', '/devices/web', { token: web, body: { timeZone: null } });
    expect(cleared.body.timeZone).toBeUndefined();
    expect((await request('PATCH', '/devices/web', { token: web, body: { timeZone: '' } })).status).toBe(400);
  });

  it('validates subscriptions', async () => {
    const { request, web } = await ready();
    for (const body of [
      {},
      { endpoint: 'http://push.example.com/x', keys: { p256dh: 'a', auth: 'b' } },
      { endpoint: 'https://push.example.com/x' },
      { endpoint: 'https://push.example.com/x', keys: { p256dh: '', auth: 'b' } },
    ]) {
      expect((await request('PUT', '/push/subscription', { token: web, body })).status).toBe(400);
    }
    expect((await request('DELETE', '/push/subscription', { token: web, body: {} })).status).toBe(400);
  });

  it('GET /push/key returns the public key', async () => {
    const { request, web } = await ready();
    const response = await request('GET', '/push/key', { token: web });
    expect(response).toMatchObject({ status: 200, body: { publicKey: 'BVapidPublicKey' } });
  });

  it('push endpoints need a device token', async () => {
    const { request } = await ready();
    expect((await request('GET', '/push/key')).status).toBe(401);
  });

  it('without push set up, every push endpoint answers 404 push_not_configured', async () => {
    const t = await testApp();
    await t.setup();
    const token = await t.login('web', 'web');
    for (const [method, path, body] of [
      ['GET', '/push/key', undefined],
      ['PUT', '/push/subscription', subscription()],
      ['DELETE', '/push/subscription', { endpoint: subscription().endpoint }],
      ['PUT', '/push/plan/web', { items: [] }],
    ] as const) {
      const response = await t.request(method, path, { token, ...(body ? { body } : {}) });
      expect(response.status, `${method} ${path}`).toBe(404);
      expect(response.body.error.code).toBe('push_not_configured');
    }
  });

  it('revoking a device deletes its subscriptions and unsent items', async () => {
    const { request, upload, item, clock, laptop, web, db, deliver, scheduler, sender } = await ready();
    await request('PUT', '/push/subscription', { token: web, body: subscription() });
    await upload([item('a', clock.now + hour)]);
    expect((await request('DELETE', '/devices/web', { token: laptop })).status).toBe(200);
    expect((await db.execute('SELECT * FROM push_subscriptions')).rows).toHaveLength(0);
    expect((await db.execute('SELECT * FROM push_items')).rows).toHaveLength(0);
    expect(await deliver(scheduler.queued[0]!.msg, clock.now + hour)).toBe('skipped');
    expect(sender.sent).toHaveLength(0);
  });
});

describe('queueing', () => {
  it('the daily cron queues items that have come within 7 days', async () => {
    const { upload, item, clock, scheduler, request } = await ready();
    const fireAt = clock.now + 10 * day;
    await upload([item('far', fireAt)]);
    expect(scheduler.queued).toHaveLength(0);
    clock.now += 4 * day;
    const cron = await request('GET', '/cron/daily', { token: cronSecret });
    expect(cron.status).toBe(200);
    expect(cron.body.queuedPushes).toBe(1);
    expect(scheduler.queued).toEqual([
      { msg: { deviceId: 'web', key: 'far', fireAt }, delaySeconds: 6 * 24 * 3600 },
    ]);
    // Running again queues nothing new.
    expect((await request('GET', '/cron/daily', { token: cronSecret })).body.queuedPushes).toBe(0);
  });

  it('queues an item just inside the horizon with an hour of retention slack; later ones wait for the cron', async () => {
    const { upload, item, clock, scheduler, request } = await ready();
    const now = clock.now;
    const inside = now + 7 * day - 2 * hour;
    const between = now + 7 * day - 30 * 60 * 1000;
    await upload([item('inside', inside), item('between', between)]);
    expect(scheduler.queued.map((q) => q.msg.key)).toEqual(['inside']);
    const delay = scheduler.queued[0]!.delaySeconds;
    expect(delay).toBeLessThanOrEqual(601200);
    expect(delay + 3600).toBeLessThanOrEqual(604800);
    clock.now += day;
    const cron = await request('GET', '/cron/daily', { token: cronSecret });
    expect(cron.body.queuedPushes).toBe(1);
    expect(scheduler.queued.map((q) => q.msg.key)).toEqual(['inside', 'between']);
  });

  it('the daily cron removes items whose time is long past', async () => {
    const { upload, item, clock, request, rows } = await ready();
    await upload([item('a', clock.now + hour), item('b', clock.now + 5 * day)]);
    clock.now += 3 * day;
    const cron = await request('GET', '/cron/daily', { token: cronSecret });
    expect(cron.body.purgedPushItems).toBe(1);
    expect((await rows()).map((r) => r.key)).toEqual(['b']);
  });

  it('queueDueItems skips past items and those of other devices when asked', async () => {
    const { upload, item, clock, db, login } = await ready();
    await login('web-2', 'web');
    await upload([item('past', clock.now - 1000), item('soon', clock.now + hour)]);
    const scheduler = fakeScheduler();
    // Both already queued by the upload; reset to check the selection.
    await db.execute('UPDATE push_items SET queued_at = NULL');
    await upload([item('other', clock.now + hour)], 'web-2');
    await db.execute('UPDATE push_items SET queued_at = NULL');
    expect(await queueDueItems(db, scheduler, clock.now, 'web')).toBe(1);
    expect(scheduler.queued.map((q) => q.msg.key)).toEqual(['soon']);
    expect(await queueDueItems(db, scheduler, clock.now)).toBe(1);
    expect(scheduler.queued.map((q) => q.msg.key)).toEqual(['soon', 'other']);
  });

  it('a failed enqueue leaves the item for the next try', async () => {
    const { upload, item, clock, db } = await ready();
    await upload([item('a', clock.now + hour)]);
    await db.execute('UPDATE push_items SET queued_at = NULL');
    const broken = { enqueue: async () => { throw new Error('queue down'); } };
    await expect(queueDueItems(db, broken, clock.now)).rejects.toThrow();
    const scheduler = fakeScheduler();
    expect(await queueDueItems(db, scheduler, clock.now)).toBe(1);
  });
});
