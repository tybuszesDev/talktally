# ADR-0003: Terraform for all infrastructure

- Status: Accepted
- Date: 2026-11-05

## Context

All AWS resources must be reproducible, reviewable in pull requests and deployable from CI. The repository is public, so no state, secrets or credentials may be committed. There are two environments: `dev` and `prod`.

## Decision

**Terraform (>= 1.10)** with the AWS provider, versions pinned in `.terraform.lock.hcl`.

Structure:

```
infra/terraform/
  bootstrap/   Applied once, locally: state bucket, GitHub OIDC provider and IAM roles, budgets
  modules/     auth, api, data, storage, pipeline, events, web-hosting, dns, observability
  envs/
    dev/       Root module for dev (own state key)
    prod/      Root module for prod (own state key)
```

Rules:

- **State:** S3 backend with native locking (`use_lockfile = true`), versioning and encryption enabled. No DynamoDB lock table.
- **Environments:** one AWS account, resources prefixed `talktally-<env>-`. Separate state per environment.
- **CI access:** GitHub Actions assume IAM roles through OIDC. A read-only `plan` role for pull requests, a `deploy` role restricted to the `main` branch and the `prod` GitHub Environment. No long-lived access keys anywhere.
- **Lambda artifacts:** CI builds each function with esbuild into a zip; Terraform deploys it with `source_code_hash`, so code changes trigger updates.
- **Configuration and secrets:** non-secret values in committed `*.tfvars`; secret values in SSM Parameter Store (SecureString), created outside Terraform state or referenced by name only.
- **DNS:** the domain `tybu.com` stays registered at Hostinger. The subdomain `talktally.tybu.com` is delegated to a Route 53 hosted zone by adding its NS records in the Hostinger DNS zone editor (one manual step). Terraform then manages all records and certificate validation inside that zone.
  - The hosted zone is created in `bootstrap/`, not in an environment, because the NS records at Hostinger must never change.
  - Host names:

    | Environment | Web app | GraphQL API |
    |---|---|---|
    | prod | `talktally.tybu.com` | `api.talktally.tybu.com` |
    | dev | `dev.talktally.tybu.com` | `api.dev.talktally.tybu.com` |
- **Quality checks:** `terraform fmt -check`, `terraform validate`, `tflint`, `trivy config` on every pull request; `terraform test` with mocked providers for modules.

## Consequences

- Infrastructure is reviewed like code; a pull request shows the `terraform plan` for dev.
- The bootstrap stack is the only manual step; it is documented in `infra/terraform/bootstrap/README.md`.
- One account is simpler, but dev and prod share account-level limits and IAM boundary mistakes could affect both. Strict naming and per-environment IAM policies reduce this risk.

## Alternatives considered

- **AWS CDK or SST:** good TypeScript integration, but the goal is to practise Terraform, which is the more common requirement in job offers.
- **AWS SAM / Serverless Framework:** focused on Lambda; weaker for Cognito, CloudFront, AppSync and DNS in one tool.
- **Terraform workspaces instead of directories:** less explicit; directories make differences between environments visible.
- **Separate AWS accounts per environment (AWS Organizations):** better isolation, worth showing in a portfolio, but more setup. Can be added later with a new ADR.
