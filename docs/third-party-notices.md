# Third-party license and provenance notes

Stroom's application license is AGPL-3.0; see the root [`LICENSE`](../LICENSE).

## Flutter and Dart packages

About > Open Source Licenses uses Flutter's `showLicensePage` and
`LicenseRegistry` to show licenses from the package graph resolved for the
build. This repository does not track `pubspec.lock`, so the exact direct and
transitive package versions cannot be reconstructed from `pubspec.yaml` alone.
This note does not duplicate or claim to enumerate that graph.

`fvp: ^0.37.3` is declared by Stroom. The [`fvp` 0.37.3 package archive](https://pub.dev/packages/fvp/versions/0.37.3)
is BSD-3-Clause licensed, and Flutter's generated package registry shows that
package license on the in-app page. That package license is separate from the
native runtime downloaded by FVP.

FVP 0.37.3's [CMake setup](https://github.com/wang-bin/fvp/blob/41dfb5487f835ba321cb73471c2a0a4e62382a6d/cmake/deps.cmake)
downloads MDK SDK archives from SourceForge's mutable
[`nightly` directory](https://sourceforge.net/projects/mdk-sdk/files/nightly/)
unless `FVP_DEPS_URL` is set. Stroom's release workflow does not set that
override, and this repository does not track `pubspec.lock`. The notices below
describe runtime packages inspected on 2026-10-11; they do not identify every
future release artifact or make the downloaded runtime reproducible.

| Native component | Observed runtime scope | License and retained text |
| --- | --- | --- |
| FFmpeg shared libraries | Linux, Windows, Android, and Apple (macOS plus iOS/Catalyst slices); build identity `git-2026-10-08-ec420ba-avbuild` | [LGPL-2.1-or-later](https://github.com/FFmpeg/FFmpeg/blob/ec420ba16172960f0009b8bdcc393688797bf8a6/COPYING.LGPLv2.1), copied to `assets/vendor/native/ffmpeg-COPYING.LGPLv2.1` |
| libass | Windows, Android, and macOS | [ISC](https://github.com/libass/libass/blob/f61db567e6593df3470e91594bcd4ad2d0473aff/COPYING), copied to `assets/vendor/native/libass-COPYING` |
| dav1d | macOS framework slice only | [BSD-2-Clause](https://github.com/videolan/dav1d/blob/99f3354ed0b9b4bf3c7c9347318dbcc522c94af5/COPYING), copied to `assets/vendor/native/dav1d-COPYING` |
| mdk-braw plugin | Linux, Windows, and macOS | [MIT](https://github.com/wang-bin/mdk-braw/blob/c05dedfd7407b54d831dd5484612627800e14fad/LICENSE), copied to `assets/vendor/native/mdk-braw-LICENSE` |
| mdk-r3d plugin | Linux, Windows, and macOS | [MIT](https://github.com/wang-bin/mdk-r3d/blob/17350174fbb64373ecbc9410faab39687eee7e07/LICENSE), copied to `assets/vendor/native/mdk-r3d-LICENSE` |
| LLVM libc++ | Linux `libc++.so.1` and Android `libc++_shared.so` | [Apache-2.0 WITH LLVM-exception](https://github.com/llvm/llvm-project/blob/611eee02d8a717ce6eb0cbe9d75268699321d352/libcxx/LICENSE.TXT), copied to `assets/vendor/native/llvm-libcxx-LICENSE.TXT` |

The Android SDK archive also contained `libdav1d.so`, but FVP's Android target
does not link it and no Stroom Android output confirmed that it is packaged.
It is therefore not listed as an Android runtime component. The separate
[`mdk-dav1d` wrapper](https://github.com/wang-bin/mdk-dav1d/blob/8f71de3a0c199fdc7c36316ae9bf043e5b3d4633/LICENSE)
has an MIT license, but no separate wrapper artifact was identified in the
inspected outputs; only the macOS `libdav1d.dylib` is confirmed here.

The inspected Windows SDK also contains `mdk-nvjp2k.dll`. Its
[upstream repository](https://github.com/wang-bin/mdk-nvjp2k) has no `LICENSE`
file or GitHub license metadata, so its terms are unresolved and are not
represented as a licensed component here. This is one reason this notice set
does not claim to identify the complete MDK runtime.

### MDK runtime terms and commercial use

The MDK core is binary-only in the inspected SDK packages, and the public MDK
SDK repository has no `LICENSE` file or GitHub license metadata. MDK's
[README](https://github.com/wang-bin/mdk-sdk/blob/f038eb2c67141e6d71ef067f11a9a3c68dd5ab95/README.md)
says Flutter users may use the bundled key without charge, including when
shipping commercial software. That addresses use and fees for the Flutter
integration; it does not provide the binary core's source or establish terms
for every platform archive.

The official [`mdk` 0.36.0 CocoaPods specification](https://cdn.jsdelivr.net/cocoa/Specs/5/1/3/mdk/0.36.0/mdk.podspec.json)
labels its license type `Commercial`, while the embedded license text grants
permission to use, modify, distribute, sublicense, and sell with the copyright
and permission notice retained. That exact text is shown on the in-app page
and stored at `assets/vendor/native/mdk-cocoapods-0.36.0-license-text.txt`.
This is evidence about that CocoaPods metadata, not proof that all platform
SDK archives have the same terms. The exact scope and source availability of
the MDK core remain unresolved; these findings do not establish an AGPL
conflict or a prohibition on commercial use.

### Anki protocol schemas

The sync protocol schemas under `lib/anki/sync/proto/anki/` are based on
[`ankitects/anki`](https://github.com/ankitects/anki/tree/d64812b680426c6dd55f9de7004070e560361d4b/proto/anki).
Against that upstream revision, 14 of the 15 local schema files match
byte-for-byte; `stats.proto` differs. The source headers retain the following
Ankitects attribution and license notice:

```text
// Copyright: Ankitects Pty Ltd and contributors
// License: GNU AGPL, version 3 or later; http://www.gnu.org/licenses/agpl.html
```

The in-app page repeats those lines and includes the AGPLv3 license text in
`assets/vendor/native/anki-sync-proto-AGPL-3.0-or-later.txt`.

AGPLv3 permits commercial use. It is copyleft: when distributing covered
object code, the distributor must provide corresponding source through one of
the methods allowed by §6; when users interact over a network with a modified
version, §13 requires a prominent offer to obtain its corresponding source.
AGPLv3 §13 also permits combining an AGPLv3-covered work with GPLv3-covered
code; the AGPL terms continue to apply to the AGPL-covered portion, while the
GPLv3 terms remain applicable to the GPLv3-covered portion.

## Android runtime dependencies observed in release APK v0.5.0-rc.1

The [Android release APK](https://github.com/JohnXu22786/Stroom/releases/tag/v0.5.0-rc.1)
(SHA-256 `0b3e3d179a49ffdc79be7b91cbdc1477d8e3f57acdb03bf7659adb508f837f12`)
contains `j$.util.DesugarTimeZone`. Neither the APK's standalone notices nor
Flutter's `NOTICES.Z` lists `desugar_jdk_libs`. Android Gradle configures
`coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`, and the
[Google Maven POM](https://dl.google.com/dl/android/maven2/com/android/tools/desugar_jdk_libs/2.1.4/desugar_jdk_libs-2.1.4.pom)
identifies GNU GPL version 2 with the Classpath Exception. The exact upstream
[`LICENSE`](https://github.com/google/desugar_jdk_libs/blob/50d9c1fb3e85fa4c00161525a45484f712c1f003/LICENSE)
and [`ADDITIONAL_LICENSE_INFO`](https://github.com/google/desugar_jdk_libs/blob/50d9c1fb3e85fa4c00161525a45484f712c1f003/ADDITIONAL_LICENSE_INFO)
from that 2.1.4 preparation commit are retained at
`assets/vendor/native/desugar-2.1.4-LICENSE.txt` and
`assets/vendor/native/desugar-2.1.4-ADDITIONAL_LICENSE_INFO.txt`, and
both are shown on Flutter's Open Source Licenses page.

The Classpath Exception permits linking independent modules with the library
in one executable under each module's own license terms. It does not extend to
code copied into or derived from the GPL-covered library. We found no AGPLv3
incompatibility for the independent-module linking path described by the
exception. The upstream additional licensing note warns that the broader
repository may include separate Apache-2.0 or FreeType programs. The inspected
`jdk11/src/java.base` subset at the preparation commit had no such headers;
that scoped check does not establish the license of every upstream source file.

The separate [`desugar_jdk_libs_configuration:2.1.4` POM](https://dl.google.com/dl/android/maven2/com/android/tools/desugar_jdk_libs_configuration/2.1.4/desugar_jdk_libs_configuration-2.1.4.pom)
identifies BSD-3-Clause. It is build-time configuration; its 29 class
descriptors were not found in this release APK, so it is not listed as bundled
runtime software.

The APK also contains AndroidX, Material Components, and Kotlinx Coroutines
Maven runtime artifacts. Inspection found 63 `META-INF/*.version` markers;
the POMs for 62 identified coordinates report Apache-2.0. The
`androidx.arch.core:core-runtime` marker contains malformed Gradle task text,
so its exact version cannot be recovered from this APK. Google's [Maven
metadata](https://dl.google.com/dl/android/maven2/androidx/arch/core/core-runtime/maven-metadata.xml)
currently lists 15 versions; the POMs for all 15 versions identify Apache-2.0.
The coordinate is included in the Apache-2.0 group despite its unknown exact
version. The APK embeds the Apache license from
`androidx.annotation`; the standard [Apache License 2.0
text](https://www.apache.org/licenses/LICENSE-2.0.txt) is retained at
`assets/vendor/native/android-maven-runtime-APACHE-2.0.txt` and registered for
the 62 identified artifacts and `androidx.arch.core:core-runtime`. Flutter's
`NOTICES.Z` does not enumerate these Maven dependencies.

This notice group describes only the dependencies observed in APK
`v0.5.0-rc.1`; the repository tracks neither a Gradle lockfile nor
`pubspec.lock`, so it does not claim to cover future build graphs. On newer
`main`, `wechat_assets_picker` 10.1.3 has a root Apache-2.0 license already
collected by Flutter. Its `photo_manager` dependency declares no Android Maven
runtime dependency and is not part of this observed APK group.

## iOS CocoaPods frameworks observed in release IPA v0.5.0-rc.1

The unsigned iOS release IPA (SHA-256
`8b2b7bff76d89b6fdcf68b13babf2405650020ee726352bf3249d2f55dd0e3ae`) contains
the following CocoaPods frameworks. Their embedded `Info.plist` versions and
the version-specific CocoaPods specs identify these licenses:

| Framework | IPA version | CocoaPods license |
| --- | --- | --- |
| [DKImagePickerController](https://cocoapods.org/pods/DKImagePickerController#4.3.9) | 4.3.9 | MIT |
| [DKPhotoGallery](https://cocoapods.org/pods/DKPhotoGallery#0.0.19) | 0.0.19 | MIT |
| [OrderedSet](https://cocoapods.org/pods/OrderedSet#6.0.3) | 6.0.3 | MIT |
| [SwiftyGif](https://cocoapods.org/pods/SwiftyGif#5.4.5) | 5.4.5 | MIT |
| [SDWebImage](https://cocoapods.org/pods/SDWebImage#5.21.7) | 5.21.7 | MIT |
| [libwebp](https://cocoapods.org/pods/libwebp#1.6.0) | 1.6.0 | BSD-3-Clause |

The five MIT license texts are retained together at
`assets/vendor/native/ios-cocoapods-MIT-licenses.txt`; the complete BSD-3-Clause
text for libwebp is at
`assets/vendor/native/libwebp-1.6.0-BSD-3-Clause.txt`. Flutter's generated
`NOTICES.Z` does not identify these native CocoaPods framework/version pairs.
It contains generic libwebp BSD notices, but does not attribute them to the
native `libwebp` 1.6.0 framework; the explicit entry supplies that link.

This is evidence from the named IPA only. That release contains FVP 0.36.1 and
MDK 0.39.0, separate from the FVP 0.37.3 / MDK CocoaPods 0.36.0 evidence above.
It does not identify current or future iOS build graphs.

## CatCatch behavior reference

The WebView hook and Dart media sniffer use the behavior of
[`xifangczy/cat-catch`](https://github.com/xifangczy/cat-catch) as a reference;
the upstream project is GPL-3.0. The local hook uses a WebView
`JavaScriptChannel`, and the Dart sniffer uses direct HTTP requests. A focused
comparison of the relevant upstream JavaScript and local implementations found
no substantial shared code block. This records the review evidence; it is not a
legal determination about derivative-work status or obligations.

## EV1 algorithm reference

[`Phantom1003/ev1-decoder`](https://github.com/Phantom1003/ev1-decoder) is cited
as an algorithm reference. At the time of this review, its GitHub repository
had no visible `LICENSE` file or GitHub license metadata. Stroom's local
implementation XORs the first 100 bytes by `0xFF` and remuxes the decoded FLV
to MP4; the reference script writes an FLV. The citation does not establish a
license grant, and this note does not determine whether any code was copied.

## Bundled vendor assets

- **flutter_math_fork 0.7.4** is declared as an app dependency. Its
  [0.7.4 package archive](https://pub.dev/packages/flutter_math_fork/versions/0.7.4)
  contains KaTeX TTF fonts and a separate MIT notice at
  `lib/katex_fonts/LICENSE` (Copyright (c) 2018 Khan Academy). Flutter's
  generated package registry covers the package-root Apache-2.0 license, but
  does not collect this nested notice because the package metadata does not
  declare it. Stroom retains the exact upstream notice at
  `assets/vendor/flutter_math_fork-katex-fonts-LICENSE.txt` and registers it as
  a separate entry on Flutter's license page.
- **MathLive 0.111.0** is bundled under `assets/vendor/mathlive`; its MIT
  license is retained at `assets/vendor/mathlive/LICENSE.txt` and registered
  with Flutter's license page. The 20 bundled `fonts/KaTeX_*.woff2` files
  match byte-for-byte the font files in the official npm tarballs for
  `mathlive@0.111.0` and `katex@0.16.22`. Both package releases declare MIT.
  The KaTeX copyright and MIT permission notice from `katex@0.16.22` is retained
  at `assets/vendor/mathlive/fonts/LICENSE.txt` and registered as a separate
  entry on Flutter's license page.
- **Mermaid 11.16.1** is MIT-licensed. The license from its
  [`mermaid@11.16.1` release](https://github.com/mermaid-js/mermaid/blob/mermaid%4011.16.1/LICENSE)
  is retained at `assets/vendor/mermaid/LICENSE.txt`. The SHA-256 of the
  checked-in `assets/vendor/mermaid.min.js` matches the exact
  [`mermaid@11.16.1` npm tarball](https://registry.npmjs.org/mermaid/-/mermaid-11.16.1.tgz).
  Its source map identifies 59 bundled package/version entries. Their complete
  upstream license files are retained in
  `assets/vendor/mermaid/THIRD-PARTY-LICENSES.txt` and shown on the in-app
  license page: 22 MIT, 31 ISC, five BSD-3-Clause, and DOMPurify 3.4.0 under
  `(MPL-2.0 OR Apache-2.0)`. Both full license alternatives for DOMPurify are
  included. `khroma` 2.1.0 omits license metadata from its package JSON, but its
  npm tarball contains an MIT license, which is retained and identified in the
  corpus. These entries describe the checked-in Mermaid bundle and do not
  claim license coverage for future bundle versions. The in-app page also keeps
  Mermaid's embedded bundled-license comment block as a separate attribution
  entry; it includes additional MIT attributions for code embedded within
  Cytoscape (Promises/A+, jQuery event handling, Bezier curves, and Runge-Kutta
  spring physics).
