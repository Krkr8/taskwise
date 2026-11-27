import { createECDH, randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';
import type { IncomingHttpHeaders } from 'node:http';
import { Agent, createServer, type Server } from 'node:https';
import type { AddressInfo } from 'node:net';

import { generateVAPIDKeys } from 'web-push';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';

import type { PushDeps } from '../src/context.js';
import { pushDeliveryHandler, parsePushMessage } from '../src/push/consumer.js';
import { deliverPushItem } from '../src/push/deliver.js';
import type { PushMessage } from '../src/push/schedule.js';
import { putSubscription, type PushSubscriptionRow } from '../src/push/store.js';
import {
  pushTopic,
  QueuePushScheduler,
  queueSendOptions,
} from '../src/push/vercel_queue.js';
import { WebPushSender } from '../src/push/web_push_sender.js';
import { testApp } from './helpers.js';

const hour = 60 * 60 * 1000;
const vapidKeys = generateVAPIDKeys();
const vapid = {
  publicKey: vapidKeys.publicKey,
  privateKey: vapidKeys.privateKey,
  subject: 'mailto:reminders@example.com',
};

/** A browser's subscription keys: a P-256 public key and 16 random bytes. */
function browserKeys() {
  const ecdh = createECDH('prime256v1');
  ecdh.generateKeys();
  return {
    p256dh: ecdh.getPublicKey().toString('base64url'),
    auth: randomBytes(16).toString('base64url'),
  };
}

/** A fake push service: the path picks the answer, e.g. /status/410/x. */
const fixture = (name: string) => readFileSync(new URL(`./fixtures/${name}`, import.meta.url));
const tls = { key: fixture('localhost-key.pem'), cert: fixture('localhost-cert.pem') };
const agent = new Agent({ rejectUnauthorized: false });
let pushService: Server;
let base: string;
const received: { path: string; headers: IncomingHttpHeaders; bytes: number }[] = [];

beforeAll(async () => {
  pushService = createServer(tls, (req, res) => {
    const chunks: Buffer[] = [];
    req.on('data', (c: Buffer) => chunks.push(c));
    req.on('end', () => {
      const path = req.url ?? '/';
      received.push({ path, headers: req.headers, bytes: Buffer.concat(chunks).length });
      const status = Number(/^\/status\/(\d+)/.exec(path)?.[1] ?? 201);
      res.writeHead(status).end();
    });
  });
  await new Promise<void>((resolve) => pushService.listen(0, '127.0.0.1', resolve));
  base = `https://127.0.0.1:${(pushService.address() as AddressInfo).port}`;
});

afterAll(async () => {
  await new Promise((resolve) => pushService.close(resolve));
});

function subscriptionAt(path: string, deviceId = 'web'): PushSubscriptionRow {
  return { endpoint: `${base}${path}`, deviceId, ...browserKeys(), createdAt: 1 };
}

describe('WebPushSender', () => {
  const sender = new WebPushSender(vapid, agent);

  it("returns 'ok' for 201", async () => {
    expect(await sender.send(subscriptionAt('/status/201/a'), '{"title":"x"}')).toBe('ok');
  });

  it("returns 'gone' for 404 and 410", async () => {
    expect(await sender.send(subscriptionAt('/status/404/a'), '{}')).toBe('gone');
    expect(await sender.send(subscriptionAt('/status/410/a'), '{}')).toBe('gone');
  });

  it('throws for other errors, without the endpoint in the message', async () => {
    const sub = subscriptionAt('/status/500/secret-endpoint');
    const error = await sender.send(sub, '{}').then(
      () => undefined,
      (e: unknown) => e as Error & { statusCode?: number },
    );
    expect(error).toBeInstanceOf(Error);
    expect(error!.statusCode).toBe(500);
    expect(error!.message).not.toContain('secret-endpoint');
    await expect(sender.send(subscriptionAt('/status/429/a'), '{}')).rejects.toThrow();
  });

  it('sends an encrypted, VAPID-signed push: TTL 1 hour, urgency high, no topic', async () => {
    received.length = 0;
    await sender.send(subscriptionAt('/status/201/headers'), '{"title":"Secret title"}');
    const { headers, bytes } = received[0]!;
    expect(headers['ttl']).toBe('3600');
    expect(headers['urgency']).toBe('high');
    expect(headers['topic']).toBeUndefined();
    expect(headers['content-encoding']).toBe('aes128gcm');
    expect(headers['authorization']).toMatch(/^vapid t=.+, k=/);
    expect(bytes).toBeGreaterThan(0);
    expect(JSON.stringify(headers)).not.toContain('Secret title');
  });
});

describe('delivery with the real sender (Review Focus 3)', () => {
  async function ready() {
    const sender = new WebPushSender(vapid, agent);
    const queued: PushMessage[] = [];
    const push: PushDeps = {
      publicKey: vapid.publicKey,
      scheduler: { enqueue: async (msg) => void queued.push(msg) },
      sender,
    };
    const t = await testApp(undefined, { push });
    await t.setup();
    const laptop = await t.login('laptop', 'linux');
    const web = await t.login('web', 'web');
    // Straight into the database (the route is tested in push.test.ts).
    const subscribe = async (path: string) => {
      const keys = browserKeys();
      await putSubscription(t.db, 'web', { endpoint: `${base}${path}`, ...keys }, t.clock.now);
      return { status: 204 };
    };
    const upload = (key: string, fireAt: number) =>
      t.request('PUT', '/push/plan/web', {
        token: laptop,
        body: { items: [{ key, fireAt, taskId: 't', title: 'Title', body: 'Body' }] },
      });
    const pushEnabled = async () =>
      (await t.request('GET', '/devices', { token: laptop })).body.devices.find(
        (d: { id: string }) => d.id === 'web',
      ).pushEnabled as boolean | undefined;
    const endpoints = async () =>
      (await t.db.execute('SELECT endpoint FROM push_subscriptions ORDER BY endpoint')).rows.map(
        (r) => String(r['endpoint']).slice(base.length),
      );
    return { ...t, sender, queued, subscribe, upload, pushEnabled, endpoints };
  }

  it("a 'gone' subscription is deleted; the device's others still get the push", async () => {
    const t = await ready();
    expect((await t.subscribe('/status/410/old')).status).toBe(204);
    expect((await t.subscribe('/status/201/new')).status).toBe(204);
    await t.upload('a', t.clock.now + hour);
    received.length = 0;
    expect(await deliverPushItem(t.db, t.sender, t.queued[0]!, t.clock.now + hour)).toBe('sent');
    expect(received.map((r) => r.path).sort()).toEqual(['/status/201/new', '/status/410/old']);
    expect(await t.endpoints()).toEqual(['/status/201/new']);
    expect(await t.pushEnabled()).toBe(true);
  });

  it('pushEnabled turns false when the last subscription is gone', async () => {
    const t = await ready();
    await t.subscribe('/status/404/only');
    await t.upload('a', t.clock.now + hour);
    expect(await deliverPushItem(t.db, t.sender, t.queued[0]!, t.clock.now + hour)).toBe('skipped');
    expect(await t.endpoints()).toEqual([]);
    expect(await t.pushEnabled()).toBeUndefined();
  });
});

describe('Vercel Queues scheduler', () => {
  const msg: PushMessage = { deviceId: 'web', key: 'k1', fireAt: 1_800_000_000_000 };

  it('sends to taskwise-push with the delay, a retention past it and an idempotency key', async () => {
    const calls: unknown[][] = [];
    const scheduler = new QueuePushScheduler(async (...args) => {
      calls.push(args);
      return { messageId: 'm' };
    });
    await scheduler.enqueue(msg, 3600);
    expect(pushTopic).toBe('taskwise-push');
    expect(calls).toEqual([
      [
        'taskwise-push',
        msg,
        { delaySeconds: 3600, retentionSeconds: 7200, idempotencyKey: 'web:k1:1800000000000' },
      ],
    ]);
  });

  it('caps retention at 7 days', () => {
    expect(queueSendOptions(msg, 604800)).toMatchObject({
      delaySeconds: 604800,
      retentionSeconds: 604800,
    });
    expect(queueSendOptions(msg, 604000).retentionSeconds).toBe(604800);
  });

  it('keeps the idempotency key within 256 characters', () => {
    const long = { deviceId: 'd'.repeat(128), key: 'k'.repeat(200), fireAt: msg.fireAt };
    const key = queueSendOptions(long, 60).idempotencyKey;
    expect(key.length).toBeLessThanOrEqual(256);
    expect(queueSendOptions(long, 60).idempotencyKey).toBe(key);
    expect(queueSendOptions({ ...long, fireAt: msg.fireAt + 1 }, 60).idempotencyKey).not.toBe(key);
  });

  it('a failed send rejects, so queueDueItems unmarks the item', async () => {
    const scheduler = new QueuePushScheduler(async () => {
      throw new Error('400');
    });
    await expect(scheduler.enqueue(msg, 60)).rejects.toThrow();
  });
});

describe('queue consumer', () => {
  it('reads only well-formed messages', () => {
    expect(parsePushMessage({ deviceId: 'web', key: 'k', fireAt: 5 })).toEqual({
      deviceId: 'web',
      key: 'k',
      fireAt: 5,
    });
    expect(parsePushMessage('{"deviceId":"web","key":"k","fireAt":5}')).toEqual({
      deviceId: 'web',
      key: 'k',
      fireAt: 5,
    });
    for (const bad of [null, 'x', {}, { deviceId: 'web', key: 'k', fireAt: '5' }, { deviceId: 1, key: 'k', fireAt: 5 }]) {
      expect(parsePushMessage(bad)).toBeUndefined();
    }
  });

  it('delivers the item and logs the result without titles', async () => {
    const t = await testApp();
    await t.setup();
    await t.login('web', 'web');
    await t.db.execute({
      sql: `INSERT INTO push_items (device_id, key, fire_at, task_id, title, body, queued_at)
            VALUES ('web', 'k', ?, 't', 'Secret title', 'Secret body', 1)`,
      args: [t.clock.now],
    });
    await t.db.execute({
      sql: `INSERT INTO push_subscriptions (endpoint, device_id, p256dh, auth, created_at)
            VALUES ('https://push.example.com/secret-endpoint', 'web', 'p', 'a', 1)`,
      args: [],
    });
    const sent: string[] = [];
    const handler = pushDeliveryHandler({
      db: async () => t.db,
      sender: {
        send: async (_sub, payload) => {
          sent.push(payload);
          return 'ok';
        },
      },
      now: () => t.clock.now,
    });
    const lines: string[] = [];
    const spy = vi.spyOn(console, 'log').mockImplementation((line: string) => void lines.push(line));
    await handler({ deviceId: 'web', key: 'k', fireAt: t.clock.now }, { deliveryCount: 1 });
    await handler({ deviceId: 'web', key: 'k', fireAt: t.clock.now }, { deliveryCount: 2 });
    await handler({ nonsense: true }, { deliveryCount: 1 });
    spy.mockRestore();
    expect(sent).toHaveLength(1);
    const events = lines.map((l) => JSON.parse(l) as Record<string, unknown>);
    expect(events.filter((e) => e['event'] === 'push_delivery').map((e) => e['result'])).toEqual([
      'sent',
      'skipped',
    ]);
    expect(events.some((e) => e['event'] === 'push_bad_message')).toBe(true);
    for (const secret of ['Secret title', 'Secret body', 'secret-endpoint']) {
      expect(lines.join('\n')).not.toContain(secret);
    }
  });

  it('without push set up, a message is dropped (acknowledged), not retried', async () => {
    const t = await testApp();
    const handler = pushDeliveryHandler({ db: async () => t.db, sender: undefined, now: () => t.clock.now });
    const spy = vi.spyOn(console, 'log').mockImplementation(() => {});
    await expect(handler({ deviceId: 'web', key: 'k', fireAt: 1 }, { deliveryCount: 1 })).resolves.toBeUndefined();
    spy.mockRestore();
  });

  it('a failed send throws, so the queue retries', async () => {
    const t = await testApp();
    await t.setup();
    await t.login('web', 'web');
    await t.db.execute({
      sql: `INSERT INTO push_items (device_id, key, fire_at, task_id, title, body, queued_at)
            VALUES ('web', 'k', ?, 't', 'T', 'B', 1)`,
      args: [t.clock.now],
    });
    await t.db.execute(
      `INSERT INTO push_subscriptions (endpoint, device_id, p256dh, auth, created_at)
       VALUES ('https://push.example.com/x', 'web', 'p', 'a', 1)`,
    );
    const handler = pushDeliveryHandler({
      db: async () => t.db,
      sender: { send: async () => { throw new Error('down'); } },
      now: () => t.clock.now,
    });
    const spies = [
      vi.spyOn(console, 'log').mockImplementation(() => {}),
      vi.spyOn(console, 'error').mockImplementation(() => {}),
    ];
    await expect(handler({ deviceId: 'web', key: 'k', fireAt: t.clock.now }, { deliveryCount: 1 })).rejects.toThrow();
    for (const spy of spies) spy.mockRestore();
  });
});
