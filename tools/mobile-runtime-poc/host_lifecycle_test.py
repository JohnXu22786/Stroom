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
cases = {
    "javascript": (True, "MOBILE_LIFECYCLE_JS_PASS", "JS lifecycle ran in Node Mobile"),
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
        env = os.environ.copy()
        env.update({
            "STROOM_NPM_CLI": str(npm_cli),
            "STROOM_SUCRASE_MODULE": str(sucrase),
            "STROOM_LIFECYCLE_MARKER": str(target / "bridge-marker.txt"),
            "NODE_OPTIONS": "--require=" + str(bridge),
        })
        result = subprocess.run(
            [
                "node", str(npm_cli), "install", "--prefix", str(target),
                "--foreground-scripts", "--package-lock=false",
                "--no-audit", "--no-fund", str(fixtures / case),
            ],
            env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            check=False,
        )
        print("===== " + case + " (exit " + str(result.returncode) + ") =====")
        print(result.stdout.rstrip())
        should_pass = result.returncode == 0
        if should_pass != accepted or output_marker not in result.stdout:
            raise SystemExit("Unexpected result for fixture: " + case)
        if accepted:
            marker_file = target / "bridge-marker.txt"
            if marker_file.read_text() != file_marker:
                raise SystemExit("Lifecycle marker does not match: " + case)
    print("HOST_MOBILE_BRIDGE_FIXTURES_PASS count=4")
