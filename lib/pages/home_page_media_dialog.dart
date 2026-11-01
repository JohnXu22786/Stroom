part of 'home_page.dart';

extension _HomePageMediaDialogExt on _HomePageState {
  /// 显示媒体资源选择弹框（供 CatCatch userSelecting 步骤使用）
  void _showMediaSelectionDialog(
    BuildContext context,
    catcatch_task.CatCatchTask task,
  ) {
    final selectedUrls = <String>{};
    var segmentsExpanded = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final mediaList = task.detectedMedia;
          final segments = mediaList.where((media) => media.isPlaylistSegment);
          final segmentCount = segments.length;
          final visibleResources = segmentCount == 0 || segmentsExpanded
              ? mediaList
              : mediaList.where((media) => !media.isPlaylistSegment).toList();
          // Keep the resource scroller to two-thirds of this dialog's content
          // viewport. The title, segment toggle, and dialog actions stay fixed.
          final contentViewportHeight = MediaQuery.sizeOf(ctx).height * 0.5;
          final resourceViewportHeight = contentViewportHeight * (2 / 3);
          return AlertDialog(
            title: Text(
              selectedUrls.isNotEmpty
                  ? '已选 ${selectedUrls.length}/${mediaList.length} 个资源'
                  : '选择要下载的资源',
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: contentViewportHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (segmentCount > 0)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const Key('dialog_m3u8_segments_toggle'),
                        onPressed: () => setDlgState(
                          () => segmentsExpanded = !segmentsExpanded,
                        ),
                        icon: Icon(
                          segmentsExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                        label: Text(
                          segmentsExpanded
                              ? '收起 $segmentCount 个分片'
                              : '显示 $segmentCount 个分片',
                        ),
                      ),
                    ),
                  if (mediaList.isEmpty)
                    const Expanded(child: Center(child: Text('检测到 0 个资源')))
                  else
                    SizedBox(
                      height: resourceViewportHeight,
                      child: ListView.builder(
                        itemCount: visibleResources.length,
                        itemBuilder: (_, i) {
                          final media = visibleResources[i];
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
                                      isAudio
                                          ? Icons.audiotrack
                                          : Icons.videocam,
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
                                          Row(
                                            children: [
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  right: 6,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 5,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: media.isPlaylistSegment
                                                      ? Colors.orange
                                                          .withValues(
                                                          alpha: 0.12,
                                                        )
                                                      : media.isPlaylist
                                                          ? Colors.blue
                                                              .withValues(
                                                              alpha: 0.12,
                                                            )
                                                          : Colors.teal
                                                              .withValues(
                                                              alpha: 0.12,
                                                            ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  media.isPlaylistSegment
                                                      ? '分片'
                                                      : media.isPlaylist
                                                          ? '播放列表'
                                                          : '整片',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: media
                                                            .isPlaylistSegment
                                                        ? Colors.orange.shade800
                                                        : media.isPlaylist
                                                            ? Colors
                                                                .blue.shade800
                                                            : Colors
                                                                .teal.shade800,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  '${media.name}.${media.ext}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontWeight: isSel
                                                        ? FontWeight.w600
                                                        : FontWeight.w500,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (media.duration != null)
                                            Text(
                                              '时长: ${formatDurationShort(media.duration!)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(ctx)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          if (media.width != null &&
                                              media.height != null)
                                            Text(
                                              '分辨率: ${media.width}x${media.height}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(ctx)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (media.canPreview)
                                      IconButton(
                                        icon: Icon(
                                          Icons.play_circle_filled,
                                          color:
                                              Theme.of(ctx).colorScheme.primary,
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
                                    if (media.isPlaylistSegment)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 4),
                                        child: Tooltip(
                                          message: '分片需通过播放列表预览',
                                          child: Icon(
                                            Icons.info_outline,
                                            size: 18,
                                            color: Colors.grey,
                                          ),
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
                  const Spacer(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: selectedUrls.isNotEmpty ||
                        (mediaList.length == 1 && visibleResources.length == 1)
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
