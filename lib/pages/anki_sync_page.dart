import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:stroom/l10n/app_localizations.dart';

import '../anki/database/anki_database.dart';
import '../anki/providers/anki_provider.dart';
import '../anki/sync/anki_collection_transfer.dart';
import '../anki/sync/anki_full_download_recovery.dart';
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
  bool _closeClientWhenIdle = false;
  bool _restoring = false;
  bool _settingsInitialized = false;

  @override
  void dispose() {
    if (_busy) {
      _closeClientWhenIdle = true;
    } else {
      _client?.close();
      _client = null;
    }
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
        _status = key == null
            ? ''
            : AppLocalizations.of(context)!.ankiSyncStatusRestored;
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
        _status =
            AppLocalizations.of(context)!.ankiSyncStatusReadSavedSessionFailed;
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
      throw AnkiSyncException(
        AppLocalizations.of(context)!.ankiSyncInvalidServerUrl,
      );
    }
    final oldIdentity = config.secureStorageKey;
    await notifier.setSyncUrl(rawUrl);
    await notifier.setCertificate(_certificateController.text.trim());
    if (!mounted) return;
    final updated = ref.read(ankiSyncProvider);
    if (updated.secureStorageKey != oldIdentity) {
      _client?.close();
      _client = null;
      if (mounted) {
        setState(() {
          _hostKey = null;
          _remoteMeta = null;
          _status = '';
          _loadedIdentity = null;
        });
      }
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
      if (mounted)
        setState(() => _status = AppLocalizations.of(context)!
            .ankiSyncStatusSettingsNotSaved(_safeMessage(context, error)));
      return null;
    }
    if (!mounted) return null;
    final updated = ref.read(ankiSyncProvider);
    if (_hostKey == null || _loadedIdentity != updated.secureStorageKey) {
      if (mounted) {
        setState(() => _status =
            AppLocalizations.of(context)!.ankiSyncStatusServerAddressChanged);
      }
      return null;
    }
    return updated;
  }

  Future<void> _login(AnkiSyncState config) async {
    if (config.mode == AnkiSyncMode.selfHosted) {
      try {
        await _saveSelfHostedSettings();
        if (!mounted) return;
        config = ref.read(ankiSyncProvider);
      } catch (error) {
        if (mounted) setState(() => _status = _safeMessage(context, error));
        return;
      }
    }

    final credentials = await _showLoginDialog(config.mode);
    if (!mounted || credentials == null) return;
    setState(() {
      _busy = true;
      _status = AppLocalizations.of(context)!.ankiSyncStatusVerifyingLogin;
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
            ? AppLocalizations.of(context)!.ankiSyncStatusLoginSuccess
            : AppLocalizations.of(context)!.ankiSyncStatusLoginSuccessNoSave;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = AppLocalizations.of(context)!
          .ankiSyncStatusLoginFailed(_safeMessage(context, error)));
    } finally {
      _closeClientIfDisposed();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, String>?> _showLoginDialog(AnkiSyncMode mode) async {
    final formKey = GlobalKey<FormState>();
    var username = '';
    var password = '';

    void submit(BuildContext dialogContext) {
      final form = formKey.currentState!;
      if (!form.validate()) return;
      form.save();
      Navigator.pop(dialogContext, {
        'username': username.trim(),
        'password': password,
      });
    }

    try {
      return await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            mode == AnkiSyncMode.ankiWeb
                ? AppLocalizations.of(dialogContext)!.ankiSyncLoginAnkiWeb
                : AppLocalizations.of(dialogContext)!.ankiSyncLoginSelfHosted,
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(dialogContext)!
                        .ankiSyncEmailOrUsername,
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? AppLocalizations.of(dialogContext)!
                          .ankiSyncEmailOrUsernameRequired
                      : null,
                  onSaved: (value) => username = value ?? '',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText:
                        AppLocalizations.of(dialogContext)!.ankiSyncPassword,
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? AppLocalizations.of(dialogContext)!
                          .ankiSyncPasswordRequired
                      : null,
                  onSaved: (value) => password = value ?? '',
                  onFieldSubmitted: (_) => submit(dialogContext),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(dialogContext)!.actionCancel),
            ),
            FilledButton(
              onPressed: () => submit(dialogContext),
              child: Text(AppLocalizations.of(dialogContext)!.ankiSyncLogin),
            ),
          ],
        ),
      );
    } finally {
      password = '';
    }
  }

  Future<void> _checkStatus(AnkiSyncState config) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status =
          AppLocalizations.of(context)!.ankiSyncStatusPreparingServerSettings;
    });
    try {
      final actionConfig = await _prepareActionConfig(config);
      if (!mounted || actionConfig == null) return;
      config = actionConfig;
      setState(() {
        _status = AppLocalizations.of(context)!.ankiSyncStatusReadingCollection;
        _remoteMeta = null;
      });
      final meta = await _clientFor(config).checkStatus();
      if (!mounted) return;
      setState(() {
        _remoteMeta = meta;
        _status = meta.shouldContinue
            ? (meta.isEmpty
                ? AppLocalizations.of(context)!
                    .ankiSyncStatusConnectedCollectionEmpty
                : AppLocalizations.of(context)!
                    .ankiSyncStatusConnectedStatusRead)
            : (meta.message.isEmpty
                ? AppLocalizations.of(context)!.ankiSyncStatusUpgradeClient
                : meta.message);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = AppLocalizations.of(context)!
          .ankiSyncStatusCheckFailed(_safeMessage(context, error)));
    } finally {
      _closeClientIfDisposed();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload(AnkiSyncState config) async {
    if (_busy) return;
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _busy = true;
      _status = AppLocalizations.of(context)!.ankiSyncStatusPreparingUpload;
    });
    String backupPath = '';
    var collectionUploaded = false;
    var transferStarted = false;
    try {
      final actionConfig = await _prepareActionConfig(config);
      if (!mounted || actionConfig == null) return;
      config = actionConfig;
      if (_remoteMeta == null || !_remoteMeta!.shouldContinue) return;
      final confirmed = await _confirmDestructiveAction(
        title:
            AppLocalizations.of(context)!.ankiSyncOverwriteServerConfirmTitle,
        message:
            AppLocalizations.of(context)!.ankiSyncOverwriteServerConfirmMessage,
        action: AppLocalizations.of(context)!.ankiSyncOverwriteServerAction,
      );
      if (confirmed != true) return;
      transferStarted = true;
      setState(() => _status =
          AppLocalizations.of(context)!.ankiSyncStatusBackingUpUploading);
      await AnkiDatabase.closeOpenedInstance();
      final client = _clientFor(config);
      backupPath = await AnkiCollectionTransfer.uploadLocalCollection(client);
      collectionUploaded = true;
      final media = await AnkiMediaSync.sync(client);
      if (!mounted) return;
      setState(() {
        _remoteMeta = null;
        _status = AppLocalizations.of(context)!.ankiSyncStatusUploadComplete(
          media.uploadedFiles,
          media.downloadedFiles,
          media.deletedFiles,
          backupPath.isEmpty
              ? ''
              : AppLocalizations.of(context)!.ankiSyncStatusBackupPath(
                  p.basename(backupPath),
                ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      final prefix = collectionUploaded
          ? AppLocalizations.of(context)!.ankiSyncStatusMediaSyncIncomplete
          : AppLocalizations.of(context)!.ankiSyncStatusUploadFailed;
      setState(() => _status = '$prefix${_safeMessage(context, error)}');
    } finally {
      if (transferStarted) _invalidateAnkiDatabase(container);
      _closeClientIfDisposed();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(AnkiSyncState config) async {
    if (_busy) return;
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _busy = true;
      _status = AppLocalizations.of(context)!.ankiSyncStatusPreparingDownload;
    });
    var backupPath = '';
    AnkiMediaDownloadReset? mediaReset;
    AnkiFullDownloadRecovery? recovery;
    var transferStarted = false;
    try {
      final actionConfig = await _prepareActionConfig(config);
      if (!mounted || actionConfig == null) return;
      config = actionConfig;
      final meta = _remoteMeta;
      if (meta == null || !meta.shouldContinue || meta.isEmpty) return;
      final confirmed = await _confirmDestructiveAction(
        title: AppLocalizations.of(context)!.ankiSyncReplaceLocalConfirmTitle,
        message:
            AppLocalizations.of(context)!.ankiSyncReplaceLocalConfirmMessage,
        action: AppLocalizations.of(context)!.ankiSyncReplaceLocalAction,
      );
      if (confirmed != true) return;
      transferStarted = true;
      setState(() => _status =
          AppLocalizations.of(context)!.ankiSyncStatusDownloadingValidating);
      final client = _clientFor(config);
      await AnkiDatabase.closeOpenedInstance();
      recovery = await AnkiFullDownloadRecovery.begin(
        documentsPath: (await getApplicationDocumentsDirectory()).path,
        destinationIdentity: client.destinationIdentity,
      );
      mediaReset = await AnkiMediaSync.prepareForFullDownload(
        client: client,
        recovery: recovery,
      );
      backupPath =
          await AnkiCollectionTransfer.downloadAndReplaceLocalCollection(
        client,
        recovery: recovery,
      );
      final media = await AnkiMediaSync.sync(client);
      await recovery.commit();
      await mediaReset.commit();
      if (!mounted) return;
      setState(() {
        _remoteMeta = null;
        _status = AppLocalizations.of(context)!.ankiSyncStatusDownloadComplete(
          media.downloadedFiles,
          media.uploadedFiles,
          media.deletedFiles,
          backupPath.isEmpty
              ? ''
              : AppLocalizations.of(context)!.ankiSyncStatusBackupPath(
                  p.basename(backupPath),
                ),
        );
      });
    } catch (error) {
      try {
        await recovery?.rollback();
      } catch (_) {
        // The durable journal retries rollback before the next collection open.
      }
      if (!mounted) return;
      setState(() => _status = AppLocalizations.of(context)!
          .ankiSyncStatusDownloadFailed(_safeMessage(context, error)));
    } finally {
      if (transferStarted) _invalidateAnkiDatabase(container);
      _closeClientIfDisposed();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncBothWays(AnkiSyncState config) async {
    if (_busy) return;
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _busy = true;
      _status = AppLocalizations.of(context)!.ankiSyncStatusPreparingSync;
    });
    var collectionComplete = false;
    try {
      final actionConfig = await _prepareActionConfig(config);
      if (!mounted || actionConfig == null) return;
      config = actionConfig;
      if (mounted)
        setState(() => _status =
            AppLocalizations.of(context)!.ankiSyncStatusMergingChanges);
      final client = _clientFor(config);
      final database = await container.read(ankiDatabaseProvider.future);
      final collectionResult = await AnkiIncrementalSync.sync(database, client);
      collectionComplete = true;
      // The collection transaction has committed, so make its changes visible
      // even if the subsequent media phase fails.
      container.read(ankiRefreshProvider.notifier).refresh();
      if (mounted) {
        setState(() => _status =
            AppLocalizations.of(context)!.ankiSyncStatusMergeCompleteSyncMedia);
      }
      final mediaResult = await AnkiMediaSync.sync(client, database: database);
      if (!mounted) return;
      setState(() {
        _remoteMeta = null;
        final collectionText = collectionResult.collectionChanged
            ? AppLocalizations.of(context)!.ankiSyncStatusChangedNotes(
                collectionResult.changedNotes,
                collectionResult.changedCards,
                collectionResult.changedReviews,
              )
            : AppLocalizations.of(context)!.ankiSyncStatusNoCollectionChanges;
        _status = AppLocalizations.of(context)!.ankiSyncStatusTwoWayComplete(
          collectionText,
          mediaResult.uploadedFiles,
          mediaResult.downloadedFiles,
          mediaResult.deletedFiles,
        );
      });
    } catch (error) {
      if (!mounted) return;
      final prefix = collectionComplete
          ? AppLocalizations.of(context)!
              .ankiSyncStatusCollectionMergedMediaIncomplete
          : AppLocalizations.of(context)!.ankiSyncStatusSyncIncomplete;
      setState(() => _status = '$prefix${_safeMessage(context, error)}');
    } finally {
      _closeClientIfDisposed();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmDestructiveAction({
    required String title,
    required String message,
    required String action,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppLocalizations.of(dialogContext)!.actionCancel),
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
      _status = AppLocalizations.of(context)!.ankiSyncStatusClearingLogin;
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
        _status = AppLocalizations.of(context)!.ankiSyncStatusLoggedOut;
      });
    } catch (_) {
      if (mounted)
        setState(() => _status =
            AppLocalizations.of(context)!.ankiSyncStatusClearLoginFailed);
    } finally {
      _closeClientIfDisposed();
      if (mounted) setState(() => _busy = false);
    }
  }

  void _invalidateAnkiDatabase(ProviderContainer container) {
    container.invalidate(ankiDatabaseProvider);
    container.invalidate(ankiColDaoProvider);
    container.invalidate(ankiCardDaoProvider);
    container.invalidate(ankiNoteDaoProvider);
    container.invalidate(ankiDeckListProvider);
    container.invalidate(ankiRefreshProvider);
  }

  void _closeClientIfDisposed() {
    if (!_closeClientWhenIdle) return;
    _client?.close();
    _client = null;
    _clientIdentity = null;
    _closeClientWhenIdle = false;
  }

  String _safeMessage(BuildContext context, Object error) =>
      error is AnkiSyncException
          ? error.message
          : error is AnkiSyncFullTransferRequired
              ? error.message
              : AppLocalizations.of(context)!.ankiSyncStatusOperationIncomplete;

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
    final l10n = AppLocalizations.of(context)!;
    final title = config.mode == AnkiSyncMode.ankiWeb
        ? 'AnkiWeb'
        : l10n.ankiSyncSelfHostedMode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ankiSyncPageTitle)),
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
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.sync_rounded, color: colors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.ankiSyncChooseMode,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.ankiSyncModeHelp,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SegmentedButton<AnkiSyncMode>(
            segments: [
              ButtonSegment(
                value: AnkiSyncMode.ankiWeb,
                icon: Icon(Icons.cloud_outlined),
                label: Text('AnkiWeb'),
              ),
              ButtonSegment(
                value: AnkiSyncMode.selfHosted,
                icon: Icon(Icons.dns_outlined),
                label: Text(l10n.ankiSyncSelfHostedMode),
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
                  Text(l10n.ankiSyncServerAddress,
                      style: Theme.of(context).textTheme.titleSmall),
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
                            () => _status = AppLocalizations.of(context)!
                                .ankiSyncStatusSettingsNotSaved(
                                    _safeMessage(context, error)),
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
                    l10n.ankiSyncServerHelp,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    type: MaterialType.transparency,
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: Text(l10n.ankiSyncCustomCaTitle),
                      subtitle: Text(l10n.ankiSyncCustomCaHelp),
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
              l10n.ankiSyncOfficialHelp,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
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
                        isLoggedIn
                            ? l10n.ankiSyncConnected(title)
                            : l10n.ankiSyncNotConnected(title),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (_status.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          _status,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
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
                  label: Text(l10n.ankiSyncLoginForService(title)),
                )
              else ...[
                FilledButton.icon(
                  onPressed: !_busy ? () => _checkStatus(config) : null,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(l10n.ankiSyncCheckServerStatus),
                ),
                OutlinedButton.icon(
                  onPressed: !_busy ? () => _logout(config) : null,
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.ankiSyncLogout),
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
                    label: Text(l10n.ankiSyncBothWays),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: !_busy ? () => _upload(config) : null,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(l10n.ankiSyncOverwriteServer),
                  ),
                  if (!_remoteMeta!.isEmpty)
                    OutlinedButton.icon(
                      onPressed: !_busy ? () => _download(config) : null,
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: Text(l10n.ankiSyncReplaceLocal),
                    ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 20),
          Text(
            l10n.ankiSyncHelp,
            style: Theme.of(context)
                .textTheme
                .bodySmall
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
        borderRadius: BorderRadius.circular(16),
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
        ? AppLocalizations.of(context)!.ankiSyncUnknown
        : DateTime.fromMillisecondsSinceEpoch(meta.modified * 1000)
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
                meta.isEmpty
                    ? AppLocalizations.of(context)!
                        .ankiSyncServerCollectionEmpty
                    : AppLocalizations.of(context)!
                        .ankiSyncServerCollectionAvailable,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!
                .ankiSyncSchemaStatus(meta.schema, meta.usn, modified),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (meta.message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              meta.message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
