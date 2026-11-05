#!/usr/bin/env python3
"""Host-side smoke check for the isolated npm lifecycle bridge prototype."""
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parent
sucrase = Path("/workspace/.mcp-runtime-validation/ts-transpiler/node_modules/sucrase")
npm_cli_value = os.environ.get("STROOM_TEST_NPM_CLI")
npm_cli = Path(npm_cli_value) if npm_cli_value else Path(shutil.which("npm")).resolve()
bridge = root / "npm-lifecycle-bridge.cjs"
fixtures = root / "lifecycle-fixtures"
shim_check = subprocess.run(
    [shutil.which("node"), "--require", str(root / "compatibility-shim.cjs"), "-e",
     "const assert=require('node:assert/strict');const b=Buffer.from('abc');"
     "assert.equal(b.toString('utf8',1,2),'b');"
     "assert.equal(b.toLocaleString('utf8',1,2),'b');"
     "assert.equal(b.toString('hex',1,2),'62')"],
    text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
)
print(shim_check.stdout.rstrip())
if shim_check.returncode != 0:
    raise SystemExit("UTF-8 compatibility shim slice behavior failed")
cases = {
    "javascript": (True, "MOBILE_LIFECYCLE_JS_PASS", "JS lifecycle ran in Node Mobile"),
    "async-javascript": (True, "MOBILE_LIFECYCLE_ASYNC_JS_PASS", "Async JS lifecycle ran in Node Mobile"),
    "async-exit": (True, "MOBILE_LIFECYCLE_ASYNC_EXIT_PASS", None),
    "async-exit-default": (False, "MOBILE_LIFECYCLE_ASYNC_EXIT_DEFAULT", None),
    "async-failure": (False, "MOBILE_LIFECYCLE_ASYNC_FAILURE_STARTED", None),
    "sync-exit": (True, "MOBILE_LIFECYCLE_SYNC_EXIT_PASS", None),
    "async-timeout": (False, "npm lifecycle JavaScript did not become idle within", None),
    "inline-js": (True, "MOBILE_LIFECYCLE_INLINE_JS_PASS", "Inline JS lifecycle ran in Node Mobile"),
    "core-js": (True, "Thank you for using core-js", None),
    "typescript": (True, "MOBILE_LIFECYCLE_TS_PASS", "TypeScript lifecycle ran in Node Mobile"),
    "child-process": (False, "Unsupported external executable from npm lifecycle script: native-helper", None),
    "native-command": (False, "Unsupported npm lifecycle command on this mobile runtime: node-gyp rebuild", None),
}

if not npm_cli.is_file():
    raise SystemExit("Set STROOM_TEST_NPM_CLI to an npm-cli.js file")
if not sucrase.is_dir():
    raise SystemExit("Expected the prepared Node Mobile POC Sucrase dependency")

with tempfile.TemporaryDirectory(prefix="stroom-mobile-lifecycle-") as temp:
    temp_path = Path(temp)
    for case, (accepted, output_marker, file_marker) in cases.items():
        target = temp_path / ("target-" + case)
        target.mkdir()
        temp_dir = target / "tmp"
        temp_dir.mkdir()
        env = os.environ.copy()
        env.update({
            "STROOM_NPM_CLI": str(npm_cli),
            "STROOM_SUCRASE_MODULE": str(sucrase),
            "STROOM_LIFECYCLE_MARKER": str(target / "bridge-marker.txt"),
            "NODE_OPTIONS": "--require=" + str(bridge),
            "TMPDIR": str(temp_dir),
        })
        if case == "async-timeout":
            env["STROOM_LIFECYCLE_TIMEOUT_MS"] = "100"
        result = subprocess.run(
            [
                "node", str(npm_cli), "install", "--prefix", str(target),
                "--foreground-scripts", "--package-lock=false",
                "--no-audit", "--no-fund",
                "core-js@3.45.1" if case == "core-js" else str(fixtures / case),
            ],
            env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            check=False,
        )
        print("===== " + case + " (exit " + str(result.returncode) + ") =====")
        print(result.stdout.rstrip())
        should_pass = result.returncode == 0
        if should_pass != accepted or output_marker not in result.stdout:
            raise SystemExit("Unexpected result for fixture: " + case)
        expected_rejection = {
            "async-exit-default": ("npm error lifecycle JS entry failed", "npm error code 17"),
            "async-failure": ("npm error MOBILE_LIFECYCLE_ASYNC_FAILURE_THROWN",),
        }.get(case)
        if expected_rejection is not None:
            for diagnostic in expected_rejection:
                if diagnostic not in result.stdout:
                    raise SystemExit("Missing expected lifecycle rejection for fixture: " + case)
        if case == "async-exit-default" and "MOBILE_LIFECYCLE_ASYNC_EXIT_CONTINUED" in result.stdout:
            raise SystemExit("Async lifecycle continued after process.exit")
        if accepted:
            if file_marker is not None:
                marker_file = target / "bridge-marker.txt"
                if marker_file.read_text() != file_marker:
                    raise SystemExit("Lifecycle marker does not match: " + case)
        elif case == "async-failure" and "ERR_STROOM_LIFECYCLE_ASYNC_TIMEOUT" in result.stdout:
            raise SystemExit("Async lifecycle error was masked by a timeout")
    print("HOST_MOBILE_BRIDGE_FIXTURES_PASS count=" + str(len(cases)))
