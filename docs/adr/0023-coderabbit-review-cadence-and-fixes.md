# ADR-0023: CodeRabbit review cadence and owner-requested fixes

- Status: Accepted
- Date: 2026-11-06
- Amends: [ADR-0021](0021-code-review-for-ai-written-code.md) (when CodeRabbit reviews, who may change code in a pull request)

## Context

ADR-0021 makes CodeRabbit a review-only layer: every finding is fixed or answered, and in Claude Code every change to a code file is approved by the owner one by one. In the first pull requests most CodeRabbit findings were small and local (a regex, a configuration key, one more test). Each one cost a round trip: Claude reads the finding, proposes the edit, the owner approves it, Claude commits, CodeRabbit reviews again. CodeRabbit reviewed every push by default, so each fix commit started a new round, often with a new edge case; on the pull request for F-04 that meant nine review rounds. The owner asked for fewer reviews, with a new review only when important findings were fixed, and whether CodeRabbit could fix low-risk findings itself.

CodeRabbit offers "finishing touches" that write code. **Fix comments** applies fixes for unresolved review findings and commits to the pull request branch. It runs only when asked: `@coderabbitai fix comments` as a reply in one finding's thread fixes only that finding, while the checkbox in a review comment or the same command in the pull request conversation fixes every unresolved finding at once. A separate **Autofix** mode (`@coderabbitai autofix` or a checkbox in the walkthrough) keeps fixing new findings without being asked again. The other finishing touches fix failing CI, resolve merge conflicts, or generate unit tests and docstrings, which is code that does not answer a review finding.

Automation tools also offer automatic merging of "low-risk" pull requests. That would remove the owner's merge, the last review layer in ADR-0021.

## Decision

- CodeRabbit reviews a pull request **automatically once, when it is opened** (or when a draft is marked ready). Later pushes are not reviewed automatically (`reviews.auto_review.auto_incremental_review: false`).
- A new review runs only on request with `@coderabbitai review`, using the severity CodeRabbit gives each finding:
  - **Critical or Major finding fixed:** after the fix commits of that round are pushed, Claude always requests one new review, which also checks the fixes.
  - **Only Minor or Trivial findings, or findings answered without a code change:** no new review.
  - **Commits that add behaviour beyond the review fixes:** Claude requests a new review and says so in the pull request.
  - The owner can request a review at any time.
- **Fix comments** (`reviews.finishing_touches.autofix`) is enabled. Only the owner triggers it, per finding, by replying `@coderabbitai fix comments` in that finding's thread. The command is the owner's approval of that change.
- The owner uses it for small, local findings. Findings that change behaviour, tests, architecture or security are fixed in Claude Code as before. The review checkbox and the command in the pull request conversation, which fix every unresolved finding at once, are not used.
- The ongoing **Autofix** mode is never turned on.
- Every other code-writing finishing touch stays disabled: fix CI, resolve merge conflicts, unit tests, docstrings.
- After a CodeRabbit commit, Claude pulls the branch (`git pull --ff-only`) before any further work and checks the change like any other diff. CI runs on it as on every push.
- When squash merging, the owner replaces the `Co-authored-by: coderabbitai[bot]` line that GitHub adds to the commit message with `Assisted-by: CodeRabbit`. AI assistance is named with `Assisted-by`, not recorded as co-authorship ([ADR-0022](0022-ai-assistance-commit-trailer.md)), and `main` still shows which commits contain CodeRabbit fixes.
- Pull requests are never merged automatically. The owner is still the only one who merges.

## Consequences

- One CodeRabbit review per pull request when it finds nothing important, so fixing small findings no longer starts new rounds.
- Fixes for important findings are always checked again by CodeRabbit; fixes for small ones are covered by CI and the owner's reading of the full diff.
- The rule relies on CodeRabbit's own severity labels; a finding the owner considers more serious than its label is treated as Major.
- Small findings are fixed with one thread reply instead of a full round trip through Claude Code.
- Not every code change in a pull request now comes from Claude Code with the `Assisted-by` trailer. CodeRabbit commits are visible in the branch history and come from the `coderabbitai[bot]` account.
- CodeRabbit commits skip the local git hooks (gitleaks, ESLint, Prettier, commitlint). CI runs ESLint and `prettier --check`, so formatting and lint problems still block the merge. The squash commit takes the pull request title, and the owner can edit the CodeRabbit commit message out of its body.
- The owner must remember to replace the co-author line when merging.

## Alternatives considered

- **Review every push (CodeRabbit default):** every fix commit starts a new round; that is what this decision stops.
- **Pause automatic reviews after fewer commits (`auto_pause_after_reviewed_commits`):** still reviews the first fix commits and then stops at an arbitrary point.
- **Keep CodeRabbit review-only (ADR-0021 as written):** safest, but every small finding costs a full round trip.
- **Enable all finishing touches:** CodeRabbit could commit without anyone asking, which bypasses the owner's approval of code changes.
- **Merge low-risk pull requests automatically:** removes the owner's merge, the last review layer.
