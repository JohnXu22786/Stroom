"""Tests for CI/CD workflow changes.

Validates:
1. pr-description-check.yml has been removed
2. build.yml: Windows build uses only Inno Setup (no ZIP fallback)
3. release.yml: Windows build uses Inno Setup installer instead of ZIP
"""

import yaml
import sys
import os

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))
WORKFLOWS_DIR = os.path.join(REPO_ROOT, ".github", "workflows")


# ── Helpers ──────────────────────────────────────────────────────────────────

def load_workflow(filename):
    """Load and parse a workflow YAML file."""
    path = os.path.join(WORKFLOWS_DIR, filename)
    if not os.path.exists(path):
        raise FileNotFoundError(f"Workflow file not found: {path}")
    with open(path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    if data is None:
        raise ValueError(f"Workflow file is empty: {filename}")
    return data, path


def count_occurrences(filepath, pattern):
    """Count the number of lines containing a given substring."""
    with open(filepath, "r", encoding="utf-8") as f:
        return sum(1 for line in f if pattern in line)


# ── Test 1: pr-description-check.yml is removed ─────────────────────────────

def test_pr_description_check_removed():
    """Test 1: pr-description-check.yml must not exist."""
    path = os.path.join(WORKFLOWS_DIR, "pr-description-check.yml")
    assert not os.path.exists(path), (
        "pr-description-check.yml still exists — it should have been deleted"
    )
    print("  ✅ pr-description-check.yml has been removed")


# ── Test 2: build.yml — Windows uses only Inno Setup, no ZIP fallback ────────

def test_build_windows_no_zip():
    """Test 2: build.yml Windows job must not have ZIP fallback step."""
    data, path = load_workflow("build.yml")
    windows_job = data.get("jobs", {}).get("build-windows", {})
    steps = windows_job.get("steps", [])

    # Check no step contains "Package ZIP" or "Compress-Archive"
    zip_steps = [
        s for s in steps
        if "Package ZIP" in (s.get("name", "") or "")
        or "Compress-Archive" in str(s.get("run", "") or "")
    ]
    assert len(zip_steps) == 0, (
        f"build.yml Windows job has {len(zip_steps)} ZIP-related step(s) — "
        "should be removed, only Inno Setup installer should remain"
    )
    print("  ✅ build.yml Windows job has no ZIP fallback step")


def test_build_windows_has_installer():
    """Test 3: build.yml Windows job must still create Inno Setup installer."""
    data, path = load_workflow("build.yml")
    windows_job = data.get("jobs", {}).get("build-windows", {})
    steps = windows_job.get("steps", [])

    # Check step for Inno Setup exists
    installer_steps = [
        s for s in steps
        if "installer" in (s.get("name", "") or "").lower()
        or "ISCC.exe" in str(s.get("run", "") or "")
        or "innosetup" in str(s.get("run", "") or "").lower()
    ]
    assert len(installer_steps) > 0, (
        "build.yml Windows job has no Inno Setup installer step"
    )
    print("  ✅ build.yml Windows job has Inno Setup installer step")


def test_build_windows_job_name_updated():
    """Test 4: build.yml Windows job name reflects only installer (no ZIP)."""
    data, path = load_workflow("build.yml")
    windows_job = data.get("jobs", {}).get("build-windows", {})
    job_name = windows_job.get("name", "")
    assert "+ ZIP" not in job_name, (
        f"build.yml Windows job name still mentions '+ ZIP': '{job_name}'"
    )
    print(f"  ✅ build.yml Windows job name: '{job_name}' (no ZIP mention)")


# ── Test 5: release.yml — Windows uses Inno Setup, no ZIP ────────────────────

def test_release_windows_no_zip():
    """Test 5: release.yml Windows job must not create ZIP."""
    data, path = load_workflow("release.yml")
    windows_job = data.get("jobs", {}).get("windows", {})
    steps = windows_job.get("steps", [])

    zip_steps = [
        s for s in steps
        if "Compress-Archive" in str(s.get("run", "") or "")
        or "windows-x64-release-*.zip" in str(s.get("files", "") or "")
        or (s.get("with") or {}).get("files", "").endswith(".zip")
    ]
    assert len(zip_steps) == 0, (
        f"release.yml Windows job has {len(zip_steps)} ZIP-related step(s) — "
        "should use Inno Setup installer instead"
    )
    print("  ✅ release.yml Windows job has no ZIP step")


def test_release_windows_has_installer():
    """Test 6: release.yml Windows job must create Inno Setup installer."""
    data, path = load_workflow("release.yml")
    windows_job = data.get("jobs", {}).get("windows", {})
    steps = windows_job.get("steps", [])

    installer_steps = [
        s for s in steps
        if "installer" in (s.get("name", "") or "").lower()
        or "ISCC.exe" in str(s.get("run", "") or "")
        or "innosetup" in str(s.get("run", "") or "").lower()
    ]
    assert len(installer_steps) > 0, (
        "release.yml Windows job has no Inno Setup installer step"
    )
    print("  ✅ release.yml Windows job has Inno Setup installer step")


def test_release_windows_uploads_exe():
    """Test 7: release.yml Windows job uploads .exe files instead of .zip."""
    data, path = load_workflow("release.yml")
    windows_job = data.get("jobs", {}).get("windows", {})
    steps = windows_job.get("steps", [])

    for step in steps:
        files = (step.get("with") or {}).get("files", "") if step.get("with") else ""
        if "windows" in files.lower() and ".zip" in files.lower():
            assert False, (
                f"release.yml still uploads .zip for Windows: '{files}'"
            )

    # Check that the step with action-gh-release uploads *.exe for Windows
    upload_steps = [
        s for s in steps
        if "action-gh-release" in (s.get("uses") or "")
    ]
    for step in upload_steps:
        files = (step.get("with") or {}).get("files", "") or ""
        assert "stroom-windows-x64" not in files or ".exe" in files, (
            f"release.yml Windows upload files pattern missing .exe: '{files}'"
        )

    print("  ✅ release.yml Windows job uploads .exe installer")


def test_release_windows_creates_artifacts_dir():
    """Test 8: release.yml Windows job must create artifacts/ directory before ISCC."""
    data, path = load_workflow("release.yml")
    windows_job = data.get("jobs", {}).get("windows", {})
    steps = windows_job.get("steps", [])

    create_installer_step = None
    for s in steps:
        if "Create Windows installer" in (s.get("name", "") or ""):
            create_installer_step = s.get("run", "")
            break

    assert create_installer_step is not None, (
        "release.yml Windows job: 'Create Windows installer' step not found"
    )
    assert "mkdir artifacts" in create_installer_step, (
        "release.yml Windows job: 'Create Windows installer' step missing 'mkdir artifacts'"
    )

    print("  ✅ release.yml Windows job creates artifacts/ directory before ISCC")


def test_build_windows_creates_artifacts_dir():
    """Test 9: build.yml Windows job must create artifacts/ directory before ISCC."""
    data, path = load_workflow("build.yml")
    windows_job = data.get("jobs", {}).get("build-windows", {})
    steps = windows_job.get("steps", [])

    create_installer_step = None
    for s in steps:
        if "Create installer" in (s.get("name", "") or ""):
            create_installer_step = s.get("run", "")
            break

    assert create_installer_step is not None, (
        "build.yml Windows job: 'Create installer' step not found"
    )
    assert "mkdir artifacts" in create_installer_step, (
        "build.yml Windows job: 'Create installer' step missing 'mkdir artifacts'"
    )

    print("  ✅ build.yml Windows job creates artifacts/ directory before ISCC")


def test_installer_iss_output_dir_relative():
    """Test 10: installer.iss OutputDir must be relative to repo root (..\\artifacts)."""
    iss_path = os.path.join(REPO_ROOT, "windows", "installer.iss")
    assert os.path.exists(iss_path), "installer.iss not found"
    with open(iss_path, "r", encoding="utf-8") as f:
        content = f.read()

    assert '#define OutputDir "..\\artifacts"' in content, (
        "installer.iss OutputDir should be '..\\\\artifacts' (relative to repo root), "
        f"not 'artifacts' (which would be relative to windows/ directory)"
    )
    print("  ✅ installer.iss OutputDir = '..\\\\artifacts' (relative to repo root)")


def test_dart_test_files_updated():
    """Test 11: Dart test files reference new Windows installer .exe instead of old .zip."""
    test_files = [
        os.path.join("test", "providers", "update_provider_test.dart"),
        os.path.join("test", "pages", "settings_page_update_test.dart"),
        os.path.join("test", "pages", "application_startup_update_test.dart"),
    ]

    for rel_path in test_files:
        full_path = os.path.join(REPO_ROOT, rel_path)
        assert os.path.exists(full_path), f"Test file not found: {rel_path}"
        with open(full_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Should NOT have old Windows ZIP artifact references
        assert "windows-x64-release" not in content, (
            f"{rel_path} still has old Windows ZIP artifact reference ('windows-x64-release')"
        )

        # Should have new Windows installer .exe references
        assert "windows-x64-installer" in content, (
            f"{rel_path} missing new Windows installer .exe reference"
        )

        print(f"  ✅ {rel_path} — updated to .exe installer references")

    print("  ✅ All Dart test files updated (ZIP→installer .exe)")


# ── Main ─────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("Validating CI/CD workflow changes...")
    print()

    tests = [
        ("pr-description-check removed", test_pr_description_check_removed),
        ("build.yml: no ZIP fallback", test_build_windows_no_zip),
        ("build.yml: has installer", test_build_windows_has_installer),
        ("build.yml: job name updated", test_build_windows_job_name_updated),
        ("release.yml: no ZIP", test_release_windows_no_zip),
        ("release.yml: has installer", test_release_windows_has_installer),
        ("release.yml: uploads .exe", test_release_windows_uploads_exe),
        ("release.yml: creates artifacts dir", test_release_windows_creates_artifacts_dir),
        ("build.yml: creates artifacts dir", test_build_windows_creates_artifacts_dir),
        ("installer.iss: OutputDir relative to repo root", test_installer_iss_output_dir_relative),
        ("Dart test files: ZIP→.exe", test_dart_test_files_updated),
    ]

    all_passed = True
    for name, test_fn in tests:
        try:
            test_fn()
        except (AssertionError, FileNotFoundError, ValueError) as e:
            print(f"  ❌ {name}: {e}")
            all_passed = False

    print()
    if all_passed:
        print("🎉 All workflow validation tests passed!")
    else:
        print("❌ Some tests failed — see above.")
        sys.exit(1)
