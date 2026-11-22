import 'package:flutter/foundation.dart' show kIsWeb;

import 'block_type_definition.dart';
import 'flow_payload.dart';
import 'task_flow_definition.dart';

/// Serialized per-block switch. It is intentionally absent/false by default
/// so existing flows continue saving to their configured folder (including
/// the root folder represented by an empty path).
const String flowTemporaryOutputParam = '_taskFlowTemporaryOutput';

bool isFlowTemporaryOutputEnabled(TaskFlowBlock block) =>
    block.params[flowTemporaryOutputParam] == true;

bool hasFileOutput(TaskFlowBlock block) {
  // CatCatch's downloader explicitly rejects Web before producing a local
  // media file, so there is no browser-side output that can be staged.
  if (kIsWeb && block.typeKey == BlockType.catcatch) return false;
  return block.possibleOutputTypes.any(FlowPayload.isFileType);
}

/// ASR and OCR produce text values but also save a text-gallery file when
/// their output is retained. Temporary mode suppresses that intermediate
/// file just as it stages media-file outputs privately.
bool producesTemporaryOutputFile(TaskFlowBlock block) =>
    hasFileOutput(block) ||
    block.typeKey == BlockType.asr ||
    block.typeKey == BlockType.ocr;

/// Only non-final processing blocks that persist an output file can be temporary.
/// The task-flow's initial source card is not in [blocks].
bool isFlowTemporaryOutputEligible(List<TaskFlowBlock> blocks, int index) =>
    index >= 0 &&
    index < blocks.length - 1 &&
    producesTemporaryOutputFile(blocks[index]);

bool isFlowBlockTemporary(List<TaskFlowBlock> blocks, int index) =>
    isFlowTemporaryOutputEligible(blocks, index) &&
    isFlowTemporaryOutputEnabled(blocks[index]);
