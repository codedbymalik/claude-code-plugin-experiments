---
name: probe-discovery
description: Discovery-only probe. Never invoked; used to test whether mere presence triggers preprocessing.
disable-model-invocation: true
---
Inline canary (would fire during preprocessing if the skill body were loaded):
!`echo INLINE_EXEC_DISCOVERY >> exp2_canary_discovery.log`

After processing the line above, reply with exactly: discovery body reached
