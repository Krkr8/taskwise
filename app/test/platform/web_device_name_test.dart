import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/platform/web_device_name.dart';

void main() {
  test('names the browser and the system', () {
    expect(
      webDeviceName(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
        'Mobile/15E148 Safari/604.1',
      ),
      'Safari on iPhone',
    );
    expect(
      webDeviceName(
        'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      ),
      'Chrome on Android',
    );
    expect(
      webDeviceName(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0',
      ),
      'Edge on Windows',
    );
    expect(
      webDeviceName(
        'Mozilla/5.0 (X11; Linux x86_64; rv:121.0) Gecko/20100101 '
        'Firefox/121.0',
      ),
      'Firefox on Linux',
    );
    expect(webDeviceName(''), 'Browser on device');
  });

  test('other browsers on iPhone are named after themselves', () {
    // Every iPhone browser says "Safari" in its user agent.
    expect(
      webDeviceName(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/121.0 '
        'Mobile/15E148 Safari/605.1.15',
      ),
      'Firefox on iPhone',
    );
    expect(
      webDeviceName(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/120.0.6099.119 '
        'Mobile/15E148 Safari/604.1',
      ),
      'Chrome on iPhone',
    );
    expect(
      webDeviceName(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
        'EdgiOS/120.0.2210.126 Mobile/15E148 Safari/605.1.15',
      ),
      'Edge on iPhone',
    );
  });
}
