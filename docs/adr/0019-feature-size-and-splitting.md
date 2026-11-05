# ADR-0019: Feature size and splitting

- Status: Accepted
- Date: 2026-11-05
- Amends: [ADR-0012](0012-git-workflow-and-ci-cd.md) (one feature = one commit)

## Context

ADR-0012 puts exactly one squash commit per feature on `main`. Some roadmap features take several days. Keeping all of that work in one unpushed commit risks losing work, produces pull requests that are too large to review well, and causes merge conflicts.

## Decision

- **Commit often on the feature branch**, at least once per working day, and push the branch to GitHub as a backup. Git hooks still run on every commit.
- **`main` still receives one squash commit per pull request.**
- **A feature expected to take more than about two days is split into several pull requests.** Each part is a complete, tested and deployable step with its own commit on `main`.
  - Parts are numbered after the feature: `F-44a`, `F-44b`, ...
  - Each part is a GitHub sub-issue of the feature issue. The feature issue closes with the last part.
  - Every part meets the definition of done in `docs/ROADMAP.md`.
  - User-facing pieces that are not finished stay unreachable in the UI (not linked in navigation) until the last part ships.
- The roadmap keeps one row per feature; splits are recorded in the issues.

## Consequences

- No multi-day commits, smaller reviews, and work is backed up daily.
- `main` gets a few more commits, but each one is still meaningful and passes all checks.
- Splitting needs some planning at the start of a large feature.

## Alternatives considered

- **One commit per feature regardless of size (ADR-0012 as written):** large, risky pull requests.
- **Rebase merge of all branch commits:** keeps work-in-progress noise in the history of `main`.
- **Stacked pull request tools (for example Graphite):** useful in teams, unnecessary overhead for one developer.
