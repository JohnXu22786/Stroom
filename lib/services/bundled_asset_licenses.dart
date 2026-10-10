import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the locally bundled vendor licenses to Flutter's Open Source Licenses
/// page. Package licenses continue to come from Flutter's generated registry.
void registerBundledAssetLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const ['MathLive 0.111.0'],
      await rootBundle.loadString('assets/vendor/mathlive/LICENSE.txt'),
    );

    yield LicenseEntryWithLineBreaks(
      const ['KaTeX fonts (katex 0.16.22)'],
      await rootBundle.loadString('assets/vendor/mathlive/fonts/LICENSE.txt'),
    );

    yield LicenseEntryWithLineBreaks(
      const ['flutter_math_fork 0.7.4 KaTeX fonts'],
      await rootBundle.loadString(
        'assets/vendor/flutter_math_fork-katex-fonts-LICENSE.txt',
      ),
    );

    yield LicenseEntryWithLineBreaks(
      const ['Mermaid 11.16.1'],
      await rootBundle.loadString('assets/vendor/mermaid/LICENSE.txt'),
    );

    final mermaidSource =
        await rootBundle.loadString('assets/vendor/mermaid.min.js');
    final bundledNotices = RegExp(
      r'/\*!\s*Bundled license information:\s*([\s\S]*?)\*/',
    )
        .allMatches(mermaidSource)
        .map((match) => match.group(1)!.trim())
        .where((notice) => notice.isNotEmpty)
        .toList(growable: false);

    if (bundledNotices.isNotEmpty) {
      yield LicenseEntryWithLineBreaks(
        const ['Mermaid 11.16.1 bundled dependency notices'],
        bundledNotices.join('\n\n'),
      );
    }
  });
}
