# Cross-Part Check Prompt

Under autopilot only. Dispatch a fresh subagent with this prompt once per
part of a split plan, after the part writer reports and before the part
executes. Fill in every bracketed placeholder. Outside autopilot, the main
session runs the cross-part check itself, as writing-plans says.

Name the checker's model explicitly; an omitted model inherits the session's:
- **A mid-tier model** (Sonnet in Claude Code) by default. The check is
  comparison and small edits; the index and the spec carry the judgment.
- **One tier below the most capable** (Opus) when the part has many
  cross-part interfaces or the earlier code drifted far from the index.

````
You are running the cross-part check on one part of a split
implementation plan, under superpowers:autopilot. You will not be able to
talk to the person who asked for it, and the main session will not read
the part file. Settle what you can; report only what you cannot.

Your inputs:
- Spec: [SPEC_PATH]
- Plan index: [INDEX_PATH]
- This part: [PART_PATH]
- The previous part's record: [PREVIOUS_RECORD_PATH] (`none` for part 1)
- Code from earlier parts: [WORKTREE_PATH] (`none` for part 1)
- The part writer's report:

[WRITER_REPORT]

- Run folder: [RUN_DIR]

Do these in order:

1. **Bring the index in line with the code.** Read the `Interfaces
   produced:` block in the previous part's record, and the interface
   differences in the writer's report. Spot-check each `file:line`
   against the code in [WORKTREE_PATH]. Where the code differs from the
   index's Cross-Part Interfaces, update the index to match the code.
   Skip this step for part 1.
2. **Check this part against the index and the spec.** This part's
   Interfaces blocks must match the index's Cross-Part Interfaces. Every
   spec requirement must map to a task in a written part, or to a later
   part in the index.
3. **Fix small mismatches yourself**, in the index or in this part file:
   a renamed function, a changed signature, a missing task an earlier
   step already decides. Append one line per fix to
   [RUN_DIR]/main-record.md, tagged like a ruling:
   `Ruling: [routine] <what you fixed> — <why> — <cost if wrong>`, or
   `[review]` when it touches permissions, data, outside systems, the
   spec's meaning, or anything costly to undo.

Then check length. The writer's `Length` line gives the part's lines and
the lines of the spec sections it covers. A part more than 3× its spec
share is far over: note it. It is a note, not a reason to rewrite the
part.

What you cannot settle (a part that is badly off, a requirement no part
covers, a conflict with the spec's meaning) goes in your report with a
recommendation. Never paste the part, the spec, or code into your
report: one line per item.

When you are done, report exactly this:

```text
Fixed: <count; each is in [RUN_DIR]/main-record.md>
Unsettled: <none, or one line each with a recommendation>
Length: <ok, or far over: <part lines>/<spec lines> = <ratio>×>
```
````
