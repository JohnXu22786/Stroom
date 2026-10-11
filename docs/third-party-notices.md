# Third-party license and provenance notes

Stroom's application license is AGPL-3.0; see the root [`LICENSE`](../LICENSE).

## Flutter and Dart packages

About > Open Source Licenses uses Flutter's `showLicensePage` and
`LicenseRegistry` to show licenses from the package graph resolved for the
build. This repository does not track `pubspec.lock`, so the exact direct and
transitive package versions cannot be reconstructed from `pubspec.yaml` alone.
This note does not duplicate or claim to enumerate that graph.

`fvp` 0.37.3's package archive includes a BSD-3-Clause license. The package is
based on libmdk, whose upstream terms allow Flutter/fvp users to use a bundled
key without charge, including in commercial software; the runtime is not under
a standard OSI-approved open-source license. This describes only the upstream
MDK component terms; they do not change Stroom's AGPL-3.0 obligations and must
not be read as permission to distribute Stroom as closed-source commercial
software. This is conditionally unsuitable if Stroom's distribution policy
requires every runtime component to use an OSI-approved license. The package
license and runtime terms are separate.

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
  is retained at `assets/vendor/mermaid/LICENSE.txt`. The license page also
  displays the embedded dependency notices from `assets/vendor/mermaid.min.js`.
  Those notices identify DOMPurify 3.4.0 (Apache-2.0 or MPL-2.0), js-yaml 4.1.1
  (MIT), lodash-es 4.18.1 (MIT), and several Cytoscape components (MIT). The
  embedded notices do not state the Cytoscape package version; no version is
  inferred here.
