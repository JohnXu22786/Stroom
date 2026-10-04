/// Web and other platforms rely on File.rename for hash-blob publication.
Future<bool> replaceExistingBlob(String stagedPath, String targetPath) async =>
    false;
