import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../anki/database/anki_database.dart';
import '../anki/providers/anki_provider.dart';
import '../anki/sync/anki_collection_transfer.dart';
import '../anki/sync/anki_incremental_sync.dart';
import '../anki/sync/anki_media_sync.dart';
import '../anki/sync/anki_sync_protocol_client.dart';
import '../anki/sync/anki_sync_provider.dart';

class AnkiSyncSettingsPage extends ConsumerStatefulWidget {
  const AnkiSyncSettingsPage({super.key});

  @override
  ConsumerState<AnkiSyncSettingsPage> createState() =>
      _AnkiSyncSettingsPageState();
}

class _AnkiSyncSettingsPageState extends ConsumerState<AnkiSyncSettingsPage> {
  final _urlController = TextEditingController();
  final _certificateController = TextEditingController();
  AnkiSyncProtocolClient? _client;
  String? _clientIdentity;
  String? _loadedIdentity;
  String? _hostKey;
  AnkiRemoteMeta? _remoteMeta;
  String _status = '';
  bool _busy = false;
  bool _restoring = false;
  bool _settingsInitialized = false;

  @override
  void dispose() {
    _client?.close();
    _urlController.dispose();
    _certificateController.dispose();
    super.dispose();
  }

  void _restoreSessionWhenReady(AnkiSyncState config) {
    if (!config.isLoaded ||
        _restoring ||
        _loadedIdentity == config.secureStorageKey) {
      return;
    }
    _restoring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreSession(config));
    });
  }

  void _restoreSessionImmediately(AnkiSyncState config) {
    if (!mounted ||
        !config.isLoaded ||
        _restoring ||
        _loadedIdentity == config.secureStorageKey) {
      return;
    }
    _restoring = true;
    unawaited(_restoreSession(config));
  }

  Future<void> _restoreSession(AnkiSyncState config) async {
    if (!mounted) return;
    try {
      final key = await ref
          .read(ankiSyncSecureStorageProvider)
          .read(key: config.secureStorageKey);
      if (!mounted) return;
      final current = ref.read(ankiSyncProvider);
      if (current.secureStorageKey != config.secureStorageKey) {
        _restoring = false;
        _restoreSessionImmediately(current);
        return;
      }
      setState(() {
        _hostKey = key;
        _remoteMeta = null;
        _status = key == null ? '' : '已恢复安全保存的登录状态';
        _loadedIdentity = config.secureStorageKey;
        _restoring = false;
      });
      if (key != null) _clientFor(current);
    } catch (_) {
      if (!mounted) return;
      final current = ref.read(ankiSyncProvider);
      if (current.secureStorageKey != config.secureStorageKey) {
        _restoring = false;
        _restoreSessionImmediately(current);
        return;
      }
      setState(() {
        _hostKey = null;
        _status = '无法读取已保存的登录状态，请重新登录';
        _loadedIdentity = config.secureStorageKey;
        _restoring = false;
      });
    }
  }

  AnkiSyncProtocolClient _clientFor(AnkiSyncState config) {
    final identity = config.secureStorageKey;
    if (_client != null && _clientIdentity == identity) return _client!;
    _client?.close();
    _client = ref.read(ankiSyncProtocolClientFactoryProvider)(config, _hostKey);
    _clientIdentity = identity;
    return _client!;
  }

  Future<void> _changeMode(AnkiSyncMode mode) async {
    if (_busy || !ref.read(ankiSyncProvider).isLoaded) return;
    _client?.close();
    _client = null;
    setState(() {
      _hostKey = null;
      _remoteMeta = null;
      _status = '';
      _loadedIdentity = null;
    });
    await ref.read(ankiSyncProvider.notifier).setMode(mode);
  }

  Future<void> _saveSelfHostedSettings() async {
    final notifier = ref.read(ankiSyncProvider.notifier);
    final config = ref.read(ankiSyncProvider);
    final rawUrl = _urlController.text.trim();
    final parsedUrl = Uri.tryParse(rawUrl);
    if (parsedUrl == null ||
        !parsedUrl.hasAuthority ||
        (parsedUrl.scheme != 'http' && parsedUrl.scheme != 'https') ||
        (parsedUrl.scheme == 'http' && !_isLoopbackHost(parsedUrl.host)) ||
        parsedUrl.userInfo.isNotEmpty ||
        parsedUrl.hasQuery) {
      throw const AnkiSyncException(
        '服务器地址须为 HTTPS URL；仅本机 loopback 地址可使用 HTTP，且不能包含用户名、密码或 query 参数',
      );
    }
    final oldIdentity = config.secureStorageKey;
    await notifier.setSyncUrl(rawUrl);
    await notifier.setCertificate(_certificateController.text.trim());
    final updated = ref.read(ankiSyncProvider);
    if (updated.secureStorageKey != oldIdentity) {
      _client?.close();
      _client = null;
      setState(() {
        _hostKey = null;
        _remoteMeta = null;
        _status = '';
        _loadedIdentity = null;
      });
    } else if (updated.certificate != config.certificate) {
      _client?.close();
      _client = null;
    }
  }

  Future<AnkiSyncState?> _prepareActionConfig(AnkiSyncState config) async {
    if (config.mode != AnkiSyncMode.selfHosted) return config;
    try {
      await _saveSelfHostedSettings();
    } catch (error) {
      if (mounted) setState(() => _status = '设置未保存：${_safeMessage(error)}');
      return null;
    }
    final updated = ref.read(ankiSyncProvider);
    if (_hostKey == null || _loadedIdentity != updated.secureStorageKey) {
      if (mounted) {
        setState(() => _status = '服务器地址已更改，请重新登录后继续');
      }
      return null;
    }
    return updated;
  }

  Future<void> _login(AnkiSyncState config) async {
    if (config.mode == AnkiSyncMode.selfHosted) {
      try {
        await _saveSelfHostedSettings();
        config = ref.read(ankiSyncProvider);
      } catch (error) {
        if (mounted) setState(() => _status = _safeMessage(error));
        return;
      }
    }

    final credentials = await _showLoginDialog(config.mode);
    if (credentials == null) return;
    setState(() {
      _busy = true;
      _status = '正在验证登录…';
      _hostKey = null;
      _remoteMeta = null;
    });
    try {
      final client = _clientFor(config);
      final key = await client.login(
        credentials['username']!,
        credentials['password']!,
      );
      var persisted = true;
      try {
        await ref
            .read(ankiSyncSecureStorageProvider)
            .write(key: config.secureStorageKey, value: key);
      } catch (_) {
        persisted = false;
      }
      if (!mounted) return;
      setState(() {
        _hostKey = key;
        _loadedIdentity = config.secureStorageKey;
        _status = persisted
            ? '登录成功。密码未保存，同步密钥已加密保存。'
            : '登录成功，但无法安全保存同步密钥；关闭页面后需要重新登录。';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '登录失败：${_safeMessage(error)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, String>?> _showLoginDialog(AnkiSyncMode mode) async {
    final userController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    try {
      return await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(mode == AnkiSyncMode.ankiWeb ? '登录 AnkiWeb' : '登录自建服务器'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: userController,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '邮箱 / 用户名',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? '请输入邮箱或用户名'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? '请输入密码' : null,
                  onFieldSubmitted: (_) {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(dialogContext, {
                        'username': userController.text.trim(),
                        'password': passwordController.text,
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, {
                    'username': userController.text.trim(),
                    'password': passwordController.text,
                  });
                }
              },
              child: const Text('登录'),
            ),
          ],
        ),
      );
    } finally {
      passwordController.clear();
      userController.dispose();
      passwordController.dispose();
    }
  }

  Future<void> _checkStatus(AnkiSyncState config) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = '正在准备服务器设置…';
    });
    try {
      final actionConfig = await _prepareActionConfig(config);
      if (actionConfig == null) return;
      config = actionConfig;
      setState(() {
        _status = '正在读取服务器 collection 状态…';
        _remoteMeta = null;
      });
      final meta = await _clientFor(config).checkStatus();
      if (!mounted) return;
      setState(() {
        _remoteMeta = meta;
        _status = meta.shouldContinue
            ? (meta.isEmpty ? '连接成功，服务器 collection 为空' : '连接成功，服务器状态已读取')
            : (meta.message.isEmpty ? '此服务器要求升级同步客户端' : meta.message);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '状态检查失败：${_safeMessage(error)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload(AnkiSyncState config) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = '正在准备上传设置…';
    });
    String backupPath = '';
    var collectionUploaded = false;
    var transferStarted = false;
    try {
      final actionConfig = await _prepareActionConfig(config);
      if (actionConfig == null) return;
      config = actionConfig;
      if (_remoteMeta == null || !_remoteMeta!.shouldContinue) return;
      final confirmed = await _confirmDestructiveAction(
        title: '用本地 collection 覆盖服务器？',
        message:
            '服务器上的 collection 将被本地数据完整替换。Stroom 会先保留一份本地数据库备份。'
            '\n\n随后仍会按服务器媒体清单双向同步文件。',
        action: '覆盖服务器',
      );
      if (confirmed != true) return;
      transferStarted = true;
      setState(() => _status = '正在备份并上传 collection…');
      await AnkiDatabase.closeOpenedInstance();
      final client = _clientFor(config);
      backupPath = await AnkiCollectionTransfer.uploadLocalCollection(client);
      collectionUploaded = true;
      final media = await AnkiMediaSync.sync(client);
      if (!mounted) return;
      setState(() {
        _remoteMeta = null;
        _status =
            '服务器已接受本地 collection，媒体同步完成：上传 ${media.uploadedFiles} 个，'
            '下载 ${media.downloadedFiles} 个，删除 ${media.deletedFiles} 个。'
            '${backupPath.isEmpty ? '' : '\n本地备份：${p.basename(backupPath)}'}'
            '\n请重新检查服务器状态。';
      });
    } catch (error) {
      if (!mounted) return;
      final prefix = collectionUploaded
          ? '服务器 collection 已替换，但媒体同步未完成：'
          : '上传失败：';
      setState(() => _status = '$prefix${_safeMessage(error)}');
    } finally {
      if (transferStarted) _invalidateAnkiDatabase();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(AnkiSyncState config) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = '正在准备下载设置…';
    });
    var backupPath = '';
    AnkiMediaDownloadReset? mediaReset;
    var transferStarted = false;
    try {
      final actionConfig = await _prepareActionConfig(config);
      if (actionConfig == null) return;
      config = actionConfig;
      final meta = _remoteMeta;
      if (meta == null || !meta.shouldContinue || meta.isEmpty) return;
      final confirmed = await _confirmDestructiveAction(
        title: '用服务器 collection 替换本地？',
        message:
            '本地 collection 将被服务器数据替换。Stroom 会先保留一份本地数据库备份。'
            '\n\n随后会用服务器媒体替换本地媒体并下载缺失文件。若任一步失败，Stroom 会恢复本地 collection 和媒体目录。',
        action: '替换本地数据',
      );
      if (confirmed != true) return;
      transferStarted = true;
      setState(() => _status = '正在下载并验证 collection…');
      final client = _clientFor(config);
      mediaReset = await AnkiMediaSync.prepareForFullDownload(client: client);
      await AnkiDatabase.closeOpenedInstance();
      backupPath =
          await AnkiCollectionTransfer.downloadAndReplaceLocalCollection(
            client,
          );
      final media = await AnkiMediaSync.sync(client);
      await mediaReset.commit();
      if (!mounted) return;
      setState(() {
        _remoteMeta = null;
        _status =
            '本地 collection 已替换，SQLite 检查通过；媒体同步完成：下载 ${media.downloadedFiles} 个，'
            '上传 ${media.uploadedFiles} 个，删除 ${media.deletedFiles} 个。'
            '${backupPath.isEmpty ? '' : '\n本地备份：${p.basename(backupPath)}'}'
            '\n请重新检查服务器状态。';
      });
    } catch (error) {
      if (backupPath.isNotEmpty) {
        try {
          await AnkiCollectionTransfer.restoreLocalCollectionBackup(backupPath);
        } catch (_) {
          // Preserve the sync error while retaining the on-disk backup.
        }
      }
      try {
        await mediaReset?.rollback();
      } catch (_) {
        // The folder backup remains available for manual recovery.
      }
      if (!mounted) return;
      setState(() => _status = '下载失败：${_safeMessage(error)}');
    } finally {
      if (transferStarted) _invalidateAnkiDatabase();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncBothWays(AnkiSyncState config) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = '正在准备同步…';
    });
    var collectionComplete = false;
    try {
      final actionConfig = await _prepareActionConfig(config);
      if (actionConfig == null) return;
      config = actionConfig;
      if (mounted) setState(() => _status = '正在合并 collection 变更…');
      final client = _clientFor(config);
      final database = await ref.read(ankiDatabaseProvider.future);
      final collectionResult = await AnkiIncrementalSync.sync(database, client);
      collectionComplete = true;
      // The collection transaction has committed, so make its changes visible
      // even if the subsequent media phase fails.
      ref.read(ankiRefreshProvider.notifier).refresh();
      if (!mounted) return;
      setState(() => _status = 'Collection 增量合并完成，正在同步媒体文件…');
      final mediaResult = await AnkiMediaSync.sync(client, database: database);
      if (!mounted) return;
      setState(() {
        _remoteMeta = null;
        final collectionText = collectionResult.collectionChanged
            ? '新增/更新 ${collectionResult.changedNotes} 个笔记、'
                  '${collectionResult.changedCards} 张卡片、'
                  '${collectionResult.changedReviews} 条复习记录'
            : 'collection 没有待合并变更';
        _status =
            '双向同步完成：$collectionText；媒体上传 ${mediaResult.uploadedFiles} 个、'
            '下载 ${mediaResult.downloadedFiles} 个、删除 ${mediaResult.deletedFiles} 个。';
      });
    } catch (error) {
      if (!mounted) return;
      final prefix = collectionComplete ? 'Collection 已合并，但媒体同步未完成：' : '同步未完成：';
      setState(() => _status = '$prefix${_safeMessage(error)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmDestructiveAction({
    required String title,
    required String message,
    required String action,
  }) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(action),
        ),
      ],
    ),
  );

  Future<void> _logout(AnkiSyncState config) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = '正在清除登录状态…';
    });
    try {
      await ref
          .read(ankiSyncSecureStorageProvider)
          .delete(key: config.secureStorageKey);
      _client?.close();
      _client = null;
      if (!mounted) return;
      setState(() {
        _hostKey = null;
        _remoteMeta = null;
        _status = '已登出，安全存储中的同步密钥已删除';
      });
    } catch (_) {
      if (mounted) setState(() => _status = '无法清除已保存的登录状态');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _invalidateAnkiDatabase() {
    ref.invalidate(ankiDatabaseProvider);
    ref.invalidate(ankiColDaoProvider);
    ref.invalidate(ankiCardDaoProvider);
    ref.invalidate(ankiNoteDaoProvider);
    ref.invalidate(ankiDeckListProvider);
    ref.invalidate(ankiRefreshProvider);
  }

  String _safeMessage(Object error) => error is AnkiSyncException
      ? error.message
      : error is AnkiSyncFullTransferRequired
      ? error.message
      : '操作未完成，请检查安全存储、网络和服务器地址';

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(ankiSyncProvider);
    final colors = Theme.of(context).colorScheme;
    if (config.isLoaded && !_settingsInitialized) {
      _urlController.text = config.selfHostedUrl;
      _certificateController.text = config.certificate;
      _settingsInitialized = true;
    }
    _restoreSessionWhenReady(config);

    final isLoggedIn = _hostKey != null;
    final title = config.mode == AnkiSyncMode.ankiWeb ? 'AnkiWeb' : '自建同步服务器';

    return Scaffold(
      appBar: AppBar(title: const Text('Anki 同步')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.sync_rounded, color: colors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '选择同步方式',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '登录状态按服务分别保存。切换方式不会合并或覆盖数据。',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SegmentedButton<AnkiSyncMode>(
            segments: const [
              ButtonSegment(
                value: AnkiSyncMode.ankiWeb,
                icon: Icon(Icons.cloud_outlined),
                label: Text('AnkiWeb'),
              ),
              ButtonSegment(
                value: AnkiSyncMode.selfHosted,
                icon: Icon(Icons.dns_outlined),
                label: Text('自建服务器'),
              ),
            ],
            selected: {config.mode},
            onSelectionChanged: _busy || !config.isLoaded
                ? null
                : (selection) => _changeMode(selection.single),
          ),
          if (config.mode == AnkiSyncMode.selfHosted) ...[
            const SizedBox(height: 18),
            _QuietSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('服务器地址', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _urlController,
                    enabled: !_busy,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) async {
                      try {
                        await _saveSelfHostedSettings();
                      } catch (error) {
                        if (mounted) {
                          setState(
                            () => _status = '设置未保存：${_safeMessage(error)}',
                          );
                        }
                      }
                    },
                    decoration: const InputDecoration(
                      hintText: 'https://anki.example.com/sync/',
                      filled: true,
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '自建远程服务器需使用 HTTPS；本机地址可使用 HTTP。'
                    '服务器需支持 Anki sync v10，证书验证默认开启。',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    type: MaterialType.transparency,
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: const Text('自定义 CA 证书（可选）'),
                      subtitle: const Text('仅在服务器使用自签名证书时填写'),
                      children: [
                        TextField(
                          controller: _certificateController,
                          enabled: !_busy,
                          minLines: 3,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            hintText: '-----BEGIN CERTIFICATE-----',
                            filled: true,
                            border: InputBorder.none,
                            alignLabelWithHint: true,
                          ),
                          onChanged: (_) {
                            _client?.close();
                            _client = null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Text(
              '使用官方 AnkiWeb 同步服务。密码只在登录时发送，不会保存在 Stroom。',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 22),
          _QuietSection(
            child: Row(
              children: [
                Icon(
                  _restoring || _busy
                      ? Icons.sync_rounded
                      : isLoggedIn
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  color: isLoggedIn ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLoggedIn ? '已连接 $title' : '未连接 $title',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (_status.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          _status,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_busy || _restoring)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (!isLoggedIn)
                FilledButton.icon(
                  onPressed: !_busy && !_restoring && config.isConfigured
                      ? () => _login(config)
                      : null,
                  icon: const Icon(Icons.login),
                  label: Text('登录$title'),
                )
              else ...[
                FilledButton.icon(
                  onPressed: !_busy ? () => _checkStatus(config) : null,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('检查服务器状态'),
                ),
                OutlinedButton.icon(
                  onPressed: !_busy ? () => _logout(config) : null,
                  icon: const Icon(Icons.logout),
                  label: const Text('登出'),
                ),
              ],
            ],
          ),
          if (_remoteMeta != null) ...[
            const SizedBox(height: 22),
            _RemoteStatus(meta: _remoteMeta!),
            if (_remoteMeta!.shouldContinue) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: !_busy ? () => _syncBothWays(config) : null,
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('双向同步'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: !_busy ? () => _upload(config) : null,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('用本地数据覆盖服务器'),
                  ),
                  if (!_remoteMeta!.isEmpty)
                    OutlinedButton.icon(
                      onPressed: !_busy ? () => _download(config) : null,
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: const Text('用服务器数据替换本地'),
                    ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 20),
          Text(
            '双向同步会合并 collection 的增量变更并传输媒体文件；结构戳不一致时，请选择完整上传或下载。'
            '完整下载失败会尝试恢复原 collection 和媒体目录。',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

bool _isLoopbackHost(String host) {
  final normalizedHost = host.toLowerCase();
  return normalizedHost == 'localhost' ||
      normalizedHost.endsWith('.localhost') ||
      InternetAddress.tryParse(normalizedHost)?.isLoopback == true;
}

class _QuietSection extends StatelessWidget {
  final Widget child;
  const _QuietSection({required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

class _RemoteStatus extends StatelessWidget {
  final AnkiRemoteMeta meta;
  const _RemoteStatus({required this.meta});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final modified = meta.modified <= 0
        ? '未知'
        : DateTime.fromMillisecondsSinceEpoch(meta.modified)
              .toLocal()
              .toString()
              .substring(0, 16);
    return _QuietSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                meta.isEmpty ? Icons.cloud_queue : Icons.cloud_done,
                color: colors.primary,
              ),
              const SizedBox(width: 10),
              Text(
                meta.isEmpty ? '服务器 collection 为空' : '服务器 collection 可用',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '结构版本戳 ${meta.schema} · USN ${meta.usn} · 修改时间 $modified',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (meta.message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              meta.message,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
