import 'package:flutter/material.dart';

void main() => runApp(const AiChatAssistantApp());

class AiChatAssistantApp extends StatelessWidget {
  const AiChatAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat Assistant',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF206B54)),
      home: Scaffold(appBar: AppBar(title: const Text('AI Chat Assistant'))),
    );
  }
}
