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
            "import 'package:stroom/pages/capture_page.dart';\n", encoding="utf-8"
        )
        self.transitive_input = self.root / "lib/widgets/capture_widget.dart"
        self.transitive_input.parent.mkdir(parents=True)
        self.transitive_input.write_text("class CaptureWidget {}\n", encoding="utf-8")
        (self.root / "lib/pages").mkdir(parents=True)
        (self.root / "lib/pages/capture_page.dart").write_text(
            "import '../widgets/capture_widget.dart';\n"
            "export '../utils/capture_platform_stub.dart'\n"
            "    if (dart.library.html) '../utils/capture_platform_web.dart';\n",
            encoding="utf-8",
        )
        (self.root / "lib/utils").mkdir(parents=True)
        (self.root / "lib/utils/capture_platform_stub.dart").write_text(
            "class CapturePlatform {}\n", encoding="utf-8"
        )
        self.web_implementation = self.root / "lib/utils/capture_platform_web.dart"
        self.web_implementation.write_text("class CapturePlatform {}\n", encoding="utf-8")
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


if __name__ == "__main__":
    unittest.main()
