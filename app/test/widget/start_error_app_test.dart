import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/ui/shared/common/start_error_app.dart';

void main() {
  testWidgets('says the start failed and reloads once', (tester) async {
    var reloads = 0;
    await tester.pumpWidget(
      StartErrorApp(onReload: () => reloads++, locale: const Locale('en')),
    );

    expect(
      find.text("Taskwise couldn't start in this browser"),
      findsOneWidget,
    );
    expect(
      find.text('Reload the page. If it keeps happening, try another browser.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reload'));
    await tester.pump();
    expect(reloads, 1);
  });

  testWidgets('says it in Arabic', (tester) async {
    var reloads = 0;
    await tester.pumpWidget(
      StartErrorApp(onReload: () => reloads++, locale: const Locale('ar')),
    );

    expect(find.text('تعذّر تشغيل Taskwise في هذا المتصفح'), findsOneWidget);
    expect(
      find.text('أعد تحميل الصفحة. إن تكرّر ذلك، جرّب متصفحًا آخر.'),
      findsOneWidget,
    );
    expect(
      Directionality.of(tester.element(find.text('أعد التحميل'))),
      TextDirection.rtl,
    );
    await tester.tap(find.text('أعد التحميل'));
    await tester.pump();
    expect(reloads, 1);
  });
}
