# Part Writer Prompt

Dispatch a fresh subagent with this prompt, once per part of a split plan,
after the index is written. Fill in every bracketed placeholder.

Name the writer's model explicitly; an omitted model inherits the session's:
- **One tier below the most capable** (Opus in Claude Code) by default. It
  plans a part well from the spec and the index, and a small part gains
  nothing from the top tier.
- **The most capable model** (Fable) only for a very intensive or critical
  part, such as security, data migrations, or payments.

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
- Under autopilot: [UNDER_AUTOPILOT] (`yes` or `no`)
- Handover file: [HANDOVER_PATH] (used only under autopilot)
- Run folder: [RUN_DIR] (`none` outside autopilot). Earlier parts'
  records there (`part-N-record.md`) list the interfaces they produced,
  with `file:line`, and the rulings their executors made.

Read the spec and the index. Your part's row in the index's Parts table
says what your part delivers.

Read and follow superpowers:writing-plans for your part only. Do not split
your part further; the main session does that. Use its Plan Document
Header, with this line directly under the title:

**Part [PART_NUMBER] of [PART_COUNT]** · Index: `[INDEX_PATH]`

Write interfaces, tests, edge cases and the reasons behind your choices
in full. A function body or a whole script becomes its signature and one
sentence on what it does, unless the code is itself the hard part (a
tricky algorithm, an exact migration, an exact command sequence). There
is no line budget: write what the executor needs, and no more.

When the part is written, run writing-plans' Self-Review on it and fix
what you find. Its spec-coverage and Review Focus checks cover only what
the index gives your part: your row in the Parts table and the interfaces
your part must produce. A spec requirement that belongs to another part
is not a gap, so do not add a task for it. The cross-part check covers
all parts.

Do not change the index's Cross-Part Interfaces. Use those names,
signatures, and types exactly as the index gives them. If [WORKTREE_PATH]
is not `none` and the code there disagrees with the index, the code wins:
plan against the code and report the difference.

Handover prompts: outside autopilot, do not write them; the main session
writes them all after every part is written. Under autopilot, write your
part's handover prompt as writing-plans' Execution Handoff says (pick the
mode, give one sentence of reason, the prompt's contents in order, as
Markdown under its heading, not in a code block), and
append it to [HANDOVER_PATH]. For part 1, create the file with that
layout first.

Do not guess on a question that changes what gets built. Report it
instead. Decide everything else yourself, the way writing-plans says to.

When you are done, report exactly this:

```text
Part file: <path>
Tasks: <count>
Interface differences from index: <none, or one line each: index says X, code has Y>
Open questions: <none, or ranked, each with why the answer changes what gets built>
Length: <lines> lines, for spec §<sections your part covers> (<lines> lines)
Handover: appended, mode <skill> (under autopilot only)
```
````
