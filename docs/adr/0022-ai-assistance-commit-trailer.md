# ADR-0022: AI assistance commit trailer

- Status: Accepted
- Date: 2026-11-05
- Amends: [ADR-0021](0021-code-review-for-ai-written-code.md) (how the model is named in commits)

## Context

ADR-0021 requires that every commit names the model that wrote the code, so the rule "Claude Opus 5.5 or a more capable model" can be checked later. It used the `Co-Authored-By` trailer. GitHub treats that trailer as co-authorship: the assistant's avatar appears next to every commit and pull request, and the owner's own authorship of the project becomes less visible.

## Decision

- Commits name the model with the trailer **`Assisted-by: <model>`**, for example `Assisted-by: Claude Opus 5.5`.
- `Co-Authored-By` is not used for AI assistance.
- Squash merges keep branch commit messages in the body (repository setting `COMMIT_MESSAGES`), so the trailer reaches `main`.
- The use of AI is stated openly in the README and in ADR-0021.
- Commits made before this decision keep their `Co-Authored-By` trailer; the public history is not rewritten.

## Consequences

- The model behind every commit stays traceable with `git log --grep "Assisted-by"`.
- GitHub shows only the owner as the author.
- `Assisted-by` is a project convention, not a GitHub feature, so tools do not interpret it.

## Alternatives considered

- **Keep `Co-Authored-By`:** recognised by GitHub, but adds the assistant as a visible co-author on every commit.
- **No trailer:** the rule from ADR-0021 could no longer be checked per commit.
