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
      const [
        'FFmpeg shared libraries (Linux, Windows, Android, Apple)',
      ],
      await rootBundle.loadString(
        'assets/vendor/native/ffmpeg-COPYING.LGPLv2.1',
      ),
    );

    yield LicenseEntryWithLineBreaks(
      const ['libass (Windows, Android, macOS; observed runtime)'],
      await rootBundle.loadString('assets/vendor/native/libass-COPYING'),
    );

    yield LicenseEntryWithLineBreaks(
      const ['dav1d (macOS framework slice; observed runtime)'],
      await rootBundle.loadString('assets/vendor/native/dav1d-COPYING'),
    );

    yield LicenseEntryWithLineBreaks(
      const ['mdk-braw (Linux, Windows, macOS; observed runtime plugins)'],
      await rootBundle.loadString('assets/vendor/native/mdk-braw-LICENSE'),
    );

    yield LicenseEntryWithLineBreaks(
      const ['mdk-r3d (Linux, Windows, macOS; observed runtime plugins)'],
      await rootBundle.loadString('assets/vendor/native/mdk-r3d-LICENSE'),
    );

    yield LicenseEntryWithLineBreaks(
      const ['LLVM libc++ (Linux, Android)'],
      await rootBundle.loadString(
        'assets/vendor/native/llvm-libcxx-LICENSE.TXT',
      ),
    );

    yield LicenseEntryWithLineBreaks(
      const [
        'desugar_jdk_libs 2.1.4 (Android; GPLv2 with Classpath Exception)',
      ],
      await rootBundle.loadString(
        'assets/vendor/native/desugar-2.1.4-LICENSE.txt',
      ),
    );

    yield LicenseEntryWithLineBreaks(
      const ['desugar_jdk_libs 2.1.4 additional licensing information'],
      await rootBundle.loadString(
        'assets/vendor/native/desugar-2.1.4-ADDITIONAL_LICENSE_INFO.txt',
      ),
    );

    yield LicenseEntryWithLineBreaks(
      const [
        'AndroidX, Material, and Kotlinx Coroutines (Android, v0.5.0-rc.1)',
      ],
      await rootBundle.loadString(
        'assets/vendor/native/android-maven-runtime-APACHE-2.0.txt',
      ),
    );

    yield LicenseEntryWithLineBreaks(
      const [
        'MDK CocoaPods 0.36.0 text (Apple; type Commercial; scope unresolved)',
      ],
      await rootBundle.loadString(
        'assets/vendor/native/mdk-cocoapods-0.36.0-license-text.txt',
      ),
    );

    yield LicenseEntryWithLineBreaks(
      const ['Anki sync protocol schemas (AGPL-3.0-or-later)'],
      await rootBundle.loadString(
        'assets/vendor/native/anki-sync-proto-AGPL-3.0-or-later.txt',
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
