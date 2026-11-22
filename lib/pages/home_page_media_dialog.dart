part of 'home_page.dart';

extension _HomePageMediaDialogExt on _HomePageState {
  /// 显示媒体资源选择弹框（供 CatCatch userSelecting 步骤使用）
  void _showMediaSelectionDialog(
    BuildContext context,
    catcatch_task.CatCatchTask task,
  ) => _showCatCatchSelectionDialog(context, task);

  void _showFlowMediaSelectionDialog(
    BuildContext context,
    catcatch_task.CatCatchTask task,
  ) {
    final encoded =
        task.metadata[catcatch_task.CatCatchTask.flowSelectionCandidatesKey];
    if (encoded == null) {
      _openMediaSelectionDialogs.remove(task.id);
      return;
    }
    final candidates = (jsonDecode(encoded) as List).cast<String>().toSet();
    final identityVersioned = task.metadata.containsKey(
      catcatch_task.CatCatchTask.flowSelectionCandidatesIdentityVersionKey,
    );
    final selectableMedia = task.detectedMedia
        .where(
          (media) => catcatch_task.CatCatchTask.flowSelectionCandidateAllowed(
            candidates: candidates,
            identity: media.selectionIdentity,
            url: media.url,
            hasByteRange: media.hasByteRange,
            identityVersioned: identityVersioned,
          ),
        )
        .toList();
    if (selectableMedia.isEmpty) {
      _openMediaSelectionDialogs.remove(task.id);
      return;
    }
    final selectableIdentities =
        selectableMedia.map((media) => media.selectionIdentity).toSet();
    final pairedAudio = task.detectedMedia.where(
      (media) =>
          media.isAudio &&
          media.isLikelySplitTrack &&
          !selectableIdentities.contains(media.selectionIdentity) &&
          selectableMedia.any(
            (candidate) =>
                candidate.isVideo &&
                candidate.isLikelySplitTrack &&
                candidate.groupId == media.groupId,
          ),
    );
    final pickerMedia = [...selectableMedia, ...pairedAudio];
    _showCatCatchSelectionDialog(
      context,
      task,
      selectableMedia: pickerMedia,
      confirmableIdentities:
          selectableMedia.map((media) => media.selectionIdentity).toSet(),
      singleSelection: true,
      onConfirm: (selectedMedia) async {
        final video = selectedMedia.firstWhere(
          (media) => !media.isAudio,
          orElse: () => selectedMedia.first,
        );
        final audio = selectedMedia
            .where((media) => media.isAudio && media.groupId == video.groupId)
            .firstOrNull;
        try {
          final started = await ref
              .read(taskFlowExecutionServiceProvider)
              .performManualCatCatchAction(
                task.id,
                true,
                (notifier) => notifier.selectMedia(
                  task.id,
                  video,
                  mergeAudioUrl: audio?.url,
                ),
                selectedMediaUrl: video.url,
                selectedMediaIdentity: video.selectionIdentity,
                selectedMediaHasByteRange: video.hasByteRange,
              );
          if (started) return true;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.catcatchFlowActionNotStarted,
                ),
              ),
            );
          }
          return ref
                  .read(catcatchTasksProvider)
                  .where((current) => current.id == task.id)
                  .firstOrNull
                  ?.status !=
              catcatch_task.TaskStatus.running;
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!
                      .catcatchFlowActionFailed(error.toString()),
                ),
              ),
            );
          }
          return false;
        }
      },
    );
  }

  void _showCatCatchSelectionDialog(
    BuildContext context,
    catcatch_task.CatCatchTask task, {
    List<MediaResource>? selectableMedia,
    Set<String>? confirmableIdentities,
    bool singleSelection = false,
    Future<bool> Function(List<MediaResource> selectedMedia)? onConfirm,
  }) {
    final selectedIdentities = <String>{};
    var segmentsExpanded = false;
    var confirmed = false;
    final mediaList = selectableMedia ?? task.detectedMedia;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final segments = mediaList.where((media) => media.isPlaylistSegment);
          final segmentCount = segments.length;
          final visibleResources = segmentCount == 0 || segmentsExpanded
              ? mediaList
              : mediaList.where((media) => !media.isPlaylistSegment).toList();
          final hasConfirmableSelection = selectedIdentities.any(
            (identity) =>
                confirmableIdentities == null ||
                confirmableIdentities.contains(identity),
          );
          final implicitSingleIdentity = confirmableIdentities?.length == 1
              ? confirmableIdentities!.single
              : null;
          final canImplicitlyConfirmSingle =
              selectedIdentities.isEmpty && implicitSingleIdentity != null
              ? visibleResources.any(
                  (media) => media.selectionIdentity == implicitSingleIdentity,
                )
              : selectedIdentities.isEmpty &&
                  confirmableIdentities == null &&
                  mediaList.length == 1 &&
                  visibleResources.length == 1;
          // Keep the resource scroller to two-thirds of this dialog's content
          // viewport. The title, segment toggle, and dialog actions stay fixed.
          final contentViewportHeight = MediaQuery.sizeOf(ctx).height * 0.5;
          final resourceViewportHeight = contentViewportHeight * (2 / 3);
          return AlertDialog(
            key: const Key('catcatch_media_selection_dialog'),
            title: ConstrainedText(
              selectedIdentities.isNotEmpty
                  ? AppLocalizations.of(ctx)!.mediaSelectionCount(
                      selectedIdentities.length,
                      mediaList.length,
                    )
                  : AppLocalizations.of(ctx)!.mediaSelectionTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                        label: ConstrainedText(
                          segmentsExpanded
                              ? AppLocalizations.of(ctx)!
                                  .mediaCollapseSegments(segmentCount)
                              : AppLocalizations.of(ctx)!
                                  .mediaExpandSegments(segmentCount),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  if (mediaList.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(AppLocalizations.of(ctx)!.mediaNoResources),
                      ),
                    )
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
                            key: ValueKey('media_selection_$identity'),
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
                                    if (singleSelection) {
                                      final selectedMedia = mediaList
                                          .where(
                                            (candidate) =>
                                                selectedIdentities.contains(
                                              candidate.selectionIdentity,
                                            ),
                                          )
                                          .toList();
                                      final completesPair =
                                          media.isLikelySplitTrack &&
                                              selectedMedia.length == 1 &&
                                              selectedMedia.single
                                                      .groupId ==
                                                  media.groupId &&
                                              selectedMedia.single.isAudio !=
                                                  media.isAudio;
                                      if (!completesPair) {
                                        selectedIdentities.clear();
                                      }
                                    }
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
                                                          ctx,
                                                        )!
                                                          .mediaSegment
                                                      : media.isPlaylist
                                                          ? AppLocalizations.of(
                                                              ctx,
                                                            )!
                                                              .mediaPlaylist
                                                          : AppLocalizations.of(
                                                              ctx,
                                                            )!
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
                                                child: ConstrainedText(
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
                                                ),
                                              ),
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
                                                  .mediaResolution(
                                                media.width!,
                                                media.height!,
                                              ),
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
                child: ConstrainedText(
                  AppLocalizations.of(ctx)!.actionCancel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              FilledButton(
                onPressed: hasConfirmableSelection || canImplicitlyConfirmSingle
                        ? () async {
                        final selectedMediaList = selectedIdentities.isEmpty &&
                                implicitSingleIdentity != null
                            ? mediaList
                                .where(
                                  (media) =>
                                      media.selectionIdentity ==
                                      implicitSingleIdentity,
                                )
                                .toList()
                            : mediaList.length == 1 &&
                                    visibleResources.length == 1
                                ? mediaList
                                : mediaList
                                    .where(
                                      (media) => selectedIdentities.contains(
                                        media.selectionIdentity,
                                      ),
                                    )
                                    .toList();
                        if (onConfirm != null) {
                          if (!await onConfirm(selectedMediaList)) return;
                          if (!ctx.mounted) return;
                          confirmed = true;
                          Navigator.pop(ctx);
                        } else {
                          confirmed = true;
                          Navigator.pop(ctx);
                          ref
                              .read(catcatchTasksProvider.notifier)
                              .batchSelectMedia(task.id, selectedMediaList);
                        }
                      }
                    : null,
                child: ConstrainedText(
                  selectedIdentities.isNotEmpty
                      ? AppLocalizations.of(ctx)!
                          .mediaDownloadSelected(selectedIdentities.length)
                      : AppLocalizations.of(ctx)!.mediaConfirmDownload,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      if (!confirmed) {
        _dismissedMediaSelectionDialogs.add(task.id);
        _openMediaSelectionDialogs.remove(task.id);
      }
    });
  }
}
