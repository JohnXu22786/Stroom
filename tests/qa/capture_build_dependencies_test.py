import os
import sys
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tool" / "qa"))

from capture_build_dependencies import needs_rebuild  # noqa: E402


class CaptureBuildDependenciesTest(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.root = Path(self.temporary_directory.name)
        self.entrypoint = self.root / "tool/qa/capture.dart"
        self.entrypoint.parent.mkdir(parents=True)
        self.entrypoint.write_text(
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

    def test_unchanged_transitive_production_import_does_not_require_rebuild(self):
        self.assertFalse(needs_rebuild(self.root, self.entrypoint, self.bundle))

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


if __name__ == "__main__":
    unittest.main()
