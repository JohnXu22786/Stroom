(function (root, factory) {
  const selectStroomManifest = factory();

  if (typeof module === 'object' && module.exports) {
    module.exports = selectStroomManifest;
  }
  if (root) {
    root.selectStroomManifest = selectStroomManifest;
  }
})(typeof window === 'undefined' ? null : window, function () {
  return function selectStroomManifest(languages) {
    const preferredLanguage = Array.isArray(languages)
      ? languages.find((language) => typeof language === 'string' && language.trim())
      : null;

    return preferredLanguage?.toLowerCase().startsWith('zh')
      ? 'manifest.zh_CN.json'
      : 'manifest.json';
  };
});
