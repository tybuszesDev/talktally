# ADR-0016: Release management and work traceability

- Status: Accepted
- Date: 2026-11-05

## Context

A reader of the repository (a recruiter, a reviewer, the owner in six months) should be able to follow any change from the plan to production: why it was built, how it was accepted, what shipped in which version. ADR-0012 defines one Conventional Commit per feature; this ADR defines how work is planned and released around those commits.

## Decision

### Planning

- **GitHub Issues:** one issue per roadmap feature, with a user story, acceptance criteria and test notes. Labels for type (`feature`, `bug`, `chore`), area (`web`, `mobile`, `api`, `pipeline`, `infra`, ...) and priority.
- **Milestones** match the milestones in `docs/ROADMAP.md`.
- **GitHub Projects board:** Backlog → Ready → In progress → In review → Done.

### Changes

- Branch names include the issue number: `feat/12-entry-upload`.
- **Pull request template:** `Closes #<issue>`, summary, checklist (tests added, docs updated, ADR needed?, screenshots for UI, infrastructure cost change).
- The squash commit message is the Conventional Commit title with the pull request number, so each commit on `main` links to its discussion.

### Releases

- **release-please** (GitHub Action) keeps an open release pull request with the next version and the generated `CHANGELOG.md`.
- Merging the release pull request creates the tag `vX.Y.Z` and a GitHub Release, which starts the prod deployment behind the `prod` environment approval (ADR-0012).
- **One version for the whole product**, not per package, because the packages are not published separately.
- **Semantic versioning:** `0.x` during MVP development; `1.0.0` marks the finished MVP.
- Mobile builds take the product version; EAS increments the build number automatically.

## Consequences

- Every line on `main` leads to a pull request, an issue and a roadmap milestone.
- Release notes are written automatically from commit messages, so commit titles must be written for users.
- Some ceremony for a single developer, accepted as part of the portfolio's purpose.

## Alternatives considered

- **Changesets:** built for per-package versioning of published libraries; not needed here.
- **semantic-release:** releases on every merge, which gives less control over when prod changes.
- **Manual tags and hand-written changelog:** easy to forget and inconsistent.
