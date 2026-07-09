# Paper Integration Brief — handoff for an LLM

**Paper:** "Claude Code Plugins: What Is Possible, What Can Go Wrong?" (IEEE-style seminar paper, single author).
**Purpose of this file:** give an LLM everything needed to rewrite the affected passages so the paper reflects (A) two experiments I actually ran and (B) citation fixes found in review. Apply edits precisely; keep the paper's existing tone (cautious, hedged, honest). Do not invent numbers — every figure below is measured or verified.

---

## PROMPT TO USE (paste this to the LLM along with this file + your paper text)

> You are editing my IEEE-style seminar paper. Using the "Paper Integration Brief" below and my attached paper text/LaTeX, produce the revised passages only (with enough surrounding context to locate each change). Convert previously hedged/"unverified" claims into empirically confirmed statements using the exact numbers provided, add a short Methodology subsection and an artifact reference, add the new reference(s), and apply the citation corrections. Preserve my voice and hedging style. Do not fabricate any figures; use only what the brief provides. Output unified, ready-to-paste text.

---

## ENVIRONMENT / PROVENANCE (cite once, e.g. in the new Methodology subsection)

- System under test: **Claude Code 2.1.205**
- Host: **macOS 26.5.1 (build 25F80)**, Node **v22.22.0**
- Date: **2026-07-09**
- Artifact repository (reproducible): **https://github.com/codedbymalik/claude-code-plugin-experiments**
  - E1 at `exp1-manifest-optional/`, E2 at `exp2-inline-exec/`. Cite the commit SHA for permanence.
- Ground-truth principle: all results were read from **deterministic artifacts** (filesystem state; a hook's own execution log; per-condition canary files), never from the model's natural-language self-report.

---

## EXPERIMENT 1 — Manifest optionality / bare-directory auto-discovery (CONFIRMED)

**What was claimed (paper §II-A):** a plugin needs no `.claude-plugin/plugin.json`; components auto-load from a bare directory tree, so "defensive tooling that enumerates extensions by searching for `plugin.json` will systematically miss a stealthy plugin deployed as a bare directory tree."

**What was done:** built a plugin directory containing a skill, a command, an agent, and a `SessionStart` hook, with **no `plugin.json`**, loaded via `--plugin-dir`.

**Result (measured):**
- A recursive search for `plugin.json` over the tree returned **0** matches.
- The plugin's `SessionStart` hook nonetheless **executed on every session start** (verified by its own timestamped log output), i.e. a code-executing component auto-loaded from a manifest-less directory.
- Evidence: `exp1-manifest-optional/logs/cc_exp1_hook.log`.

**Note for accuracy:** the hook fired once per session start (4 entries across the runs). Do not imply a single invocation; say it fired on each session start.

---

## EXPERIMENT 2 — Inline shell execution in `SKILL.md` (CONFIRMED, WITH REFINEMENTS)

**What was claimed (paper §II-A, §IV-A, Table II):** a `` !`command` `` directive in a skill body is run by Claude Code during preprocessing, before the text reaches the model. The paper marked this "documentation-indicated / unverified" and left the "load versus use" timing as future work; Table II row 4 reads "Inline execution (documented, unverified)."

**What was done:** a probe skill whose body contains a benign inline canary `` !`echo <marker> >> <file>` `` (no secrets, no network). Four conditions; each result is the presence/absence of the canary file. Two independent runs (the second a higher-n replication with a call-health guard so network-failed calls are discarded — none occurred).

**Results (measured, combined across both runs):**

| Condition | Setup | Canary fired |
| --- | --- | --- |
| A — discovery only | skill on disk, `disable-model-invocation`, neutral prompt, perms bypassed | **0/3** |
| B — invocation | matching prompt loads skill, perms bypassed | **8/8** |
| C — disabled control | invocation + `--settings '{"disableSkillShellExecution":true}'` | **0/3** |
| P — default perms | invocation, default permission mode (no bypass) | **0/6+** (blocked) |

**Four findings to state:**
1. **Real:** the inline path executed during preprocessing with **no separate Bash approval prompt** (8/8 on invocation).
2. **Use-triggered, not load-triggered:** mere on-disk presence never fired (0/3). This *resolves* the paper's open load-vs-use question: execution happens when the skill body loads into context (on invocation), not on directory discovery.
3. **Permission-gated (the finding that DIFFERS from the docs):** in default headless (`-p`) mode the inline command was blocked (0/6+); it fired only when the permission gate was removed (`--permission-mode bypassPermissions`). So the documentation's "runs before Claude sees anything" is subject to the permission system, not unconditional.
4. **Kill-switch works:** `disableSkillShellExecution: true` suppressed it (0/3), matching the documented `[shell command execution disabled by policy]` behavior.

**Bonus (optional, strong):** during development the model produced **three mutually inconsistent explanations** for the missing canary ("contains expansion", "/tmp outside working dir", "permission check") while the canary files told the real story — a concrete illustration of the data/instruction-trust problem the paper analyzes, and the justification for the artifact-over-self-report methodology.

**Honesty caveats to include:** Condition B (model-invocation) is stochastic (reported 8/8 here); A/B/C used `bypassPermissions` to isolate skill-loading from the permission gate, which is characterized separately by P; single build/host.

---

## SECTION-BY-SECTION EDITS

### 1) Abstract
- FIND: the clause describing the inline path, currently "...a documentation-described inline-shell-execution path inside skills that would bypass the model..." (and any "(whose timing I flag for empirical confirmation)").
- CHANGE TO: state it is now demonstrated but permission-gated and use-triggered, e.g. add: "which I confirm empirically on Claude Code 2.1.205 as a real, use-triggered preprocessing path that is nonetheless gated by the permission system (blocked in default headless mode, executed only when permissions were relaxed)."
- Also soften the manifest sentence to "confirmed" rather than "documented."

### 2) §II-A — manifest optionality
- FIND: "This optionality matters for threat modeling: defensive tooling that enumerates extensions by searching for plugin.json will systematically miss a stealthy plugin deployed as a bare directory tree."
- ADD immediately after: "I confirmed this on Claude Code 2.1.205: a plugin directory with no `plugin.json` but containing a skill, command, agent, and `SessionStart` hook was loaded via `--plugin-dir`; a recursive search for `plugin.json` returned zero matches, yet the plugin's hook executed at session start (verified by its own log output). A `plugin.json`-keyed scan therefore misses a bare-directory plugin whose components can still run code. (Artifact: E1.)"

### 3) §II-A — inline shell execution
- FIND: the passage ending "...I have not run a proof-of-concept, so I report this as documentation-indicated and leave the precise triggering conditions (load versus use) as future work (Section VII)."
- REPLACE the "I have not run a proof-of-concept..." hedge with the confirmed result: "I confirmed this behavior on Claude Code 2.1.205 (artifact: E2). An inline `` !`command` `` in a skill body executed during preprocessing on invocation in 8/8 trials, with no separate tool-approval prompt. The triggering condition is *use*, not mere *load*: a skill present on disk but not invoked never fired (0/3). Execution is, however, gated by the permission system — in default headless mode the command was blocked (0/6+) and ran only when permissions were relaxed — so the 'before the model sees it' preprocessing is conditional, not unconditional. The managed `disableSkillShellExecution` setting suppressed it entirely (0/3)."
- Keep the sentence about `disableSkillShellExecution` but now frame it as confirmed.

### 4) §IV-A — deterministic path paragraph
- FIND: "...obtains code execution the moment the skill loads, with no stochastic gate to clear..."
- ADJUST: change "the moment the skill loads" to "the moment the skill is invoked" and add a clause that this is empirically use-triggered and permission-gated (per E2), so the deterministic path is real but bounded by the permission system.

### 5) Table II (row 4)
- FIND cell: "Inline execution (documented, unverified)"
- CHANGE TO: "Inline execution (demonstrated; use-triggered, permission-gated — CC 2.1.205)"

### 6) §VII — Discussion / future work
- FIND: "a proof-of-concept and timing study of the inline-execution and .mcp.json approval semantics discussed here"
- SPLIT: mark the inline-execution part as DONE ("the inline-execution timing is resolved in this paper: use-triggered and permission-gated on CC 2.1.205; see Methodology/Appendix"), and keep the `.mcp.json` approval part as future work.
- In "Threats to Validity," add: results are pinned to CC 2.1.205 on one host; model-invocation is stochastic; the permission-gate result was observed in non-interactive `-p` mode and should be re-checked in interactive mode.

### 7) NEW subsection — Methodology (put near start of the experimental content, e.g. end of §II or a new §II-E)
Paste:
> **Empirical method.** Two documentation-grounded claims were tested on Claude Code 2.1.205 (macOS 26.5.1 build 25F80; Node v22.22.0), 2026-07-09. Inputs were content-hashed (SHA-256). All outcomes were read from deterministic artifacts — filesystem state, a plugin hook's own execution log, and per-condition canary files — not from model self-report; where the model narrated a cause, it was disregarded in favor of the artifact. Scaffolding was authored with AI assistance and reviewed by the author; no experimental outcome was determined by model output. Artifacts and a one-command reproducer are at the repository cited above (commit <SHA>).

### 8) Conclusion
- Update "the documentation-described inline-execution path inside skills" to "the demonstrated, use-triggered, permission-gated inline-execution path inside skills," keeping the overall argument intact.

---

## CITATION / FACTUAL FIXES (from review; independent of the experiments)

1. **Missing citation for the "26% increase in completed tasks."** This figure is from Cui, Demirer, et al., *The Effects of Generative AI on High-Skilled Work: Evidence from Three Field Experiments with Software* (4,867 developers; 26.08%, SE 10.3%). ADD as a new reference and cite it at that sentence; it is currently uncited / implicitly (and wrongly) attributed to the Peng et al. Copilot RCT.

2. **GitClear number vs. report mismatch.** The paper cites "roughly 211 million changed lines" but reference [32] is titled "Coding on Copilot: 2024 data..." — that earlier report analyzed **153 million** lines. The 211M figure is from GitClear's **2025** report ("AI Copilot Code Quality: 2025"). FIX: either cite the 2025 report for the 211M figure, or change the number to 153M to match the cited 2024 report. Also correct the reference title.

3. **NVD CVSS for CVE-2025-54136.** The paper says "the NVD entry publishes no score." NVD now lists **CVSS 3.1 base 8.8 (High)**. FIX: "NVD lists a CVSS 3.1 base score of 8.8; Check Point/Tenable report 7.2," or, if keeping the mid-2026 snapshot framing, add "as of consultation; NVD has since published 8.8."

4. **Browser vs. editor extensions.** Reference [25] (Nayak et al.) concerns **browser** extensions, but is grouped under "analyses of editor-extension ecosystems." FIX: say "browser- and editor-extension ecosystems," or move [25] out of that clause; [26] (VS Code) is the editor-extension one.

5. **SWE-bench phrasing (minor).** 80.9% is "low eighties," not "low-to-mid eighties." Optional tightening.

6. **Framework surfaces (minor nuance).** Acharya & Gupta [17] use **four** attack surfaces; the paper condenses to three. Add a half-clause noting the three-surface split is the author's condensation/adaptation, to avoid implying it comes verbatim from [17].

---

## WHAT TO ATTACH TO THE PAPER

**In the body (keep it compact):**
- One **results table** summarizing E1 and E2 (use the E2 table above; add an E1 row: "manifest search = 0 matches; hook executed").
- The repository URL + commit SHA (footnote or Methodology).

**In an Appendix (recommended for a security paper):**
- The **probe file contents** (the manifest-less tree layout for E1; the two `SKILL.md` probes for E2) — short, and they let a reader see exactly what was tested.
- The **SHA-256 hashes** of the probe inputs (`inputs.sha256`).
- The condensed **result logs**: `exp1-manifest-optional/logs/cc_exp1_hook.log`, `exp2-inline-exec/logs/summary.txt`, and `exp2-inline-exec/logs/verify_summary.txt`.

**Figures / screenshots (1–3 max; optional but persuasive):**
- Fig. E1: screenshot or verbatim block of `cc_exp1_hook.log` (shows the hook fired from a manifest-less plugin).
- Fig. E2: screenshot or verbatim block of `verify_summary.txt` (shows the 4-condition matrix: A 0/3, B 8/8, C 0/3, P 0/6+).
- Optional: a terminal capture (e.g. asciinema still) of a single run. Prefer clean typeset text blocks over raw screenshots for a paper; screenshots are fine as appendix evidence.

**Do NOT attach:** raw multi-hundred-line debug logs, anything containing your absolute home path/username (already scrubbed in the repo), or a runnable weaponized payload (all probes here are benign timestamp/marker writes — keep them that way).

---

## ONE-LINE SUMMARY FOR THE COVER/ABSTRACT
"Two documentation-grounded claims were empirically verified on Claude Code 2.1.205: manifest-less plugins auto-load and can execute code (defeating `plugin.json`-based enumeration), and the inline `` !`command` `` skill path is a real but *use-triggered* and *permission-gated* execution vector — refining, and in the permission-gating respect correcting, the vendor documentation."
