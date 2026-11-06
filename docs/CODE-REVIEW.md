# Code review

How pull requests are reviewed in TalkTally. Most code is written by Claude Code, so review is designed not to depend on the author's own judgement. Decisions: [ADR-0021](adr/0021-code-review-for-ai-written-code.md) (three layers), [ADR-0022](adr/0022-ai-assistance-commit-trailer.md) (commit trailer), [ADR-0023](adr/0023-coderabbit-review-cadence-and-fixes.md) (CodeRabbit cadence and fixes).

## Three layers

| Layer | Who | What blocks the merge |
|---|---|---|
| 1. Deterministic tools | GitHub Actions | Required checks `CI` (lint, typecheck, test, build), `PR title` (Conventional Commit) and `PR checklist` (description follows the template) |
| 2. Independent AI review | [CodeRabbit](https://coderabbit.ai), a reviewer from another vendor than the author | Unresolved review threads (`main` ruleset) |
| 3. Owner review | The owner reads the full diff | Only the owner merges, with a squash merge in the GitHub web UI |

Claude `/code-review` is an optional pre-check before a pull request is opened. `/security-review` is required for changes to authentication, IAM, resolvers and subscriptions ([WORKING-AGREEMENT](WORKING-AGREEMENT.md)).

## When CodeRabbit reviews

- **Once, automatically, when the pull request is opened.** Draft pull requests are skipped until they are marked ready for review.
- **Later pushes are not reviewed automatically.** Fix commits for review findings do not start a new round.
- **Again only on request:** a comment with `@coderabbitai review` reviews the commits since the last review. Claude requests it only for commits that add behaviour beyond the review fixes, and says so in the pull request. The owner can request it at any time.

## What CodeRabbit looks for

Configuration: [.coderabbit.yaml](../.coderabbit.yaml).

- **Real problems only:** profile `chill` and tone instructions that ask for bugs, security, data loss, broken CI and violated ADRs or project rules, and skip style, wording, Markdown edge cases and deliberate misuse by the author.
- **Project rules as guidelines:** [CLAUDE.md](../CLAUDE.md) and [WORKING-AGREEMENT](WORKING-AGREEMENT.md).
- **Path instructions:** accepted ADRs are immutable; workflows pin actions by SHA, use least privilege and pass untrusted input only through environment variables; `packages/domain` stays platform-neutral; tests follow Arrange-Act-Assert and never call real AWS services.
- **Not duplicated:** its ESLint, markdownlint and LanguageTool runs are off, because CI runs ESLint with the repository configuration and Markdown is written by hand.
- **The description stays ours:** CodeRabbit never edits the pull request description, which the `PR checklist` check reads. Its summary is in the walkthrough comment.

## Handling findings

Every finding is fixed or answered in the pull request.

- **Fixed:** a commit on the same branch; a reply in the thread names the commit; the thread is resolved.
- **Answered:** a reply with the reason, for example a deliberate design decision; the thread is resolved.
- **Outside the diff:** GitHub cannot attach a comment to lines the pull request did not change, so CodeRabbit puts such findings in the review body. They are answered with a pull request comment.
- **Pre-merge warnings** in the walkthrough comment (for example "Linked Issues check") are advisory and do not block the merge.

## CodeRabbit fixes on the owner's request

For a small, local finding the owner can reply `@coderabbitai fix comments` in the finding's thread. CodeRabbit then commits the fix for that finding only to the branch.

- Only the owner triggers it, per finding. The reply is the owner's approval of that change.
- Not used: the **Fix comments** checkbox in the review comment and the same command in the pull request conversation, because they fix every unresolved finding at once, and the ongoing **Autofix** mode (`@coderabbitai autofix`, walkthrough checkbox), which keeps fixing without being asked.
- Findings that change behaviour, tests, architecture or security are fixed in Claude Code, where every edit is approved one by one.
- Claude runs `git pull --ff-only` before continuing on the branch and checks the CodeRabbit commit like any other diff. CI runs on it.
- Every other CodeRabbit feature that writes code is off: fix CI, resolve merge conflicts, unit tests, docstrings.

## Merging

- Only the owner merges; nothing is merged automatically.
- The squash commit takes the pull request title. Its body collects the branch commit messages, so the `Assisted-by` trailers reach `main`.
- If CodeRabbit committed to the branch, GitHub adds a `Co-authored-by: coderabbitai[bot]` line to the squash message. The owner replaces it with `Assisted-by: CodeRabbit` in the merge dialog, because AI assistance is named with `Assisted-by`, not recorded as co-authorship.

## CodeRabbit commands

Written as a pull request comment, or as a reply in a review thread where noted:

| Command | Effect |
|---|---|
| `@coderabbitai fix comments` (reply in a finding's thread) | Commit a fix for that finding only; owner only |
| `@coderabbitai review` | Review the commits pushed since the last review |
| `@coderabbitai full review` | Review the whole pull request again from scratch |
| `@coderabbitai pause` / `@coderabbitai resume` | Stop or restart automatic reviews on this pull request |
