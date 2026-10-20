import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/main.dart';

void main() {
  testWidgets('placeholder home screen shows the app name', (tester) async {
    await tester.pumpWidget(const TaskwiseApp());

    expect(find.byType(PlaceholderHomePage), findsOneWidget);
    expect(find.text('Taskwise'), findsWidgets);
    expect(find.text('Coming soon: your tasks.'), findsOneWidget);
  });
}
