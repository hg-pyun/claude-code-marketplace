---
name: install-statusline
description: >
  Install the canonical ccstatusline-based Claude Code status line onto this
  machine. Installs the ccstatusline binary if missing, merges the `statusLine`
  block into a target settings.json (preserving all other keys), and writes the
  shipped widget layout (model · thinking-effort · skills · git-branch ·
  context% · session-clock · usage rows) to the ccstatusline config. TRIGGER
  when: user wants to set up / replicate / install the status line or status bar
  (e.g. "claude status 설정 설치해줘", "상태줄 깔아줘", "statusline 설정해줘",
  "내 상태바 세팅 복제해줘", "install the status line", "set up ccstatusline",
  "replicate my status bar config"). Also trigger with /install-statusline
  slash command. DO NOT TRIGGER when: user wants to design a brand-new custom
  status line from scratch (use the built-in statusline-setup agent), is asking
  what the status line shows conceptually, or only wants to tweak one widget.
---

<Purpose>
Install a known-good, ready-to-use Claude Code status line in one step. The skill ships two config snapshots as assets — the `statusLine` wiring block and the full ccstatusline widget layout — and applies both: it ensures the `ccstatusline` binary is present, merges the wiring block into the chosen settings.json without clobbering existing keys, and writes the widget layout to `~/.config/ccstatusline/settings.json`. Use it to set up or replicate the maintainer's status line on a new machine or for a new user.
</Purpose>

<Use_When>
- User wants to install / set up / replicate the project's standard status line ("상태줄 깔아줘", "install the status line")
- User invokes `/install-statusline` (optionally `--scope=project` or `--dry-run`)
- A fresh machine or teammate needs the same ccstatusline configuration without manual editing
- The `statusLine` block and/or ccstatusline widget layout is missing or should be reset to the canonical preset
</Use_When>

<Do_Not_Use_When>
- User wants to design a brand-new, fully custom status line from scratch → use the built-in `statusline-setup` agent instead
- User only wants to tweak a single widget or color → edit `~/.config/ccstatusline/settings.json` directly or run `ccstatusline` interactively
- User is asking conceptually what the status line displays — just explain
- User explicitly does not use ccstatusline and wants a different status-line tool
</Do_Not_Use_When>

<Why_This_Exists>
A working status line is split across two files — the `statusLine` block in Claude Code's `settings.json` (the wiring) and the ccstatusline widget layout in `~/.config/ccstatusline/settings.json` (what's actually shown) — plus a globally installed binary. Setting this up by hand is error-prone: editing `settings.json` risks clobbering unrelated keys, and the widget layout is tedious to recreate. This skill captures the maintainer's current, validated configuration as shipped assets and installs all three pieces atomically with backups, so replication is one command instead of a manual checklist.
</Why_This_Exists>

<Execution_Policy>
- Run the shipped `install.sh` — do not hand-edit settings.json with ad-hoc shell.
- Always back up any existing target file before overwriting (the script does this; never bypass it).
- The `settings.json` merge MUST preserve every existing key — only `statusLine` is added/replaced.
- Default scope is **user** (`~/.claude/settings.json`). Use `--scope=project` only when the user wants the status line wired at the project level.
- When unsure whether the user wants user-level or project-level install, AskUserQuestion before running.
- Offer `--dry-run` first if the user is cautious or has an existing custom status line.
</Execution_Policy>

<Arguments>
- `--scope=user` (default): merge into `~/.claude/settings.json`.
- `--scope=project`: merge into `./.claude/settings.json` (current working directory).
- `--dry-run`: print every action without changing any file or installing anything.
</Arguments>

<Steps>
### Step 1: Confirm scope
Determine whether the user wants a **user-level** (default, `~/.claude/settings.json`) or **project-level** (`./.claude/settings.json`) install. If the request is ambiguous and the choice matters, AskUserQuestion with the two options. If the user already signaled "for this machine / globally", default to user scope without asking.

### Step 2: Preview (optional but recommended)
If the user is cautious, or an existing `statusLine` / ccstatusline config is present that they may want to keep, run a dry run first and show the output:

```
bash "${CLAUDE_PLUGIN_ROOT}/skills/install-statusline/install.sh" --dry-run [--scope=project]
```

Confirm with the user before the real run.

### Step 3: Install
Run the script for real:

```
bash "${CLAUDE_PLUGIN_ROOT}/skills/install-statusline/install.sh" [--scope=user|--scope=project]
```

The script will, in order:
1. Install `ccstatusline` via `npm install -g ccstatusline` if the binary is not on PATH (warns if npm is unavailable).
2. Back up the target `settings.json` (if it exists) and merge in the `statusLine` block, preserving all other keys.
3. Back up `~/.config/ccstatusline/settings.json` (if it exists) and write the shipped widget layout.

Stream the script output to the user.

### Step 4: Report
Summarize what changed:
- Whether ccstatusline was already present or freshly installed
- Which `settings.json` was updated and where its backup is (`<path>.bak.<timestamp>`)
- That the widget layout was written (and its backup, if any)
- Remind the user to restart Claude Code (or wait for the next refresh) to see the status line

If npm was missing, tell the user to run `npm install -g ccstatusline` manually, then they're done.
</Steps>

<Tool_Usage>
- `Bash` to run `install.sh` (dry-run in Step 2, real run in Step 3). Always invoke via the `${CLAUDE_PLUGIN_ROOT}` path.
- `AskUserQuestion` in Step 1 when user-vs-project scope is ambiguous, and in Step 2 to confirm before overwriting an existing custom status line.
- Do **not** hand-edit `settings.json` with `Edit`/`sed` — the script's JSON merge is the safe path.
</Tool_Usage>

<Examples>
**Example 1 — fresh machine, user scope:**
User: "/install-statusline"
Flow: Step 1 defaults to user scope → Step 3 runs the script → ccstatusline installed via npm, `~/.claude/settings.json` gets the `statusLine` block (no existing file, so no backup), widget layout written → Step 4 reports and tells the user to restart.

**Example 2 — cautious user with an existing status line:**
User: "내 상태줄 설정 복제하고 싶은데 기존 설정 날아갈까 걱정돼"
Flow: Step 1 confirms user scope → Step 2 runs `--dry-run`, shows that backups will be made and other keys preserved → user confirms → Step 3 runs for real, backing up both files → Step 4 reports backup paths.

**Example 3 — project-level wiring:**
User: "이 프로젝트에서만 status line 켜줘"
Flow: Step 1 picks `--scope=project` → Step 3 runs `install.sh --scope=project` → `./.claude/settings.json` gets the `statusLine` block → Step 4 notes the project-level path. (The ccstatusline widget layout is always user-level at `~/.config/ccstatusline/settings.json`.)
</Examples>

<Final_Checklist>
- Did I confirm user-vs-project scope (asked when ambiguous)?
- Did I run the shipped `install.sh` rather than hand-editing settings.json?
- Were existing files backed up before any overwrite?
- Did the settings.json merge preserve all non-`statusLine` keys?
- Did I report backup paths and the restart/refresh reminder?
- If npm was missing, did I tell the user how to finish the install manually?
</Final_Checklist>
