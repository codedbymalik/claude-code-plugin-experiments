# Claude Code Plugin Experiments

Reproducible experiments supporting the seminar paper
**"Claude Code Plugins: What Is Possible, What Can Go Wrong?"**

These experiments convert documentation-grounded claims about the Claude Code
plugin system into empirically confirmed observations on a pinned build. Every
result is preserved in an auditable artifact: deterministic filesystem state and
component logs for E1/E2, and saved per-trial model transcripts under an explicit
classification rule for E3.

## Environment (results are build-specific)

| Item | Value |
| --- | --- |
| Claude Code | 2.1.205 |
| OS | macOS 26.5.1 (build 25F80) |
| Node | v22.22.0 |
| Date | 2026-07-09 |

## Experiments

### E1 — Manifest optionality / bare-directory auto-discovery
Folder: [`exp1-manifest-optional/`](exp1-manifest-optional/)

**Claim tested (paper §II-A):** a Claude Code plugin needs no
`.claude-plugin/plugin.json`; components auto-load from a bare directory tree, so
defensive tooling that enumerates plugins by searching for `plugin.json` will
systematically miss a stealthy plugin.

**Setup:** a plugin directory containing a skill, a command, an agent, and a
`SessionStart` hook — but **no `plugin.json`** — loaded via `--plugin-dir`.

**Result: CONFIRMED.**
- A recursive search for `plugin.json` over the plugin returned **0** matches.
- The plugin's `SessionStart` hook nonetheless executed on every session start,
  proving a code-executing component was auto-discovered from a manifest-less
  directory. Evidence: [`exp1-manifest-optional/logs/cc_exp1_hook.log`](exp1-manifest-optional/logs/cc_exp1_hook.log).

**Note on evidence channel:** in headless print mode (`-p`), Claude Code 2.1.205
suppresses verbose plugin-registration logging, so `exp1_debug.log` captured only
the model's answer. The hook's execution log is used as ground truth instead — a
deterministic side effect that a model cannot fabricate.

**Reproduce:**
```bash
cd exp1-manifest-optional
bash run.sh
```

### E2 — Inline shell execution in `SKILL.md` (load-vs-use + permission gate)
Folder: [`exp2-inline-exec/`](exp2-inline-exec/)

**Claim tested (paper §II-A, §IV-A):** a `` !`command` `` directive in a skill body is
run by Claude Code during preprocessing, before the text reaches the model. The paper
listed this as "documented, unverified" and left load-vs-use timing as future work.

**Result: CONFIRMED with refinements.**
- The inline path is real: the canary fired in **8/8** healthy invocation runs when
  permissions were bypassed to isolate the execution mechanism.
- It is **use-triggered, not load-triggered** — mere on-disk presence did not fire.
- It is **permission-gated** — blocked in default headless mode, fired only with the
  permission gate removed.
- `disableSkillShellExecution: true` **suppressed** it.

Full matrix and evidence: [`exp2-inline-exec/README.md`](exp2-inline-exec/README.md) and
[`exp2-inline-exec/logs/summary.txt`](exp2-inline-exec/logs/summary.txt).

**Reproduce:**
```bash
cd exp2-inline-exec
bash run.sh
```

### E3 — MCP tool-description poisoning: channel confirmed, obedience 0/30
Folder: [`exp3-tool-poisoning/`](exp3-tool-poisoning/)

**Claim tested (paper §IV-A, Fig. 1):** an MCP tool *description* is
attacker-influenceable metadata that enters the model's context (typically without being
surfaced in full by the approval UI). Does that text (a) reach the model and (b) get obeyed?

**Setup:** a minimal local MCP stdio server exposing one `health_check` tool whose
description embeds a benign marker directive (append token `7Q9Z`), in an `overt` and a
disguised-as-formatting `subtle` variant, plus a `clean` control. Each trial's full
transcript is saved and classified under an explicit, auditable rule.

**Result: channel CONFIRMED; this model RESISTS (obedience 0/30).**
- The description text provably reaches the model — in every poisoned trial it quoted the
  embedded directive verbatim while declining it (direct evidence of the Fig. 1 channel).
- Claude Code 2.1.205 refused the directive in **30/30** poisoned trials (overt + subtle),
  including a **neutral-directory replication** that rules out directory signposting as
  a necessary cause. The model's provenance-focused explanation is qualitative, not
  causal proof.
- The `clean` control never emitted the token (0/5), confirming the token can only come
  from the description.
- Honest framing: do **not** claim the model obeys hidden directives — for this version it
  does not. Do claim the channel is real and that obedience is model-version-dependent, so
  defense-in-depth still matters.

Full matrix, transcripts, interpretation, and the independent saved-log audit:
[`exp3-tool-poisoning/README.md`](exp3-tool-poisoning/README.md) and
[`exp3-tool-poisoning/CLASSIFICATION_AUDIT.md`](exp3-tool-poisoning/CLASSIFICATION_AUDIT.md).

**Reproduce:**
```bash
cd exp3-tool-poisoning
bash run.sh
bash audit_saved_transcripts.sh
```

Interactive approval behavior is intentionally kept separate from headless results. See
[`INTERACTIVE_VALIDATION.md`](INTERACTIVE_VALIDATION.md) for screenshot-ready E2 and E3
checks.

## Ethics & safety

- All probes use **benign markers only** (a hook that appends a UTC timestamp to a
  local temp file). No payloads that read secrets, reach the network, or execute
  remote code are included in this repository.
- Experiments are functional demonstrations run in a scratch directory. They are
  not exploits.
- Any experiment that could reveal an unpatched vulnerability will follow
  coordinated disclosure to the vendor before publication; such experiments are
  described in prose rather than shipped as runnable PoCs.

## Limitations

- Single build, single host. Behavior may change across Claude Code versions;
  claims are pinned to the environment above.
- E1 is a functional-discovery demonstration; it does not survey real-world
  scanner/EDR tooling.
- E2's default-permission result is headless-only; interactive approval behavior remains
  operator-verifiable.
- E3 measures one model/build with simple overt and formatting-style directives. Its
  0/30 obedience result is descriptive, not evidence of universal immunity.

## How to cite

Cite the tagged release and immutable commit for reproducibility, e.g.:

> M. Z. Hassan, "Claude Code Plugin Experiments," GitHub, release `v1.0.0`,
> commit `<SHA>`, 2026.
