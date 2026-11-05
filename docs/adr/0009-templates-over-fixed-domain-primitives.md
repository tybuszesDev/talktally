# ADR-0009: Templates configure fixed domain primitives

- Status: Accepted
- Date: 2026-11-05

## Context

Different kinds of projects need different structures: a renovation tracks materials and square metres, a developer tracks bugs and pull requests, a salesperson tracks leads and deals. The web app should offer ready-made templates for such cases. At the same time, the AI extraction (ADR-0008) needs a stable, finite set of operation targets, and the data model must stay simple enough to design for DynamoDB (ADR-0006).

## Decision

A small set of **fixed domain primitives**, configured by **declarative, versioned templates**.

### Primitives

- **Project**
- **Work item** with kinds `task`, `issue`, `purchase`, a status and optional due date
- **Resource** with unit, quantity and low-stock threshold, plus a ledger of **movements**
- **Metric** with unit and optional target, plus **metric entries**
- **Entry** (dictation or text) and **change set**
- **Daily plan** with **plan items**
- **Routine** (recurring plan item)

Each primitive can carry **custom attributes** whose definitions (text, number, date, select) come from the template and are validated at runtime with Zod.

### Templates

- Defined in `packages/templates` as TypeScript objects validated by a Zod schema from `packages/domain`. Each has an `id` and a `version`.
- A template contains: enabled modules, custom attribute definitions, seed resources and metrics (for example "Tile adhesive, 25 kg bag"; "Tiles laid, target 40 m²"), routines (for example "Check deliveries" every weekday), vocabulary and synonyms for extraction (for example "klej" → tile adhesive, "worek" → bag), terms for a Transcribe custom vocabulary, and the default dashboard widgets.
- **Creating a project from a template copies** the seeds into the project and records the template ID and version. Later template versions do not change existing projects.
- MVP templates: **Blank** and **Renovation**. Post-MVP: **Software developer**, **Sales**, and user-defined templates ("save project as template").
- If a later template needs a concept that the primitives cannot express (for example a sales pipeline with stages), a new ADR either extends an existing primitive or adds a new one.

## Consequences

- The AI always works against the same operation types; templates only add vocabulary and seed data.
- Adding a template is mostly data, not code.
- Users cannot design arbitrary tables. That is a deliberate limit for the MVP.

## Alternatives considered

- **Fully dynamic schema (user-defined tables and fields, Notion-style):** very flexible, but much harder to build, to store efficiently in DynamoDB, and to target reliably with AI extraction.
- **Hard-coded project types without templates:** simplest, but every new project kind would need code changes in several places.
