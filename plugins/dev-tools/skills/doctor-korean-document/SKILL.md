---
name: doctor-korean-document
description: >
  Polish AI-written Korean documents into natural human-sounding Korean by editing files in place.
  Removes translation-ese (직역체) first — catalog patterns get phrase-level substitution,
  principle-based judgment handles sentence-level rewrites — while never touching code,
  identifiers, quotes, or terminology.
  TRIGGER when: user asks to polish, naturalize, or fix awkward Korean in a document file
  (e.g., "이 문서 다듬어줘", "번역투 고쳐줘", "한국어 자연스럽게 바꿔줘",
  "AI 말투 좀 고쳐줘", "문서 교정해줘", "이 마크다운 한국어 좀 사람답게",
  "polish this Korean doc", "fix the translation-ese").
  Also trigger with /doctor-korean-document slash command.
  DO NOT TRIGGER when: user wants content changes, summarization, or translation to another
  language; the text is not in a file (inline/pasted text is out of scope); the document is
  not Korean; or the user only wants spelling/spacing lint (use a dedicated linter).
---

<Purpose>
Edit a Korean document file in place so it reads like a person wrote it, not like machine-translated English. The #1 target is translation-ese (번역투·직역체): English structures surviving in Korean. A fixed correction catalog handles known patterns with phrase-level substitution; principle-based judgment supplements it with sentence-level rewrites — and correction intensity is tied to that mechanism, never exceeding it. Review happens through `git diff`; the skill creates no approval step of its own.
</Purpose>

<Use_When>
- User points at a Korean markdown/document file and asks to make it read naturally ("이 문서 다듬어줘", "번역투 고쳐줘")
- An AI-generated Korean doc (README, spec, guide) needs a humanizing pass before sharing
- User invokes `/doctor-korean-document <file>` with one or more file paths
- Another skill (e.g., `github-pr`) needs its drafted Korean prose polished — it applies this skill's catalog and principles to its draft text
</Use_When>

<Do_Not_Use_When>
- The text is not in a file (pasted text, chat drafts) — this skill is file-only by design; polish inline text ad hoc without invoking the skill
- User wants meaning-level edits: restructuring content, adding/removing information, summarizing
- User wants translation (Korean→English or vice versa)
- The document is not primarily Korean
- User only wants mechanical spelling/spacing checks — a linter does that better
</Do_Not_Use_When>

<Why_This_Exists>
AI writes Korean that is grammatically fine but recognizably machine-flavored: "~에 대해", "~를 통해", double passives like "~되어집니다", English word order wearing Korean particles. Readers spot it instantly and trust drops. Fixing it by hand is repetitive — the same dozen patterns recur in every generated document. This skill freezes those patterns into a maintainable catalog (consistent, personal-taste-tunable) and covers the long tail with stated principles, so any Korean document file can be brought to human-natural prose in one pass, reviewed through `git diff` like any other change.
</Why_This_Exists>

<Execution_Policy>
- **File-only.** Input is one or more file paths. The skill never operates on inline text when invoked directly. (Other skills may *borrow* the catalog and principles for their own draft text — that is their step, not this skill's invocation.)
- **Edit in place.** Modify the target file directly; `git diff` is the review surface. Never create a side-by-side copy, never require pre-approval per change.
- **Intensity is bound to mechanism:**
  - Catalog pattern matched → **phrase-level substitution only** (swap the pattern, keep the sentence frame).
  - Judgment (principle-based) → **up to one-sentence rewrite** (reorder, de-passivize, de-nominalize within that sentence).
  - **Never** merge, split, reorder, or delete sentences; never restructure paragraphs. Verbosity trimming beyond the matched pattern is out of scope.
- **Meaning is inviolable.** A rewrite that could shift nuance is skipped, not risked. When unsure between a natural phrasing and the original meaning, keep the meaning.
- **Protected regions are never edited** (see `<Protected_Regions>`).
- **Terminology is out of scope**: never translate, replace, or "consistify" technical terms — deprioritized by design.
- **Non-Korean sentences are left untouched** (English paragraphs, foreign quotes).
- **No auto-commit, no PR.** The skill ends with the edited file and a short report; committing is the user's move.
- Session dialogue (the report) follows the calling-session language; the document itself stays Korean regardless of `$LANGUAGE`.
</Execution_Policy>

<Settings_Reference>
- `$LANGUAGE` (plugin `settings.language`, default `Korean`) does **not** govern this skill's output: the edited document is Korean by definition. Only the closing report follows the session language. `--lang` is accepted but affects the report only.
</Settings_Reference>

<Arguments>
- `$ARGUMENTS` (required): one or more file paths to polish. Globs allowed (`docs/*.md`). If empty, ask for a path — do not guess a target.
</Arguments>

<Translation_Catalog>
Seeded from well-known Korean translation-ese corrections. Each entry is a **phrase-level substitution**: apply mechanically wherever the pattern appears outside protected regions, adjusting particles to fit. Grow this list by hand when a new pattern proves annoying — additions are maintainer edits, not runtime learning.

| # | 번역투 패턴 | 교정 | 예시 (before → after) |
|---|------------|------|----------------------|
| 1 | `~에 대해/대하여` (about) | 목적격 조사로 직결 | 설정 방법에 대해 설명합니다 → 설정 방법을 설명합니다 |
| 2 | `~를 통해` (through) | `~로`, `~을 이용해` | API를 통해 데이터를 가져옵니다 → API로 데이터를 가져옵니다 |
| 3 | `~에 의해` (by) | 능동형으로 | 스케줄러에 의해 실행됩니다 → 스케줄러가 실행합니다 |
| 4 | `~되어지다`, `~되어집니다` (이중 피동) | `~되다`, `~됩니다` | 자동으로 생성되어집니다 → 자동으로 생성됩니다 |
| 5 | `~하는 것이 가능하다` (it is possible to) | `~할 수 있다` | 확장하는 것이 가능합니다 → 확장할 수 있습니다 |
| 6 | `~함에 있어(서)` | `~할 때`, 또는 삭제 | 배포함에 있어 주의할 점 → 배포할 때 주의할 점 |
| 7 | `~에 있어(서)` (in/for) | `~에서`, `~의 경우`, 또는 삭제 | 성능에 있어서 중요한 → 성능에서 중요한 |
| 8 | `만약 ~(하)면` (if) | `만약` 삭제 | 만약 값이 없으면 → 값이 없으면 |
| 9 | `~하지 않으면 안 된다` (이중 부정) | `~해야 한다` | 설정하지 않으면 안 됩니다 → 설정해야 합니다 |
| 10 | `~라고 불린다` (is called) | `~라고 한다` | 미들웨어라고 불립니다 → 미들웨어라고 합니다 |
| 11 | `~를 가지고 있다` (have) | `~이/가 있다` | 세 가지 옵션을 가지고 있습니다 → 옵션이 세 가지 있습니다 |
| 12 | `~을/를 필요로 하다` (require) | `~이/가 필요하다` | 인증을 필요로 합니다 → 인증이 필요합니다 |
| 13 | `~에 위치하다` (is located) | `~에 있다` | 루트에 위치합니다 → 루트에 있습니다 |
| 14 | `~로부터` (from) | `~에서` | 서버로부터 응답을 받아 → 서버에서 응답을 받아 |
| 15 | `~와/과 함께` (with, 도구·수단) | `~로`, `~와` | 이 설정과 함께 실행하면 → 이 설정으로 실행하면 |
| 16 | 복수 `~들` 남용 | 문맥상 복수가 자명하면 삭제 | 아래 파일들을 수정합니다 → 아래 파일을 수정합니다 |
| 17 | `~하고 있습니다` (진행형 남용, 상태 서술) | `~합니다` | 이 기능을 지원하고 있습니다 → 이 기능을 지원합니다 |
| 18 | `가장 ~ 중 하나` (one of the most) | 단정하거나 완화 표현으로 | 가장 널리 쓰이는 도구 중 하나입니다 → 널리 쓰이는 도구입니다 |

Substitution rule: the sentence frame stays; only the matched phrase (and its particles) changes. If applying an entry would require touching anything beyond the phrase, hand the sentence to judgment (below) instead.
</Translation_Catalog>

<Judgment_Principles>
For awkwardness the catalog does not list. Ceiling: **rewrite within a single sentence**. Principles, in priority order:

1. **De-passivize** — unnecessary passives (`~된다`, `~받다`, `~어지다`) become active voice when the actor is clear.
2. **De-nominalize** — noun-heavy constructions become verbs: `설치를 진행합니다` → `설치합니다`, `개선이 이루어졌다` → `개선했다`.
3. **Restore Korean word order** — English SVO residue and trailing qualifiers move to natural Korean order; long pre-noun modifier chains (관형절 중첩) unwind *within the sentence*.
4. **Drop dummy pronouns** — `그것`, `이것`, `해당` referring to the obvious noun are deleted or replaced with the noun.
5. **Prune hedging fillers** — `~할 수 있습니다` used as decoration (not ability), `기본적으로`, `일반적으로` with no informational value.

If a principle-based rewrite risks nuance drift, skip it. Judgment covers less; that is the accepted trade.
</Judgment_Principles>

<Protected_Regions>
Never edited, regardless of what they contain:

- **Code**: fenced code blocks, inline code spans, indented code.
- **Machine strings**: URLs, file paths, identifiers (function/variable/flag/branch names), version strings, shell commands and their output.
- **Verbatim quotes**: blockquoted external text, error messages, log excerpts — quoted material is evidence, not prose.
- **Metadata**: YAML frontmatter, HTML comments, badge/link reference definitions.
- **Terminology & proper nouns**: technical terms (원어든 음차든 그대로), product/library names.
- **Non-Korean prose**: English or other-language sentences and paragraphs.
- **Table structure**: cells may have their Korean prose polished, but rows/columns are never added, removed, or reordered.
</Protected_Regions>

<Steps>
### Step 1: Resolve targets
1. Expand `$ARGUMENTS` into concrete file paths (globs allowed). No argument → ask for a path; never guess.
2. For each file, verify it exists and is primarily Korean prose. Skip non-Korean files with a note.
3. Warn (but continue) if a target file is untracked by git — the user loses the `git diff` review surface for that file.

### Step 2: Read and mark protected regions
1. Read the full file.
2. Mentally mark every `<Protected_Regions>` span — these are hard boundaries for every subsequent step.

### Step 3: Catalog pass (phrase-level)
1. Sweep the prose for `<Translation_Catalog>` patterns.
2. Apply each match as a minimal substitution: pattern out, correction in, particles adjusted, sentence frame intact.
3. If a match cannot be fixed without touching the rest of the sentence, defer it to Step 4.

### Step 4: Judgment pass (sentence-level)
1. Re-read each paragraph; flag sentences that still read as machine-flavored.
2. Rewrite flagged sentences using `<Judgment_Principles>` — one sentence at a time, never crossing sentence boundaries, never merging/splitting/reordering.
3. Skip any rewrite where meaning preservation is not certain.

### Step 5: Re-read test (the success gate)
1. Read the polished document top to bottom once more, as a reader.
2. Anything that still trips the eye → fix within the same intensity limits, or leave it and note it in the report if fixing would exceed them.
3. The pass criterion is "re-reading finds nothing left to fix" — the final judge is the human re-reading the diff.

### Step 6: Report
Output a short summary: files edited, count of catalog substitutions vs judgment rewrites, anything intentionally left (with reason), and a reminder that `git diff` shows every change. **Do not commit.**
</Steps>

<Tool_Usage>
- **Read** to load target files; **Edit** for individual substitutions; **Write** only when edits are so pervasive a full rewrite of the file is cleaner.
- **Glob** to expand path patterns; **Grep** to locate catalog patterns across targets and to double-check none remain after Step 5.
- **Bash** (`git status`, `git ls-files`) only to check whether targets are tracked (Step 1 warning). No `git add`, no `git commit`.
- **No network, no subagents** — this is a single-context editing pass.
</Tool_Usage>

<Examples>
**Example 1 — polish one README:**
User: "/doctor-korean-document docs/guide.md"
Flow: read file → catalog pass fixes "~를 통해"(3), "~에 대해"(2), "되어집니다"(1) → judgment pass rewrites 2 passive sentences to active → re-read finds one more "~들" → report: "catalog 6건, judgment 2건, 코드 블록·용어 미접촉. git diff로 확인하세요."

**Example 2 — awkward sentence beyond the catalog:**
Sentence: "이 기능은 개발자들에 의해 널리 사용되어지고 있는 기능 중 하나입니다."
Catalog: `~에 의해`→능동, `되어지고`→이중 피동 해소, `~중 하나`→단정. Judgment merges the fixes within the one sentence: "이 기능은 개발자들이 널리 사용합니다." Sentence count unchanged.

**Example 3 — borrowed by github-pr:**
`/github-pr` drafts a Korean PR body, then applies this skill's catalog + principles to its draft before creating the PR. That is github-pr's own step (draft text, not a file); this skill is not separately invoked.

**Example 4 — declined scope:**
User: "이 문단 요약하면서 자연스럽게 해줘" → summarization is content change; polish-only is offered, summarization declined under this skill.
</Examples>

<Final_Checklist>
- Did I edit files only (no inline-text invocation), and warn on untracked targets?
- Did every catalog fix stay phrase-level, and every judgment fix stay within one sentence?
- Zero sentences merged, split, reordered, or deleted? Zero paragraph restructuring?
- Are all protected regions byte-identical (code, quotes, URLs, identifiers, frontmatter, terms, non-Korean prose)?
- Did I run the final re-read pass and fix or explicitly report what still reads awkward?
- Did the report give substitution/rewrite counts and point the user to `git diff`?
- Did I avoid committing, and avoid translating or replacing any technical term?
</Final_Checklist>
