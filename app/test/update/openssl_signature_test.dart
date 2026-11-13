import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/update/update_verifier.dart';

/// fixtures/ holds a SHA256SUMS signed by tool/sign_release.sh (openssl) with
/// the real release key: the app's built-in key must accept it, so the
/// release workflow and the app agree on the format.
void main() {
  const dir = 'test/update/fixtures';

  test('the app verifies what the release workflow signs', () async {
    final sums = await File('$dir/SHA256SUMS').readAsBytes();
    final signature = await File('$dir/SHA256SUMS.sig').readAsBytes();
    final verified = await UpdateVerifier().verifiedSums(sums, signature);

    final apk = await File('$dir/taskwise-1.1.0-android.apk').readAsBytes();
    final hash = Sha256Accumulator()..add(apk);
    UpdateVerifier.checkHash(
      verified,
      'taskwise-1.1.0-android.apk',
      await hash.close(),
    );
  });

  test('a changed list is refused', () async {
    final sums = [...await File('$dir/SHA256SUMS').readAsBytes()];
    sums[0] ^= 1;
    final signature = await File('$dir/SHA256SUMS.sig').readAsBytes();
    expect(
      () => UpdateVerifier().verifiedSums(sums, signature),
      throwsA(isA<UpdateVerificationException>()),
    );
  });
}
