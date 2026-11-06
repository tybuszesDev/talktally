# ADR-0025: release-please with a GitHub App token

- Status: Accepted
- Date: 2026-11-06
- Amends: [ADR-0016](0016-release-management-and-work-traceability.md) (how release-please authenticates and how releases are named)

## Context

ADR-0016 chooses release-please: it keeps an open release pull request with the next version and the generated `CHANGELOG.md`, and merging it creates the tag `vX.Y.Z` and a GitHub Release. ADR-0012 starts the prod deployment from that tag.

By default the release-please action uses the workflow's `GITHUB_TOKEN` ([release-please-action README, "Other Actions on Release Please PRs"](https://github.com/googleapis/release-please-action/tree/v5.0.0#other-actions-on-release-please-prs)). Events caused by that token start no workflow runs, with one exception ([GitHub docs, "When GITHUB_TOKEN triggers workflow runs"](https://docs.github.com/en/actions/concepts/security/github_token)): when it opens or updates a pull request, the runs wait until someone with write access approves them. The `main` ruleset requires `CI`, `PR title`, `Secret scan` and CodeQL, so the owner would have to approve the runs after every update of the release pull request. A tag created with that token starts no workflow at all, so it would not start the prod deployment. The repository setting that lets GitHub Actions create pull requests is also off.

release-please's defaults also clash with the repository rules (release-please 17.6.0, the version in release-please-action v5.0.0):

- The default release pull request title is `chore(main): release <version>`. commitlint allows only workspace names and `infra` as scopes, so the required `PR title` check fails.
- The default tag of a Node package is `<package name>-v<version>`, not `vX.Y.Z`.
- A package that was never released starts at `1.0.0`, but ADR-0016 keeps the product on `0.x` until the MVP.

## Decision

- release-please runs with a short-lived installation token of a **GitHub App** owned by the owner's account. The App has the repository permissions Contents, Issues and Pull requests (read and write), no webhook, and is installed only on this repository. The workflow creates the token with `actions/create-github-app-token` and narrows it to those three permissions.
- Events caused by the App start workflows, so every required check runs on the release pull request, and a release tag can start the prod deployment. The release pull request is authored by a bot account, so the `PR checklist` check skips it, as it already does for bot pull requests.
- The App's client ID is an environment variable and its private key an environment secret of a GitHub environment **`release`**. Only the `main` branch may use the environment. The job uses it with `deployment: false`, so no deployment records are created. Workflows on other branches cannot read the key.
- release-please configuration (`release-please-config.json`): one root package of type `node`, so the root `package.json` holds the product version. Tags are `vX.Y.Z` (`include-component-in-tag: false`). The release pull request title is `chore: release X.Y.Z`. The first release is `0.1.0` (`initial-version`). A breaking change before `1.0.0` raises the minor version (`bump-minor-pre-major`). The release pull request is updated after every push to `main` (`always-update`), because the ruleset requires branches to be up to date.
- The changelog uses release-please's default sections: `feat`, `fix`, `perf` and `revert` appear; `docs`, `chore`, `ci`, `refactor`, `test` and `build` are hidden. Pushes with only hidden types open no release pull request.

## Consequences

- One more owner action: creating the App and the `release` environment before the first release workflow runs. The private key does not expire; it is rotated by generating a new key in the App settings and deleting the old one.
- No token is tied to the owner's personal account, and no token expires and silently stops releases.
- Release pull requests pass the same checks as every other pull request, and CodeRabbit may review them.
- The first release pull request appears after the first `feat` or `fix` commit, not when this workflow is added.

## Alternatives considered

- **Fine-grained personal access token:** expires after at most a year, acts as the owner (the `PR checklist` check would then fail on the release pull request), and is tied to the personal account.
- **`GITHUB_TOKEN` with runs approved by hand:** no App, but GitHub Actions must be allowed to create pull requests, the owner approves the check runs after every update of the release pull request, and the tag would not start the prod deployment.
- **Repository secret instead of an environment secret:** simpler, but a workflow changed on any branch could read the key.
