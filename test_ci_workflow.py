"""Tests for ci.yml workflow -- format check is mandatory.

Validates:
1. YAML is syntactically valid
2. format job exists with "dart format --set-exit-if-changed" check
3. format job has NO needs: (it runs first, independently)
4. analyze job has needs: [format] -- format gates static analysis
5. test job has needs: [analyze] -- tests wait for analysis
6. All expected jobs (format, analyze, test) are present
"""

import yaml
import sys
import os

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))
WORKFLOW_PATH = os.path.join(REPO_ROOT, ".github", "workflows", "ci.yml")


def load_workflow():
    """Load and parse the workflow YAML file."""
    if not os.path.exists(WORKFLOW_PATH):
        raise FileNotFoundError(f"Workflow file not found: {WORKFLOW_PATH}")
    with open(WORKFLOW_PATH, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def test_yaml_valid():
    """Test 1: YAML syntax is valid."""
    data = load_workflow()
    assert data is not None, "YAML file is empty"
    print("  [PASS] YAML syntax is valid")
    return data


def test_format_job_exists(data):
    """Test 2: format job exists with dart format check."""
    jobs = data.get("jobs", {})
    format_job = jobs.get("format")
    assert format_job is not None, "format job is missing"
    assert format_job.get("name") == "Format Check", (
        f"format job name is '{format_job.get('name')}', expected 'Format Check'"
    )

    steps = format_job.get("steps", [])
    has_dart_format = any(
        "dart format" in (s.get("run", "") or "")
        for s in steps
    )
    assert has_dart_format, (
        "format job is missing 'dart format --set-exit-if-changed .' step"
    )
    print("  [PASS] format job exists with dart format check")


def test_format_has_no_needs(data):
    """Test 3: format job must have NO needs: -- it runs first."""
    jobs = data.get("jobs", {})
    format_job = jobs.get("format", {})
    needs = format_job.get("needs")
    assert needs is None, (
        f"format job has needs: {needs} -- expected no needs (should run first)"
    )
    print("  [PASS] format job has no 'needs:' dependency (runs first)")


def test_analyze_needs_format(data):
    """Test 4: analyze job must have needs: [format] -- format gates analysis."""
    jobs = data.get("jobs", {})
    analyze_job = jobs.get("analyze")
    assert analyze_job is not None, "analyze job is missing"

    needs = analyze_job.get("needs")
    if isinstance(needs, str):
        needs_list = [needs]
    else:
        needs_list = list(needs) if needs else []

    assert "format" in needs_list, (
        f"analyze job needs {needs_list}, expected 'format' to be in needs"
    )
    print("  [PASS] analyze job has 'needs: [format]' -- format check is mandatory")


def test_test_needs_analyze(data):
    """Test 5: test job must have needs: [analyze]."""
    jobs = data.get("jobs", {})
    test_job = jobs.get("test")
    assert test_job is not None, "test job is missing"

    needs = test_job.get("needs")
    if isinstance(needs, str):
        needs_list = [needs]
    else:
        needs_list = list(needs) if needs else []

    assert "analyze" in needs_list, (
        f"test job needs {needs_list}, expected 'analyze' to be in needs"
    )
    print("  [PASS] test job has 'needs: [analyze]' -- depends on static analysis")


def test_all_expected_jobs_present(data):
    """Test 6: All expected jobs (format, analyze, test) are present."""
    jobs = data.get("jobs", {})
    expected = {"format", "analyze", "test"}
    actual = set(jobs.keys())
    missing = expected - actual
    assert not missing, f"Missing expected jobs: {missing}"
    print("  [PASS] All expected jobs (format, analyze, test) are present")


def test_format_check_dart_command(data):
    """Test 7: The dart format command uses --set-exit-if-changed."""
    jobs = data.get("jobs", {})
    format_job = jobs.get("format", {})
    steps = format_job.get("steps", [])

    format_step = None
    for s in steps:
        run = s.get("run", "")
        if "dart format" in run:
            format_step = run
            break

    assert format_step is not None, "No step with 'dart format' found"
    assert "--set-exit-if-changed" in format_step, (
        "dart format command is missing --set-exit-if-changed flag"
    )
    print("  [PASS] dart format command includes --set-exit-if-changed flag")


if __name__ == "__main__":
    print(f"Validating: {WORKFLOW_PATH}")
    print()

    tests = [
        ("YAML syntax valid", test_yaml_valid),
        ("format job exists with dart format", test_format_job_exists),
        ("format has no needs (runs first)", test_format_has_no_needs),
        ("analyze needs format (mandatory gate)", test_analyze_needs_format),
        ("test needs analyze", test_test_needs_analyze),
        ("all expected jobs present", test_all_expected_jobs_present),
        ("dart format --set-exit-if-changed", test_format_check_dart_command),
    ]

    all_passed = True
    data = None

    for name, test_fn in tests:
        try:
            if data is None:
                data = test_fn()
            else:
                test_fn(data)
        except (AssertionError, FileNotFoundError, ValueError) as e:
            print(f"  [FAIL] {name}: {e}")
            all_passed = False

    print()
    if all_passed:
        print("All ci.yml workflow validation tests passed!")
    else:
        print("Some tests failed -- see above.")
        sys.exit(1)
