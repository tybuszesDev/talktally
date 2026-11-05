# ADR-0021: Code review for AI-written code

- Status: Accepted
- Date: 2026-11-05

## Context

Most code in this repository is written by Claude Code under the owner's supervision. A review by the same model in another session is useful, but it shares the author's blind spots, so it is not an independent check. The owner asked for an independent reviewer, preferably an AWS service, within the project's budget.

Options evaluated (November 2026):

- **Amazon CodeGuru Reviewer:** closed to new customers since 7 November 2025.
- **Amazon Q Developer:** reviews GitHub pull requests. According to third-party pricing pages, reviews are part of the Pro tier (about 19 USD per user per month); whether the free tier includes them is unclear. This alone would exceed the 10 USD monthly budget of ADR-0002.
- **CodeRabbit:** a GitHub app from another vendor with its own review pipeline. Its Pro features are free for public repositories, with rate limits.
- **Claude `/code-review` and `/security-review`:** good pre-checks in a fresh context, not independent of the author.

## Decision

Review has three layers, from most to least independent of the author:

1. **Deterministic tools:** tests, type checks, lint, dependency-cruiser, CodeQL, trivy (ADR-0011, ADR-0017).
2. **Independent AI review:** CodeRabbit reviews every pull request. Every finding is fixed or answered in the pull request before merge. Its configuration lives in `.coderabbit.yaml`.
3. **Owner review:** the owner reads the full diff and **is the only one who merges** pull requests.

Claude `/code-review` is an optional pre-check before opening a pull request. `/security-review` is required for changes to authentication, IAM, resolvers and subscriptions ([WORKING-AGREEMENT](../WORKING-AGREEMENT.md)).

Authoring rules for AI-written code:

- Code is written with Claude Opus 5.5 or a more capable model. The model is named in the commit trailer `Co-Authored-By`.
- In Claude Code, every change to a code file is approved by the owner one by one. Automatic acceptance of edits is not used for code. The project settings in `.claude/settings.json` make this the default.

## Consequences

- Every change is seen by tools, by a reviewer from another vendor and by a human.
- Manual approval of edits slows down writing, but the owner knows every line that enters the repository.
- CodeRabbit gets read access to the repository (which is public anyway). Its free tier may change; the fallback is Amazon Q Developer Pro or owner review with Claude pre-checks.
- Amazon Q Developer is revisited if its free tier is confirmed to include pull request reviews.

## Alternatives considered

- **Claude review only:** cheap and convenient, but not independent.
- **Amazon Q Developer Pro:** AWS-native, but a fixed monthly fee larger than the whole infrastructure budget.
- **No AI reviewer, owner only:** independent, but the owner is not a full-time reviewer and would miss more than with a second AI pass.
