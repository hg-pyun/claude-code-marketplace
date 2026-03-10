# Craft Plugin

Tools for creating, testing, evaluating, and deploying Claude Code skills.

## Skills

### skill-creator

Skill creation tool from [anthropics/skills](https://github.com/anthropics/skills/tree/main/skills/skill-creator).

Supports the full skill lifecycle:
- Write skills (SKILL.md + YAML frontmatter)
- Generate test cases (evals.json)
- Run evals and benchmarks (with/without skill comparison)
- Analyze results and incorporate feedback
- Optimize descriptions (improve trigger accuracy)
- Package as `.skill` files

#### Requirements

- **Python 3**: Required for running scripts
- **Claude CLI** (`claude`): Evals invoke `claude -p` under the hood

#### License

skill-creator is licensed under Apache License 2.0. See `skills/skill-creator/LICENSE.txt` for details.
