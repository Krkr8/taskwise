import { hash, verify } from '@node-rs/argon2';

// argon2id with the OWASP-recommended minimum (19 MiB, 2 passes). The
// parameters are stored inside each hash, so they can be raised later.
const options = { memoryCost: 19_456, timeCost: 2, parallelism: 1 } as const;

export const minPasswordLength = 10;

export function hashPassword(password: string): Promise<string> {
  return hash(password, options);
}

export async function verifyPassword(
  passwordHash: string,
  password: string,
): Promise<boolean> {
  try {
    return await verify(passwordHash, password);
  } catch {
    return false;
  }
}

let dummyHash: Promise<string> | undefined;

/**
 * Spends the same time as a real check when there is no account to check
 * against, so response times don't reveal whether a username exists.
 */
export async function verifyDummy(password: string): Promise<void> {
  dummyHash ??= hashPassword('taskwise-dummy-password');
  await verifyPassword(await dummyHash, password);
}
