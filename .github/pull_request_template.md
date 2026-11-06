Closes #

## Summary

<!-- What changed and why. The title becomes the squash commit on main: write it as a Conventional Commit for release notes. -->

## Checks run locally

<!-- Commands run and anything verified by hand. -->

## Definition of Done

<!-- Required: the "PR checklist" check fails until every box in this section is ticked. Rules: docs/WORKING-AGREEMENT.md -->

- [ ] Every acceptance criterion in the issue is met and checked
- [ ] The change stays inside the issue; follow-up work is filed as new issues and every `TODO` has an issue number
- [ ] Tests from ADR-0011 are included (a bug fix starts with a failing test) and coverage thresholds hold
- [ ] Documentation that describes the changed behaviour is updated; a new decision has its ADR
- [ ] The title is a Conventional Commit written for release notes

## Manual test

<!-- Required: tick exactly one. -->

- [ ] Manually tested (on `dev` from M1, locally before that). What was checked:
- [ ] No user-visible change; verified by CI (and smoke tests on `dev` from M1)

## Area checks

<!-- Optional: keep and tick the rows for the areas this change touches, delete the rest. Details: "Additional checks by area" in docs/WORKING-AGREEMENT.md -->

- [ ] UI: screenshots of a small and a large screen; DESIGN checklist; no serious or critical axe violations; `testID`s and accessibility labels; empty, loading, error and offline states
- [ ] GraphQL schema: expand → migrate → contract; schema diff check passes; generated code is up to date
- [ ] DynamoDB data: new access patterns in DOMAIN; `schemaVersion` raised for changed shapes; idempotent migrations with a dry run
- [ ] Auth, IAM, resolvers, subscriptions: cross-user authorization tests; `/security-review`; SECURITY-MODEL updated when needed
- [ ] Infrastructure: Terraform plan and Infracost difference reviewed; a new paid service has an ADR; tags present
- [ ] Backend function or pipeline step: structured logs with the correlation ID and no user content; a metric or alarm for each new failure mode; retries and idempotency considered
- [ ] AI prompt or model: prompt version raised; evaluation report in `docs/evals/`, not worse than the previous one by more than 2 points in precision or recall
- [ ] Mobile: runs on the smallest and the largest supported iPhone simulator; a new native module means a new development build; permission texts are correct
- [ ] New dependency: why it is needed, alternatives considered, license compatible with MIT
