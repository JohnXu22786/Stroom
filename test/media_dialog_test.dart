import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/pages/unified_task_list_page.dart';

MediaResource _m(String name, String ext, {bool playable = true}) =>
    MediaResource(
      url: 'https://ex.com/$name.$ext',
      name: name,
      ext: ext,
      mimeType: ext == 'mp4' ? 'video/mp4' : 'audio/mp4',
      isPlayable: playable,
    );

/// 测试弹窗的选择逻辑，与 _showMediaSelectionDialog 中的 StatefulBuilder 结构一致
Future<void> _showTestDialog(
    BuildContext context,
    List<MediaResource> mediaList,
    ) async {
  final selectedUrls = <String>{};
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) {
        return AlertDialog(
          title: Text(selectedUrls.isNotEmpty
              ? '已选 ${selectedUrls.length}/${mediaList.length} 个资源'
              : '选择要下载的资源'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: mediaList.length,
              itemBuilder: (_, i) {
                final media = mediaList[i];
                final isSel = selectedUrls.contains(media.url);
                final isAudio = ['mp3', 'wav', 'm4a', 'aac', 'opus', 'weba']
                    .contains(media.ext.toLowerCase());
                return Card(
                  child: InkWell(
                    onTap: () => setDlgState(() {
                      if (isSel) {
                        selectedUrls.remove(media.url);
                      } else {
                        selectedUrls.add(media.url);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Icon(isAudio ? Icons.audiotrack : Icons.videocam),
                          Icon(isSel
                              ? Icons.check_box
                              : Icons.check_box_outline_blank),
                          Expanded(child: Text('${media.name}.${media.ext}')),
                          if (media.isPlayable)
                            IconButton(
                              icon: const Icon(Icons.play_circle_filled),
                              onPressed: () => showMediaPreview(
                                  ctx, media, 'Test'),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: selectedUrls.isNotEmpty || mediaList.length == 1
                  ? () {
                final selected = mediaList.length == 1
                    ? mediaList
                    : mediaList
                        .where((m) => selectedUrls.contains(m.url))
                        .toList();
                Navigator.pop(ctx);
              }
                  : null,
              child: Text(selectedUrls.isNotEmpty
                  ? '下载选中的 ${selectedUrls.length} 个资源'
                  : '确认下载'),
            ),
          ],
        );
      },
    ),
  );
}

void main() {
  testWidgets('dialog shows all media items with checkboxes', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) => ElevatedButton(
        onPressed: () => _showTestDialog(ctx, [_m('v1', 'mp4'), _m('a1', 'm4a'), _m('img', 'jpg', playable: false)]),
        child: const Text('Open'),
      )),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('选择要下载的资源'), findsOneWidget);
    expect(find.text('v1.mp4'), findsOneWidget);
    expect(find.text('a1.m4a'), findsOneWidget);
    expect(find.text('img.jpg'), findsOneWidget);
  });

  testWidgets('playable media shows preview button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) => ElevatedButton(
        onPressed: () => _showTestDialog(ctx, [_m('v1', 'mp4'), _m('img', 'jpg', playable: false)]),
        child: const Text('Open'),
      )),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // mp4 可播放 → 有预览按钮；jpg 不可播放 → 无预览按钮
    expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
  });

  testWidgets('multi-select toggles correctly and updates title', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) => ElevatedButton(
        onPressed: () => _showTestDialog(ctx, [_m('v1', 'mp4'), _m('v2', 'mp4')]),
        child: const Text('Open'),
      )),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // 初始：无选中
    expect(find.text('选择要下载的资源'), findsOneWidget);

    // 选择第一个
    await tester.tap(find.text('v1.mp4'));
    await tester.pumpAndSettle();
    expect(find.text('已选 1/2 个资源'), findsOneWidget);

    // 选择第二个
    await tester.tap(find.text('v2.mp4'));
    await tester.pumpAndSettle();
    expect(find.text('已选 2/2 个资源'), findsOneWidget);

    // 取消第一个
    await tester.tap(find.text('v1.mp4'));
    await tester.pumpAndSettle();
    expect(find.text('已选 1/2 个资源'), findsOneWidget);
  });

  testWidgets('confirm button text updates with selection count', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) => ElevatedButton(
        onPressed: () => _showTestDialog(ctx, [_m('v1', 'mp4'), _m('v2', 'mp4')]),
        child: const Text('Open'),
      )),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('确认下载'), findsOneWidget);

    await tester.tap(find.text('v1.mp4'));
    await tester.pumpAndSettle();
    expect(find.text('下载选中的 1 个资源'), findsOneWidget);
  });

  testWidgets('cancel closes dialog', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) => ElevatedButton(
        onPressed: () => _showTestDialog(ctx, [_m('v1', 'mp4')]),
        child: const Text('Open'),
      )),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('确认下载'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('确认下载'), findsNothing);
  });
}
