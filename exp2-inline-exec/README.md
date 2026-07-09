# Experiment 2 — Inline shell execution in `SKILL.md` (load-vs-use + permission gate)

**Claim tested (paper §II-A, §IV-A):** the Claude Code skill body supports an inline
`` !`command` `` directive that Claude Code runs *before* the skill text reaches the
model ("preprocessing, not something Claude executes"). The paper flagged the precise
triggering conditions — **load vs. use** — as unverified future work, and listed the
vector in Table II as "Inline execution (documented, unverified)."

## Design

A probe skill whose body contains a benign inline canary
`` !`echo INLINE_EXEC_... >> <file>` `` (no secrets, no network). Ground truth is the
**presence/absence of the canary file**, checked by `run.sh` — never the model's prose.

| Condition | Setup | Prediction | Result |
| --- | --- | --- | --- |
| A — discovery only | skill present, `disable-model-invocation`, neutral prompt, perms bypassed | no fire | **absent (MATCH)** |
| B — invocation ×3 | matching prompt loads skill, perms bypassed | fires | **3/3 fired** |
| C — disabled control | invocation + `--settings '{"disableSkillShellExecution":true}'` | no fire | **absent (MATCH)** |
| P — default perms | invocation, default permission mode (no bypass) | (open) | **absent** — blocked |

## Findings (Claude Code 2.1.205, macOS 26.5.1 25F80, 2026-07-09)

1. **The inline path is real.** `` !`cmd` `` in a skill body executed during preprocessing
   and wrote the canary in **3/3** invocation runs, with **no separate Bash tool call or
   approval prompt** — confirming it is not an ordinary, individually-approved tool use.
2. **It is *use*-triggered, not *load*-triggered.** Mere on-disk presence of the skill,
   without invocation, did **not** fire (Condition A). This resolves the paper's open
   question: execution happens when the skill body is loaded into context (on
   invocation), not merely when the plugin directory is discovered.
3. **It is permission-gated.** In default headless (`-p`) mode the inline command was
   **blocked** (Condition P; also 3 earlier ad-hoc trials). It fired only when the
   permission gate was removed (`--permission-mode bypassPermissions`). So the docs'
   "runs before Claude sees anything" is subject to the permission system, not
   unconditional.
4. **The managed kill-switch works.** `disableSkillShellExecution: true` suppressed the
   canary (Condition C), matching the documented `[shell command execution disabled by
   policy]` behavior.

## Methodological note (important)

During development the model narrated **three mutually inconsistent explanations**
across runs ("contains expansion", "/tmp outside working dir", "permission check")
while the canary files told the actual story. This is a concrete instance of why the
experiment treats deterministic artifacts, not model self-report, as ground truth —
the same data/instruction-trust problem the paper analyzes.

## Reproduce

```bash
cd exp2-inline-exec
bash run.sh    # ~6 live model calls, ~5 min; writes logs/summary.txt
```

## Limitations

- Single build/host. Model-invocation (Condition B) is stochastic; reported as 3/3 here.
- Conditions A/B/C were run with `bypassPermissions` to isolate the skill-loading
  variable from the permission gate; the gate itself is characterized separately (P).
- Suggested paper phrasing: "Inline execution (demonstrated; use-triggered and
  permission-gated on CC 2.1.205)."
