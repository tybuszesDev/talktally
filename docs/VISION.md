# Vision

> **TalkTally**: you talk, it tallies. Package scope `@talktally/*`, home at `talktally.tybu.com`.

## One-liner

A voice-first tracker for the projects in your life. At the end of the day you talk to your phone; the system turns what you said into updated tasks, inventory and progress, and shows you a plan for today.

## Problem

Keeping track of progress across several life projects (a renovation, a side project, a sales pipeline) is tedious:

- Forms, spreadsheets and task apps need typing and navigation. At the end of a day on a renovation site nobody wants to fill in tables.
- Information is scattered: what was done, what is blocked, what must be bought, how much material is left.
- Planning the next day means re-reading all of that.

Talking is the lowest-friction input. Structuring is what software is good at.

## Who it is for

- **Primary user: the owner (single user).** One person, several personal projects.
- **Secondary: portfolio visitors.** Recruiters and engineers who log in to a demo account, read the code, the ADRs and the CI history.
- **Not in scope:** teams, shared projects, multi-tenant SaaS billing.

## Core loop

1. **Morning.** Open the phone and see today's plan: items you added, routine items from your project templates, and AI suggestions you accepted.
2. **During or at the end of the day.** Choose a project, tap the mic and dictate a summary in Polish.
3. **Processing.** The system transcribes the audio and extracts structured changes. Confident changes are applied automatically. Uncertain ones become questions.
4. **Review.** The phone shows what changed and asks about what is unclear. You confirm, correct or reject. Every applied change can be undone.
5. **Overview.** On the web (later also desktop) you see each project in depth: tables, inventory, progress, history, the plan, and the templates.

### Example

Project: *Renovation*. Dictation:

> "Zużyłem 4 kleje Atlas, położyłem 3 m² płytek, naprawiłem wczorajszy problem z hydrauliką, muszę kupić silikon sanitarny."

Proposed changes:

| Operation | Details | Confidence | Result |
|---|---|---|---|
| `resource.consume` | Tile adhesive Atlas: −4 bags | high | applied |
| `metric.record` | Tiles laid: +3 m² | high | applied |
| `task.complete` | "Fix plumbing leak" (issue reported yesterday) | high | applied |
| `task.create` (purchase) | "Buy sanitary silicone" | high | applied |
| clarification | "Atlas Plus or Atlas Geoflex?" (two adhesives in inventory) | low | asks the user |

## Roles of the apps

- **Mobile (thin capture tool).** Log in, see and check off today's plan, dictate, follow processing status, answer clarifications, switch the active project. Nothing else.
- **Web (command center).** Projects and their dashboards, template gallery, tables of work items, inventory and metrics, plan management, dictation history, change audit and undo, settings.
- **Desktop (later).** The web app wrapped in Electron. Possible extras: tray icon, global shortcut to start a dictation.

All apps share one account (Amazon Cognito) and see changes in real time (AWS AppSync subscriptions).

## Templates

A project is created from a template. A template defines which modules the project uses (work items, inventory, metrics), seed data, routine plan items, and vocabulary that helps transcription and extraction.

- **Blank** (MVP)
- **Renovation** (MVP): materials inventory, area metrics (m² of tiles, paint), issues, shopping list, routines such as "check deliveries".
- **Software developer** (post-MVP): tasks, bugs, learning goals, metrics such as PRs merged.
- **Sales** (post-MVP): leads and stages, calls, deals, revenue metric.
- **Custom templates** (post-MVP): save an existing project as a template.
- **Start a project by talking** (post-MVP): the user describes their first day of something new ("Today I started learning English, 30 minutes of vocabulary, I want to do it every day"). The app proposes a project with a template draft (metrics such as minutes studied and new words, a daily routine), and the user edits it before it is created.

## Daily plan

- The user owns the plan. AI never changes it without approval.
- One plan per day across all projects. The user sets how much of their attention each project gets (for example Renovation 60%, Learning English 30%, Raking leaves 10%), and the day is arranged according to these shares.
- Sources: items added manually, routine items from templates, AI suggestions (pending until accepted).
- The plan can be edited by voice ("move tiling to tomorrow, add buying silicone"). The voice edit goes through the same extraction pipeline and produces plan operations.
- AI suggests a plan for tomorrow after an evening summary, and in the morning if nothing was suggested yet.

## MVP scope

**In**

- Invite-only sign-up, shared login for web and mobile.
- Projects from the Blank and Renovation templates.
- Work items (task, issue, purchase), resources with a movement ledger, metrics with entries.
- Dictation pipeline: record, upload, transcribe (Polish), extract, review, apply, undo.
- Text input as an alternative to voice (same pipeline without transcription).
- Daily plan: manual items, template routines, AI suggestions with approval, voice edits.
- Real-time sync between web and mobile.
- Offline recording queue on mobile (record without network, upload later).
- Event bus prepared for integrations (no external integrations connected).
- Infrastructure as code, CI/CD for dev and prod, observability, cost alarms.
- Mobile app released on iOS through TestFlight and tested on real devices of different sizes.
- Privacy policy page, data export and in-app account deletion.
- UI in English, in a calm black-and-white style ([DESIGN.md](DESIGN.md)).

**Out (later)**

- Android release. The code is cross-platform from the start; Android is the first step after the MVP.
- Electron desktop app.
- Polish UI and i18n.
- Developer and Sales templates, custom templates.
- External integrations (GitHub, calendars, fitness apps).
- Push notifications.
- Answering clarifications by voice.
- Full offline-first data sync.
- Sharing projects, teams, social login.
- Weekly balance per project and a weekly summary email.
- Daily capacity per weekday (the MVP has one value, set with a slider from 60 to 600 minutes).
- Reports and long-term analytics.
- Live (streaming) transcription.

## Non-functional requirements

- **Cost:** target under 10 USD per month for one active user. AWS Budgets alarm at 10 USD.
- **Security:** public repository with no secrets. Least-privilege IAM. GitHub Actions authenticate to AWS with OIDC. Invite-only sign-up and per-user quotas, so strangers cannot spend the AI and transcription budget.
- **Privacy and retention:** audio moves to cold archive storage after 30 days and is deleted only when the user deletes the entry. Transcripts and structured data are kept.
- **Latency:** a typical 2–3 minute dictation produces a proposal in under 2 minutes.
- **Quality:** every feature ships with tests. CI blocks merges on failures.
- **Design:** the interface is quiet, monochrome and free of decoration, so the user can focus. Details in [DESIGN.md](DESIGN.md).

## Portfolio success criteria

- Live demo URL on the owner's domain, with a demo account.
- README with an architecture diagram, a short video and links to the ADRs.
- Green CI, visible test coverage, a clean history of one Conventional Commit per feature.
- A short cost report: what the system costs per month and why.

## Constraints and context

- AWS account with roughly 100 USD of credits.
- Domain `tybu.com` registered at Hostinger. The app lives on the subdomain `talktally.tybu.com`.
- Apple Developer Program membership (99 USD per year) for TestFlight distribution.
- Dictation language: Polish. UI language: English.

## Glossary

- **Project:** a long-running effort (for example a renovation), created from a template.
- **Template:** a versioned definition of modules, seed data, routines and vocabulary for a kind of project.
- **Work item:** a unit of work in a project. Kinds: task, issue, purchase.
- **Resource:** something countable the project has (material, tool, budget), with a unit and a quantity.
- **Movement:** one change of a resource quantity (consumed, restocked, adjusted).
- **Metric:** a measured progress value with a unit and an optional target (for example 40 m² of tiles).
- **Entry:** one dictation or text note, with its audio, transcript and processing status.
- **Change set:** the list of operations extracted from one entry, with confidence values and its review state.
- **Operation:** one atomic change inside a change set (for example `resource.consume`).
- **Clarification:** a question the system asks when an operation is uncertain.
- **Daily plan:** the list of plan items for one date.
- **Routine:** a recurring plan item that comes from a template.
