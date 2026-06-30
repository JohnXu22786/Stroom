"""Tests for nightly-build.yml workflow fix.

Validates:
1. YAML is syntactically valid
2. No 'check-repository' gating job exists
3. All jobs run unconditionally (no 'if' conditions depending on check-repository)
4. FORCE_JAVASCRIPT_ACTIONS_TO_NODE24 env var is present
"""

import yaml
import sys
import os

WORKFLOW_PATH = os.path.join(
    os.path.dirname(__file__),
    ".github", "workflows", "nightly-build.yml"
)

def load_workflow():
    """Load and parse the workflow YAML file."""
    if not os.path.exists(WORKFLOW_PATH):
        raise FileNotFoundError(f"Workflow file not found: {WORKFLOW_PATH}")
    with open(WORKFLOW_PATH, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def test_yaml_valid():
    """Test 1: YAML syntax is valid."""
    try:
        data = load_workflow()
        assert data is not None, "YAML file is empty"
        print("  ✅ YAML syntax is valid")
        return data
    except (yaml.YAMLError, FileNotFoundError) as e:
        print(f"  ❌ {e}")
        sys.exit(1)


def test_no_check_repository_job(data):
    """Test 2: No 'check-repository' gating job."""
    jobs = data.get("jobs", {})
    assert "check-repository" not in jobs, (
        "check-repository job still exists"
    )
    print("  ✅ No 'check-repository' gating job")


def test_no_gating_conditions(data):
    """Test 3: No job has 'needs: check-repository' or depends on it."""
    jobs = data.get("jobs", {})
    for job_name, job in jobs.items():
        needs = job.get("needs") or []
        if isinstance(needs, str):
            needs = [needs]
        assert "check-repository" not in needs, (
            f"Job '{job_name}' still needs check-repository"
        )

        job_if = job.get("if", "")
        assert not (isinstance(job_if, str) and "check-repository" in job_if), (
            f"Job '{job_name}' still has if condition referencing check-repository"
        )

    print("  ✅ No job depends on 'check-repository'")


def test_env_var_present(data):
    """Test 4: FORCE_JAVASCRIPT_ACTIONS_TO_NODE24 is set."""
    env = data.get("env", {})
    assert env.get("FORCE_JAVASCRIPT_ACTIONS_TO_NODE24") is True, (
        "FORCE_JAVASCRIPT_ACTIONS_TO_NODE24 env var not set to true"
    )
    print("  ✅ FORCE_JAVASCRIPT_ACTIONS_TO_NODE24 env var is present")


def test_triggers_present(data):
    """Test 5: Correct triggers exist."""
    # PyYAML uses YAML 1.1 where 'on' is a boolean keyword,
    # so we check raw text with proper scoping.
    with open(WORKFLOW_PATH, "r", encoding="utf-8") as f:
        lines = f.readlines()

    # Find the 'on:' section and check its immediate children
    found_on = False
    on_indent = 0
    found_schedule = False
    found_workflow_dispatch = False
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped == "on:":
            found_on = True
            on_indent = len(line) - len(line.lstrip())
            continue
        if found_on:
            line_indent = len(line) - len(line.lstrip())
            # Skip empty/comment lines
            if stripped == "" or stripped.startswith("#"):
                continue
            # If we encounter a line at the same or lesser indentation as 'on:', we've left the section
            if line_indent <= on_indent:
                break
            # Only check immediate children of 'on:' (one indent level deeper)
            if line_indent == on_indent + 2:
                if "schedule:" in stripped:
                    found_schedule = True
                if "workflow_dispatch:" in stripped:
                    found_workflow_dispatch = True

    assert found_on, "Could not find 'on:' section in workflow"
    assert found_schedule, "schedule trigger is missing under 'on:'"
    assert found_workflow_dispatch, "workflow_dispatch trigger is missing under 'on:'"
    print("  ✅ Both schedule and workflow_dispatch triggers present")


def test_all_jobs_preserved(data):
    """Test 6: All original build/test jobs are preserved."""
    expected_jobs = {
        "coverage", "e2e",
        "build-linux", "build-web", "build-android",
        "build-windows", "build-macos", "build-ios"
    }
    actual_jobs = set(data.get("jobs", {}).keys())
    missing = expected_jobs - actual_jobs
    unexpected = actual_jobs - expected_jobs
    assert not missing, f"Missing expected jobs: {missing}"
    assert not unexpected, f"Unexpected extra jobs: {unexpected}"
    print("  ✅ All original build/test jobs are preserved, no extra jobs")


if __name__ == "__main__":
    print(f"Validating: {WORKFLOW_PATH}")
    print()

    try:
        data = test_yaml_valid()
        test_no_check_repository_job(data)
        test_no_gating_conditions(data)
        test_env_var_present(data)
        test_triggers_present(data)
        test_all_jobs_preserved(data)

        print()
        print("🎉 All tests passed!")
    except AssertionError as e:
        print(f"\n  ❌ {e}")
        sys.exit(1)
