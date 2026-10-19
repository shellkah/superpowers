# Brainstorming Active Partner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: the handover prompt names which skill runs this plan, superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make brainstorming ask selectable questions after an open opening, bring its own options with a recommendation, look at the project without asking, and hunt gaps after recon and before the write-up.

**Architecture:** Edits to `skills/brainstorming/SKILL.md` only, pinned by comprehension tests in `tests/claude-code/test-brainstorming-focus.sh`. Task 1 changes how questions are asked; Task 2 changes what the agent brings to them.

**Tech Stack:** Markdown skill; bash tests driving `claude -p` through `run_claude_fork` (`tests/claude-code/test-helpers.sh`).

**Spec:** `docs/superpowers/specs/2026-10-19-brainstorming-active-partner-design.md`

## Global Constraints

- Fork-only; no behaviour evals.
- Keep the skill's voice: "your human partner", short plain sentences, Claude Code specifics in parentheses (`AskUserQuestion` in Claude Code).
- Unchanged: "Your First Message", playback chunks, sizing, the builder-check prompt, the HARD-GATE, autopilot hooks, "Where to focus", the visual companion section.
- Options per question: 2–4; batch up to 4 related, independent questions; the agent's pick first, marked "(Recommended)".
- Existing Tests 1–3 in `test-brainstorming-focus.sh` keep passing.

## Review Focus

1. **The opening gets steered anyway.** A surviving or new line that lets the first message carry options or recon findings. Pinned by Task 1's "First question" and Task 2's "Share findings before they describe it" assertions.
2. **Picker stalls unattended runs.** The fallback must cover no tool, headless runs, and an errored or empty answer. Pinned by Task 1's "Picker unavailable or empty" assertion.
3. **Plain-text prompts turned into pickers.** The opt-out line, visual companion offer and playback close stay text. Pinned by Task 1's "Visual companion offer" assertion.
4. **Web lookups made free by the recon change.** Pinned by Task 2's "Search the web without asking" assertion.
5. **Old anti-menu wording left contradicting the new rule** ("Offer a short menu only when they're stuck", the "Options steer" Red Flag, "one question… no list of example answers"). Caught by the Task 2 read-through step.

---

### Task 1: Selectable questions after an open opening

**Files:**
- Modify: `skills/brainstorming/SKILL.md` ("The Conversation" opening paragraphs, "Get them describing", "The Written Design" theirs-pile paragraph, Red Flags)
- Test: `tests/claude-code/test-brainstorming-focus.sh`

- [ ] **Step 1: Write the failing test.** Append before the final echo:

```bash
echo "Test 4: Opening open, then selectable questions..."
output=$(run_claude_fork "Read the superpowers:brainstorming skill. Answer using exactly this structure:
First question: <open or selectable>
Later decision questions: <open or selectable>
Batch related independent questions: <yes or no>
Picker unavailable or empty: <stall, skip, or ask in text>
Visual companion offer: <picker or plain text>
Builder check theirs questions: <picker or plain text>" "$T")
assert_contains "$output" "First question:.*open" "Opening stays open" || exit 1
assert_contains "$output" "Later decision questions:.*selectable" "Later questions selectable" || exit 1
assert_contains "$output" "Batch related independent questions:[^a-z]*yes\b" "Related questions batched" || exit 1
assert_contains "$output" "Picker unavailable or empty:.*text" "Text fallback" || exit 1
assert_contains "$output" "Visual companion offer:.*plain text" "Companion offer stays text" || exit 1
assert_contains "$output" "Builder check theirs questions:.*picker" "Theirs pile uses picker" || exit 1
echo ""
```

- [ ] **Step 2: Run it.** Run: `bash tests/claude-code/test-brainstorming-focus.sh`. Expected: Tests 1–3 PASS, Test 4 FAIL.

- [ ] **Step 3: Edit `SKILL.md`** per spec §1, §2 (question tool with 2–4 options, batching rule, the text fallback with its three triggers, scope list, open questions still right when options would be guesses; replace "Each message ends with one question… no list of example answers" and "Offer a short menu only when they're stuck"), §6 (theirs pile through the picker, one round, most important first), and the first §7 row ("I'll open with options to save them effort").

- [ ] **Step 4: Run the test.** Expected: all PASS.

- [ ] **Step 5: Commit.** `git add skills/brainstorming/SKILL.md tests/claude-code/test-brainstorming-focus.sh && git commit -m "feat(brainstorming): selectable questions after an open opening"`

### Task 2: Options with a recommendation, recon without asking, gap hunts

**Files:**
- Modify: `skills/brainstorming/SKILL.md` ("Get them describing" ideas line, "Think wide privately", "Offer recon", a new gap-hunt passage before "The Written Design", Red Flags)
- Test: `tests/claude-code/test-brainstorming-focus.sh`

- [ ] **Step 1: Write the failing test.** Append:

```bash
echo "Test 5: Ideas, recon, gaps..."
output=$(run_claude_fork "Read the superpowers:brainstorming skill. Answer using exactly this structure:
Decision questions carry a recommended option: <yes or no>
Separate approaches round: <yes or no>
Read the project without asking: <yes or no>
Search the web without asking: <yes or no>
Share findings before they describe it: <yes or no>
Gap hunts happen: <when>" "$T")
assert_contains "$output" "Decision questions carry a recommended option:[^a-z]*yes\b" "Recommendation on each decision" || exit 1
assert_contains "$output" "Separate approaches round:[^a-z]*no\b" "No approaches round" || exit 1
assert_contains "$output" "Read the project without asking:[^a-z]*yes\b" "Project recon is free" || exit 1
assert_contains "$output" "Search the web without asking:[^a-z]*no\b" "Web still asks" || exit 1
assert_contains "$output" "Share findings before they describe it:[^a-z]*no\b" "Findings held until after the opening" || exit 1
assert_contains "$output" "Gap hunts happen:.*recon.*write-up\|Gap hunts happen:.*recon.*design" "Two gap hunts" || exit 1
echo ""
```

- [ ] **Step 2: Run it.** Expected: Test 5 FAIL.

- [ ] **Step 3: Edit `SKILL.md`** per spec §3 (options with trade-offs in descriptions, pick first and "(Recommended)"; "Think wide privately" brings the strong ideas as options), §4 ("Look around": read-only project recon without asking, say what you looked at; web and outside the project still ask; may read early, share only after they've described it), §5 (gap list after recon as a multi-select where supported; deliberate "what's missing?" pass before the write-up, settling the rest as your calls), and the two added §7 rows.

- [ ] **Step 4: Read-through.** Search `SKILL.md` for "menu", "one question", "Offer recon", "Options steer", "They decide whether you go"; none may contradict the new rules.

- [ ] **Step 5: Run the test.** Run: `bash tests/claude-code/test-brainstorming-focus.sh && bash tests/claude-code/test-autopilot.sh`. Expected: all PASS.

- [ ] **Step 6: Commit.** `git commit -am "feat(brainstorming): bring options, look around, hunt gaps"` (add the test file if untracked changes remain).
