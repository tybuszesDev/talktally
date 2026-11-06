# ADR-0024: Documentation first and one session per feature

- Status: Accepted
- Date: 2026-11-06
- Amends: [ADR-0021](0021-code-review-for-ai-written-code.md) (authoring rules for AI-written code)

## Context

Claude's knowledge of libraries comes from training data with a cutoff, while this repository uses recent major versions (Expo SDK 58, React 19.3, ESLint 10, TypeScript 6, pnpm 12). An API written from memory can belong to an older version, or not exist at all. While setting up the repository this happened in small ways: configuration options that behaved differently from what was assumed were only caught by running the tool or reading its documentation.

A long conversation has a second cost. When the context fills up, older parts are compressed into a summary, details are lost, and mistakes become more likely. Everything a feature needs is already written down in the repository, the issue and the project board, so a long conversation adds little that cannot be recovered.

## Decision

**Order of sources.** When Claude needs to know how something works, it uses, in this order:

1. This repository: `docs/`, the ADRs, CLAUDE.md and the existing code.
2. The official documentation of the tool, for the version the repository uses (from `package.json`, the lockfile or the workflow pin). Claude reads it through the **Context7** MCP server, which serves version-specific library documentation, and falls back to the tool's documentation site when Context7 does not have the library or the version.
3. The tool's own code and type definitions in `node_modules`.

Other sources (blog posts, forums, general web search) are used only when these do not answer the question, and Claude says so. APIs and configuration options are not written from memory; when a change relies on a tool's documentation, the pull request links the page.

**One session per feature.** Each feature starts in a new Claude Code session with an empty context, after the previous pull request is merged. Before a session ends, follow-up work is filed as issues, local facts go to Claude's memory, and the branch is pushed. If the context is compressed in the middle of a feature, Claude re-reads the issue, the working tree state including untracked files (`git status --short`) and the branch diff (`git diff origin/main`) before continuing.

## Consequences

- Code matches the versions actually installed, and reviewers can check the linked documentation.
- Looking things up takes longer than writing from memory.
- Context7 is a Claude Code plugin in the owner's user settings, authorized once with the owner's Context7 account; it is not part of the repository, so other contributors use the documentation sites.
- Each session starts by reading CLAUDE.md, the issue and the relevant docs, so state that lives only in a conversation is lost; the repository, the board and the memory must stay complete.

## Alternatives considered

- **Technical restriction of web access** (WebFetch allowed only for documentation domains, WebSearch always asking): stronger, but adds permission prompts; the owner chose a written rule.
- **Context7 as the only source of documentation:** it does not cover every tool and version, so the documentation sites stay the fallback.
- **Reset only when mistakes appear:** mistakes from a degraded context are hard to notice in time.
