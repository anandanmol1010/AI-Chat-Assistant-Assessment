import 'package:ai_chat_assistant/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('launches the app shell', (tester) async {
    await tester.pumpWidget(const AiChatAssistantApp());
    expect(find.text('Conversations'), findsOneWidget);
  });
}
