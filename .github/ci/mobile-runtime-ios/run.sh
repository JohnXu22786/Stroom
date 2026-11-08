#!/usr/bin/env bash
set -euo pipefail

app=${1:?usage: run.sh <testnode.app> <temp-dir>}
temp=${2:?usage: run.sh <testnode.app> <temp-dir>}
bundle_id='nodejsmobile.test'
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

python3 "$script_dir/test_log_marker.py"

device=$(xcrun simctl list devices available --json | python3 -c '
import json, sys
data = json.load(sys.stdin)
for devices in data["devices"].values():
    for device in devices:
        if device.get("isAvailable") and "iPhone" in device.get("name", ""):
            print(device["udid"])
            raise SystemExit(0)
raise SystemExit("No available iPhone Simulator device found")
')

echo "Using iOS Simulator $device"
xcrun simctl boot "$device" 2>/dev/null || true
xcrun simctl bootstatus "$device" -b
xcrun simctl install "$device" "$app"

run_capture() {
  local logfile=$1 seconds=$2
  shift 2
  python3 - "$logfile" "$seconds" "$@" <<'PY'
import subprocess
import sys

log_path, timeout_seconds, *command = sys.argv[1:]
try:
    with open(log_path, "w", encoding="utf-8") as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                                timeout=float(timeout_seconds), check=False)
    raise SystemExit(result.returncode)
except subprocess.TimeoutExpired:
    with open(log_path, "a", encoding="utf-8") as log:
        log.write(f"Timed out after {timeout_seconds} seconds.\n")
    raise SystemExit(124)
PY
}

copy_log="$temp/ios-copy-test-assets.log"
set +e
# A fresh Xcode 26 simulator can spend several minutes migrating system data
# before the app is ready to launch. Keep requiring the asset-copy success marker.
run_capture "$copy_log" 600 xcrun simctl launch --console-pty --terminate-running-process \
  "$device" "$bundle_id" --copy-path-for-testing
copy_status=$?
set -e
cat "$copy_log"
if [[ $copy_status -ne 0 ]]; then
  echo "Copying upstream test assets failed (exit $copy_status)." >&2
  exit "$copy_status"
fi

container=$(xcrun simctl get_app_container "$device" "$bundle_id" data)
fixture="$container/Documents/test/mobile-runtime-poc/npm-fixture"
npm="$container/Documents/test/npm/package/bin/npm-cli.js"
shim="$container/Documents/test/mobile-runtime-poc/compatibility-shim.cjs"
cache="$container/Documents/.npm-cache"
test -f "$fixture/package-lock.json"
test -f "$npm"
test -f "$shim"

run_node() {
  local label=$1 required_marker=$2 seconds=$3
  shift 3
  local log="$temp/ios-${label}.log" status=0
  set +e
  run_capture "$log" "$seconds" xcrun simctl launch --console-pty \
    --terminate-running-process "$device" "$bundle_id" "$@"
  status=$?
  set -e
  cat "$log"
  if [[ $status -ne 0 ]] || ! python3 "$script_dir/check_log_marker.py" "$log" "$required_marker"
  then
    echo "$label failed (exit $status; expected marker: $required_marker)." >&2
    exit 1
  fi
}

raw_expression="(()=>{console.log('IOS_NODE_RUNTIME_'+process.version);let value='Stroom 学习 🙂';try{let decoded=Buffer.from(value,'utf8').toString('utf8');if(decoded!==value)throw new Error('UTF-8 round-trip mismatch');console.log('IOS_RAW_UTF8_ROUNDTRIP:'+Buffer.from(decoded,'utf8').toString('hex'))}catch(error){if(!(error instanceof RangeError&&error.message==='Index out of range')){console.log('RESULT:FAIL');throw error}console.log('IOS_RAW_UTF8_RANGEERROR:'+error.name+':'+error.message)}console.log('RESULT:PASS')})()"
raw_markers=$'IOS_RAW_UTF8_ROUNDTRIP:5374726f6f6d20e5ada6e4b9a020f09f9982\nIOS_RAW_UTF8_RANGEERROR:RangeError:Index out of range'
run_node raw-runtime "$raw_markers" 60 -p "$raw_expression"

npm_expression="(()=>{let fs=require('node:fs');let source=new TextDecoder().decode(fs.readFileSync('$shim'));eval(source);process.argv=['node','$npm','ci','--prefix','$fixture','--cache','$cache','--no-audit','--no-fund','--progress=false','--registry=https://registry.npmjs.org','--replace-registry-host=always','--fetch-retries=0'];process.on('exit',()=>process.stdout.write('\\nIOS_NPM_CI_PROCESS_EXIT:'+String(process.exitCode||0)+'\\n'));return require('$npm')})()"
run_node npm-ci IOS_NPM_CI_PROCESS_EXIT:0 360 -p "$npm_expression"

verify_expression="(()=>{let fs=require('node:fs');let source=new TextDecoder().decode(fs.readFileSync('$shim'));eval(source);return require('$fixture/verify-install.cjs')})()"
run_node npm-typescript-mcp MCP_IN_MEMORY_INITIALIZE_LIST_CALL_PASS 120 -p "$verify_expression"

runner="$container/Documents/test/mobile-runtime-poc/run-lifecycle-install.cjs"
for lifecycle_case in javascript async-javascript async-exit async-exit-default async-failure sync-exit async-timeout inline-js core-js typescript child-process native-command; do
  lifecycle_expression="(()=>{let fs=require('node:fs');eval(new/**/TextDecoder().decode(fs.readFileSync('$shim')));globalThis.__STROOM_LIFECYCLE_CASE='$lifecycle_case';return/**/require('$runner')})()"
  run_node "lifecycle-$lifecycle_case" \
    'RESULT:PASS' 180 \
    -p "$lifecycle_expression"
done
