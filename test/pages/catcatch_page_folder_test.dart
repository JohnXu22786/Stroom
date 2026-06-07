import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/catcatch_page.dart';

void main() {
  group('CatCatchPage - Folder Selection', () {
    testWidgets('folder selectors for video and audio are present',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CatCatchPage(),
          ),
        ),
      );

      await tester.pump();

      // Find folder selector sections - they should show labels for video & audio
      expect(find.textContaining('视频保存'), findsWidgets);
      expect(find.textContaining('音频保存'), findsWidgets);
    });
  });
}
