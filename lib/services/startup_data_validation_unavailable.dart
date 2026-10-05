/// Indicates both browser workers needed to validate startup data failed.
///
/// Callers must stop startup instead of treating a missing report as clean data.
class StartupDataValidationUnavailable implements Exception {
  final Object primaryWorkerError;
  final Object bundledWorkerError;

  const StartupDataValidationUnavailable(
    this.primaryWorkerError,
    this.bundledWorkerError,
  );

  @override
  String toString() =>
      'Startup data validation could not run: $primaryWorkerError; '
      'bundled worker: $bundledWorkerError';
}
