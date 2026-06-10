import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/widgets/info_row.dart';

void main() {
  group('InfoRow', () {
    testWidgets('renders label and value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfoRow(label: '类型', value: '文档 (application/pdf)'),
          ),
        ),
      );

      expect(find.text('类型'), findsOneWidget);
      expect(find.text('文档 (application/pdf)'), findsOneWidget);
    });

    testWidgets('renders with long value', (tester) async {
      final longPath = 'C:\\very\\long\\path\\to\\a\\file\\document.pdf';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfoRow(label: '路径', value: longPath),
          ),
        ),
      );

      expect(find.text('路径'), findsOneWidget);
      expect(find.text(longPath), findsOneWidget);
    });
  });
}
