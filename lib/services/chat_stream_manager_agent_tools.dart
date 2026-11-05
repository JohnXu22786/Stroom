part of 'chat_stream_manager.dart';

extension ChatStreamManagerAgentTools on ChatService {
  void registerAgentToolHandlers({
    required ChatStreamManager manager,
    required List<ChatMessage> history,
    required ProviderEntriesState? entriesState,
  }) {
    final ref = manager._ref;
    if (ref == null) return;
    final attachments = ChatMediaToolService.attachmentsFromMessages(history);

    registerConversationToolHandler(
      ChatMediaToolService.mediaListToolName,
      (args) => ChatMediaToolService.handleLibraryList(
        args,
        loadImages: () async => ImageManifest.loadRecords(),
        loadAudio: () async => FileManifest.loadRecords(),
      ),
    );

    if (entriesState != null) {
      final ocrModel = flattenProviderModels(entriesState, 'ocr').firstOrNull;
      if (ocrModel != null) {
        registerConversationToolHandler(
          ChatMediaToolService.ocrToolName,
          (args) => ChatMediaToolService.handleOcr(
            args,
            attachments: attachments,
            recognizeLibraryImage: (imageId) async {
              final ImageRecord? record = ChatMediaToolService.findRecordById(
                await ImageManifest.loadRecords(),
                imageId,
              );
              if (record == null) {
                return 'Error: the selected Stroom image was not found.';
              }
              final bytes = await ImageManifest.readFile(record.storagePath);
              if (bytes == null || bytes.isEmpty) {
                return 'Error: the selected Stroom image could not be read.';
              }
              final format = switch (record.format.toLowerCase()) {
                'jpg' || 'jpeg' => 'jpeg',
                'png' ||
                'gif' ||
                'webp' ||
                'bmp' =>
                  record.format.toLowerCase(),
                _ => '',
              };
              if (format.isEmpty) {
                return 'Error: this Stroom image format is not supported for OCR.';
              }
              final config = OcrConfig(
                host: ocrModel.config.host,
                apiKey: ocrModel.config.key,
                model: ocrModel.model.modelId,
                typeConfig: Map<String, dynamic>.from(
                  ocrModel.model.typeConfig,
                ),
                customParams: ocrModel.model.customParams
                    .map((parameter) => parameter.copy())
                    .toList(),
              );
              final result = await OcrService(
                config: config,
              ).recognize(imageBytes: bytes, imageFormat: format);
              return result.text;
            },
            recognize: (attachment) async {
              final payload = await readAttachmentBase64(attachment);
              if (payload.status != AttachmentReadStatus.ok ||
                  payload.base64 == null) {
                return 'Error: the selected image could not be read.';
              }
              final imageFormat = ChatMediaToolService.imageFormat(
                attachment,
                mimeType: payload.mimeType,
              );
              if (imageFormat.isEmpty) {
                return 'Error: this image format is not supported for OCR.';
              }
              final config = OcrConfig(
                host: ocrModel.config.host,
                apiKey: ocrModel.config.key,
                model: ocrModel.model.modelId,
                typeConfig: Map<String, dynamic>.from(
                  ocrModel.model.typeConfig,
                ),
                customParams: ocrModel.model.customParams
                    .map((parameter) => parameter.copy())
                    .toList(),
              );
              final result = await OcrService(config: config).recognize(
                imageBytes: base64Decode(payload.base64!),
                imageFormat: imageFormat,
              );
              return result.text;
            },
          ),
        );
      }

      final asrModel = flattenProviderModels(entriesState, 'asr').firstOrNull;
      if (asrModel != null) {
        Future<String> transcribeAudio(Uint8List bytes, String format) async {
          final providerTypeConfig = asrModel.config.typeConfig;
          final uploadMethodName =
              providerTypeConfig['uploadMethod'] as String?;
          final uploadMethod = AudioUploadMethod.values.firstWhere(
            (method) => method.name == uploadMethodName,
            orElse: () => AudioUploadMethod.multipart,
          );
          if (uploadMethod == AudioUploadMethod.url) {
            return 'Error: this ASR provider accepts public URLs only; '
                'a local audio file cannot be sent as a URL.';
          }
          final maxFileSizeMb = providerTypeConfig['maxFileSizeMb'] as num?;
          final config = AsrConfig(
            host: asrModel.config.host,
            apiKey: asrModel.config.key,
            model: asrModel.model.modelId,
            typeConfig: Map<String, dynamic>.from(asrModel.model.typeConfig),
            customParams: asrModel.model.customParams
                .map((parameter) => parameter.copy())
                .toList(),
            uploadMethod: uploadMethod,
            maxFileSizeBytes: maxFileSizeMb != null
                ? (maxFileSizeMb * 1024 * 1024).toInt()
                : AsrConfig.defaultMaxAudioFileSizeBytes,
            preprocessing:
                providerTypeConfig['preprocessing'] as String? ?? 'none',
            chunking: providerTypeConfig['chunking'] as String? ?? 'none',
            compression: providerTypeConfig['compression'] as String? ?? 'none',
            fallbackMethod:
                providerTypeConfig['fallbackMethod'] as String? ?? 'none',
          );
          final audioFormat = normalizeAsrUploadFormat(format);
          final result = await AsrService(
            config: config,
          ).transcribe(audioBytes: bytes, audioFormat: audioFormat);
          return result.text;
        }

        registerConversationToolHandler(
          ChatMediaToolService.asrToolName,
          (args) => ChatMediaToolService.handleAsr(
            args,
            attachments: attachments,
            transcribeLibraryAudio: (audioId) async {
              final AudioRecord? record = ChatMediaToolService.findRecordById(
                await FileManifest.loadRecords(),
                audioId,
              );
              if (record == null) {
                return 'Error: the selected Stroom audio file was not found.';
              }
              final bytes = await FileManifest.readFile(record.storagePath);
              if (bytes == null || bytes.isEmpty) {
                return 'Error: the selected Stroom audio file could not be read.';
              }
              return transcribeAudio(bytes, record.format);
            },
            transcribe: (attachment) async {
              final bytes = await AttachmentStorage.readFile(
                attachment.storagePath,
              );
              if (bytes == null || bytes.isEmpty) {
                return 'Error: the selected audio could not be read.';
              }
              return transcribeAudio(
                bytes,
                ChatMediaToolService.audioFormat(attachment, bytes),
              );
            },
          ),
        );
      }

      final ttsModel = flattenProviderModels(entriesState, 'tts').firstOrNull;
      if (ttsModel != null) {
        registerConversationToolHandler(
          'stroom_tts',
          (args) => ChatMediaToolService.handleTts(
            args,
            synthesize: (text, title) async {
              final record =
                  await ref.read(ttsStateProvider.notifier).synthesize(
                        text,
                        providerConfig: ttsModel.config,
                        modelConfig: ttsModel.model,
                        title: title,
                      );
              if (record == null) return null;
              return 'Audio saved to the Stroom audio library: '
                  '${record.name} (record ID: ${record.id}, '
                  'format: ${record.format}).';
            },
          ),
        );
      }
    }

    for (final def in ChatTaskFlowToolService.toolDefinitions) {
      registerConversationToolHandler(def.name, (args) async {
        switch (def.name) {
          case ChatTaskFlowToolService.listToolName:
            return ChatTaskFlowToolService.handleList(
              args,
              loadFlows: () async => ref.read(taskFlowListProvider),
            );
          case ChatTaskFlowToolService.runToolName:
            return ChatTaskFlowToolService.handleRun(
              args,
              attachments: attachments,
              findFlow: (flowId) async => ref
                  .read(taskFlowListProvider)
                  .where((flow) => flow.id == flowId)
                  .firstOrNull,
              copyAttachment: (attachment) async {
                final maxBytes = attachment.fileType == 'image'
                    ? maxFlowImageInputBytes
                    : maxAttachmentBytes;
                if (attachment.fileSize <= 0 ||
                    attachment.fileSize > maxBytes) {
                  return null;
                }
                final bytes = await AttachmentStorage.readFile(
                  attachment.storagePath,
                );
                if (bytes == null || bytes.isEmpty || bytes.length > maxBytes) {
                  return null;
                }
                final copyPath = await AttachmentStorage.saveFile(
                  attachment.fileName,
                  bytes,
                );
                final reference = kIsWeb
                    ? copyPath
                    : p.join(
                        await AttachmentStorage.getStorageDirPath(),
                        p.basename(copyPath),
                      );
                return FlowRunInput(
                  text: reference,
                  fileName: attachment.fileName,
                  mimeType: attachment.mimeType,
                  ownedStoragePath: copyPath,
                );
              },
              launch: (flowId, input) async {
                final service = ref.read(taskFlowExecutionServiceProvider);
                try {
                  return await service.launchFlowMany(flowId, [input]);
                } catch (_) {
                  final path = input.ownedStoragePath;
                  final notifier = ref.read(
                    taskFlowExecutionsProvider.notifier,
                  );
                  if (path != null &&
                      !notifier.referencesInputStoragePath(path)) {
                    await AttachmentStorage.deleteFile(path);
                  }
                  rethrow;
                }
              },
            );
          case ChatTaskFlowToolService.statusToolName:
            return ChatTaskFlowToolService.handleStatus(
              args,
              executions: ref.read(taskFlowExecutionsProvider),
            );
          case ChatTaskFlowToolService.controlToolName:
            return ChatTaskFlowToolService.handleControl(
              args,
              exists: (executionId) => ref
                  .read(taskFlowExecutionsProvider)
                  .any((execution) => execution.id == executionId),
              control: (action, executionId) async {
                final service = ref.read(taskFlowExecutionServiceProvider);
                switch (action) {
                  case 'pause':
                    await service.pauseExecution(executionId);
                  case 'resume':
                    await service.resumeExecution(executionId);
                  case 'cancel':
                    await service.cancelExecution(executionId);
                }
              },
            );
          default:
            return 'Error: unknown Stroom task flow tool.';
        }
      });
    }
  }
}
