# Claude Code Marketplace Spec

## Project Overview

**Project name**: claude-code-marketplace
**Marketplace name**: `hg-pyun-plugins`
**Repository**: `hg-pyun/claude-code-marketplace` (Public)
**License**: MIT

A static GitHub repository for the Claude Code plugin marketplace.
Starting as personal use, but maintaining a structure that can be gradually shared with teams or the community in the future.

## Key Decisions

| Item | Decision | Rationale |
|------|----------|-----------|
| Project type | Static repository (marketplace.json + plugin files) | Minimal structure suitable for personal use |
| Source management | Monorepo (all plugins included in this repository) | Consistent management in a single repository |
| Directory structure | Separated by plugin (plugins/plugin-name/) | Simple and intuitive structure |
| pluginRoot | Set to `./plugins` | Simplifies source paths |
| Versioning | Date-based (YYYY.MM[.patch] format) | Intuitive versioning scheme suitable for personal projects |
| Templates | Not included | Claude Code can help when needed |
| Automation scripts | Not included | Manual management + Claude Code assistance |
| Target users | Personal → gradual sharing | Use the same plugin set across multiple environments |

## Directory Structure

```
claude-code-marketplace/
├── .claude-plugin/
│   └── marketplace.json        # Marketplace catalog (core file)
├── plugins/                    # Root directory for all plugins
│   ├── git/                    # Git workflow automation plugin
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── commands/
│   │   │   ├── git-commit.md
│   │   │   ├── github-pr.md
│   │   │   └── git-rebase-stack.md
│   │   └── README.md
│   ├── linear/                 # Linear ticket enrichment plugin
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── commands/
│   │   │   └── enrich-ticket.md
│   │   └── README.md
│   └── plan/                   # Project planning plugin
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── commands/
│       │   └── deep-interview.md
│       └── README.md
├── LICENSE                     # MIT License
├── README.md                   # Project description and usage
└── SPEC.md                     # This spec document
```

## marketplace.json Schema

```json
{
  "name": "hg-pyun-plugins",
  "owner": {
    "name": "hg-pyun"
  },
  "metadata": {
    "description": "Personal Claude Code plugin marketplace by hg-pyun",
    "version": "2026.02",
    "pluginRoot": "./plugins"
  },
  "plugins": [
    {
      "name": "git",
      "source": "./plugins/git",
      "description": "Analyzes git diff/log to auto-generate Korean conventional commit messages, create GitHub PRs, and handle stacked PR rebase",
      "version": "2026.02",
      "keywords": ["git", "commit", "pull-request", "conventional-commit", "korean", "rebase", "stacked-pr"]
    },
    {
      "name": "plan",
      "source": "./plugins/plan",
      "description": "Auto-generates project spec documents through in-depth interviews",
      "version": "2026.02",
      "keywords": ["interview", "spec", "requirements", "planning"]
    },
    {
      "name": "linear",
      "source": "./plugins/linear",
      "description": "Analyzes Linear tickets and fills in missing information through interviews",
      "version": "2026.02",
      "keywords": ["linear", "ticket", "interview"]
    }
  ]
}
```

### Plugin Entry Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Y | Plugin identifier (kebab-case) |
| `source` | Y | Plugin directory path (`./plugins/<name>` format) |
| `description` | Y | Plugin description |
| `version` | Y | Date-based version (YYYY.MM[.patch]) |
| `keywords` | N | Array of search keywords |

## Version Management Rules

- Format: `YYYY.MM` (first release of the month) or `YYYY.MM.patch` (additional changes in the same month)
- When a plugin is changed, its version must be bumped.
  - `version` in `plugins/<name>/.claude-plugin/plugin.json`
  - `version` of the corresponding plugin in `.claude-plugin/marketplace.json`
- The versions in both locations must always be kept in sync.
- The marketplace metadata version is only bumped when the overall catalog changes.

## Constraints and Notes

- **Reserved names**: Names like `claude-code-marketplace`, `claude-code-plugins`, `anthropic-marketplace` cannot be used as marketplace names
- **File references**: Plugins cannot reference files outside their own directory using `../` paths (because they are copied to a cache directory during installation)
- **Path traversal**: `..` cannot be included in the source path
- **Plugin names**: kebab-case, no spaces
- **`${CLAUDE_PLUGIN_ROOT}`**: Used to reference the plugin installation path in hooks and MCP server configurations

## Plugin Language Setting

### Overview

Add a configurable language setting to all plugins so that generated output can be written in Korean, English, or other languages. This replaces the current hard-coded Korean requirement across all plugins. Each plugin manages its own `settings.language` independently.

### Shared Mechanism (All Plugins)

#### Settings Storage

Add a `settings` field to each plugin's `.claude-plugin/plugin.json`:

```json
{
  "name": "<plugin-name>",
  "version": "2026.02",
  "settings": {
    "language": "Korean"
  }
}
```

- Simple string value — stores the default language
- Preset languages and parsing logic are managed in the command md files, not in plugin.json
- Default value: **Korean** (backward compatible with existing behavior)

#### Language Value Format

Both full language names and ISO 639-1 codes are accepted:

| Full Name | ISO Code |
|-----------|----------|
| Korean | ko |
| English | en |
| Japanese | ja |
| Chinese | zh |

Custom values (e.g., `Spanish`, `Bahasa Indonesia`) are also accepted as free text.

Presets: **Korean, English, Japanese, Chinese**. Any other value is treated as a custom language name and passed through as-is.

#### UX: How to Change Language

Two mechanisms, used together:

1. **plugin.json default**: Edit `settings.language` in the plugin's `.claude-plugin/plugin.json` to change the persistent default.
2. **Command argument override**: Pass `--lang=<value>` to override the default for a single invocation.
   - The argument takes precedence over plugin.json when provided.

#### Command MD File Changes

Each affected command md file will be updated with:

1. **Settings Reference section** at the top of the file:
   ```markdown
   ## Settings Reference
   - `$LANGUAGE`: The language setting from plugin.json `settings.language`.
     Override with `--lang=<value>` argument.
     Presets: Korean, English, Japanese, Chinese.
     Custom values also accepted (e.g., Spanish, Bahasa Indonesia).
   ```

2. **$LANGUAGE variable** replaces all hard-coded "Korean" references in the body:
   ```markdown
   - **Must be written in $LANGUAGE.**
   ```

3. **Examples**: Replace Korean examples with English examples to match the English documentation language. The `$LANGUAGE` instruction is sufficient to guide output language regardless of example language.

---

### git Plugin

#### Scope

| Item | Decision | Rationale |
|------|----------|-----------|
| Setting level | Plugin-level unified setting | All 3 commands share one language setting |
| Affected output | Artifacts only | Commit messages, PR title/body. Conversational output (questions, guidance, reports) is NOT affected |
| Affected commands | git-commit, github-pr | git-rebase-stack is excluded (no artifacts; its Ground Rules for Korean conversation remain unchanged) |

#### Affected Artifacts by Command

**git-commit**

| Part | Language Behavior |
|------|-------------------|
| type | English (fixed, e.g., `feat`, `fix`) |
| scope | English (fixed, inferred from paths) |
| subject description | Written in `$LANGUAGE` |
| body | Written in `$LANGUAGE` |
| footer (BREAKING CHANGE keyword) | English (fixed) |
| footer (BREAKING CHANGE description) | English (fixed) |

**github-pr**

| Part | Language Behavior |
|------|-------------------|
| PR title: type(scope) | English (fixed) |
| PR title: description | Written in `$LANGUAGE` |
| PR body: section headers (## Summary, ## Changes) | English (fixed) |
| PR body: section content | Written in `$LANGUAGE` |
| Issue linking (Closes #123) | English (fixed) |

**git-rebase-stack**

No artifacts — excluded from language setting. The existing Ground Rules ("All guidance, questions, and reports must be output in Korean") remain unchanged.

#### Argument Parsing

For git-commit (currently accepts no `$ARGUMENTS`):
- Now accepts optional `--lang=<value>` flag.
- If `$ARGUMENTS` contains `--lang=<value>`, extract and use as language override.
- All other arguments are ignored (same as before).

For github-pr (currently accepts `--draft`):
- Now additionally accepts `--lang=<value>` flag.
- Both flags can coexist: `/pr --draft --lang=en`

For git-rebase-stack:
- No change. Does not accept `--lang`.

#### Implementation Checklist

- [ ] Add `settings.language` field to `plugins/git/.claude-plugin/plugin.json`
- [ ] Update `git-commit.md`: add Settings Reference, replace hard-coded Korean with `$LANGUAGE`, replace Korean examples with English, add `--lang` argument support
- [ ] Update `github-pr.md`: add Settings Reference, replace hard-coded Korean with `$LANGUAGE`, replace Korean examples with English, add `--lang` argument support
- [ ] Update `plugins/git/README.md`: document language setting and `--lang` flag
- [ ] Bump plugin version in both `plugin.json` and `marketplace.json`

---

### linear Plugin

#### Scope

| Item | Decision | Rationale |
|------|----------|-----------|
| Setting level | Plugin-level setting | enrich-ticket command uses the setting |
| Affected output | Interview questions + ticket content | Both the interview questions asked to the user and the content written back to the Linear ticket are language-dependent |
| Affected commands | enrich-ticket | Only command in this plugin |

#### Affected Output

**enrich-ticket**

| Part | Language Behavior |
|------|-------------------|
| Interview questions (AskUserQuestion) | Written in `$LANGUAGE` |
| Enriched ticket content written to Linear | Written in `$LANGUAGE` |

#### Argument Parsing

For enrich-ticket (currently accepts a Linear ticket URL as `$ARGUMENTS`):
- Now additionally accepts optional `--lang=<value>` flag.
- The URL and `--lang` flag can coexist: `/linear:enrich-ticket <URL> --lang=en`
- If `--lang` is not provided, uses the default from plugin.json.

#### Implementation Checklist

- [ ] Add `settings.language` field to `plugins/linear/.claude-plugin/plugin.json`
- [ ] Update `enrich-ticket.md`: add Settings Reference, replace hard-coded "Korean" Ground Rule with `$LANGUAGE`, add `--lang` argument support
- [ ] Update `plugins/linear/README.md`: document language setting and `--lang` flag
- [ ] Bump plugin version in both `plugin.json` and `marketplace.json`

---

### plan Plugin

#### Scope

| Item | Decision | Rationale |
|------|----------|-----------|
| Setting level | Plugin-level setting | deep-interview command uses the setting |
| Affected output | Interview questions + spec document | Both the interview questions and the generated spec document are language-dependent |
| Affected commands | deep-interview | Only command in this plugin |

#### Affected Output

**deep-interview**

| Part | Language Behavior |
|------|-------------------|
| Interview questions (AskUserQuestion) | Written in `$LANGUAGE` |
| Generated spec document | Written in `$LANGUAGE` |

#### Argument Parsing

For deep-interview (currently accepts a request description as `$ARGUMENTS`):
- Now additionally accepts optional `--lang=<value>` flag.
- The request and `--lang` flag can coexist: `/plan:deep-interview <request> --lang=en`
- If `--lang` is not provided, uses the default from plugin.json.

#### Implementation Checklist

- [ ] Add `settings.language` field to `plugins/plan/.claude-plugin/plugin.json`
- [ ] Update `deep-interview.md`: add Settings Reference, add `$LANGUAGE` directive for interview and spec output, add `--lang` argument support
- [ ] Update `plugins/plan/README.md`: document language setting and `--lang` flag
- [ ] Bump plugin version in both `plugin.json` and `marketplace.json`
