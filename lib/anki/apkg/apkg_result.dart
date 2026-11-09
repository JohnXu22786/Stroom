import '../../l10n/app_localizations.dart';

enum AnkiApkgErrorCode {
  fileNotFound,
  collectionMissing,
  targetDatabaseMissing,
  databaseCorrupt,
  exportFailed,
  unexpectedError,
}

class AnkiApkgException implements Exception {
  final AnkiApkgErrorCode code;
  final String? path;

  const AnkiApkgException(this.code) : path = null;
  const AnkiApkgException.fileNotFound(this.path)
      : code = AnkiApkgErrorCode.fileNotFound;
  const AnkiApkgException.targetDatabaseMissing(this.path)
      : code = AnkiApkgErrorCode.targetDatabaseMissing;
  const AnkiApkgException.unexpectedError(this.path)
      : code = AnkiApkgErrorCode.unexpectedError;
  const AnkiApkgException.exportFailed(this.path)
      : code = AnkiApkgErrorCode.exportFailed;

  String localizedMessage(AppLocalizations l10n) => switch (code) {
        AnkiApkgErrorCode.fileNotFound => l10n.backupRestoreApkgFileNotFound(
            path ?? '',
          ),
        AnkiApkgErrorCode.collectionMissing =>
          l10n.backupRestoreApkgCollectionMissing,
        AnkiApkgErrorCode.targetDatabaseMissing =>
          l10n.backupRestoreApkgTargetMissing(path ?? ''),
        AnkiApkgErrorCode.databaseCorrupt =>
          l10n.backupRestoreApkgDatabaseCorrupt,
        AnkiApkgErrorCode.exportFailed =>
          l10n.backupRestoreApkgExportFailed(path ?? ''),
        AnkiApkgErrorCode.unexpectedError =>
          l10n.backupRestoreApkgUnexpectedError(path ?? ''),
      };
}

class AnkiApkgImportSummary {
  final int decksImported;
  final int notesImported;
  final int cardsImported;

  const AnkiApkgImportSummary({
    required this.decksImported,
    required this.notesImported,
    required this.cardsImported,
  });

  String format(AppLocalizations l10n) => l10n.backupRestoreApkgImportSummary(
        decksImported,
        notesImported,
        cardsImported,
      );
}
