part of 'home_page.dart';

extension _HomePageMediaDialogExt on _HomePageState {
  /// 显示媒体资源选择弹框（供 CatCatch userSelecting 步骤使用）
  void _showMediaSelectionDialog(
    BuildContext context,
    catcatch_task.CatCatchTask task,
  ) {
    final selectedUrls = <String>{};
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final mediaList = task.detectedMedia;
          return AlertDialog(
            title: Text(
              selectedUrls.isNotEmpty
                  ? '已选 ${selectedUrls.length}/${mediaList.length} 个资源'
                  : '选择要下载的资源',
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: mediaList.isEmpty
                  ? const Center(child: Text('检测到 0 个资源'))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: mediaList.length,
                      itemBuilder: (_, i) {
                        final media = mediaList[i];
                        final isSel = selectedUrls.contains(media.url);
                        final isAudio = [
                          'mp3',
                          'wav',
                          'm4a',
                          'aac',
                          'opus',
                          'weba',
                        ].contains(media.ext.toLowerCase());
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSel
                                  ? Theme.of(ctx).colorScheme.primary
                                  : Theme.of(ctx).colorScheme.outlineVariant,
                              width: isSel ? 1.5 : 0.5,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              setDlgState(() {
                                if (isSel) {
                                  selectedUrls.remove(media.url);
                                } else {
                                  selectedUrls.add(media.url);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isAudio ? Icons.audiotrack : Icons.videocam,
                                    size: 18,
                                    color:
                                        isAudio ? Colors.purple : Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isSel
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                    color: isSel
                                        ? Theme.of(ctx).colorScheme.primary
                                        : Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${media.name}.${media.ext}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: isSel
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (media.duration != null)
                                          Text(
                                            '时长: ${formatDurationShort(media.duration!)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(
                                                ctx,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        if (media.width != null &&
                                            media.height != null)
                                          Text(
                                            '分辨率: ${media.width}x${media.height}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(
                                                ctx,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (media.isPlayable)
                                    IconButton(
                                      icon: Icon(
                                        Icons.play_circle_filled,
                                        color: Theme.of(
                                          ctx,
                                        ).colorScheme.primary,
                                        size: 22,
                                      ),
                                      tooltip: '预览',
                                      onPressed: () {
                                        showMediaPreview(
                                          ctx,
                                          media,
                                          task.title.isNotEmpty
                                              ? task.title
                                              : task.url,
                                        );
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
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
                        final selectedMediaList = mediaList.length == 1
                            ? mediaList
                            : mediaList
                                .where((m) => selectedUrls.contains(m.url))
                                .toList();
                        Navigator.pop(ctx);
                        ref
                            .read(catcatchTasksProvider.notifier)
                            .batchSelectMedia(task.id, selectedMediaList);
                      }
                    : null,
                child: Text(
                  selectedUrls.isNotEmpty
                      ? '下载选中的 ${selectedUrls.length} 个资源'
                      : '确认下载',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
