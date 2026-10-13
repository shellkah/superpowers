# Part Writer Prompt

Dispatch a fresh subagent on the most capable model available with this
prompt, once per part of a split plan, after the index is written. Fill in
every bracketed placeholder.

````
You are writing one part of a split implementation plan. You will not be
able to talk to the person who asked for it.

Your inputs:
- Spec: [SPEC_PATH]
- Plan index: [INDEX_PATH]
- Your part: part [PART_NUMBER] of [PART_COUNT]
- Earlier parts: [EARLIER_PART_PATHS]. Read only their Interfaces blocks,
  not their whole content.
- Code from earlier parts: [WORKTREE_PATH] (`none` when no earlier part
  has run)
- Write your part to: [OUTPUT_PATH]

Read the spec and the index. Your part's row in the index's Parts table
says what your part delivers.

Read and follow superpowers:writing-plans for your part only. Do not split
your part further and do not write handover prompts; the main session does
both. Use its Plan Document Header, with this line directly under the
title:

**Part [PART_NUMBER] of [PART_COUNT]** · Index: `[INDEX_PATH]`

When the part is written, run writing-plans' Self-Review on it and fix
what you find.

Do not change the index's Cross-Part Interfaces. Use those names,
signatures, and types exactly as the index gives them. If [WORKTREE_PATH]
is not `none` and the code there disagrees with the index, the code wins:
plan against the code and report the difference.

Do not guess on a question that changes what gets built. Report it
instead. Decide everything else yourself, the way writing-plans says to.

When you are done, report exactly this:

```text
Part file: <path>
Tasks: <count>
Interface differences from index: <none, or one line each: index says X, code has Y>
Open questions: <none, or ranked, each with why the answer changes what gets built>
```
````
