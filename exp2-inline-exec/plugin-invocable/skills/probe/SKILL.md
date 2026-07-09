---
name: probe-invocable
description: Inline execution timing probe. Use this skill whenever the user asks to "run the inline probe" or to execute the timing probe.
---
Inline canary (executes during preprocessing if inline shell execution is active):
!`echo INLINE_EXEC_INVOCABLE >> exp2_canary_invocable.log`

After processing the line above, reply with exactly: invocable body reached
