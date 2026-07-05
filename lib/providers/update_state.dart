class UpdateState {
  final bool isChecking;
  final String? latestVersion;
  final String? releaseNotes;
  final String? downloadUrl;
  final String? error;
  final bool updateAvailable;

  // Download fields
  final bool isDownloading;
  final double downloadProgress;
  final bool downloadComplete;
  final String? downloadError;
  final String? downloadedFilePath;

  // Auto-install field: true while the app is auto-installing
  // the downloaded update immediately after download completes.
  final bool isInstalling;

  /// Whether the user accepts pre-release versions in update checks.
  /// When true, checks include pre-releases; when false, only stable releases.
  final bool acceptPreRelease;

  const UpdateState({
    this.isChecking = false,
    this.latestVersion,
    this.releaseNotes,
    this.downloadUrl,
    this.error,
    this.updateAvailable = false,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
    this.downloadComplete = false,
    this.downloadError,
    this.downloadedFilePath,
    this.isInstalling = false,
    this.acceptPreRelease = false,
  });

  UpdateState copyWith({
    bool? isChecking,
    String? latestVersion,
    String? releaseNotes,
    String? downloadUrl,
    String? error,
    bool? updateAvailable,
    bool? isDownloading,
    double? downloadProgress,
    bool? downloadComplete,
    String? downloadError,
    String? downloadedFilePath,
    bool? isInstalling,
    bool? acceptPreRelease,
  }) {
    return UpdateState(
      isChecking: isChecking ?? this.isChecking,
      latestVersion: latestVersion ?? this.latestVersion,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      error: error ?? this.error,
      updateAvailable: updateAvailable ?? this.updateAvailable,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadComplete: downloadComplete ?? this.downloadComplete,
      downloadError: downloadError ?? this.downloadError,
      downloadedFilePath: downloadedFilePath ?? this.downloadedFilePath,
      isInstalling: isInstalling ?? this.isInstalling,
      acceptPreRelease: acceptPreRelease ?? this.acceptPreRelease,
    );
  }
}