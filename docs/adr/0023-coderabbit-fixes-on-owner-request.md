# ADR-0023: CodeRabbit fixes on owner request

- Status: Accepted
- Date: 2026-11-06
- Amends: [ADR-0021](0021-code-review-for-ai-written-code.md) (who may change code in a pull request)

## Context

ADR-0021 makes CodeRabbit a review-only layer: every finding is fixed or answered, and in Claude Code every change to a code file is approved by the owner one by one. In the first pull requests most CodeRabbit findings were small and local (a regex, a configuration key, one more test). Each one cost a round trip: Claude reads the finding, proposes the edit, the owner approves it, Claude commits, CodeRabbit reviews again. The owner asked whether CodeRabbit could fix low-risk findings itself.

CodeRabbit offers "finishing touches" that write code. **Fix comments** applies the fix for a review finding: it runs only when someone ticks its checkbox under the finding or asks for it with an `@coderabbitai` command, and it commits to the pull request branch. The others fix failing CI, resolve merge conflicts, or generate unit tests and docstrings, which is code that does not answer a review finding.

GitHub also offers automatic merging of "low-risk" pull requests. That would remove the owner's merge, the last review layer in ADR-0021.

## Decision

- **Fix comments** (`reviews.finishing_touches.autofix`) is enabled. Only the owner triggers it, per finding, from the GitHub interface. Ticking the checkbox is the owner's approval of that change.
- The owner uses it for small, local findings. Findings that change behaviour, tests, architecture or security are fixed in Claude Code as before.
- Every other code-writing finishing touch stays disabled: fix CI, resolve merge conflicts, unit tests, docstrings.
- After a CodeRabbit commit, Claude pulls the branch (`git pull --ff-only`) before any further work and checks the change like any other diff. CI runs on it as on every push.
- When squash merging, the owner deletes the `Co-authored-by: coderabbitai[bot]` line that GitHub adds to the commit message, because AI assistance is not recorded as co-authorship ([ADR-0022](0022-ai-assistance-commit-trailer.md)).
- Pull requests are never merged automatically. The owner is still the only one who merges.

## Consequences

- Small findings are fixed with one click instead of a full round trip through Claude Code.
- Not every code change in a pull request now comes from Claude Code with the `Assisted-by` trailer. CodeRabbit commits are visible in the branch history and come from the `coderabbitai[bot]` account.
- CodeRabbit commits skip the local git hooks (gitleaks, ESLint, Prettier, commitlint). CI runs ESLint and `prettier --check`, so formatting and lint problems still block the merge; the commit message does not matter because the squash commit uses the pull request title.
- The owner must remember to remove the co-author line when merging.

## Alternatives considered

- **Keep CodeRabbit review-only (ADR-0021 as written):** safest, but every small finding costs a full round trip.
- **Enable all finishing touches:** CodeRabbit could commit without anyone asking, which bypasses the owner's approval of code changes.
- **Merge low-risk pull requests automatically:** removes the owner's merge, the last review layer.
