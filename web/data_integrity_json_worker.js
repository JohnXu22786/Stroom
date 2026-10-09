self.addEventListener('message', function (event) {
  const [operation, first, second, third, fourth] = event.data;
  let result;
  if (operation === 'migrateLegacyConversations') {
    self.postMessage(migrateLegacyConversations(first));
    return;
  } else if (operation === 'prepareLegacyChatConfigs') {
    const result = prepareLegacyChatConfigs(first);
    self.postMessage(migrationResponse(result.metadata, result.payload));
    return;
  } else if (operation === 'mergeLegacyChatConfigs') {
    const result = mergeLegacyChatConfigs(first, second);
    self.postMessage(migrationResponse(result.metadata, result.payload));
    return;
  } else if (operation === 'fixProviderEntries') {
    const result = fixProviderEntries(first);
    self.postMessage(migrationResponse(result.metadata, result.payload));
    return;
  } else if (operation === 'migrateProviderModelSettings') {
    const result = migrateProviderModelSettings(first);
    self.postMessage(migrationResponse(result.metadata, result.payload));
    return;
  } else if (operation === 'migrateWebManifestData') {
    const result = migrateWebManifestData(first, second, third, fourth);
    const payload = result.payload == null
      ? null
      : new TextEncoder().encode(result.payload);
    const metadata = JSON.stringify({
      ...result.metadata,
      hasPayload: payload != null,
    });
    self.postMessage(metadata);
    if (payload == null) {
      return;
    } else {
      self.postMessage(payload.buffer, [payload.buffer]);
    }
    return;
  } else if (operation === 'validateWebManifestData') {
    result = validateWebManifestData(first);
  } else if (operation === 'parseJsonBatch') {
    result = first.map(function (content) {
      try {
        JSON.parse(content);
        return null;
      } catch (error) {
        return String(error);
      }
    });
  } else if (operation === 'validateDataFormats') {
    result = validateDataFormats(first, second);
  } else if (operation === 'validateJsonBatchAndDataFormats') {
    result = validateJsonBatchAndDataFormats(first, second, third);
  } else if (operation === 'checkDataIntegrity') {
    result = checkDataIntegrity(first);
  } else {
    throw new Error('Unknown JSON worker operation');
  }
  self.postMessage(JSON.stringify(result));
});

function migrationResponse(metadata, payload) {
  return JSON.stringify(metadata) + '\n' + (payload || '');
}

function migrateWebManifestData(
  rawBytes,
  folderTables,
  removeLegacyFolders,
  migrateOldVideos,
) {
  let json;
  try {
    json = new TextDecoder('utf-8', { fatal: true }).decode(rawBytes);
  } catch (error) {
    return { metadata: { status: 'parseError', error: String(error) } };
  }

  let data;
  try {
    data = JSON.parse(json);
  } catch (error) {
    return { metadata: { status: 'parseError', error: String(error) } };
  }
  if (!isRecord(data)) {
    return {
      metadata: { status: 'invalidManifest', error: 'Expected a JSON object.' },
    };
  }

  let changed = false;
  let videoChanged = false;
  let setVideoFlag = false;
  if (migrateOldVideos) {
    const audioValue = data.audio_records;
    const videoValue = data.video_records;
    const audioRecords = audioValue == null ? [] : audioValue;
    const videoRecords = videoValue == null ? [] : videoValue;
    if (!Array.isArray(audioRecords) || !Array.isArray(videoRecords)) {
      return {
        metadata: {
          status: 'videoError',
          error: 'Audio/video records must be arrays.',
        },
      };
    }
    if (videoRecords.length > 0) {
      setVideoFlag = true;
    } else {
      const videoFormats = new Set([
        'mp4',
        'mov',
        'avi',
        'mkv',
        'webm',
        'flv',
        'wmv',
        'm4v',
        '3gp',
        'gif',
      ]);
      const toMigrate = [];
      const remaining = [];
      for (const item of audioRecords) {
        if (!isRecord(item) ||
            (item.format != null && typeof item.format !== 'string')) {
          return {
            metadata: {
              status: 'videoError',
              error: 'Audio record has an invalid shape.',
            },
          };
        }
        if (videoFormats.has(item.format)) {
          toMigrate.push(item);
        } else {
          remaining.push(item);
        }
      }
      if (toMigrate.length > 0) {
        data.audio_records = remaining;
        for (const record of toMigrate) {
          videoRecords.push({
            id: record.id,
            name: record.name,
            hash: record.hash,
            format: record.format,
            createdAt: record.createdAt,
            size: record.size,
            folder: record.folder,
            duration: record.duration,
          });
        }
        data.video_records = videoRecords;
        changed = true;
        videoChanged = true;
      }
      setVideoFlag = true;
    }
  }

  const videoPayload = videoChanged ? JSON.stringify(data) : null;
  const legacyValue = data.folders;
  const legacyFolders = legacyValue == null ? [] : legacyValue;
  if (
    !Array.isArray(legacyFolders) ||
    legacyFolders.some((folder) => typeof folder !== 'string')
  ) {
    return {
      metadata: {
        status: 'folderError',
        error: 'Legacy folders must be a list of strings.',
        videoChanged,
        setVideoFlag,
      },
      payload: videoPayload,
    };
  }

  let foldersMigrated = false;
  if (legacyFolders.length > 0) {
    if (
      !Array.isArray(folderTables) ||
      folderTables.some((table) => typeof table !== 'string')
    ) {
      return {
        metadata: {
          status: 'folderError',
          error: 'Folder table names are invalid.',
          videoChanged,
          setVideoFlag,
        },
        payload: videoPayload,
      };
    }
    for (const folderTable of folderTables) {
      const currentValue = data[folderTable];
      const existing = currentValue == null ? [] : currentValue;
      if (
        !Array.isArray(existing) ||
        existing.some((folder) => typeof folder !== 'string')
      ) {
        return {
          metadata: {
            status: 'folderError',
            error: `Folder table ${folderTable} must be a list of strings.`,
            videoChanged,
            setVideoFlag,
          },
          payload: videoPayload,
        };
      }
      data[folderTable] = Array.from(new Set([...existing, ...legacyFolders]));
    }
    if (removeLegacyFolders) delete data.folders;
    changed = true;
    foldersMigrated = true;
  } else if (removeLegacyFolders && legacyValue != null) {
    delete data.folders;
    changed = true;
  }

  return {
    metadata: {
      status: 'ok',
      changed,
      foldersMigrated,
      videoChanged,
      setVideoFlag,
    },
    payload: changed ? JSON.stringify(data) : null,
  };
}

function validateWebManifestData(rawBytes) {
  let data;
  try {
    const text = new TextDecoder('utf-8', { fatal: true }).decode(rawBytes);
    data = JSON.parse(text);
  } catch (error) {
    return { status: 'invalidManifest', error: String(error) };
  }
  if (!isRecord(data)) {
    return { status: 'invalidManifest', error: 'Expected a JSON object.' };
  }

  for (const table of [
    'image_records',
    'audio_records',
    'video_records',
    'text_records',
  ]) {
    const value = data[table];
    if (
      value != null &&
      (!Array.isArray(value) || value.some((item) => !isRecord(item)))
    ) {
      return {
        status: 'invalidManifest',
        error: `Manifest table ${table} must contain record objects.`,
      };
    }
  }

  for (const table of [
    'folders',
    'image_folders',
    'audio_folders',
    'video_folders',
    'text_folders',
  ]) {
    const value = data[table];
    if (
      value != null &&
      (!Array.isArray(value) ||
        value.some((folder) => typeof folder !== 'string'))
    ) {
      return {
        status: 'invalidManifest',
        error: `Manifest table ${table} must contain strings.`,
      };
    }
  }

  return { status: 'ok' };
}

function prepareLegacyChatConfigs(json) {
  let decoded;
  try {
    decoded = JSON.parse(json);
  } catch (error) {
    return { metadata: { status: 'parseError', error: String(error) } };
  }
  if (!Array.isArray(decoded)) return { metadata: { status: 'notList' } };

  const oldList = decoded.filter(isRecord);
  if (oldList.length === 0) return { metadata: { status: 'empty' } };

  const migratedConfigs = oldList.map(function (oldItem) {
    const rawModels = oldItem.models;
    const oldModels = Array.isArray(rawModels) ? rawModels.filter(isRecord) : [];
    const models = oldModels.map(function (model) {
      const typeConfig = {};
      if (model.temperature != null) typeConfig.temperature = model.temperature;
      const context = model.maxTokens != null ? model.maxTokens : model.context;
      if (context != null) typeConfig.context = context;
      const modelId = typeof model.modelId === 'string' ? model.modelId : '';
      return {
        name: modelId,
        modelId,
        supportStream: typeof model.supportStream === 'boolean'
          ? model.supportStream
          : true,
        typeConfig,
      };
    });
    return {
      providerName: typeof oldItem.providerName === 'string'
        ? oldItem.providerName
        : '',
      host: typeof oldItem.host === 'string' ? oldItem.host : '',
      key: typeof oldItem.key === 'string' ? oldItem.key : '',
      models,
    };
  });

  return {
    metadata: { status: 'ready', legacyConfigCount: oldList.length },
    payload: JSON.stringify(migratedConfigs),
  };
}

function mergeLegacyChatConfigs(migratedConfigsJson, existingJson) {
  const migratedConfigs = JSON.parse(migratedConfigsJson);
  let existingEntries = [];
  let corruptExisting = false;
  if (typeof existingJson === 'string' && existingJson.length > 0) {
    try {
      const decoded = JSON.parse(existingJson);
      if (Array.isArray(decoded)) {
        existingEntries = decoded.filter(isRecord);
      } else {
        corruptExisting = true;
      }
    } catch (_) {
      corruptExisting = true;
    }
  }

  const hasLlmEntry = existingEntries.some((entry) =>
    entry.type === 'llm' && entry.id !== 'builtin_llm',
  );
  if (hasLlmEntry) {
    return { metadata: { status: 'alreadyMigrated', corruptExisting } };
  }

  existingEntries.push({
    id: 'migrated_llm',
    type: 'llm',
    name: 'LLM供应商',
    configs: migratedConfigs,
  });
  return {
    metadata: { status: 'write', corruptExisting },
    payload: JSON.stringify(existingEntries),
  };
}

function fixProviderEntries(json) {
  let decoded;
  try {
    decoded = JSON.parse(json);
  } catch (error) {
    return { metadata: { status: 'parseError', error: String(error) } };
  }
  if (!Array.isArray(decoded)) return { metadata: { status: 'notList' } };

  const list = decoded.filter(isRecord);
  let changed = false;
  list.forEach(function (entry, index) {
    if (typeof entry.id !== 'string' || entry.id.length === 0) {
      const typeName = typeof entry.type === 'string' ? entry.type : 'unknown';
      entry.id = `migrated_${typeName}_${index}`;
      changed = true;
    }

    if (Array.isArray(entry.configs)) {
      entry.configs.forEach(function (config) {
        if (!isRecord(config) || !Array.isArray(config.models)) return;
        config.models.forEach(function (model) {
          if (!isRecord(model) || !Array.isArray(model.customParams)) return;
          model.customParams.forEach(function (param) {
            if (isRecord(param) && param.type == null) {
              param.type = 'string';
              changed = true;
            }
          });
        });
      });
    }

    if (typeof entry.type !== 'string' || entry.type.length === 0) {
      entry.type = 'tts';
      changed = true;
    }
  });

  return {
    metadata: { status: 'ok', changed },
    payload: changed ? JSON.stringify(list) : null,
  };
}

function migrateProviderModelSettings(json) {
  let entries;
  try {
    entries = JSON.parse(json);
  } catch (error) {
    return { metadata: { status: 'parseError', error: String(error) } };
  }
  if (!Array.isArray(entries)) {
    return { metadata: { status: 'parseError', error: 'Expected a list.' } };
  }

  const configs = [];
  const models = [];
  let changed = false;
  entries.forEach(function (entry) {
    if (!isRecord(entry)) return;
    if (!Object.prototype.hasOwnProperty.call(entry, 'configs')) {
      const fields = [
        'providerName',
        'host',
        'key',
        'models',
        'typeConfig',
        'customParams',
        'reasoningParams',
        'endpointType',
      ];
      const config = {};
      fields.forEach((field) => {
        if (Object.prototype.hasOwnProperty.call(entry, field)) {
          config[field] = entry[field];
        }
      });
      entry.configs = ['providerName', 'host', 'key'].some((key) =>
        typeof config[key] === 'string' && config[key].length > 0,
      ) ? [config] : [];
      fields.forEach((field) => delete entry[field]);
      changed = true;
    }
    const entryConfigs = Array.isArray(entry.configs) ? entry.configs : [];
    entryConfigs.filter(isRecord).forEach(function (config) {
      configs.push(config);
      if (Array.isArray(config.models)) {
        models.push(...config.models.filter(isRecord));
      }
    });
  });

  changed = assignUniqueIds(configs, 'config') || changed;
  changed = assignUniqueIds(models, 'model') || changed;
  const normalized = JSON.stringify(entries);
  changed = normalized !== json || changed;
  return {
    metadata: { status: 'ok', changed },
    payload: changed ? normalized : null,
  };
}

function assignUniqueIds(items, prefix) {
  const counts = new Map();
  let changed = false;
  items.forEach(function (item) {
    const id = item.id;
    if (typeof id === 'string' && id.length > 0) {
      counts.set(id, (counts.get(id) || 0) + 1);
    }
  });
  items.forEach(function (item) {
    const id = item.id;
    if (typeof id !== 'string' || id.length === 0 || counts.get(id) !== 1) {
      item.id = `${prefix}_${newUuidV4()}`;
      changed = true;
    }
  });
  return changed;
}

function newUuidV4() {
  const bytes = new Uint8Array(16);
  self.crypto.getRandomValues(bytes);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0'));
  return `${hex.slice(0, 4).join('')}-${hex.slice(4, 6).join('')}-` +
    `${hex.slice(6, 8).join('')}-${hex.slice(8, 10).join('')}-` +
    hex.slice(10, 16).join('');
}

function migrateLegacyConversations(json) {
  let conversations;
  try {
    conversations = JSON.parse(json);
  } catch (error) {
    return 'parse-error\n' + JSON.stringify(String(error));
  }
  if (!Array.isArray(conversations)) return 'not-list';

  let migrated = 0;
  let skipped = 0;
  conversations.forEach(function (conversation) {
    if (!isRecord(conversation)) {
      skipped++;
      return;
    }
    const messages = Array.isArray(conversation.messages)
      ? conversation.messages
      : [];
    messages.forEach(function (message) {
      if (!isRecord(message)) {
        skipped++;
        return;
      }
      if (message.role !== 'assistant') return;
      if (Array.isArray(message.blocks) && message.blocks.length > 0) return;

      try {
        const reasoningSections = asStringList(message.reasoningSections);
        const textChunks = asStringList(message.textSections);
        const toolCalls = asToolCalls(message.toolCalls);
        const toolCallRoundStarts = asIntList(message.toolCallRoundStarts);
        const blocks = legacyToBlocks(
          reasoningSections,
          textChunks,
          toolCalls,
          toolCallRoundStarts,
        );
        if (blocks.length > 0) {
          message.blocks = blocks;
          migrated++;
        }
      } catch (_) {
        // A malformed message is skipped while valid siblings still migrate.
        skipped++;
      }
    });
  });

  return 'ok:' + migrated + ':' + skipped + '\n' + JSON.stringify(conversations);
}

function asStringList(value) {
  if (value == null) return [];
  if (!Array.isArray(value) || value.some((item) => typeof item !== 'string')) {
    throw new TypeError('Expected a list of strings');
  }
  return value;
}

function asIntList(value) {
  if (value == null) return [];
  if (!Array.isArray(value) || value.some((item) => !Number.isInteger(item))) {
    throw new TypeError('Expected a list of integers');
  }
  return value;
}

function asToolCalls(value) {
  if (value == null) return [];
  if (!Array.isArray(value)) throw new TypeError('Expected a list of tool calls');
  return value.map(function (toolCall) {
    if (!isRecord(toolCall)) throw new TypeError('Expected a tool call object');
    if (toolCall.id != null && typeof toolCall.id !== 'string') {
      throw new TypeError('Tool call id must be a string');
    }
    if (toolCall.name != null && typeof toolCall.name !== 'string') {
      throw new TypeError('Tool call name must be a string');
    }
    if (toolCall.status != null && typeof toolCall.status !== 'string') {
      throw new TypeError('Tool call status must be a string');
    }
    if (toolCall.result != null && typeof toolCall.result !== 'string') {
      throw new TypeError('Tool call result must be a string');
    }

    const status = ['running', 'completed', 'error'].includes(toolCall.status)
      ? toolCall.status
      : 'pending';
    const normalized = {
      id: toolCall.id || '',
      name: toolCall.name || '',
      arguments: isRecord(toolCall.arguments) ? toolCall.arguments : {},
      status,
    };
    if (toolCall.result != null) normalized.result = toolCall.result;
    if (typeof toolCall.compactedAt === 'string') {
      const compactedAt = normalizeDateTime(toolCall.compactedAt);
      if (compactedAt != null) normalized.compactedAt = compactedAt;
    }
    return normalized;
  });
}

function normalizeDateTime(value) {
  // Dart parses a date-only DateTime as local midnight. JavaScript treats
  // ISO date-only strings as UTC, so add a local time before parsing to keep
  // the worker conversion equivalent on non-UTC browsers.
  const dateOnly = value.match(/^(\d{4})(?:-(\d{1,2})(?:-(\d{1,2}))?)?$/);
  const parseValue = dateOnly == null
    ? value
    : `${dateOnly[1]}-${(dateOnly[2] || '1').padStart(2, '0')}-` +
      `${(dateOnly[3] || '1').padStart(2, '0')}T00:00:00`;
  const milliseconds = Date.parse(parseValue);
  if (!Number.isFinite(milliseconds)) return null;
  const date = new Date(milliseconds);
  const hasZone = /(?:Z|[+-]\d{2}:?\d{2})$/i.test(value);
  const year = String(hasZone ? date.getUTCFullYear() : date.getFullYear())
    .padStart(4, '0');
  const month = String((hasZone ? date.getUTCMonth() : date.getMonth()) + 1)
    .padStart(2, '0');
  const day = String(hasZone ? date.getUTCDate() : date.getDate())
    .padStart(2, '0');
  const hours = String(hasZone ? date.getUTCHours() : date.getHours())
    .padStart(2, '0');
  const minutes = String(hasZone ? date.getUTCMinutes() : date.getMinutes())
    .padStart(2, '0');
  const seconds = String(hasZone ? date.getUTCSeconds() : date.getSeconds())
    .padStart(2, '0');
  const millisecond = String(
    hasZone ? date.getUTCMilliseconds() : date.getMilliseconds(),
  ).padStart(3, '0');
  let normalized = `${year}-${month}-${day}T${hours}:${minutes}:${seconds}.` +
    millisecond + (hasZone ? 'Z' : '');
  const fraction = value.match(/[T ]\d{2}:\d{2}:\d{2}\.(\d+)/);
  if (fraction != null) {
    const microseconds = (fraction[1] + '000000').slice(3, 6);
    if (/[1-9]/.test(microseconds)) {
      normalized = normalized.replace(/(\.\d{3})(Z?)$/, '$1' + microseconds + '$2');
    }
  }
  return normalized;
}

function legacyToBlocks(reasoningSections, textChunks, toolCalls, roundStarts) {
  const blocks = [];
  const numRounds = roundStarts.length > 0
    ? roundStarts.length
    : (toolCalls.length > 0 ? 1 : 0);

  for (let i = 0; i < numRounds; i++) {
    if (i < reasoningSections.length) {
      blocks.push({
        type: 'reasoning',
        text: reasoningSections[i],
        isComplete: true,
      });
    }
    if (i < textChunks.length && textChunks[i].length > 0) {
      blocks.push({ type: 'text', text: textChunks[i] });
    }
    const start = roundStarts.length > 0 ? roundStarts[i] : i;
    const end = roundStarts.length > 0 && i + 1 < roundStarts.length
      ? roundStarts[i + 1]
      : toolCalls.length;
    for (let j = start; j < end && j < toolCalls.length; j++) {
      if (j < 0) throw new RangeError('Negative tool call index');
      const toolCall = toolCalls[j];
      const block = {
        type: 'tool_call',
        id: toolCall.id,
        name: toolCall.name,
        arguments: toolCall.arguments,
        status: toolCall.status,
      };
      if (toolCall.result != null) block.result = toolCall.result;
      if (toolCall.compactedAt != null) block.compactedAt = toolCall.compactedAt;
      blocks.push(block);
    }
  }

  const maxRemaining = Math.max(reasoningSections.length, textChunks.length);
  for (let i = numRounds; i < maxRemaining; i++) {
    if (i < reasoningSections.length) {
      blocks.push({
        type: 'reasoning',
        text: reasoningSections[i],
        isComplete: true,
      });
    }
    if (i < textChunks.length && textChunks[i].length > 0) {
      blocks.push({ type: 'text', text: textChunks[i] });
    }
  }
  return blocks;
}

function validateDataFormats(providerEntriesJson, conversationsJson) {
  const issues = [];
  validateProviderEntries(providerEntriesJson, issues);
  validateConversations(conversationsJson, issues);
  return issues;
}

function validateJsonBatchAndDataFormats(contents, providerEntriesIndex, conversationsIndex) {
  const parseErrors = [];
  let providerEntries;
  let providerEntriesParseFailed = false;
  let conversations;
  let conversationsParseFailed = false;
  contents.forEach(function (content, index) {
    try {
      const decoded = JSON.parse(content);
      if (index === providerEntriesIndex) providerEntries = decoded;
      if (index === conversationsIndex) conversations = decoded;
      parseErrors.push(null);
    } catch (error) {
      parseErrors.push(String(error));
      if (index === providerEntriesIndex) providerEntriesParseFailed = true;
      if (index === conversationsIndex) conversationsParseFailed = true;
    }
  });
  const issues = [];
  if (providerEntriesIndex != null) {
    validateProviderEntriesValue(
      providerEntries,
      providerEntriesParseFailed,
      issues,
    );
  }
  if (conversationsIndex != null) {
    validateConversationsValue(
      conversations,
      conversationsParseFailed,
      issues,
    );
  }
  return {
    parseErrors,
    issues,
  };
}

function checkDataIntegrity(providerEntriesJson) {
  if (providerEntriesJson == null || providerEntriesJson.length === 0) return [];

  let list;
  try {
    list = JSON.parse(providerEntriesJson);
    if (!Array.isArray(list)) return [];
  } catch (_) {
    return [];
  }

  const knownProviderTypes = ['llm', 'tts', 'ocr', 'asr', 'mcp', 'builtin'];
  const issues = [];
  for (let i = 0; i < list.length; i++) {
    const entry = list[i];
    if (!isRecord(entry)) continue;

    const type = entry.type;
    if (typeof type !== 'string' || type.length === 0) continue;
    if (!knownProviderTypes.includes(type)) {
      issues.push(issue(
        `provider_entries[${i}]: 未知的供应商类型 "${type}"，` +
          '应用可能无法正常使用该供应商',
        'warning',
        'provider_entries',
      ));
    }
  }
  return issues;
}

function validateProviderEntries(json, issues) {
  if (json == null || json.length === 0) return;
  let list;
  try {
    list = JSON.parse(json);
  } catch (_) {
    validateProviderEntriesValue(null, true, issues);
    return;
  }
  validateProviderEntriesValue(list, false, issues);
}

function validateProviderEntriesValue(list, parseFailed, issues) {
  if (parseFailed || !Array.isArray(list)) {
    issues.push(issue(
      'provider_entries 数据格式错误：不是合法的 JSON 数组',
      'error',
      'provider_entries',
    ));
    return;
  }

  list.forEach(function (entry, i) {
    if (!isRecord(entry)) {
      issues.push(issue(
        `provider_entries[${i}]: 条目为 null 或类型无效`,
        'error',
        'provider_entries',
      ));
      return;
    }

    if (typeof entry.id !== 'string' || entry.id.length === 0) {
      issues.push(issue(
        `provider_entries[${i}]: id 字段缺失或为空`,
        'error',
        'provider_entries',
      ));
    }
    if (typeof entry.type !== 'string' || entry.type.length === 0) {
      issues.push(issue(
        `provider_entries[${i}]: type 字段缺失或为空`,
        'warning',
        'provider_entries',
      ));
    }
    if (typeof entry.name !== 'string' || entry.name.length === 0) {
      issues.push(issue(
        `provider_entries[${i}]: name 字段缺失或为空`,
        'warning',
        'provider_entries',
      ));
    }

    const rawConfigs = entry.configs;
    if (rawConfigs != null && !Array.isArray(rawConfigs)) {
      issues.push(issue(
        `provider_entries[${i}].configs: 字段不是合法列表`,
        'error',
        'provider_entries',
      ));
    }
    validateNestedList(entry, 'configs', i, issues);
    if (!Array.isArray(rawConfigs)) return;

    rawConfigs.forEach(function (config, ci) {
      if (!isRecord(config)) return;
      const rawModels = config.models;
      if (rawModels != null && !Array.isArray(rawModels)) {
        issues.push(issue(
          `provider_entries[${i}].configs[${ci}].models: 字段不是合法列表`,
          'error',
          'provider_entries',
        ));
      }
      validateNestedList(config, 'models', i, issues);
      if (!Array.isArray(rawModels)) return;

      rawModels.forEach(function (model) {
        if (!isRecord(model)) return;
        validateNestedList(model, 'customParams', i, issues);
        validateNestedList(model, 'voices', i, issues);
        validateNestedList(model, 'reasoningParams', i, issues);
      });
    });
  });
}

function validateConversations(json, issues) {
  if (json == null || json.length === 0) return;
  let list;
  try {
    list = JSON.parse(json);
  } catch (_) {
    validateConversationsValue(null, true, issues);
    return;
  }
  validateConversationsValue(list, false, issues);
}

function validateConversationsValue(list, parseFailed, issues) {
  if (parseFailed || !Array.isArray(list)) {
    issues.push(issue(
      'conversations 数据格式错误：不是合法的 JSON 数组',
      'error',
      'conversations',
    ));
    return;
  }

  list.forEach(function (conversation, i) {
    if (!isRecord(conversation)) {
      issues.push(issue(
        `conversations[${i}]: 会话为 null 或类型无效`,
        'error',
        'conversations',
      ));
      return;
    }
    if (typeof conversation.id !== 'string' || conversation.id.length === 0) {
      issues.push(issue(
        `conversations[${i}]: id 字段缺失`,
        'error',
        'conversations',
      ));
    }
    if (conversation.messages == null) {
      issues.push(issue(
        `conversations[${i}]: messages 字段缺失`,
        'warning',
        'conversations',
      ));
    } else if (!Array.isArray(conversation.messages)) {
      issues.push(issue(
        `conversations[${i}]: messages 字段不是合法列表`,
        'error',
        'conversations',
      ));
    }
  });
}

function validateNestedList(parent, fieldName, entryIndex, issues) {
  const list = parent[fieldName];
  if (!Array.isArray(list)) return;
  list.forEach(function (item, itemIndex) {
    if (!isRecord(item)) {
      issues.push(issue(
        `provider_entries[${entryIndex}].${fieldName}[${itemIndex}]: 条目不是合法对象，可能会导致解析闪退`,
        'error',
        'provider_entries',
      ));
    }
  });
}

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function issue(message, severity, dataKey) {
  return { message, severity, dataKey };
}
