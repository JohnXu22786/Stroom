import 'package:flutter/material.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() => runApp(const _OverwriteButtonPreview());

class _OverwriteButtonPreview extends StatelessWidget {
  const _OverwriteButtonPreview();

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('de', 'DE'),
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          cardTheme: const CardThemeData(elevation: 0),
          appBarTheme: const AppBarTheme(surfaceTintColor: Colors.transparent),
        ),
        home: Scaffold(
          backgroundColor: const Color(0xfff8f8ff),
          appBar: AppBar(title: const Text('Anki-Synchronisierung')),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: 280,
              child: FilledButton.tonalIcon(
                onPressed: () {},
                icon: const Icon(Icons.cloud_upload_outlined),
                label: ConstrainedText(
                  'Serverdaten durch lokale Daten ersetzen',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      );
}
