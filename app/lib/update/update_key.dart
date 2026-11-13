/// The public half of the key that signs Taskwise releases (M12). The
/// release workflow signs `SHA256SUMS` with the private half (GitHub secret
/// `UPDATE_SIGNING_KEY`); the app installs only files listed in a correctly
/// signed `SHA256SUMS`. See docs/updates.md, including what to do if the
/// key is ever replaced.
///
/// Raw 32-byte Ed25519 public key, base64. A build can use another key with
/// `--dart-define=TASKWISE_UPDATE_KEY=<base64>` (tests and forks).
const updatePublicKey = String.fromEnvironment(
  'TASKWISE_UPDATE_KEY',
  defaultValue: 'AAqRJmwD356s/WkCXZSeaAm9/quKx/2z5cRXyITMtvg=',
);

/// Where Taskwise looks for new versions: the newest published release.
/// `--dart-define=TASKWISE_UPDATE_URL=<url>` points it elsewhere (tests).
const latestReleaseUrl = String.fromEnvironment(
  'TASKWISE_UPDATE_URL',
  defaultValue: 'https://api.github.com/repos/Krkr8/taskwise/releases/latest',
);
