# Working agreement

- Status: Accepted 2026-11-05
- Related: [ROADMAP](ROADMAP.md), [ADR-0011](adr/0011-testing-strategy-and-quality-gates.md) (tests), [ADR-0012](adr/0012-git-workflow-and-ci-cd.md) and [ADR-0019](adr/0019-feature-size-and-splitting.md) (git), [ADR-0016](adr/0016-release-management-and-work-traceability.md) (issues and releases), [ADR-0017](adr/0017-code-quality-security-and-cost-checks.md) (CI checks), [ADR-0020](adr/0020-schema-evolution-and-backward-compatibility.md) (schema evolution), [ADR-0021](adr/0021-code-review-for-ai-written-code.md) (code review)

How a piece of work moves from an idea to production, and what "ready" and "done" mean.

## Flow on the project board

| Column | The card is here when |
|---|---|
| Backlog | The issue exists |
| Ready | The [Definition of Ready](#definition-of-ready) is met |
| In progress | A branch for the issue exists |
| In review | A pull request is open and CI is green |
| Done | The [Definition of Done](#definition-of-done-feature) is met: merged and deployed |

## Authoring rules

Most code is written by Claude Code under the owner's supervision ([ADR-0021](adr/0021-code-review-for-ai-written-code.md)).

1. Code is written with Claude Opus 5.5 or a more capable model. The model is named in the `Co-Authored-By` commit trailer.
2. Every change to a code file is approved by the owner one by one in Claude Code. Automatic acceptance of edits is not used for code.
3. Only the owner merges pull requests.

## Definition of Ready

An issue moves from Backlog to Ready when:

1. The goal and the acceptance criteria are concrete and testable.
2. Every feature it depends on is Done.
3. The owner actions it needs are done ([ROADMAP](ROADMAP.md#owner-actions)).
4. It fits in about two days of work, or it is split into sub-issues ([ADR-0019](adr/0019-feature-size-and-splitting.md)).
5. For UI work: the screens and their states (empty, loading, error, offline) are listed in the issue.
6. Open questions are answered. If the work needs a new decision, the ADR is written first.

## Definition of Done (feature)

A feature, or one part of a split feature, is Done when all of the following are true.

**Scope**

1. Every acceptance criterion in the issue is checked.
2. The change stays inside the issue. Follow-up work is filed as new issues; no `TODO` without an issue number.

**Quality**

3. Tests from [ADR-0011](adr/0011-testing-strategy-and-quality-gates.md) are in the same pull request. A bug fix starts with a failing test. Coverage thresholds hold.
4. All CI checks are green ([ADR-0017](adr/0017-code-quality-security-and-cost-checks.md)).
5. The pull request is reviewed in three layers ([ADR-0021](adr/0021-code-review-for-ai-written-code.md)): CI tools, CodeRabbit, and the owner reading the full diff. Every finding is fixed or answered in the pull request.

**Product**

6. The change is deployed to `dev` (from M1). Smoke tests pass there.
7. **Manual test is required.** The pull request template has two checkboxes, and exactly one must be ticked:
   - "Manually tested on `dev`", followed by what was checked;
   - "No user-visible change; verified by CI and smoke tests".

   A CI check blocks the merge until one of them and every Definition of Done box are ticked.

**Documentation and history**

8. Documentation that describes the changed behaviour is updated. A new decision has its ADR.
9. The squash commit title is a Conventional Commit written for release notes. The pull request follows the template and contains `Closes #<issue>`.
10. The issue is closed by the merge and the card is in Done.

## Additional checks by area

Apply each row whose area the change touches.

| Area | Additional checks |
|---|---|
| **UI (web or mobile)** | Screenshots of a small and a large screen in the pull request; [DESIGN](DESIGN.md) checklist; no serious or critical axe violations; `testID` and accessibility labels; empty, loading, error and offline states |
| **GraphQL schema** | Expand → migrate → contract ([ADR-0020](adr/0020-schema-evolution-and-backward-compatibility.md)): within a release the schema only grows; removal only after deprecation and a raised `minimumClientVersion`; the schema diff check passes. Generated code is up to date |
| **DynamoDB data** | New access patterns are added to [DOMAIN](DOMAIN.md). Changed item shapes raise `schemaVersion`, old versions stay readable, and migrations are idempotent with a dry run ([ADR-0020](adr/0020-schema-evolution-and-backward-compatibility.md)) |
| **Auth, IAM, resolvers, subscriptions** | Cross-user authorization tests; `/security-review`; [SECURITY-MODEL](SECURITY-MODEL.md) updated when a threat or control changes |
| **Infrastructure** | Terraform plan reviewed; Infracost difference reviewed; a new paid service requires an ADR; tags present; apply succeeded |
| **Backend function or pipeline step** | Structured logs with the correlation ID and no user content; a metric or alarm for each new failure mode; retries and idempotency considered |
| **AI prompt or model** | Prompt version increased; evaluation set run; report added to `docs/evals/`. The new version may not be worse than the previous report by more than 2 percentage points in **precision** (share of proposed changes that are correct) or **recall** (share of expected changes that were found) |
| **Mobile** | Runs on the smallest and the largest supported iPhone simulator; a new native module means a new development build; permission texts are correct |
| **New dependency** | The pull request explains why it is needed and what alternatives were considered; its license is compatible with MIT |

## Definition of Done (milestone)

1. Every issue of the milestone is Done, or moved to another milestone with a reason.
2. The release pull request is reviewed: the changelog reads well for users. Merging it creates the tag and the GitHub Release.
3. From M6: prod is deployed after approval, and smoke tests pass on prod.
4. From M2: a TestFlight build of the release is installed and checked on the owner's iPhone.
5. Actual AWS cost compared with the estimate in [ADR-0002](adr/0002-serverless-aws-and-cost-guardrails.md) and noted in the release notes.
6. README and ROADMAP reflect the new state; the demo still works.
7. A short retrospective (what worked, what to change) is added to the release notes.

## Pull request checklist

The pull request template created in F-04 mirrors the feature Definition of Done, contains the two manual-test checkboxes, and lists the area checks as optional items. A CI check reads the pull request description and fails while a required box is unticked.
