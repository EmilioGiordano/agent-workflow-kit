<!-- Merge policy template. /workflow-init inserts it into the "How we work" section of AGENTS.md with every <...> filled from the parameters table. Drop a bracketed alternative that does not apply. -->
### Merge policy

**A PR merges only when all hold:**
- Implemented, tested and working: the full gate passed after merging the current `<default-branch>` into the branch.
- The reviewer gave PASS on the final commits. Any commit after a PASS needs a new PASS, except a merge of `<default-branch>` with no conflict resolution.
- <Extra required reviews passed: <extra-reviews>.>
- <`ci: required`: CI is green on every job. | `ci: none / skipped-on-forks / no-push`: CI cannot run, so the orchestrator re-runs the full gate on the merged result and records the output in the PR.>
- The feature was validated through its interface (`ui_validation`), with evidence. If there is no interface, the PR states `n/a` and why.
- <Merge approval: <merge-approval>.>

A criterion that does not apply counts as met only when the PR says so and why.

**Who merges:** <merger>. Command: `gh pr merge <n> --merge`<, or the project's own merge procedure>. Never `--delete-branch`, never squash unless the project says so.

**Review rounds:** <no limit | after <n> failed rounds on a branch, stop and ask the user>.

**Branches:**
- Never delete a branch or worktree. Cleanup is the user's call.
- Before rewriting any existing commit: `git branch backup/<branch>-before-rework`.
- Never force-push a pushed branch, and never push to `<default-branch>` directly.

**Commits and PRs:**
- Commit messages: <commit-format>, in <commit-language>.
- Attribution: <attribution-rule>.

**Stop and ask the user:**
- before anything they cannot undo: deleting, force-pushing, merging a PR that misses a criterion;
- before irreversible or external choices: licence, third-party binaries, publishing, paid services.

Record these as pending decisions in `REPORT.md`. Never work around them.
