import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/bundled_asset_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'registers MDK package MIT and NVJP2K source notices separately',
    () async {
      registerBundledAssetLicenses();
      final entries = await LicenseRegistry.licenses.toList();

      const packageLabel =
          'MDK 0.39.0.2635 Windows x64 vendor .nupkg '
          '(package-level MIT declaration)';
      final packageEntry = entries.singleWhere(
        (entry) => entry.packages.contains(packageLabel),
      );
      final packageText = packageEntry.paragraphs
          .map((paragraph) => paragraph.text)
          .join('\n');
      expect(packageText, contains('MIT License'));
      expect(packageText, contains('Copyright (c) 2016-2025 WangBin'));
      expect(packageText, isNot(contains('NVIDIA Corporation')));

      const sourceNoticeLabel =
          'mdk-nvjp2k source-file notice (Windows x64; '
          'separate from package MIT; '
          'NVIDIA source and external runtime scope)';
      final sourceNoticeEntry = entries.singleWhere(
        (entry) => entry.packages.contains(sourceNoticeLabel),
      );
      final sourceNoticeText = sourceNoticeEntry.paragraphs
          .map((paragraph) => paragraph.text)
          .join('\n');
      expect(sourceNoticeText, contains('This file is part of MDK'));
      expect(
        sourceNoticeText,
        contains('source code provided by NVIDIA Corporation.'),
      );
      expect(packageEntry, isNot(same(sourceNoticeEntry)));
    },
  );
}
