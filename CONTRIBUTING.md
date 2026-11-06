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
  - **CI:** lint, typecheck, test and build of the affected workspaces, root files and formatting;
  - **PR title:** commitlint on the title;
  - **PR checklist:** fails while a Definition of Done box is unticked or not exactly one manual-test box is ticked.
- CodeRabbit reviews each pull request when it is opened, and again after fixes for Critical or Major findings; every review thread must be resolved before merge. Review rules, CodeRabbit fixes and commands: [docs/CODE-REVIEW.md](docs/CODE-REVIEW.md).
- `main` accepts only squash merges of pull requests that are up to date with it; force pushes and deletion are blocked, also for the owner.
- Only the owner merges.

## Dependencies

- Versions shared by several workspaces live in the pnpm catalog in `pnpm-workspace.yaml`.
- New package versions are installed only after they are 3 days old (`minimumReleaseAge`).
- Dependency install scripts run only when approved in `allowBuilds`.
- A new dependency needs a reason, the alternatives considered, and a license compatible with MIT.
