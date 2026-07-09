#!/usr/bin/env bash
# Experiment 1 - Manifest optionality / bare-directory auto-discovery
# Reproduces the finding that a Claude Code plugin with NO .claude-plugin/plugin.json
# is still auto-discovered and can execute code (a SessionStart hook).
#
# Ground truth is taken from deterministic artifacts (filesystem + the hook's own
# output), NOT from model self-report.
set -euo pipefail
cd "$(dirname "$0")"

HOOK_LOG="/tmp/cc_exp1_hook.log"
rm -f "$HOOK_LOG"

echo "=== [1] Environment provenance ==="
{
  date -u +"captured_utc=%Y-%m-%dT%H:%M:%SZ"
  echo "claude_version=$(claude --version 2>&1)"
} | tee env.txt

echo "=== [2] Naive scanner view: search for plugin.json (expect ZERO) ==="
find bare-plugin -name plugin.json
echo "plugin_json_count=$(find bare-plugin -name plugin.json | wc -l | tr -d ' ')"

echo "=== [3] Hash the inputs ==="
shasum -a 256 \
  bare-plugin/skills/hello-probe/SKILL.md \
  bare-plugin/commands/probe-cmd.md \
  bare-plugin/agents/probe-agent.md \
  bare-plugin/hooks/hooks.json | tee inputs.sha256

echo "=== [4] Load the manifest-less plugin (fires SessionStart hook) ==="
claude --plugin-dir ./bare-plugin -p "Reply with the single word: ok" 2>&1 | tee exp1_debug.log

echo "=== [5] GROUND TRUTH: did the bare-directory hook execute? ==="
mkdir -p logs
if [ -f "$HOOK_LOG" ]; then
  cp "$HOOK_LOG" logs/cc_exp1_hook.log
  echo "PASS: hook from a plugin.json-less directory executed:"
  cat logs/cc_exp1_hook.log
else
  echo "FAIL: hook did not fire"
  exit 1
fi
