# ADR-0012: Git workflow and CI/CD

- Status: Accepted
- Date: 2026-11-05

## Context

The repository is public on GitHub and is part of a portfolio, so its history is read by other people. Each feature must be one commit with tests. Deployments to dev and prod must be automatic and safe. No AWS credentials may be stored in GitHub.

## Decision

### Branching and commits

- **Trunk-based:** `main` is protected and always deployable.
- One short-lived branch per feature: `feat/<scope>-<short-description>` (also `fix/`, `chore/`, `docs/`).
- Changes reach `main` only through pull requests with passing CI, merged with **squash merge**. Result: **one feature = one Conventional Commit on `main`**.
- A feature is the smallest vertical slice that delivers user-visible value or one complete infrastructure capability, together with its tests and documentation updates.
- **Conventional Commits** with types `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `build`, `perf`, and scopes equal to workspace names (`web`, `mobile`, `api`, `pipeline`, `domain`, `client`, `templates`, `infra`, ...).
- Local hooks with **lefthook**: format and lint staged files on `pre-commit`, `commitlint` on `commit-msg`, typecheck and tests of affected workspaces on `pre-push`.

### CI/CD with GitHub Actions

| Trigger | Jobs |
|---|---|
| Pull request | Install (pnpm cache) → lint, typecheck, test, build (affected) → codegen check → Terraform fmt, validate, tflint, trivy → `terraform plan` for dev posted as a comment → secret scan (gitleaks) |
| Merge to `main` | Build artifacts → `terraform apply` dev → upload web app and invalidate CloudFront → Playwright smoke tests |
| Release tag `v*` or manual run | Same as above for prod, behind a GitHub Environment `prod` with required approval |
| Mobile release (post-MVP) | EAS Build and EAS Update on tag |

Rules:

- AWS access through **OIDC** roles only (ADR-0003). The prod role trusts only the `prod` GitHub Environment.
- Third-party actions are pinned by commit SHA.
- Dependency updates through Renovate (or Dependabot), grouped weekly.
- Because the repository is public: gitleaks runs in CI and as a pre-commit hook, `.env*` files are ignored, and no AWS account IDs or emails appear in committed config.

## Consequences

- The `main` history reads like a changelog; release notes can be generated from it.
- Squash merge loses intermediate commits of a branch. Accepted, since the goal is one commit per feature.
- Prod deployments need a manual approval click, which is deliberate.

## Alternatives considered

- **GitFlow:** long-lived `develop` and release branches add ceremony with no benefit for one developer.
- **Rebase merge of every commit:** preserves detail but breaks the one-commit-per-feature rule.
- **AWS CodePipeline and CodeBuild:** more AWS in the stack, but GitHub Actions is free for public repositories, integrates with pull requests, and is the more common skill.
