import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

import 'openai_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String _baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.deepseek.com',
  );
  String _apiKey = const String.fromEnvironment(
    'API_KEY',
    defaultValue: 'sk-9377402d779d4d3192d37b09dc7a1cbf',
  );
  String _modelName = const String.fromEnvironment(
    'MODEL_NAME',
    defaultValue: 'deepseek-v4-flash',
  );
  int _providerKey = 0;

  LlmProvider _createProvider() {
    return OpenAIProvider(
      baseUrl: _baseUrl,
      apiKey: _apiKey,
      model: _modelName,
    );
  }

  void _showSettings() {
    final urlController = TextEditingController(text: _baseUrl);
    final keyController = TextEditingController(text: _apiKey);
    final modelController = TextEditingController(text: _modelName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'API Base URL',
                  hintText: 'https://api.deepseek.com',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'sk-...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelController,
                decoration: const InputDecoration(
                  labelText: 'Model Name',
                  hintText: 'deepseek-v4-flash',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _baseUrl = urlController.text.trim();
                _apiKey = keyController.text.trim();
                _modelName = modelController.text.trim();
                _providerKey++;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat ($_modelName)'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: LlmChatView(
        key: ValueKey(_providerKey),
        provider: _createProvider(),
        onErrorCallback: (context, error) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Error'),
                ],
              ),
              content: SingleChildScrollView(
                child: SelectableText(
                  error.message.isEmpty ? error.toString() : error.message,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
        suggestions: const [
          'What is 42 * 15?',
          'Calculate (12 + 8) * 3',
          'Explain quantum computing in simple terms',
          'Write a haiku about coding',
        ],
        welcomeMessage: 'Hello! I\'m your AI assistant. You can type a message, use voice input, or attach images/files.',
      ),
    );
  }
}
