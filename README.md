# LLM Wiki

> [🇰🇷 한국어](README.ko.md) | 🇺🇸 English
[![Publish](https://github.com/addiescode-sj/LLM-wiki/actions/workflows/publish.yml/badge.svg?branch=main)](https://github.com/addiescode-sj/LLM-wiki/actions/workflows/publish.yml)

> A team knowledge base built on Andrej Karpathy's LLM Wiki pattern.

A local-first markdown knowledge base that overcomes RAG's "session amnesia" through **ingest-time compilation**. Whenever a new document arrives, Claude Code automatically structures and stores it under `wiki/`.

---

## Quick Start

### 1. Prerequisites

```bash
# Verify Claude Code CLI is installed
claude --version

# Open this folder as an Obsidian Vault
# → Install and enable the following Community Plugins:
#   - Obsidian Git
#   - Dataview
#   - Templater
```

### 2. Initialize the repository (run once on first use)

```bash
./scripts/ingest.sh --init
./scripts/setup-hooks.sh    # install commit-msg validator (see CLAUDE.md §8)
```

### 3. Add knowledge

```bash
# Add from a file
./scripts/ingest.sh raw/articles/my-article.md

# Add from a URL
./scripts/ingest.sh --url https://example.com/paper

# Batch process everything in inbox/
./scripts/ingest.sh --all-inbox
```

### 4. Query knowledge

```bash
./scripts/query.sh "What is the Transformer attention mechanism?"

# Save the answer as a wiki page
./scripts/query.sh --save "How does RAG differ from LLM Wiki?"
```

### 5. Quality control

```bash
./scripts/lint.sh           # Full audit
./scripts/lint.sh --fix     # Auto-repair
./scripts/freshness.sh      # SHA consistency check
```

---

## Directory Structure

```
LLM-wiki/
├── CLAUDE.md              # Agent constitution (AI behavior rules)
├── AGENTS.md              # Agent role specification
├── CONTRIBUTING.md        # Contribution guide
│
├── raw/                   # ⚠️ Immutable source of truth (do not modify)
│   ├── articles/          # Web clippings, blog posts
│   ├── papers/            # Paper PDF summaries
│   ├── videos/            # YouTube/lecture transcripts
│   └── meetings/          # Meeting notes
│
├── wiki/                  # 🤖 AI-only maintained (humans browse read-only)
│   ├── index.md           # Master index (for agent routing)
│   ├── log.md             # Transaction audit ledger
│   └── *.md               # Compiled wiki pages
│
├── _templates/            # Document templates
│   ├── concept.md
│   ├── decision.md
│   └── meeting.md
│
├── inbox/                 # Drop-box for pending files
│
├── scripts/               # Automation scripts
│   ├── ingest.sh          # Ingest Agent
│   ├── query.sh           # Query Agent
│   ├── lint.sh            # Lint Agent
│   ├── freshness.sh       # SHA consistency verifier
│   └── async_ingest.sh    # Async ingest for git hooks
│
└── .obsidian/             # Obsidian settings
```

---

## Git Automation

Committing a file under `raw/` triggers a post-commit hook that starts wiki compilation automatically.

```bash
# Add a raw source → commit and it's processed automatically
git add raw/articles/new-article.md
git commit -m "raw: add new-article.md"
# → wiki/ is compiled in the background
# → Log: /tmp/llm-wiki-async-ingest.log
```

---

## Personal → Team Knowledge Promotion Policy

> **Core principle**: validate knowledge on a personal branch first, and only promote what is genuinely valuable to the team into `main`.

### Branch Structure

```
main                  ← Team-shared knowledge (protected, verified content only)
  └── personal/addie  ← Personal knowledge (experiment freely)
       └── feature/redis-research  ← Topic-specific investigation
```

### Promotion Criteria

**Promote** — content the whole team will need repeatedly:
- Architecture decisions (ADRs), technology choice rationale
- Troubleshooting records, production incident retrospectives
- Onboarding essentials (deployment procedures, environment setup)
- Technical research results (benchmarks, library comparisons)

**Keep on personal branch** — context unrelated to the team:
- Personal learning notes, book summaries
- Temporary notes during a specific PR
- Unverified drafts

### Promotion Workflow (at a glance)

```
① Add raw/ on a personal branch → commit
         ↓ (automatic)
② wiki/ compilation completes

③ Verify lint passes
   ./scripts/lint.sh

④ Open a PR: personal/<name> → main
   (fill in the checklist)

⑤ One teammate reviews → Squash Merge

⑥ Accessible to the entire team ✅
```

### Quick Start — Create a Personal Branch

```bash
# When starting for the first time
git checkout -b personal/your-name
git push -u origin personal/your-name
```

→ Scenario example: [wiki/promotion-example.md](wiki/promotion-example.md)
→ Promotion policy details: [decisions/ADR-001-knowledge-promotion-policy.md](decisions/ADR-001-knowledge-promotion-policy.md)

---

## Distribution (Embedding in Other Repos)

The compiled `wiki/` is published to a dedicated `dist` branch so other product repos can embed it as a read-only git submodule. See [decisions/ADR-002-wiki-distribution-submodule.md](decisions/ADR-002-wiki-distribution-submodule.md).

### Automatic publishing (push to `main`)

Every push to `main` that touches `wiki/**` triggers the [Publish Wiki Release](.github/workflows/publish.yml) workflow, which:

1. Runs `scripts/publish.sh` to rebuild the `dist` branch and tag `wiki-vX.Y.Z`.
2. Creates a corresponding GitHub Release (notes auto-generated from commits since the previous tag).
3. The README badge updates automatically (shields.io reads the latest release tag).

**Bump level is inferred from the commit message:**

| Marker in commit message | Bump | Use when |
|--------------------------|------|----------|
| _(none)_                 | `patch` | Default — content edits, additions |
| `[bump:minor]`           | `minor` | New pages added (back-compatible) |
| `[bump:major]`           | `major` | Existing page slugs removed/renamed (breaks consumers) |
| `[bump:skip]`            | _none_ | Doc-only / non-content change |

You can also trigger a manual release via **Actions → Publish Wiki Release → Run workflow** (choose bump level).

### Manual publishing (local)

```bash
./scripts/publish.sh patch          # 1.0.0 → 1.0.1
./scripts/publish.sh minor --push   # 1.0.1 → 1.1.0 + push
./scripts/publish.sh major --push   # bump + push branch & tag to origin
```

### Embedding in a consumer repo

```bash
# Initial embed, pinned to a tag
git submodule add -b dist <wiki-repo-url> docs/wiki
git -C docs/wiki checkout wiki-v1.0.0
git add .gitmodules docs/wiki
git commit -m "docs: embed LLM wiki @ v1.0.0"

# Later, bump the pinned version
git -C docs/wiki fetch --tags
git -C docs/wiki checkout wiki-v1.1.0
git add docs/wiki && git commit -m "docs: bump LLM wiki to v1.1.0"
```

Consumers receive only `wiki/` and `manifest.json` — `raw/`, `scripts/`, and workspace metadata are excluded.

---

## Team Collaboration Workflow

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## Architecture References

- Wiki pattern details: [wiki/llm-wiki-pattern.md](wiki/llm-wiki-pattern.md)
- Agent rules: [CLAUDE.md](CLAUDE.md)
- Agent specification: [AGENTS.md](AGENTS.md)
