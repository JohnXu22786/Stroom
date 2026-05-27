import 'package:flutter_test/flutter_test.dart';
import 'package:demo5_flutter_ai_toolkit/main.dart';

void main() {
  testWidgets('App renders chat screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatApp());
    // AppBar shows the default model name
    expect(find.text('Chat (deepseek-v4-flash)'), findsOneWidget);
    // Welcome message is rendered
    expect(
      find.text(
        'Hello! I\'m your AI assistant. You can type a message, use voice input, or attach images/files.',
      ),
      findsOneWidget,
    );
  });
}
