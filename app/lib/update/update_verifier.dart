import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import 'update_key.dart';

/// A download that must not be installed: a bad signature, a file missing
/// from `SHA256SUMS`, or a file whose SHA-256 doesn't match.
class UpdateVerificationException implements Exception {
  const UpdateVerificationException(this.message);

  final String message;

  @override
  String toString() => 'UpdateVerificationException: $message';
}

/// Checks that update files come from Taskwise's releases.
class UpdateVerifier {
  UpdateVerifier({List<int>? publicKey})
    : _publicKey = SimplePublicKey(
        publicKey ?? base64Decode(updatePublicKey),
        type: KeyPairType.ed25519,
      );

  final SimplePublicKey _publicKey;

  /// Returns the hashes in [sums] (`SHA256SUMS`) if [signature] is its valid
  /// Ed25519 signature; throws [UpdateVerificationException] otherwise.
  Future<Map<String, String>> verifiedSums(
    List<int> sums,
    List<int> signature,
  ) async {
    if (signature.length != 64) {
      throw const UpdateVerificationException('Signature has the wrong size');
    }
    final ok = await Ed25519().verify(
      sums,
      signature: Signature(signature, publicKey: _publicKey),
    );
    if (!ok) {
      throw const UpdateVerificationException('Signature does not match');
    }
    return parseSha256Sums(utf8.decode(sums, allowMalformed: true));
  }

  /// Throws unless [actualHex] is the hash [sums] lists for [fileName].
  static void checkHash(
    Map<String, String> sums,
    String fileName,
    String actualHex,
  ) {
    final expected = sums[fileName];
    if (expected == null) {
      throw UpdateVerificationException('$fileName is not in SHA256SUMS');
    }
    if (expected != actualHex.toLowerCase()) {
      throw UpdateVerificationException('$fileName has the wrong SHA-256');
    }
  }
}

/// SHA-256 of a stream of bytes, as lower-case hex.
class Sha256Accumulator {
  final _sink = Sha256().newHashSink();

  void add(List<int> chunk) => _sink.add(chunk);

  Future<String> close() async {
    _sink.close();
    final hash = await _sink.hash();
    return [for (final b in hash.bytes) b.toRadixString(16).padLeft(2, '0')]
        .join();
  }
}
