import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/notifications/time_zones.dart';

void main() {
  final from = DateTime.utc(2026, 11, 28, 10, 30);

  bool same(String a, String b, [DateTime? at]) =>
      sameTimeZones(a, b, from: at ?? from);

  test('zones with the same offsets all along count as the same', () {
    expect(same('Asia/Riyadh', 'Asia/Baghdad'), isTrue);
    expect(same('Asia/Kolkata', 'Asia/Calcutta'), isTrue);
    expect(same('Europe/London', 'Europe/Lisbon'), isTrue);
    expect(same('Europe/Berlin', 'Europe/Berlin'), isTrue);
  });

  test('zones whose daylight saving differs are not the same', () {
    // The same offset in winter, but Berlin moves its clocks in March:
    // from late February the 60 days include the change.
    expect(
      same('Europe/Berlin', 'Africa/Lagos', DateTime.utc(2027, 2, 20)),
      isFalse,
    );
    expect(
      same('Europe/Berlin', 'Africa/Lagos', DateTime.utc(2026, 7, 1)),
      isFalse,
    );
    // From late November the 60 days are all winter: no difference yet.
    expect(same('Europe/Berlin', 'Africa/Lagos'), isTrue);
    expect(same('Asia/Tokyo', 'Asia/Baghdad'), isFalse);
  });

  test('an unknown name is never the same', () {
    expect(same('Mars/Olympus', 'Asia/Baghdad'), isFalse);
    expect(same('Asia/Baghdad', 'Not/AZone'), isFalse);
  });
}
