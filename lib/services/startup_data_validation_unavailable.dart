/// Indicates required startup data validation or migration could not complete.
///
/// Callers must stop startup instead of treating a missing report as clean data.
class StartupDataValidationUnavailable implements Exception {
  final Object? primaryWorkerError;
  final Object? bundledWorkerError;
  final Object? isolateError;
  final Object? migrationError;

  const StartupDataValidationUnavailable(
    this.primaryWorkerError,
    this.bundledWorkerError,
  )   : isolateError = null,
        migrationError = null;

  const StartupDataValidationUnavailable.isolate(Object error)
      : isolateError = error,
        primaryWorkerError = null,
        bundledWorkerError = null,
        migrationError = null;

  const StartupDataValidationUnavailable.migration(Object error)
      : migrationError = error,
        primaryWorkerError = null,
        bundledWorkerError = null,
        isolateError = null;

  @override
  String toString() {
    final migration = migrationError;
    if (migration != null) {
      return 'Startup data migration could not complete: $migration';
    }
    final error = isolateError;
    if (error != null) {
      return 'Startup data validation could not run because its Isolate failed: '
          '$error';
    }
    return 'Startup data validation could not run: $primaryWorkerError; '
        'bundled worker: $bundledWorkerError';
  }
}
