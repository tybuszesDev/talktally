# TalkTally

> You talk, it tallies.

A voice-first tracker for the projects in your life. At the end of the day you talk to your phone; TalkTally turns what you said into updated tasks, inventory and progress, and shows you a plan for today.

> **Status:** early development, milestone M0 Foundation. There is no usable app yet. Progress is tracked on the [project board](https://github.com/users/tybuszesDev/projects/1) and in the [roadmap](docs/ROADMAP.md).

## Why

Keeping track of a renovation, a side project or a sales pipeline means forms, spreadsheets and task apps, and nobody wants to fill in tables at the end of a day on a building site. Talking is the lowest-friction input; structuring is what software is good at.

Example dictation for a *Renovation* project (in Polish):

> "Zużyłem 4 kleje Atlas, położyłem 3 m² płytek, naprawiłem wczorajszy problem z hydrauliką, muszę kupić silikon sanitarny."

TalkTally proposes: tile adhesive −4 bags, tiles laid +3 m², "Fix plumbing leak" done, new purchase "Buy sanitary silicone". Confident changes are applied, unclear ones become questions ("Atlas Plus or Atlas Geoflex?"), and every change can be undone.

## How it works

- **Mobile app** (Expo, iOS first): today's plan, dictation, review of proposed changes.
- **Web app** (Vite + React): projects, tables, inventory, metrics, history and undo.
- **Backend** (serverless AWS, Terraform): Cognito, AppSync GraphQL with live subscriptions, DynamoDB, a Step Functions pipeline with Amazon Transcribe and Claude on Amazon Bedrock.
- **AI proposes, code applies:** the model returns a validated change set; deterministic, tested code applies it ([ADR-0008](docs/adr/0008-ai-proposes-changes-code-applies-them.md)).
- Running cost target: under 10 USD per month for one active user ([ADR-0002](docs/adr/0002-serverless-aws-and-cost-guardrails.md)).

## Documentation

| Document | Content |
|---|---|
| [Vision](docs/VISION.md) | Problem, users, core loop, scope |
| [Architecture](docs/ARCHITECTURE.md) | System context, main flows, environments |
| [Domain](docs/DOMAIN.md) | Domain model and access patterns |
| [Design](docs/DESIGN.md) | UI principles, tokens, accessibility |
| [Security model](docs/SECURITY-MODEL.md) | Assets, threats and mitigations, privacy |
| [Roadmap](docs/ROADMAP.md) | Milestones and features |
| [Working agreement](docs/WORKING-AGREEMENT.md) | Definition of Ready and Done, checks by area |
| [Code review](docs/CODE-REVIEW.md) | Review layers, CodeRabbit rules, merging |
| [Architecture decisions](docs/adr/README.md) | 23 ADRs |

## How this project is built

This is a portfolio project built by one developer with an AI coding assistant:

- Most code is written by [Claude Code](https://claude.com/claude-code) (Claude Opus 5.5 or a more capable model) under the owner's supervision.
- Every change to a code file is approved by the owner one by one; automatic acceptance of edits is not used for code.
- Each commit names the model in an `Assisted-by` trailer ([ADR-0022](docs/adr/0022-ai-assistance-commit-trailer.md)).
- Planning came first: vision, ADRs, domain model and roadmap were written and accepted before any code.

## Code review

Because most code is written by an AI assistant, every pull request is reviewed in three layers ([ADR-0021](docs/adr/0021-code-review-for-ai-written-code.md)):

1. **CI tools:** lint, typecheck, tests and build, architecture rules and unused code, a Conventional Commit title, and a description that follows the Definition of Done template.
2. **[CodeRabbit](https://coderabbit.ai)**, an independent AI reviewer from another vendor. It reviews each pull request when it is opened, and again after fixes for critical or major findings, and is tuned to report real problems only. Every finding is fixed or answered, and open review threads block the merge. The owner can let CodeRabbit fix a small finding itself; it never merges and its other code-writing features are off ([ADR-0023](docs/adr/0023-coderabbit-review-cadence-and-fixes.md)).
3. **The owner** reads the full diff and is the only one who merges.

Details, including how findings are handled and the CodeRabbit commands: [docs/CODE-REVIEW.md](docs/CODE-REVIEW.md).

## Getting started

See [CONTRIBUTING.md](CONTRIBUTING.md) for prerequisites, setup and the local workflow.

## Security

Please report vulnerabilities privately, as described in [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE) © 2026 Łukasz Tybuszewski
