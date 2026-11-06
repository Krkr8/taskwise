import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/ui/shared/common/whole_words_text.dart';

void main() {
  Future<Text> shown(WidgetTester tester, double width, String text) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: width,
            child: WholeWordsText(
              text,
              style: const TextStyle(fontSize: 14),
              maxLines: 3,
            ),
          ),
        ),
      ),
    );
    return tester.widget<Text>(find.byType(Text));
  }

  testWidgets('wide enough: shown as it is', (tester) async {
    final text = await shown(tester, 400, 'Pay the electricity bill');
    expect(text.data, 'Pay the electricity bill');
    expect(text.textScaler!.scale(14), 14);
  });

  testWidgets('a word that only just does not fit: the text shrinks a bit', (
    tester,
  ) async {
    // The test font is 14 px per character: "bill" is 56 px.
    final text = await shown(tester, 50, 'Pay the bill');
    expect(text.data, 'Pay the bill');
    expect(text.textScaler!.scale(14), closeTo(14 * 50 / 56, 0.01));
  });

  testWidgets('a word far too long: cut short with an ellipsis, not split', (
    tester,
  ) async {
    final text = await shown(tester, 60, 'Pay the electricity bill');
    expect(text.data, startsWith('Pay the '));
    expect(text.data, contains('…'));
    expect(text.data, endsWith(' bill'));
    expect(text.data, isNot(contains('electricity')));
  });
}
