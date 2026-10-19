# Brainstorming: an active partner, not only a listener

Personal change for the `shellkah/superpowers` fork, built on 7.0.1. It
stays in the fork; it reverses a deliberate upstream 7.0.0 choice.

## Why

The 7.0.0 rebuild (`docs/superpowers/specs/2026-10-05-brainstorming-rebuild-design.md`)
made the agent a careful listener: open questions one at a time, menus
only when the human is stuck, ideas compared privately, recon only with
permission. Its reason was sound: menus steer the human toward the
agent's assumptions.

In practice your human partner finds it slow and passive. The 6.x skill
asked selectable questions, proposed ideas with trade-offs and a
recommendation, and surfaced gaps the human hadn't thought of. 7.0.x
asks plain-text questions and waits.

Evidence from the 2026-10-19 session that designed the autopilot
changes: the first questions came as plain text, one at a time, and the
agent hunted for gaps only after your human partner complained. That
late hunt found three of the most useful items in the design (delegating
the cross-part check, the writer writing the handover, a run-state file).

What your human partner wants, all together: **fast selectable answers,
the agent's own ideas, and gaps it catches unprompted.**

## Goals

- After the opening, every question your human partner answers can be
  answered by selecting, with "Other" always available.
- Every real decision arrives with the agent's own options and its
  recommendation.
- The agent looks at the project without asking, and reports gaps twice:
  after recon and before the write-up.
- The 7.0.0 core stays: understanding the why, playback, sizing, the
  builder check, the hard gate.

## Non-goals

- Changing the visual companion, the builder-check prompt, sizing, the
  hard gate, autopilot's hooks into brainstorming, or "Where to focus".
- Changing playback chunks (your human partner: keep as is).
- Making web or outside-project lookups free. Those still ask.

## Anti-goals

- **Garden-pathing the opening.** The first question stays open, so the
  human describes the idea in their own words before any option steers
  them. This keeps the rebuild's main protection.
- **Interrogation by picker.** Batched questions must be related; a
  picker is not a checklist read at the human.
- **Options as filler.** Options the agent hasn't thought through, or
  options that don't actually differ, are worse than an open question.

## Design

All in `skills/brainstorming/SKILL.md` unless noted.

### 1. Opening stays open

"Your First Message" is unchanged: the opt-out line and one open question
about a real moment. If the human's answer is thin, a second open
question is fine; switch to choices once they have described the thing.

### 2. Selectable questions after the opening

- After the opening, ask through the harness's question tool
  (`AskUserQuestion` in Claude Code), with 2–4 options per question. The
  tool adds "Other"; where a harness has no such tool, write numbered
  options in text and say they can answer in their own words.
- **Batch related questions**, up to 4 in one call, when they are
  independent of each other's answers. A question whose options depend on
  another's answer waits for the next round.
- The rule "each message ends with one question: a single sentence with no
  list of example answers hanging off it" is replaced by the above.
  Questions stay short and in plain language, pitched as today.
- **When the tool can't be used**, ask in plain text with numbered
  options: no question tool in the harness, a headless run (`claude -p`,
  autopilot unattended), or a tool call that errors or comes back with no
  answer. A run never stalls on, or carries on past, an unanswered
  picker. *(Designer's call, from the builder check.)*
- **Scope:** pickers are for questions that gather requirements and
  decisions, and the builder check's "theirs" questions. These stay plain
  text: the opt-out line, the visual companion offer (its own message),
  playback's closing "what's wrong or missing?", and yes/no offers like a
  spike or a size override. *(Designer's call.)*
- An open question is still right when options would be guesses (the
  human's taste, a story, a real moment). Not every question must be a
  picker.

### 3. The agent's ideas come as options

- Each real decision comes with 2–4 options the agent thought up, each
  with its trade-off in the option's description, and the agent's pick
  first, marked "(Recommended)".
- "Think wide privately" becomes: think wide, drop the weak ideas, and
  bring the strong ones as the options. No separate "approaches" round.
- When the human asks "what do you think?", propose concretely, as today.

### 4. Recon without asking

- "Offer recon" becomes **"Look around."** Reading the project (the
  codebase, its docs, its history, the human's files in the working
  directory) is read-only: do it when it helps, without asking, and say
  briefly what you looked at.
- Web searches and anything outside the project still ask first.
- **Timing:** the agent may read before or during the opening, so its
  first question is better informed, but it shares findings and gaps only
  after the human has described the idea. Your human partner chose this
  over "no reading until they describe it".

### 5. Gap hunting, twice

- **After recon:** list what you found that matters and the human hasn't
  mentioned (constraints, existing behaviour, likely conflicts, prior
  attempts), briefly, and ask which matter, as a multi-select question
  when the harness supports it.
- **Before the write-up:** a deliberate "what's missing?" pass over
  goals, edge cases, failure modes, how it's run and maintained, and what
  the design touches that nobody mentioned. Bring what matters as
  questions with options; settle the rest as your calls in the design.

### 6. Builder check "theirs" questions use the picker

In "The Written Design", the "theirs" pile is asked through the question
tool, with options and the agent's recommendation, still in one round,
most important first.

### 7. Red Flags

- Replace "I'll offer options to save them effort | Options steer. Ask
  them to describe it first." with a row that keeps the opening open:
  "I'll open with options to save them effort | The first question is
  open. Options come after they've described it."
- Add: "I'll ask open questions so I don't steer | After the opening,
  bring your options and your recommendation. 'Other' is always there."
- Add: "I'll ask before I look at the code | Reading the project is free.
  Look, then say what you found."

### 8. Tests

Add comprehension tests to `tests/claude-code/test-brainstorming-focus.sh`
in its existing style (`run_claude_fork`, "Answer using exactly this
structure"), covering:

- the first question is open; later questions are selectable;
- related questions may be batched;
- each decision carries a recommended option;
- recon of the project does not ask; the web does;
- gap hunting happens after recon and before the write-up.

Existing Tests 1–3 must still pass.

## Verification

The tests above, plus your human partner's next real brainstorm. No
behaviour evals: this is fork-only, and your human partner chose this
level. Comprehension tests check the rules are stated, not followed; the
real session is the behaviour check.

## Left to the builder

- Exact wording, in the skill's voice ("your human partner", short
  sentences).
- Where in the skill each change sits, as long as "Your First Message"
  stays first and the hard gate stays intact.
- Whether `using-superpowers/references/*-tools.md` gain a line naming each
  harness's question tool; only if a reference file already lists tool
  equivalents in a table.
