self.addEventListener('message', function (event) {
  const [operation, first, second] = event.data;
  let result;
  if (operation === 'parseJsonBatch') {
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
  } else if (operation === 'checkDataIntegrity') {
    result = checkDataIntegrity(first);
  } else {
    throw new Error('Unknown JSON worker operation');
  }
  self.postMessage(JSON.stringify(result));
});

function validateDataFormats(providerEntriesJson, conversationsJson) {
  const issues = [];
  validateProviderEntries(providerEntriesJson, issues);
  validateConversations(conversationsJson, issues);
  return issues;
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
    if (!Array.isArray(list)) throw new Error();
  } catch (_) {
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
    if (!Array.isArray(list)) throw new Error();
  } catch (_) {
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
