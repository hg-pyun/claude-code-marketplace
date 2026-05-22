---
name: REPLACE-WITH-SKILL-NAME
description: >
  REPLACE: one-paragraph description. Include TRIGGER phrases (Korean + English)
  and explicit DO NOT TRIGGER conditions. The description drives auto-load, so
  invest in it.
---

<Purpose>
<!-- One paragraph: what this skill produces and for whom. -->
</Purpose>

<Use_When>
<!-- Bullet list of triggering scenarios and phrases. -->
- ...
</Use_When>

<Do_Not_Use_When>
<!-- Bullet list of non-triggering or out-of-scope scenarios. -->
- ...
</Do_Not_Use_When>

<Why_This_Exists>
<!-- One paragraph: the motivating problem and why this skill is the right tool for it. -->
</Why_This_Exists>

<Execution_Policy>
<!-- Hard rules, language requirements, irrevocable bans, fallback contracts, etc. -->
- ...
</Execution_Policy>

<Settings_Reference>
<!-- Optional. Remove if the skill does not use settings.language. -->
- `$LANGUAGE`: the language setting from `plugin.json` `settings.language` (default `Korean`). Override with `--lang=<value>`. Presets: Korean, English, Japanese, Chinese. Custom values accepted.
</Settings_Reference>

<Arguments>
<!-- Optional. Document $ARGUMENTS shape. -->
- `$ARGUMENTS`: <description>
</Arguments>

<Steps>
### Step 1: <action>
<!-- Concrete sub-steps; cite tools used. -->

### Step 2: <action>
<!-- ... -->
</Steps>

<Tool_Usage>
<!-- Which tools this skill uses and why. -->
- ...
</Tool_Usage>

<Examples>
**Example 1 — <scenario>:**
<!-- User input + flow + expected behavior. -->

**Example 2 — <scenario>:**
<!-- ... -->
</Examples>

<Final_Checklist>
<!-- Things to confirm before considering the skill done. -->
- ...
</Final_Checklist>
