# Claude Code Plugin Experiments

Reproducible experiments supporting the seminar paper
**"Claude Code Plugins: What Is Possible, What Can Go Wrong?"**

These experiments convert documentation-grounded claims about the Claude Code
plugin system into empirically confirmed observations on a pinned build. Every
result is taken from **deterministic artifacts** (filesystem state and a plugin
component's own execution output), never from model self-report.

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
- The inline path is real: the canary fired in **3/3** invocation runs with no separate
  Bash approval prompt.
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

## How to cite

Cite the specific commit for reproducibility, e.g.:

> M. Z. Hassan, "Claude Code Plugin Experiments," GitHub, commit `<SHA>`, 2026.
