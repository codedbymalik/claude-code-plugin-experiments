#!/usr/bin/env bash
# Experiment 2 - REPLICATION harness (independent second run, higher n).
# Re-verifies the differentiating findings:
#   - use-triggered (A absent, B present)
#   - permission-gated (P absent in default mode; B present with bypass)
#   - disableSkillShellExecution suppresses (C absent)
# Each run's canary outcome is appended IMMEDIATELY so partial progress survives
# a network interruption. Ground truth = canary files, not model prose.
set -uo pipefail
cd "$(dirname "$0")"
mkdir -p logs
SUM=logs/verify_summary.txt
DISC=exp2_canary_discovery.log
INV=exp2_canary_invocable.log

{
  echo "=== EXP2 REPLICATION run ==="
  date -u +"captured_utc=%Y-%m-%dT%H:%M:%SZ"
  echo "claude_version=$(claude --version 2>&1)"
  echo "os=$(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null) build $(sw_vers -buildVersion 2>/dev/null)"
} | tee -a "$SUM"

# health flag: a call is only trustworthy if it exited 0 AND produced stdout.
# Otherwise (e.g. network failure) an absent canary is meaningless -> CALL_SUSPECT.
run_disc() {
  rm -f "$DISC"; local out; out=$(mktemp)
  claude --permission-mode bypassPermissions --plugin-dir ./plugin-discovery \
    -p "Reply with the single word: ok" < /dev/null > "$out" 2>&1
  local rc=$?; local c=absent; [ -f "$DISC" ] && c=present
  local h=ok; { [ $rc -ne 0 ] || [ ! -s "$out" ]; } && h=CALL_SUSPECT
  echo "$c [$h]"; rm -f "$out"
}
run_inv() { # $1 = bypass|default|disabled
  rm -f "$INV"; local out; out=$(mktemp)
  case "$1" in
    bypass)   claude --permission-mode bypassPermissions --plugin-dir ./plugin-invocable -p "Please run the inline probe now." < /dev/null > "$out" 2>&1 ;;
    default)  claude --plugin-dir ./plugin-invocable -p "Please run the inline probe now." < /dev/null > "$out" 2>&1 ;;
    disabled) claude --permission-mode bypassPermissions --settings '{"disableSkillShellExecution": true}' --plugin-dir ./plugin-invocable -p "Please run the inline probe now." < /dev/null > "$out" 2>&1 ;;
  esac
  local rc=$?; local c=absent; [ -f "$INV" ] && c=present
  local h=ok; { [ $rc -ne 0 ] || [ ! -s "$out" ]; } && h=CALL_SUSPECT
  echo "$c [$h]"; rm -f "$out"
}

for i in 1 2;         do echo "A discovery-only      #$i expected=absent  -> $(run_disc)"        | tee -a "$SUM"; done
for i in 1 2 3 4 5;   do echo "B invocation(bypass)  #$i expected=present -> $(run_inv bypass)"   | tee -a "$SUM"; done
for i in 1 2;         do echo "C disabled(bypass)    #$i expected=absent  -> $(run_inv disabled)" | tee -a "$SUM"; done
for i in 1 2 3 4 5;   do echo "P default-perms       #$i expected=absent  -> $(run_inv default)"  | tee -a "$SUM"; done
echo "=== replication done ===" | tee -a "$SUM"
