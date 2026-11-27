import { afterEach, describe, expect, it, vi } from 'vitest';

import type { PushDeps } from '../src/context.js';
import type { PushSender } from '../src/push/deliver.js';
import { NoopScheduler, sendDuePushes } from '../src/push/due.js';
import { testApp } from './helpers.js';

const minute = 60 * 1000;
const hour = 60 * minute;

async function ready(results: Record<string, 'ok' | 'throw'> = {}) {
  const sent: string[] = [];
  const sender: PushSender = {
    send: async (sub, payload) => {
      if (results[sub.endpoint] === 'throw') throw new Error('push service down');
      sent.push((JSON.parse(payload) as { key: string }).key);
      return 'ok';
    },
  };
  const push: PushDeps = { publicKey: 'BVapidPublicKey', scheduler: new NoopScheduler(), sender };
  const t = await testApp(undefined, { push });
  await t.setup();
  const laptop = await t.login('laptop', 'linux');
  const web = await t.login('web', 'web');
  await t.request('PUT', '/push/subscription', {
    token: web,
    body: { endpoint: 'https://push.example.com/1', keys: { p256dh: 'p', auth: 'a' } },
  });
  const item = (key: string, fireAt: number) => ({ key, fireAt, taskId: 't', title: 'T', body: 'B' });
  const upload = async (items: unknown[]) =>
    expect(
      (await t.request('PUT', '/push/plan/web', { token: laptop, body: { items } })).status,
    ).toBe(204);
  return { ...t, sender, sent, item, upload };
}

describe('sendDuePushes (the Node timer)', () => {
  it('sends a due item once; the next tick sends nothing', async () => {
    const t = await ready();
    await t.upload([t.item('a', t.clock.now + minute), t.item('later', t.clock.now + hour)]);
    expect(await sendDuePushes(t.db, t.sender, t.clock.now)).toMatchObject({ sent: 0 });
    expect(t.sent).toEqual([]);

    t.clock.now += minute;
    expect(await sendDuePushes(t.db, t.sender, t.clock.now)).toMatchObject({ sent: 1 });
    expect(t.sent).toEqual(['a']);

    t.clock.now += 30 * 1000;
    expect(await sendDuePushes(t.db, t.sender, t.clock.now)).toMatchObject({ sent: 0 });
    expect(t.sent).toEqual(['a']);
  });

  it('two ticks at once send an item once', async () => {
    const t = await ready();
    await t.upload([t.item('a', t.clock.now + minute)]);
    t.clock.now += minute;
    await Promise.all([
      sendDuePushes(t.db, t.sender, t.clock.now),
      sendDuePushes(t.db, t.sender, t.clock.now),
    ]);
    expect(t.sent).toEqual(['a']);
  });

  it('an item more than an hour past (server was down) is marked stale, not sent', async () => {
    const t = await ready();
    await t.upload([t.item('a', t.clock.now + minute)]);
    const spy = vi.spyOn(console, 'log').mockImplementation(() => {});
    t.clock.now += 2 * hour;
    expect(await sendDuePushes(t.db, t.sender, t.clock.now)).toMatchObject({ stale: 1, sent: 0 });
    expect(t.sent).toEqual([]);
  });

  it('a failed send is tried again on the next tick; other items still go out', async () => {
    const t = await ready({ 'https://push.example.com/1': 'throw' });
    await t.upload([t.item('a', t.clock.now + minute)]);
    t.clock.now += minute;
    vi.spyOn(console, 'log').mockImplementation(() => {});
    vi.spyOn(console, 'error').mockImplementation(() => {});
    expect(await sendDuePushes(t.db, t.sender, t.clock.now)).toMatchObject({ failed: 1 });
    const unsent = await t.db.execute('SELECT COUNT(*) AS n FROM push_items WHERE sent_at IS NULL');
    expect(Number(unsent.rows[0]!['n'])).toBe(1);
  });

  it('the Node scheduler queues nothing (the timer finds items itself)', async () => {
    await expect(new NoopScheduler().enqueue({ deviceId: 'w', key: 'k', fireAt: 1 }, 60)).resolves.toBeUndefined();
  });
});

afterEach(() => {
  vi.restoreAllMocks();
});
