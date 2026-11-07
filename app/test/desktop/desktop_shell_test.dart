import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/desktop/desktop_shell.dart';

void main() {
  group('DesktopShell.launchPath', () {
    test('uses the executable outside an AppImage', () {
      expect(
        DesktopShell.launchPath(const {}, '/opt/taskwise/taskwise'),
        '/opt/taskwise/taskwise',
      );
    });

    test('uses the AppImage file, not its temporary mount', () {
      expect(
        DesktopShell.launchPath(const {
          'APPIMAGE': '/home/me/Apps/Taskwise.AppImage',
        }, '/tmp/.mount_TaskwiXYZ/usr/bin/taskwise'),
        '/home/me/Apps/Taskwise.AppImage',
      );
    });

    test('ignores an empty APPIMAGE', () {
      expect(DesktopShell.launchPath(const {'APPIMAGE': ''}, '/x'), '/x');
    });
  });
}
