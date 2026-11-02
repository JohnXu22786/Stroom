#!/usr/bin/env bash
set -euo pipefail

package='nodejsmobile.test.testnode'
component='nodejsmobile.test.testnode/com.janeasystems.test.testnode.MainActivity'
files='/data/user/0/nodejsmobile.test.testnode/files'

adb wait-for-device
adb shell am start -W -n "$component" >/dev/null
sleep 2

run_node() {
  local label=$1 nodeargs=$2 marker=$3 max_wait=${4:-120} log i
  adb shell am force-stop "$package" || true
  adb logcat -c
  adb shell am start -W -n "$component" --es nodeargs "$nodeargs" >/dev/null
  for i in $(seq 1 "$max_wait"); do
    log=$(adb logcat -d -s TestNode:I nodejs:I '*:S' 2>/dev/null || true)
    if grep -Fq "$marker" <<<"$log" || grep -Fq 'RESULT:FAIL' <<<"$log"; then
      break
    fi
    sleep 1
  done
  printf '%s\n' "===== $label =====" "$log"
  grep -Fq "$marker" <<<"$log"
  grep -Fq 'RESULT:PASS' <<<"$log"
}

run_node 'Node runtime + app-private fs' './test/runtime-check.cjs' 'NODE_RUNTIME_PASS v18.20.4'
run_node 'npm runtime install of MCP SDK + Zod' \
  "./test/npm/package/bin/npm-cli.js --prefix $files --no-audit --no-fund --ignore-scripts install @modelcontextprotocol/sdk@1.32.2 zod@3.25.76" \
  'added' 300
run_node 'MCP SDK stdio initialize/list/call' './test/mcp-stdio-roundtrip.cjs' 'MCP_STDIO_ROUNDTRIP_PASS'
