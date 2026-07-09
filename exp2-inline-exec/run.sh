#!/usr/bin/env bash
# Experiment 2 - Inline shell execution in SKILL.md (load-vs-use timing + permission gate)
#
# Tests whether the documented inline `!`command`` preprocessing in a skill body
# executes, WHEN it fires (mere discovery vs. actual invocation), whether the
# managed disableSkillShellExecution setting suppresses it, and whether the
# default permission gate blocks it in headless mode.
#
# GROUND TRUTH = presence/absence of per-condition canary files, checked by this
# script. The model's prose is NOT used to determine any result (during
# development the model gave several mutually inconsistent explanations while the
# canary files told the real story).
#
# NOTE: each `claude -p` call performs a live model call (~50s).
set -uo pipefail
cd "$(dirname "$0")"
mkdir -p logs

DISC_CANARY="exp2_canary_discovery.log"
INV_CANARY="exp2_canary_invocable.log"

echo "=== env provenance ===" | tee logs/summary.txt
{
  date -u +"captured_utc=%Y-%m-%dT%H:%M:%SZ"
  echo "claude_version=$(claude --version 2>&1)"
  echo "os=$(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null) build $(sw_vers -buildVersion 2>/dev/null)"
} | tee env.txt | tee -a logs/summary.txt

shasum -a 256 plugin-discovery/skills/probe/SKILL.md plugin-invocable/skills/probe/SKILL.md | tee inputs.sha256

result() { # name  canary_file  expected(present|absent)
  local name="$1" f="$2" exp="$3" got
  if [ -f "$f" ]; then got="present"; else got="absent"; fi
  local verdict="MATCH"; [ "$got" = "$exp" ] || verdict="MISMATCH"
  printf '%-42s expected=%-8s got=%-8s [%s]\n' "$name" "$exp" "$got" "$verdict" | tee -a logs/summary.txt
}

echo "=== A: discovery only (disable-model-invocation, neutral prompt, perms bypassed) ===" | tee -a logs/summary.txt
rm -f "$DISC_CANARY"
claude --permission-mode bypassPermissions --plugin-dir ./plugin-discovery \
  -p "Reply with the single word: ok" < /dev/null > logs/condA_stdout.log 2>&1
result "A discovery-only (bypass)" "$DISC_CANARY" absent

echo "=== B: invocation (matching prompt, perms bypassed) x3 ===" | tee -a logs/summary.txt
B_HITS=0
for i in 1 2 3; do
  rm -f "$INV_CANARY"
  claude --permission-mode bypassPermissions --plugin-dir ./plugin-invocable \
    -p "Please run the inline probe now." < /dev/null > "logs/condB_run${i}_stdout.log" 2>&1
  if [ -f "$INV_CANARY" ]; then B_HITS=$((B_HITS+1)); cp "$INV_CANARY" "logs/condB_run${i}_canary.log"; fi
done
echo "B invocation (bypass): canary fired in ${B_HITS}/3 runs" | tee -a logs/summary.txt

echo "=== C: invocation + disableSkillShellExecution (perms bypassed) ===" | tee -a logs/summary.txt
rm -f "$INV_CANARY"
claude --permission-mode bypassPermissions --settings '{"disableSkillShellExecution": true}' \
  --plugin-dir ./plugin-invocable -p "Please run the inline probe now." < /dev/null > logs/condC_stdout.log 2>&1
result "C invocation + disabled setting" "$INV_CANARY" absent

echo "=== P: invocation in DEFAULT permission mode (no bypass) ===" | tee -a logs/summary.txt
rm -f "$INV_CANARY"
claude --plugin-dir ./plugin-invocable -p "Please run the inline probe now." < /dev/null > logs/condP_default_stdout.log 2>&1
result "P invocation (default perms)" "$INV_CANARY" absent

echo "=== DONE. Summary in logs/summary.txt ===" | tee -a logs/summary.txt
