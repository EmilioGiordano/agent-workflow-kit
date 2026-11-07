# Lessons

Rules learned on real projects. They are the one source: agents, the orchestrate skill and the profiles point here instead of copying the rules. To add a lesson, append an entry. Use the format at the end.

Each entry gives the rule, who it applies to (`all`, `orchestrator`, `implementer`, `reviewer`) and its scope (`any stack`, or a named profile or platform).

## L1. Never steal focus from the user
- Applies to: orchestrator. Scope: desktop UI validation.
- Rule: do not send keys, click, or bring windows to the front while the user may be at the machine.
- Evidence capture: use methods that do not take focus:
  - Windows: `PrintWindow` plus `ShowWindow(SW_SHOWNOACTIVATE)`;
  - browsers: headless Playwright.
- Drive a window with real input only after the user says they are away.
- Why: an agent once typed into the user's browser.

## L2. The reviewer verifies; it does not trust
- Applies to: reviewer.
- Rule: run the gate yourself and follow each claim of the implementer to the code. A claim without evidence is unverified.
- Why: every review on the source project found real bugs, such as a test failing 4 runs in 6, a thread that never exited, and races on shutdown.

## L3. Count orphan processes at any depth
- Applies to: implementer, reviewer. Scope: code that spawns or shuts down processes.
- Rule: a shutdown test counts descendants at every depth, grandchildren included (e.g. `cmd -> node`), not only direct children.

## L4. Every commit builds and passes lint and fmt
- Applies to: implementer.
- Rule: no standalone "fmt fix" or "lint fix" commits. Fold the fix into the commit it belongs to before handing over.

## L5. Back up before rewriting history
- Applies to: orchestrator, implementer.
- Before any rebase, reset or amend of existing commits, run:
  ```sh
  git branch backup/<branch>-before-rework
  ```
- Rewrite non-interactively, in one of two ways:
  - `GIT_SEQUENCE_EDITOR="sed -i ..." git rebase -i <base>`;
  - `git reset --mixed <base>`, then new commits.
- Never `rebase -i` with an editor; agents cannot drive it.

## L6. Inject time; wait on signals
- Applies to: implementer, reviewer.
- Rule: tests take time as an injected clock and wait on a signal (channel, event, condition), never on `sleep`.
- Why: tests that depend on the wall clock fail when the machine is loaded.

## L7. Side-effecting features are off by default
- Applies to: implementer, reviewer.
- Rule: a feature that starts external processes or uses the network (git, HTTP, CLIs) is disabled in the config `Default` and enabled by the app.
- Why: otherwise unrelated tests trigger it and become flaky.

## L8. Merge main and re-gate before the PR
- Applies to: orchestrator.
- Rule: after PASS and before opening or merging the PR, merge the current `main` into the branch and run the full gate again.
- Why: parallel branches collide, even on a single import line.

## L9. Write the report as you go
- Applies to: orchestrator.
- Rule: update `REPORT.md` after every event: what was merged, the evidence, incidents and pending decisions. Never write it only at the end.

## L10. Pending user decisions are never bypassed
- Applies to: all.
- Rule: record irreversible or external choices as "pending decision" in `REPORT.md` and stop that line of work. Examples: a licence, downloading third-party binaries, publishing, paid services, deleting data.
- Do not take the decision. Do not look for a workaround that avoids the block.

## L11. One target dir per branch for compiled stacks
- Applies to: orchestrator. Scope: rust-compiled and other compiled profiles.
- Rule: never share a build output directory between two branches.
- Why: mixed builds have caused real bugs.

## L12. Long builds run in the background
- Applies to: orchestrator, implementer.
- Rule: a gate or release build that can outlast a tool-call timeout runs in the background. Wait for it to finish; do not poll in a sleep loop.

---

## Entry format

```md
## L<n>. <imperative title>
- Applies to: <roles>. Scope: <any stack | profile | platform>.
- Rule: <trigger -> action>.
- Why: <one line, only if it prevents misuse>.
```
