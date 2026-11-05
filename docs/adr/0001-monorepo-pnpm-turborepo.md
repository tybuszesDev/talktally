# ADR-0001: Monorepo with pnpm workspaces and Turborepo

- Status: Accepted
- Date: 2026-11-05

## Context

The system has a web app, a mobile app, a later desktop app, several backend Lambda functions, a GraphQL schema shared by all of them, and Terraform code. Types and validation rules must be identical on every side. One person develops everything, and each feature must land as one commit that may touch several parts at once.

## Decision

One repository, managed with **pnpm workspaces** and **Turborepo**, TypeScript everywhere (strict mode, ESM), Node.js 24 LTS.

Layout:

```
apps/
  web/            Vite + React SPA (command center)
  mobile/         Expo (React Native) capture app
  desktop/        Electron shell around apps/web (later)
services/
  api/            AppSync resolver Lambda(s)
  pipeline/       Voice pipeline Lambdas (extraction, apply, plan suggestions)
packages/
  domain/         Zod schemas, domain types, pure domain logic (change set apply, units)
  graphql-schema/ schema.graphql + generated TypeScript types
  client/         Platform-agnostic client: auth, GraphQL operations, query hooks, subscription sync
  templates/      Built-in project templates (versioned, validated by packages/domain)
  config/         Shared tsconfig, ESLint, Prettier and Vitest presets
infra/
  terraform/      bootstrap/, modules/, envs/dev, envs/prod
docs/             Vision, architecture, ADRs, domain, roadmap
```

Rules:

- `packages/*` never import from `apps/*` or `services/*`.
- `packages/domain` and `packages/client` have no DOM, React Native or AWS SDK imports, so every app and service can use them.
- Turborepo runs `lint`, `typecheck`, `test` and `build` with caching, and only for affected workspaces in CI.
- Expo supports pnpm monorepos. If a native module fails to resolve with isolated `node_modules`, switch the repository to `node-linker=hoisted` and record that in a new ADR.

## Consequences

- One commit can change the schema, the resolver, the client and both apps together, which matches the "one feature, one commit" rule.
- Shared Zod schemas give one source of truth for validation on the server, on the web and on mobile.
- Tooling is more complex than a single app: workspace boundaries, build order and Expo's Metro bundler need care.

## Alternatives considered

- **Nx:** more features (generators, project graph UI), but heavier and more opinionated than needed for one developer.
- **npm or Yarn workspaces without Turborepo:** no task caching or affected-only runs, so CI gets slower as the repo grows.
- **Separate repositories:** shared types would need to be published as packages, and a feature would be spread over several commits and repositories.
