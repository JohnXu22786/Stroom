import ast
import os
import sys
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tool" / "qa"))

from capture_build_dependencies import capture_build_inputs, needs_rebuild  # noqa: E402


class CaptureBuildDependenciesTest(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.root = Path(self.temporary_directory.name)
        self.entrypoint = self.root / "tool/qa/capture.dart"
        self.entrypoint.parent.mkdir(parents=True)
        self.entrypoint.write_text(
            "@Deprecated('old') import 'package:stroom/utils/annotated_input.dart';\n"
            "import 'package:stroom/pages/capture_page.dart'; "
            "export 'package:stroom/utils/capture_extra.dart'; "
            "import 'package:local_capture_package/local_widget.dart'; "
            "import 'package:inline_capture_package/inline_widget.dart';\n",
            encoding="utf-8",
        )
        self.transitive_input = self.root / "lib/widgets/capture_widget.dart"
        self.transitive_input.parent.mkdir(parents=True)
        self.transitive_input.write_text("class CaptureWidget {}\n", encoding="utf-8")
        (self.root / "lib/pages").mkdir(parents=True)
        (self.root / "lib/pages/capture_page.dart").write_text(
            "import '../widgets/capture_widget.dart';\n"
            "/* platform selection */ export '../utils/capture_platform_stub.dart' "
            "// conditional; web target follows\n"
            "    if (dart.library.html) '../utils/capture_platform_web.dart';\n",
            encoding="utf-8",
        )
        (self.root / "lib/utils").mkdir(parents=True)
        (self.root / "lib/utils/capture_platform_stub.dart").write_text(
            "class CapturePlatform {}\n", encoding="utf-8"
        )
        self.web_implementation = self.root / "lib/utils/capture_platform_web.dart"
        self.web_implementation.write_text("class CapturePlatform {}\n", encoding="utf-8")
        self.same_line_input = self.root / "lib/utils/capture_extra.dart"
        self.same_line_input.write_text("class CaptureExtra {}\n", encoding="utf-8")
        self.annotated_input = self.root / "lib/utils/annotated_input.dart"
        self.annotated_input.write_text("class AnnotatedInput {}\n", encoding="utf-8")
        self.local_package = self.root / "packages/local_capture_package"
        (self.local_package / "lib").mkdir(parents=True)
        (self.local_package / "pubspec.yaml").write_text(
            "name: local_capture_package\n"
            "dependencies:\n"
            "  nested_capture_package:\n"
            "    path: ../nested_capture_package\n",
            encoding="utf-8",
        )
        (self.root / "pubspec.yaml").write_text(
            "name: capture_test\n"
            "dependency_overrides:\n"
            "  local_capture_package:\n"
            "    path: packages/local_capture_package\n"
            "  inline_capture_package: {path: packages/inline_capture_package}\n",
            encoding="utf-8",
        )
        self.local_package_input = self.local_package / "lib/local_widget.dart"
        self.local_package_input.write_text(
            "import 'package:nested_capture_package/nested_widget.dart';\n"
            "class LocalWidget {}\n",
            encoding="utf-8",
        )
        self.nested_package = self.root / "packages/nested_capture_package"
        (self.nested_package / "lib").mkdir(parents=True)
        (self.nested_package / "pubspec.yaml").write_text(
            "name: nested_capture_package\n", encoding="utf-8"
        )
        self.nested_package_input = self.nested_package / "lib/nested_widget.dart"
        self.nested_package_input.write_text("class NestedWidget {}\n", encoding="utf-8")
        self.inline_package = self.root / "packages/inline_capture_package"
        (self.inline_package / "lib").mkdir(parents=True)
        (self.inline_package / "pubspec.yaml").write_text(
            "name: inline_capture_package\n", encoding="utf-8"
        )
        self.inline_package_input = self.inline_package / "lib/inline_widget.dart"
        self.inline_package_input.write_text("class InlineWidget {}\n", encoding="utf-8")
        self.bundle = self.root / "build/index.html"
        self.bundle.parent.mkdir()
        self.bundle.write_text("built bundle\n", encoding="utf-8")

    def test_newer_transitive_production_import_requires_rebuild(self):
        newer_mtime = self.bundle.stat().st_mtime + 1
        os.utime(self.transitive_input, (newer_mtime, newer_mtime))

        self.assertTrue(needs_rebuild(self.root, self.entrypoint, self.bundle))

    def test_newer_metadata_annotated_import_requires_rebuild(self):
        newer_mtime = self.bundle.stat().st_mtime + 1
        os.utime(self.annotated_input, (newer_mtime, newer_mtime))

        self.assertTrue(needs_rebuild(self.root, self.entrypoint, self.bundle))

    def test_unchanged_transitive_production_import_does_not_require_rebuild(self):
        self.assertFalse(needs_rebuild(self.root, self.entrypoint, self.bundle))

    def test_missing_bundle_requires_rebuild(self):
        missing_bundle = self.root / "missing-build/index.html"

        self.assertTrue(needs_rebuild(self.root, self.entrypoint, missing_bundle))

    def test_qa_capture_scripts_use_transitive_build_dependency_check(self):
        script_calls = {
            ("tool/qa", "capture_anki_delete_confirmation.py"): "capture_entrypoint",
            ("tool/qa", "capture_file_info_label.py"): "capture_entrypoint",
            ("tool/qa", "capture_vertical_editor_gutter_scale.py"): "entrypoint",
            ("tools/qa", "capture_vertical_backup_error.py"): "capture_entrypoint",
            ("tools/qa", "capture_vertical_provider_config_header.py"): "capture_entrypoint",
        }
        repository_root = Path(__file__).resolve().parents[2]

        for (qa_directory, script_name), entrypoint_name in script_calls.items():
            with self.subTest(script=script_name):
                script = ast.parse(
                    (repository_root / qa_directory / script_name).read_text()
                )
                checks_dependencies = any(
                    isinstance(node, ast.If)
                    and isinstance(node.test, ast.Call)
                    and isinstance(node.test.func, ast.Name)
                    and node.test.func.id == "needs_rebuild"
                    and len(node.test.args) == 3
                    and isinstance(node.test.args[0], ast.Name)
                    and node.test.args[0].id == "ROOT"
                    and isinstance(node.test.args[1], ast.Name)
                    and node.test.args[1].id == entrypoint_name
                    for node in ast.walk(script)
                )
                self.assertTrue(checks_dependencies)

    def _assert_newer_transitive_source_requires_rebuild(self, entrypoint_path):
        entrypoint = self.root / entrypoint_path
        entrypoint.parent.mkdir(parents=True, exist_ok=True)
        entrypoint.write_text(
            "import 'package:stroom/widgets/capture_widget.dart';\n",
            encoding="utf-8",
        )
        capture_widget = self.root / "lib/widgets/capture_widget.dart"
        capture_widget.parent.mkdir(parents=True, exist_ok=True)
        capture_widget.write_text(
            "import '../utils/capture_dependency.dart';\n",
            encoding="utf-8",
        )
        transitive_source = self.root / "lib/utils/capture_dependency.dart"
        transitive_source.parent.mkdir(parents=True, exist_ok=True)
        transitive_source.write_text("class CaptureDependency {}\n", encoding="utf-8")
        bundle = self.root / "build/index.html"
        bundle.parent.mkdir(parents=True, exist_ok=True)
        bundle.write_text("built bundle\n", encoding="utf-8")
        newer_mtime = bundle.stat().st_mtime + 1
        os.utime(transitive_source, (newer_mtime, newer_mtime))

        self.assertTrue(needs_rebuild(self.root, entrypoint, bundle))

    def test_vertical_backup_error_capture_tracks_transitive_source(self):
        self._assert_newer_transitive_source_requires_rebuild(
            "tool/qa/vertical_backup_error_capture.dart"
        )

    def test_vertical_provider_config_header_capture_tracks_transitive_source(self):
        self._assert_newer_transitive_source_requires_rebuild(
            "tool/qa/vertical_provider_config_header_capture.dart"
        )

    def test_newer_conditional_production_import_requires_rebuild(self):
        newer_mtime = self.bundle.stat().st_mtime + 1
        os.utime(self.web_implementation, (newer_mtime, newer_mtime))

        self.assertTrue(needs_rebuild(self.root, self.entrypoint, self.bundle))

    def test_newer_same_line_production_import_requires_rebuild(self):
        newer_mtime = self.bundle.stat().st_mtime + 1
        os.utime(self.same_line_input, (newer_mtime, newer_mtime))

        self.assertTrue(needs_rebuild(self.root, self.entrypoint, self.bundle))

    def test_newer_import_from_local_path_package_requires_rebuild(self):
        newer_mtime = self.bundle.stat().st_mtime + 1
        os.utime(self.local_package_input, (newer_mtime, newer_mtime))

        self.assertTrue(needs_rebuild(self.root, self.entrypoint, self.bundle))

    def test_newer_import_from_inline_local_path_package_requires_rebuild(self):
        newer_mtime = self.bundle.stat().st_mtime + 1
        os.utime(self.inline_package_input, (newer_mtime, newer_mtime))

        self.assertTrue(needs_rebuild(self.root, self.entrypoint, self.bundle))

    def test_newer_transitive_local_path_package_import_requires_rebuild(self):
        newer_mtime = self.bundle.stat().st_mtime + 1
        os.utime(self.nested_package_input, (newer_mtime, newer_mtime))

        self.assertTrue(needs_rebuild(self.root, self.entrypoint, self.bundle))

    def test_vertical_result_dialog_capture_tracks_imported_dialog_source(self):
        root = self.root / "vertical-result-dialog-capture"
        entrypoint = root / "tool/qa/vertical_result_dialog_scroll_capture.dart"
        entrypoint.parent.mkdir(parents=True)
        entrypoint.write_text(
            "import 'package:stroom/widgets/backup_restore_result_dialogs.dart';\n",
            encoding="utf-8",
        )
        dialog_source = root / "lib/widgets/backup_restore_result_dialogs.dart"
        dialog_source.parent.mkdir(parents=True)
        dialog_source.write_text(
            "import 'constrained_text.dart';\nclass BackupRestoreRestartDialog {}\n",
            encoding="utf-8",
        )
        (dialog_source.parent / "constrained_text.dart").write_text(
            "class ConstrainedText {}\n", encoding="utf-8"
        )
        (root / "pubspec.yaml").write_text("name: stroom\n", encoding="utf-8")
        (root / "pubspec.lock").write_text("", encoding="utf-8")
        (root / "l10n.yaml").write_text("", encoding="utf-8")
        (root / "web").mkdir()
        (root / "web/index.html").write_text("<html></html>\n", encoding="utf-8")
        bundle = self.root / "build/vertical-result-dialog/index.html"
        bundle.parent.mkdir(parents=True)
        bundle.write_text("built bundle\n", encoding="utf-8")

        inputs = capture_build_inputs(root, entrypoint)
        self.assertIn(dialog_source.resolve(), inputs)

        baseline_mtime = 1_700_000_000_000_000_000
        for source in inputs:
            os.utime(source, ns=(baseline_mtime, baseline_mtime))
        os.utime(bundle, ns=(baseline_mtime + 1_000_000_000,) * 2)
        os.utime(dialog_source, ns=(baseline_mtime + 2_000_000_000,) * 2)

        self.assertTrue(needs_rebuild(root, entrypoint, bundle))


if __name__ == "__main__":
    unittest.main()
