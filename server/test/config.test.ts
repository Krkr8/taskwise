import { describe, expect, it } from 'vitest';

import { configFromEnv } from '../src/config.js';
import { Database } from '../src/db/client.js';
import { NoopScheduler } from '../src/push/due.js';
import { WebPushSender } from '../src/push/web_push_sender.js';
import { appFromConfig } from '../src/wiring.js';

const vapidEnv = {
  VAPID_PUBLIC_KEY: 'BPublicKey',
  VAPID_PRIVATE_KEY: 'privateKey',
  VAPID_SUBJECT: 'mailto:reminders@example.com',
};

describe('push configuration', () => {
  it('is on when all three VAPID variables are set', () => {
    expect(configFromEnv(vapidEnv).vapid).toEqual({
      publicKey: 'BPublicKey',
      privateKey: 'privateKey',
      subject: 'mailto:reminders@example.com',
    });
  });

  it('is off when any one of them is missing or empty', () => {
    for (const name of Object.keys(vapidEnv)) {
      expect(configFromEnv({ ...vapidEnv, [name]: undefined }).vapid).toBeUndefined();
      expect(configFromEnv({ ...vapidEnv, [name]: '  ' }).vapid).toBeUndefined();
    }
    expect(configFromEnv({}).vapid).toBeUndefined();
  });

  it('the app gets push (VAPID public key, Web Push sender) only when configured', () => {
    const off = appFromConfig(configFromEnv({}), Database.fromUrl(':memory:'), new NoopScheduler());
    const on = appFromConfig(configFromEnv(vapidEnv), Database.fromUrl(':memory:'), new NoopScheduler());
    expect(off.push).toBeUndefined();
    expect(on.push?.publicKey).toBe('BPublicKey');
    expect(on.push?.sender).toBeInstanceOf(WebPushSender);
    expect(on.push?.scheduler).toBeInstanceOf(NoopScheduler);
  });
});
