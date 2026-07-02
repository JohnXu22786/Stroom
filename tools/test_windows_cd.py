"""Tests for Windows CD changes.

Validates:
1. pr-description-check.yml is removed (no PR description check)
2. build.yml Windows job no longer creates ZIP archives
3. build.yml Windows job uses InstallShield instead of Inno Setup
4. release.yml Windows job no longer creates ZIP archives
5. release.yml Windows job uses InstallShield
6. InstallShield project file (.ism) exists
"""

import yaml
import os
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORKFLOWS_DIR = os.path.join(REPO_ROOT, ".github", "workflows")
WINDOWS_DIR = os.path.join(REPO_ROOT, "windows")


def load_workflow(filename):
    """Load and parse a workflow YAML file."""
    path = os.path.join(WORKFLOWS_DIR, filename)
    if not os.path.exists(path):
        raise FileNotFoundError(f"Workflow file not found: {path}")
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f), path


def test_pr_description_check_removed():
    """Test 1: pr-description-check.yml must NOT exist."""
    path = os.path.join(WORKFLOWS_DIR, "pr-description-check.yml")
    assert not os.path.exists(path), (
        "pr-description-check.yml still exists — it should have been removed"
    )
    print("  ✅ pr-description-check.yml has been removed")


def test_build_windows_no_zip():
    """Test 2: build.yml Windows job must NOT create ZIP archives."""
    data, path = load_workflow("build.yml")
    jobs = data.get("jobs", {})
    assert "build-windows" in jobs, "build-windows job not found in build.yml"

    steps = jobs["build-windows"].get("steps", [])
    for step in steps:
        run_cmd = step.get("run", "")
        shell = step.get("shell", "")
        name = step.get("name", "")

        assert "Compress-Archive" not in run_cmd, (
            f"Step '{name}' still uses Compress-Archive (ZIP) — remove it"
        )
        assert "zip" not in name.lower(), (
            f"Step '{name}' still mentions ZIP — remove it"
        )

    print("  ✅ build.yml Windows job no longer creates ZIP archives")


def test_build_windows_uses_installshield():
    """Test 3: build.yml Windows job must use InstallShield."""
    data, path = load_workflow("build.yml")
    jobs = data.get("jobs", {})
    steps = jobs["build-windows"].get("steps", [])

    has_installshield = False
    for step in steps:
        run_cmd = step.get("run", "")
        name = step.get("name", "")
        if "installshield" in run_cmd.lower() or "installshield" in name.lower():
            has_installshield = True
            break
        if "isproj" in run_cmd.lower() or "ism" in run_cmd.lower():
            has_installshield = True
            break
        if "IsCmdBld" in run_cmd or "iscmdbld" in run_cmd.lower():
            has_installshield = True
            break

    assert has_installshield, (
        "build.yml Windows job does not contain InstallShield build steps"
    )

    # Also verify no Inno Setup remains
    for step in steps:
        run_cmd = step.get("run", "")
        name = step.get("name", "")
        assert "innosetup" not in run_cmd.lower(), (
            f"Step '{name}' still uses Inno Setup — should be replaced with InstallShield"
        )
        assert "ISCC.exe" not in run_cmd, (
            f"Step '{name}' still uses ISCC.exe (Inno Setup) — should be replaced with InstallShield"
        )

    print("  ✅ build.yml Windows job uses InstallShield (no Inno Setup, no ZIP)")


def test_build_job_name_updated():
    """Test 4: build.yml Windows job name should not reference ZIP."""
    data, path = load_workflow("build.yml")
    jobs = data.get("jobs", {})
    job_name = jobs["build-windows"].get("name", "")
    assert "ZIP" not in job_name, (
        f"Job name '{job_name}' still references ZIP — update it"
    )
    print(f"  ✅ build.yml Windows job name is '{job_name}' (no ZIP reference)")


def test_release_windows_no_zip():
    """Test 5: release.yml Windows job must NOT create ZIP archives."""
    data, path = load_workflow("release.yml")
    jobs = data.get("jobs", {})
    assert "windows" in jobs, "windows job not found in release.yml"

    steps = jobs["windows"].get("steps", [])
    for step in steps:
        run_cmd = step.get("run", "")
        name = step.get("name", "")
        assert "Compress-Archive" not in run_cmd, (
            f"Step '{name}' still uses Compress-Archive (ZIP) — remove it"
        )
        assert ".zip" not in run_cmd, (
            f"Step '{name}' still references .zip — remove it"
        )

    # 通过 YAML 数据检查 gh-release 步骤的 files 属性
    for step in steps:
        files = step.get("with", {}).get("files", "")
        if isinstance(files, str):
            assert "*.zip" not in files, (
                "release.yml windows job gh-release step still uploads *.zip files"
            )
        elif isinstance(files, list):
            assert "*.zip" not in files, (
                "release.yml windows job gh-release step still uploads *.zip files"
            )

    print("  ✅ release.yml Windows job no longer creates ZIP archives")


def test_release_windows_uses_installshield():
    """Test 6: release.yml Windows job must use InstallShield."""
    data, path = load_workflow("release.yml")
    jobs = data.get("jobs", {})
    steps = jobs["windows"].get("steps", [])

    has_installshield = False
    for step in steps:
        run_cmd = step.get("run", "")
        name = step.get("name", "")
        if "installshield" in run_cmd.lower() or "installshield" in name.lower():
            has_installshield = True
            break
        if "isproj" in run_cmd.lower() or "ism" in run_cmd.lower():
            has_installshield = True
            break
        if "IsCmdBld" in run_cmd or "iscmdbld" in run_cmd.lower():
            has_installshield = True
            break

    assert has_installshield, (
        "release.yml Windows job does not contain InstallShield build steps"
    )

    print("  ✅ release.yml Windows job uses InstallShield")


def test_installshield_project_exists():
    """Test 7: InstallShield project file must exist."""
    ism_path = os.path.join(WINDOWS_DIR, "installer.ism")
    assert os.path.exists(ism_path), (
        f"InstallShield project file not found at {ism_path}"
    )

    with open(ism_path, "r", encoding="utf-8") as f:
        content = f.read()

    assert "ProductName" in content, (
        "InstallShield project file must contain ProductName"
    )
    assert "Stroom" in content, (
        "InstallShield project file must reference 'Stroom'"
    )
    assert "ProductVersion" in content, (
        "InstallShield project file must contain ProductVersion"
    )
    assert "ISProject" in content, (
        "InstallShield project file seems invalid — missing ISProject element"
    )

    print(f"  ✅ InstallShield project file exists at windows/installer.ism")


def test_workflows_reference_ism():
    """Test 9: build.yml and release.yml Windows jobs must reference installer.ism."""
    for wf_name in ("build.yml", "release.yml"):
        data, path = load_workflow(wf_name)
        jobs = data.get("jobs", {})
        # Find the Windows job (named "build-windows" in build.yml, "windows" in release.yml)
        win_job = jobs.get("build-windows") or jobs.get("windows")
        assert win_job is not None, (
            f"No Windows job found in {wf_name}"
        )

        steps_text = str(win_job.get("steps", []))
        assert "installer.ism" in steps_text or "installer.tmp.ism" in steps_text, (
            f"{wf_name} Windows job does not reference installer.ism"
        )
        print(f"  ✅ {wf_name} Windows job references installer.ism")


def test_build_release_includes_exe():
    """Test 8: build.yml create-release job must include *.exe files."""
    data, path = load_workflow("build.yml")
    jobs = data.get("jobs", {})
    assert "create-release" in jobs, "create-release job not found in build.yml"

    steps = jobs["create-release"].get("steps", [])
    found_exe = False
    for step in steps:
        files = step.get("with", {}).get("files", "")
        if isinstance(files, str) and "*.exe" in files:
            found_exe = True
            break
        if isinstance(files, list) and "*.exe" in files:
            found_exe = True
            break

    assert found_exe, (
        "build.yml create-release job does not include *.exe in release files"
    )
    print("  ✅ build.yml create-release includes *.exe (Windows installer)")


if __name__ == "__main__":
    print("=== Windows CD Changes Validation ===")
    print()
    failed = []

    tests = [
        ("pr-description-check.yml removed", test_pr_description_check_removed),
        ("build.yml - no ZIP", test_build_windows_no_zip),
        ("build.yml - uses InstallShield", test_build_windows_uses_installshield),
        ("build.yml - job name updated", test_build_job_name_updated),
        ("release.yml - no ZIP", test_release_windows_no_zip),
        ("release.yml - uses InstallShield", test_release_windows_uses_installshield),
        ("InstallShield project exists", test_installshield_project_exists),
        ("Release includes .exe", test_build_release_includes_exe),
        ("Workflows reference .ism", test_workflows_reference_ism),
    ]

    for name, test_fn in tests:
        try:
            test_fn()
        except (AssertionError, FileNotFoundError, yaml.YAMLError) as e:
            print(f"  ❌ {name}: {e}")
            failed.append(name)

    print()
    if failed:
        print(f"❌ {len(failed)} test(s) FAILED: {', '.join(failed)}")
        sys.exit(1)
    else:
        print("🎉 All tests passed!")
