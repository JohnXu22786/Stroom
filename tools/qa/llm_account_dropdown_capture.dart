import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/widgets/constrained_text.dart';

const _accounts = [
  'Compte local de démonstration avec un nom très long pour tester la révélation',
  'Compte court',
];
const _models = [
  'Modèle amont local avec un nom très long pour tester la révélation',
  'Modèle court',
];

void main() {
  final query = Uri.base.queryParameters;
  final scale = double.tryParse(query['scale'] ?? '') ?? 1;
  final brightness =
      query['theme'] == 'dark' ? Brightness.dark : Brightness.light;
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(useMaterial3: true, brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: query['motion'] == 'off',
        ),
        child: child!,
      ),
      home: const _DropdownCapturePage(),
    ),
  );
}

class _DropdownCapturePage extends StatefulWidget {
  const _DropdownCapturePage();

  @override
  State<_DropdownCapturePage> createState() => _DropdownCapturePageState();
}

class _DropdownCapturePageState extends State<_DropdownCapturePage> {
  String _account = _accounts.first;
  String _model = _models.first;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Ajouter un membre au groupe',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          initialValue: _account,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'Compte'),
                          items: [
                            for (final account in _accounts)
                              DropdownMenuItem(
                                value: account,
                                child: ConstrainedText(
                                  account,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  useNaturalWidthLayout: true,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _account = value);
                          },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _model,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Modèle amont',
                          ),
                          items: [
                            for (final model in _models)
                              DropdownMenuItem(
                                value: model,
                                child: ConstrainedText(
                                  model,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  useNaturalWidthLayout: true,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _model = value);
                          },
                        ),
                        const SizedBox(height: 8),
                        const TextField(
                          decoration: InputDecoration(
                            labelText: 'Référence locale',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {},
                              child: const Text('Annuler'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () {},
                              child: const Text('Ajouter'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
