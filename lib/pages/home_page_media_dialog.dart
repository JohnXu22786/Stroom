part of 'home_page.dart';

extension _HomePageMediaDialogExt on _HomePageState {
  /// 显示媒体资源选择弹框（供 CatCatch userSelecting 步骤使用）
  void _showMediaSelectionDialog(
    BuildContext context,
    catcatch_task.CatCatchTask task,
  ) {
    final selectedIdentities = <String>{};
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
              selectedIdentities.isNotEmpty
                  ? AppLocalizations.of(ctx)!.mediaSelectionCount(
                      selectedIdentities.length, mediaList.length)
                  : AppLocalizations.of(ctx)!.mediaSelectionTitle,
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
                              ? AppLocalizations.of(ctx)!
                                  .mediaCollapseSegments(segmentCount)
                              : AppLocalizations.of(ctx)!
                                  .mediaExpandSegments(segmentCount),
                        ),
                      ),
                    ),
                  if (mediaList.isEmpty)
                    Expanded(
                        child: Center(
                            child: Text(
                                AppLocalizations.of(ctx)!.mediaNoResources)))
                  else
                    SizedBox(
                      height: resourceViewportHeight,
                      child: ListView.builder(
                        itemCount: visibleResources.length,
                        itemBuilder: (_, i) {
                          final media = visibleResources[i];
                          final identity = media.selectionIdentity;
                          final isSel = selectedIdentities.contains(identity);
                          final isAudio = isAudioPreviewResource(media);
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
                                    selectedIdentities.remove(identity);
                                  } else {
                                    selectedIdentities.add(identity);
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
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  media.isPlaylistSegment
                                                      ? AppLocalizations.of(
                                                              ctx)!
                                                          .mediaSegment
                                                      : media.isPlaylist
                                                          ? AppLocalizations.of(
                                                                  ctx)!
                                                              .mediaPlaylist
                                                          : AppLocalizations.of(
                                                                  ctx)!
                                                              .mediaFullVideo,
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
                                              AppLocalizations.of(ctx)!
                                                  .mediaDuration(
                                                      formatDurationShort(
                                                media.duration!,
                                                AppLocalizations.of(ctx)!,
                                              )),
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
                                              AppLocalizations.of(ctx)!
                                                  .mediaResolution(media.width!,
                                                      media.height!),
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
                                        tooltip: AppLocalizations.of(ctx)!
                                            .mediaPreview,
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
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Tooltip(
                                          message: AppLocalizations.of(ctx)!
                                              .mediaSegmentPreviewHint,
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
                child: Text(AppLocalizations.of(ctx)!.actionCancel),
              ),
              FilledButton(
                onPressed: selectedIdentities.isNotEmpty ||
                        (mediaList.length == 1 && visibleResources.length == 1)
                    ? () {
                        final selectedMediaList = mediaList.length == 1
                            ? mediaList
                            : mediaList
                                .where((m) => selectedIdentities
                                    .contains(m.selectionIdentity))
                                .toList();
                        Navigator.pop(ctx);
                        ref
                            .read(catcatchTasksProvider.notifier)
                            .batchSelectMedia(task.id, selectedMediaList);
                      }
                    : null,
                child: Text(
                  selectedIdentities.isNotEmpty
                      ? AppLocalizations.of(ctx)!
                          .mediaDownloadSelected(selectedIdentities.length)
                      : AppLocalizations.of(ctx)!.mediaConfirmDownload,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
