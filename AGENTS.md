# Agent Instructions

## Project Overview

**reve_ai** - Ruby gem wrapper for the Reve image generation API (aimlapi.com)

- **Type**: Ruby Gem (library)
- **Ruby**: >= 3.0
- **Testing**: Minitest + WebMock
- **Task Tracking**: Beads (`bd`)

## Quick Start

```bash
bundle install           # Install dependencies
bundle exec rake test    # Run tests
bundle exec rubocop      # Run linter
```

## Issue Tracking (Beads)

```bash
bd ready              # Find available work (no blockers)
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Universal Conventions

- **Code Style**: RuboCop standard, frozen string literals
- **Testing**: TDD workflow - write test first, then implement
- **Commits**: Conventional commits (`feat:`, `fix:`, `test:`, `docs:`)
- **Module**: `ReveAi` (not `Reve` - name taken on RubyGems)
- **Env Var**: `REVE_AI_API_KEY`

## Implementation Rules

Before adding ANY external dependency:
- Use WebSearch to verify the latest stable version
- Never trust training data for version numbers
- Check gem compatibility with Ruby 3.0+

## Key Files

| Path | Purpose |
|------|---------|
| `lib/reve_ai.rb` | Main entry point |
| `lib/reve_ai/client.rb` | API client |
| `lib/reve_ai/resources/images.rb` | Image operations |
| `test/test_helper.rb` | Test setup |
| `docs/plans/*.md` | Implementation plans |

## JIT Index

```bash
# Find class definitions
rg -n "class.*<" lib/

# Find test files
find test -name "*_test.rb"

# Check plan
cat docs/plans/260104-01a-reve-ruby-gem-architecture.md
```

## Definition of Done

Before completing any task:
1. All tests pass: `bundle exec rake test`
2. Linter clean: `bundle exec rubocop`
3. Update Beads: `bd close <id>`
4. Commit and push

## Landing the Plane (Session Completion)

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - `bd create "..." -p 1`
2. **Run quality gates** - `bundle exec rake`
3. **Update issue status** - `bd close <id>`
4. **PUSH TO REMOTE**:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```

**CRITICAL**: Work is NOT complete until `git push` succeeds.
