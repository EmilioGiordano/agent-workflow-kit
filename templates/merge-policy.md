<!-- Merge policy template. /workflow-init inserts it into the "How we work" section of AGENTS.md with <merger> and <attribution-rule> filled in. -->
### Merge policy

**A PR merges only when all hold:**
- Implemented, tested and working: the full gate passed after merging the current `main` into the branch.
- The reviewer gave PASS on the final commits. Any commit after a PASS needs a new PASS, except a merge of `main` with no conflict resolution.
- CI is green on every job.
- The feature was validated through its interface, with evidence (screenshots or logs). If there is no interface, the PR states `n/a` and why.

A criterion that does not apply counts as met only when the PR says so and why.

**Who merges:** <merger>. Command: `gh pr merge <n> --merge`. Never `--delete-branch`, never squash unless the project says so.

**Branches:**
- Never delete a branch or worktree. Cleanup is the user's call.
- Before rewriting any existing commit: `git branch backup/<branch>-before-rework`.
- Never force-push a pushed branch, and never push to `main` directly.

**Commits and PRs:**
- One-line messages: `type/short description` (slash, not colon), in <commit-language>.
- Attribution: <attribution-rule>.

**Stop and ask the user:**
- before anything they cannot undo: deleting, force-pushing, merging a PR that misses a criterion;
- before irreversible or external choices: licence, third-party binaries, publishing, paid services.

Record these as pending decisions in `REPORT.md`. Never work around them.
