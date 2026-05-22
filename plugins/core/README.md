# core

Shared reviewer, explorer, architect, and critic agents plus verify and code-review skills for cross-plugin orchestration within the `hg-pyun-plugins` marketplace.

## Purpose

`core` is the shared-asset plugin for `hg-pyun-plugins`. Other plugins (e.g., `debug`, `git`) can delegate severity-rated review, architectural opinion, or fast file lookup to `core` agents instead of re-implementing the same logic locally.

## Usage

Install alongside other hg-pyun-plugins:

```shell
/plugin install core@hg-pyun-plugins
```

After install, other skills can delegate via:

```
Task(subagent_type="core:reviewer", prompt="...")
Task(subagent_type="core:explorer", prompt="...")
Task(subagent_type="core:architect", prompt="...")
Task(subagent_type="core:critic", prompt="...")
```

You can also invoke the bundled skills directly:

- `/core-verify` — evidence-based PASS/FAIL on recent changes
- `/code-review` — severity-rated review of the current diff or a named file

## Agents

| Agent | Model | Role |
|-------|-------|------|
| reviewer | sonnet | Severity-rated review (CRITICAL/MAJOR/MINOR) of diffs or files |
| explorer | haiku | Fast read-only search for files, symbols, patterns |
| architect | opus | Read-only architecture and debugging advisor with file:line evidence |
| critic | opus | Adversarial critique of plans and decisions with steelman counterarguments |

All agents are READ-ONLY (`disallowedTools: Write, Edit`) so they cannot mutate the repo.

## Skills

| Skill | Trigger | What it does |
|-------|---------|--------------|
| core-verify | "verify with core", "/core-verify" | Evidence-based PASS/FAIL on recent changes |
| code-review | "review my changes", "/code-review" | Severity-rated review via `core:reviewer` |

The `core-verify` skill is named with a `core-` prefix to make its source plugin explicit when callers see it in their skill list, and to avoid clashing with any other generic `verify` skill the user may have installed.

## Settings

This plugin currently exposes no `settings` fields.

## Smoke Test Log

Records of agent/skill invocations and PASS/FAIL verdicts are kept in `plugins/core/SPEC.md` under the "Smoke Test Log" section.

## Why this plugin exists

See [`SPEC.md`](SPEC.md) for the architectural decision (hybrid model + multi-agent reach) and the smoke-test log location.

## License

MIT (inherits from the marketplace root).
