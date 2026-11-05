#!/usr/bin/env bash
set -euo pipefail

package='nodejsmobile.test.testnode'
component='nodejsmobile.test.testnode/nodejsmobile.test.testnode.MainActivity'
files='/data/user/0/nodejsmobile.test.testnode/files'
fixture="$files/test/mobile-runtime-poc/npm-fixture"
npm="$files/test/npm/package/bin/npm-cli.js"
shim="$files/test/mobile-runtime-poc/compatibility-shim.cjs"
registry=${MOBILE_RUNTIME_NPM_REGISTRY:-https://registry.npmjs.org}

adb wait-for-device

start_with_nodeargs() {
  local nodeargs=$1 remote_nodeargs
  local expression=${nodeargs#-p }
  if [[ "$nodeargs" != -p\ * || "$expression" == *[[:space:]]* ]]; then
    echo 'Node Mobile sample splits its nodeargs string on spaces; use a whitespace-free -p expression.' >&2
    return 1
  fi
  remote_nodeargs=$(python3 -c 'import shlex,sys; print(shlex.quote(sys.argv[1]))' "$nodeargs")
  adb shell "am start -W -n $component --es nodeargs $remote_nodeargs"
}

echo '===== Prepare app-private test assets ====='
prepare_output=$(adb shell am start -W -n "$component" 2>&1) || {
  printf '%s\n' "$prepare_output"
  adb logcat -d -v threadtime -t 400 2>&1 || true
  exit 1
}
printf '%s\n' "$prepare_output"
if grep -Eq 'Error type 3|Activity class .* does not exist' <<<"$prepare_output"; then
  adb logcat -d -v threadtime -t 400 2>&1 || true
  exit 1
fi
prepare_log=''
for i in $(seq 1 90); do
  prepare_log=$(adb logcat -d -v threadtime -s 'TestNode:V' '*:S' 2>/dev/null || true)
  if grep -Fq 'COPYASSETS:PASS' <<<"$prepare_log" || grep -Fq 'COPYASSETS:FAIL' <<<"$prepare_log"; then
    break
  fi
  sleep 2
done
printf '%s\n' "$prepare_log"
if ! grep -Fq 'COPYASSETS:PASS' <<<"$prepare_log"; then
  echo 'App-private asset copy did not report success.'
  adb logcat -d -v threadtime -t 400 2>&1 || true
  exit 1
fi

run_node() {
  local label=$1 nodeargs=$2 marker=$3 max_wait=${4:-120} log i
  adb shell am force-stop "$package" || true
  adb logcat -c
  local expression=${nodeargs#-p }
  local launch_marker="NODE_MOBILE_RUN_${RANDOM}_$RANDOM"
  nodeargs="-p (console.log('$launch_marker'),$expression)"
  echo "===== Start $label ====="
  local start_output
  start_output=$(start_with_nodeargs "$nodeargs" 2>&1) || {
    printf '%s\n' "$start_output"
    adb logcat -d -v threadtime -t 400 2>&1 || true
    return 1
  }
  printf '%s\n' "$start_output"
  if ! grep -Fq 'Status: ok' <<<"$start_output"; then
    if grep -Eq 'Error type 3|Activity class .* does not exist' <<<"$start_output"; then
      adb logcat -d -v threadtime -t 400 2>&1 || true
      return 1
    fi
    echo "Activity start has not completed yet; waiting for $label output."
  fi
  for i in $(seq 1 "$max_wait"); do
    log=$(adb logcat -d -v threadtime -s 'TestNode:V' nodejs:E '*:S' 2>/dev/null || true)
    local pid
    pid=$(awk -v marker="$launch_marker" 'index($0, marker) { print $3; exit }' <<<"$log")
    if [[ -n "$pid" ]]; then
      # Capture this launch's logs even after npm exits the app process. The
      # per-launch marker prevents an older process's generic RESULT line from
      # being mistaken for this run.
      log=$(adb logcat -d --pid="$pid" -v threadtime -s 'TestNode:V' nodejs:E '*:S' 2>/dev/null || true)
    fi
    if grep -Fq "$marker" <<<"$log" || grep -Fq 'RESULT:FAIL' <<<"$log"; then
      break
    fi
    sleep 1
  done
  printf '%s\n' "===== $label =====" "$log"
  if ! grep -Fq "$marker" <<<"$log" || ! grep -Fq 'RESULT:PASS' <<<"$log"; then
    echo "===== Full logcat tail after $label ====="
    adb logcat -d -v threadtime -t 400 2>&1 || true
    echo "===== App process after $label ====="
    adb shell pidof "$package" 2>&1 || true
    return 1
  fi
}

run_expected_raw_failure() {
  adb shell am force-stop "$package" || true
  adb logcat -c
  echo '===== Confirm unpatched UTF-8 module read failure ====='
  local output log i
  output=$(start_with_nodeargs \
    "-p (console.log('RAW_REQUIRE_BEGIN_mobile_runtime_poc'),(()=>{try{return/**/require('$fixture/verify-install.cjs')}catch(error){console.log('RAW_REQUIRE_ERROR:'+error.name+':'+String.fromCharCode(32)+error.message)}})())" 2>&1) || {
    printf '%s\n' "$output"
    adb logcat -d -v threadtime -t 400 2>&1 || true
    return 1
  }
  printf '%s\n' "$output"
  for i in $(seq 1 45); do
    local pid
    pid=$(adb shell pidof "$package" 2>/dev/null | tr -d '\r' | awk '{print $1}') || true
    if [[ -n "$pid" ]]; then
      log=$(adb logcat -d --pid="$pid" -v threadtime -s 'TestNode:I' nodejs:E '*:S' 2>/dev/null || true)
    else
      log=''
    fi
    if grep -Fq 'RangeError: Index out of range' <<<"$log"; then break; fi
    sleep 1
  done
  printf '%s\n' "$log"
  if ! grep -Fq 'RangeError: Index out of range' <<<"$log"; then
    echo 'The unpatched require path did not reproduce the expected UTF-8 decoding failure in this app process.'
    adb logcat -d -v threadtime -t 400 2>&1 || true
    return 1
  fi
  echo 'RAW_NODE_MOBILE_REQUIRE_FAILURE_CONFIRMED'
}

runtime_args="-p (console.log('NODE_RUNTIME_PASS_'+process.version),console.log('RESULT:PASS'))"
run_node 'Node runtime version' "$runtime_args" 'NODE_RUNTIME_PASS_v18.20.4'
run_expected_raw_failure

adb shell run-as "$package" rm -rf "$fixture/node_modules" "$fixture/.npm" "$files/.npm-cache"
shim_args="-p (()=>{console.log('SHIM_BOOTSTRAP_BEGIN');let/**/source=new/**/TextDecoder().decode(require('node:fs').readFileSync('$shim'));console.log('SHIM_SOURCE_READ:'+source.length);eval(source);console.log('SHIM_BOOTSTRAP_EVAL_DONE');console.log('RESULT:PASS')})()"
run_node 'Load committed UTF-8 shim from app-private storage' "$shim_args" 'SHIM_BOOTSTRAP_EVAL_DONE' 120

npm_args="-p (()=>{console.log('NPM_BOOTSTRAP_BEGIN');let/**/source=new/**/TextDecoder().decode(require('node:fs').readFileSync('$shim'));console.log('NPM_SHIM_SOURCE_READ:'+source.length);eval(source);console.log('NPM_BOOTSTRAP_EVAL_DONE');process.argv=['node','$npm','ci','--prefix','$fixture','--cache','$files/.npm-cache','--no-audit','--no-fund','--registry=$registry','--replace-registry-host=always','--fetch-retries=0'];process.on('exit',()=>{console.log('NPM_CI_PROCESS_EXIT:'+String(process.exitCode||0));console.log('RESULT:PASS')});return/**/require('$npm')})()"
run_node 'Clean npm ci with committed lock and fast-uri override' "$npm_args" 'NPM_CI_PROCESS_EXIT:0' 300

verify_args="-p (eval(new/**/TextDecoder().decode(require('node:fs').readFileSync('$shim'))),require('$fixture/verify-install.cjs'))"
run_node 'Patched package, TypeScript, and MCP API checks' "$verify_args" 'MCP_IN_MEMORY_INITIALIZE_LIST_CALL_PASS' 120

runner="$files/test/mobile-runtime-poc/run-lifecycle-install.cjs"
for lifecycle_case in javascript async-javascript async-exit async-exit-default async-failure sync-exit async-timeout inline-js core-js typescript child-process native-command; do
  lifecycle_expression="(()=>{let/**/fs=require('node:fs');eval(new/**/TextDecoder().decode(fs.readFileSync('$shim')));globalThis.__STROOM_LIFECYCLE_CASE='$lifecycle_case';return/**/require('$runner')})()"
  run_node "npm lifecycle bridge: $lifecycle_case" \
    "-p $lifecycle_expression" \
    'RESULT:PASS' 180
done
