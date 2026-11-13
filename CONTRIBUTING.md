# Contributing

TalkTally is a personal portfolio project.

- **Issues are welcome:** bug reports, questions and suggestions.
- **Pull requests from other people are not accepted for now.** The rest of this guide describes the owner's own workflow, so anyone can see how changes are made.

Security problems: see [SECURITY.md](SECURITY.md), not public issues.

## Prerequisites

- macOS (iOS development needs Xcode).
- **Node.js 24**, as pinned in `.node-version` (for example with nvm: `nvm install && nvm use`).
- **pnpm 12.16.1**, pinned in `packageManager`: run `corepack enable` once.
- **gitleaks** for the pre-commit secret scan: `brew install gitleaks`.
- For the mobile app: **Xcode** with an iOS simulator, and the **Xcode Command Line Tools** (`xcode-select --install`).
- For infrastructure work only: **Terraform** from HashiCorp's tap: `brew install hashicorp/tap/terraform` (needs the Command Line Tools).
- For infrastructure work only: the **AWS CLI 2.32.0 or later** from the [official macOS installer](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html). Sign in with `aws login --profile talktally-admin` and `export AWS_PROFILE=talktally-admin` ([ADR-0026](docs/adr/0026-admin-access-with-iam-user-and-aws-login.md)). The one-time setup is in [infra/terraform/bootstrap/README.md](infra/terraform/bootstrap/README.md).
- Keep the clone **outside iCloud-synced folders** such as Desktop or Documents: iCloud adds file attributes that break Xcode code signing.

## Setup

```sh
git clone https://github.com/tybuszesDev/talktally.git
cd talktally
pnpm install   # installs dependencies and the git hooks
```

## Commands

| Command | What it does |
|---|---|
| `pnpm lint` | ESLint in every workspace, root files, and `prettier --check` |
| `pnpm format` | Formats all files with Prettier |
| `pnpm typecheck` | TypeScript in every workspace |
| `pnpm test` | Unit tests |
| `pnpm build` | Web build and iOS bundle |
| `pnpm check:architecture` | Import rules from ADR-0001 with dependency-cruiser ([dependency-cruiser.config.js](dependency-cruiser.config.js)) |
| `pnpm check:unused` | Unused files, exports and dependencies with knip ([knip.config.js](knip.config.js)) |
| `pnpm --filter @talktally/web dev` | Web app at http://localhost:5173 |
| `pnpm --filter @talktally/mobile ios` | Builds the development client and runs it on the iPhone 17 simulator (`ios:small`, `ios:large` for other sizes) |

## Git hooks

Installed by lefthook during `pnpm install`:

- **pre-commit:** gitleaks scans the staged changes, then ESLint (`--fix`), Prettier and `terraform fmt` fix the staged files and stage them again.
- **commit-msg:** commitlint checks the Conventional Commits format.
- **pre-push:** typecheck and tests of the workspaces affected by the branch.

Formatting happens only in the hook and in CI. No editor setup is needed.

## Branches and commits

- Every change starts from a GitHub issue and goes through a pull request; `main` is never committed to directly.
- Branch name: `<type>/<issue>-<short-description>`, for example `feat/12-entry-upload`.
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/):
  - types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `build`, `perf`;
  - optional scope: a workspace folder name (`web`, `mobile`, `domain`, `config`, ...) or `infra`;
  - AI-assisted commits end with a trailer naming the model, for example `Assisted-by: Claude Opus 5.5` ([ADR-0022](docs/adr/0022-ai-assistance-commit-trailer.md)).
- Commit and push the branch at least once per working day. A feature larger than about two days is split into several pull requests ([ADR-0019](docs/adr/0019-feature-size-and-splitting.md)).

## Pull requests

- The title is the Conventional Commit that lands on `main` (pull requests are squash-merged), written for release notes.
- The description follows the [pull request template](.github/pull_request_template.md): `Closes #<issue>`, summary, checks run, the Definition of Done checklist, exactly one manual-test box, and the area checks that apply ([docs/WORKING-AGREEMENT.md](docs/WORKING-AGREEMENT.md)).
- Required checks on `main` (ruleset in [.github/rulesets/main.json](.github/rulesets/main.json)):
  - **CI:** lint, typecheck, test and build of the affected workspaces, root files and formatting, import rules (dependency-cruiser) and unused code (knip);
  - **Secret scan:** gitleaks on the commits of the pull request;
  - **PR title:** commitlint on the title;
  - **PR checklist:** fails while a Definition of Done box is unticked or not exactly one manual-test box is ticked;
  - **CodeQL results** (code scanning merge protection, not a status check): the analysis must have run, and new high or critical security alerts or error-level alerts block the merge. Alerts are in the [Security tab](https://github.com/tybuszesDev/talktally/security/code-scanning).
- CodeRabbit reviews each pull request when it is opened, and again after fixes for Critical or Major findings; every review thread must be resolved before merge. Review rules, CodeRabbit fixes and commands: [docs/CODE-REVIEW.md](docs/CODE-REVIEW.md).
- `main` accepts only squash merges of pull requests that are up to date with it; force pushes and deletion are blocked, also for the owner.
- Only the owner merges.

## Releases

[release-please](https://github.com/googleapis/release-please) keeps one release pull request open, titled `chore: release X.Y.Z`. It contains the next product version and the new `CHANGELOG.md` entry ([ADR-0016](docs/adr/0016-release-management-and-work-traceability.md), [ADR-0025](docs/adr/0025-release-please-with-a-github-app-token.md)). The workflow is [.github/workflows/release.yml](.github/workflows/release.yml); the settings are in [release-please-config.json](release-please-config.json) and [.release-please-manifest.json](.release-please-manifest.json).

- **Version:** one for the whole product, in the root `package.json`. The first release is `0.1.0`. Before `1.0.0`, `feat` raises the minor version, `fix` the patch version, and a breaking change only the minor version.
- **Changelog:** built from the squash commits on `main`. `feat`, `fix` and `perf` commits appear in it; `docs`, `chore`, `ci`, `refactor`, `test` and `build` do not. Pushes with only those types open no release pull request.
- **Releasing:** review the release pull request like any other: the changelog must read well for users. Squash-merge it; release-please then creates the tag `vX.Y.Z` and the GitHub Release.
- **Version 1.0.0:** put the line `Release-As: 1.0.0` in the body of the squash commit of the last MVP pull request (in a commit message on the branch, or in the merge dialog). release-please then proposes `1.0.0`.

### GitHub App and `release` environment

release-please uses a token of a GitHub App, so the checks run on the release pull request and the tags can start later workflows. One-time setup by the owner:

1. Register the App on the personal account. This [prefilled form](https://github.com/settings/apps/new?name=talktally-release&description=release-please%20for%20tybuszesDev%2Ftalktally&url=https://github.com/tybuszesDev/talktally&public=false&contents=write&issues=write&pull_requests=write) selects the permissions Contents, Issues and Pull requests (Read and write), no webhook, and "Only on this account". If the name is taken, choose another one. Click **Create GitHub App**.
2. On the App page, copy the **Client ID**. Under **Private keys**, click **Generate a private key**; a `.pem` file downloads.
3. **Install App** on the account, with **Only select repositories** → `talktally`.
4. In the repository, open **Settings → Environments → New environment** and name it `release`. Under **Deployment branches and tags**, choose **Selected branches and tags** and add `main`.
5. In the `release` environment, add the variable `RELEASE_APP_CLIENT_ID` (the Client ID) and the secret `RELEASE_APP_PRIVATE_KEY` (the whole content of the `.pem` file).
6. Delete the `.pem` file.

To rotate the key: generate a new private key, replace the secret, then delete the old key on the App page.

## Dependencies

- Versions shared by several workspaces live in the pnpm catalog in `pnpm-workspace.yaml`.
- New package versions are installed only after they are 3 days old (`minimumReleaseAge`).
- Dependency install scripts run only when approved in `allowBuilds`.
- A new dependency needs a reason, the alternatives considered, and a license compatible with MIT.

### Updates with Renovate

The [Mend Renovate app](https://github.com/apps/renovate) opens the update pull requests; the configuration is [renovate.json](renovate.json).

- **Schedule:** Monday mornings (before 08:00, Europe/Warsaw), only for versions at least 3 days old. Security updates come right away.
- **Groups:** one pull request each for minor and patch updates of `web`, `mobile`, `tooling` (root, `packages/*`, the pnpm catalog, Node.js) and GitHub Actions (pinned by digest); a weekly lock file maintenance; every major update on its own.
- **Expo SDK:** `expo`, `expo-*`, `react`, `react-dom`, `react-native` and their types wait for approval in the Dependency Dashboard issue, because the SDK decides their versions. Upgrade them with `expo install --fix`.
- **gitleaks image:** GHCR gives no release dates, so Renovate cannot check its age. The update waits for approval in the Dependency Dashboard. Approve it once the new digest was published at least 3 days ago: an old release can get a newly pushed digest, so check the digest itself on the [GHCR versions page](https://github.com/gitleaks/gitleaks/pkgs/container/gitleaks/versions?filters%5Bversion_type%5D=tagged), not only the release date. After the merge, run `brew upgrade gitleaks` for the pre-commit hook.
- **TypeScript** stays below 7 until typescript-eslint supports it.
- Titles are `chore: update ...` without a scope. The `PR checklist` check skips bot pull requests; the other checks and CodeRabbit run as usual.
- A "Configure Renovate" onboarding pull request is not needed: close it without merging.
