import 'dart:html' as html;

import 'package:stroom/services/startup_preferences.dart';

// The neighboring symlinks expose the tracked suite and worker asset to the
// Flutter Web test server.
import 'startup_check_service_test_source.dart' as checks;

void main() {
  StartupPreferences.debugUseLegacyPreferencesForTesting = true;
  checks.loadStartupValidationWorkerSourceForTesting = () =>
      html.HttpRequest.getString(
        Uri.base.resolve('/startup/data_integrity_json_worker.js').toString(),
      );
  checks.main();
}
