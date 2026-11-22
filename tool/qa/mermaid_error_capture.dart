import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/mermaid_render_widget.dart';

const _longDiagnostic =
    '''The Mermaid engine could not load its renderer after repeated attempts. The browser rejected the CDN response because its certificate chain could not be verified by the system trust store. Check the network connection, proxy configuration, and device clock, then retry. If the problem continues, use the source button to inspect or save the Mermaid text before contacting support. Renderer request: https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js. Browser detail: net::ERR_CERT_AUTHORITY_INVALID. Diagnostic reference: MERMAID-LOAD-2026-11-21-7C91.''';
const _shortDiagnostic = 'The renderer could not load the page.';

void main() {
  final compact = Uri.base.queryParameters['compact'] == '1';
  runApp(_CaptureApp(compact: compact));
}

class _CaptureApp extends StatelessWidget {
  const _CaptureApp({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'US'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: child!,
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFFF2F3F5),
        body: SafeArea(
          child: compact
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      height: 112,
                      width: double.infinity,
                      child: const MermaidRenderWidget(
                        mermaidCode: 'graph TD\nA-->B',
                        testOnlyInitialErrorMessage: _shortDiagnostic,
                      ),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 500,
                    child: const MermaidRenderWidget(
                      mermaidCode: 'graph TD\nA-->B',
                      testOnlyInitialErrorMessage: _longDiagnostic,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
