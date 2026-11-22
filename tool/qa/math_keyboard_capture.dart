import 'package:flutter/material.dart';
import 'package:stroom/widgets/math_keyboard.dart';

void main() {
  final query = Uri.base.queryParameters;
  final brightness =
      query['theme'] == 'dark' ? Brightness.dark : Brightness.light;
  final textScale = double.tryParse(query['scale'] ?? '') ?? 1;
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode:
          brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const ListTile(
                title: Text('数学公式'),
                subtitle: Text('本地预览 · 当前公式与结构位置'),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    r'\sqrt{a^2 + b^2}',
                    style: TextStyle(fontSize: 28),
                  ),
                ),
              ),
              SizedBox(
                height: 408,
                child: MathKeyboard(
                  activeLabel: '公式 12345678901234567890',
                  location: '根式 / 第 3 层 / 嵌套项',
                  onCommand: (_, _) async {},
                  onDismiss: () {},
                  onPlot: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
