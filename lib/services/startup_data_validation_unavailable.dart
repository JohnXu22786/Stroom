/// Indicates startup data validation could not run in its background worker.
///
/// Callers must stop startup instead of treating a missing report as clean data.
class StartupDataValidationUnavailable implements Exception {
  final Object? primaryWorkerError;
  final Object? bundledWorkerError;
  final Object? isolateError;

  const StartupDataValidationUnavailable(
    this.primaryWorkerError,
    this.bundledWorkerError,
  ) : isolateError = null;

  const StartupDataValidationUnavailable.isolate(Object error)
      : isolateError = error,
        primaryWorkerError = null,
        bundledWorkerError = null;

  @override
  String toString() {
    final error = isolateError;
    if (error != null) {
      return 'Startup data validation could not run because its Isolate failed: '
          '$error';
    }
    return 'Startup data validation could not run: $primaryWorkerError; '
        'bundled worker: $bundledWorkerError';
  }
}
