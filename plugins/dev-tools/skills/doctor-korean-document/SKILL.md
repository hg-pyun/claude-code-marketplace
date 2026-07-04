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
Seeded from well-known Korean translation-ese corrections, then reviewed by a Korean-language expert pass. Each entry is a **phrase-level substitution**: apply mechanically wherever the pattern appears outside protected regions, adjusting particles to fit. Every pattern **includes its 관형형/명사형 variants** (`~에 대한`, `~를 통한`, `~에 의한`, `~를 필요로 하는`, `~에 위치한`, …). Grow this list by hand when a new pattern proves annoying — additions are maintainer edits, not runtime learning.

| # | 번역투 패턴 | 교정 | 예시 (before → after) | 적용 조건·예외 |
|---|------------|------|----------------------|----------------|
| 1 | `~에 대해/대하여` (about) | 목적격 조사로 직결 | 설정 방법에 대해 설명합니다 → 설정 방법을 설명합니다 | 서술어가 그 명사를 목적어로 자연스럽게 취할 때만("오류에 대해 사과합니다"는 불가); 아니면 judgment로 이관 |
| 2 | `~를 통해` (through) | `~로`, `~을 이용해` | API를 통해 데이터를 가져옵니다 → API로 데이터를 가져옵니다 | 수단·도구일 때만. 매개가 사람이면 `~를 거쳐`/`~에게서`; 물리적 통과("터널을 통해")는 원문 유지 |
| 3 | `~에 의해` (by) | 능동형으로 | 스케줄러에 의해 실행됩니다 → 스케줄러가 실행합니다 | 원문에 주어가 있으면 주어·목적어 역할 교체가 필요하므로 **judgment로 이관** |
| 4 | `~되어지다`, `~되어집니다` (이중 피동) | `~되다`, `~됩니다` | 자동으로 생성되어집니다 → 자동으로 생성됩니다 | — |
| 5 | `~하는 것이 가능하다` (it is possible to) | `~할 수 있다` | 확장하는 것이 가능합니다 → 확장할 수 있습니다 | — |
| 6 | `~함에 있어(서)` | `~할 때`, 또는 삭제 | 배포함에 있어 주의할 점 → 배포할 때 주의할 점 | — |
| 7 | `~에 있어(서)` (in/for) | `~에`, `~ 면에서`, `~의 경우`, 또는 삭제 | 성능에 있어서 중요한 → 성능에 중요한 | — |
| 8 | `만약 ~(하)면` (if) | `만약` 삭제 | 만약 값이 없으면 → 값이 없으면 | 조건절이 짧아 `-면`이 문두에서 가까울 때만; 긴 조건절·강조 맥락에서는 유지 (규범 오류가 아닌 문체 교정임) |
| 9 | `~하지 않으면 안 된다` (이중 부정) | `~해야 한다` | 설정하지 않으면 안 됩니다 → 설정해야 합니다 | — |
| 10 | `~라고 불린다` (is called) | `~라고 한다` | 미들웨어라고 불립니다 → 미들웨어라고 합니다 | — |
| 11 | `~를 가지고 있다` (have) | `~이/가 있다` | 세 가지 옵션을 가지고 있습니다 → 옵션이 세 가지 있습니다 | — |
| 12 | `~을/를 필요로 하다` (require) | `~이/가 필요하다` | 인증을 필요로 합니다 → 인증이 필요합니다 | — |
| 13 | `~에 위치하다` (is located) | `~에 있다` | 루트에 위치합니다 → 루트에 있습니다 | — |
| 14 | `~로부터` (from) | 무정물 출처 `~에서` / 유정물 출처 `~에게서` | 서버로부터 응답을 받아 → 서버에서 응답을 받아 | 출처가 사람·조직이면 반드시 `~에게서`("친구에서 들었다"는 비문); `~에서`는 장소·시스템에만 |
| 15 | `~와/과 함께` (with) | `~로`, `~와` | 이 설정과 함께 실행하면 → 이 설정으로 실행하면 | 도구·수단일 때만; 동반("팀과 함께")·동시("릴리스와 함께 추가") 의미면 원문 유지 |
| 16 | 복수 `~들` 남용 | 삭제 | 아래 파일들을 수정합니다 → 아래 파일을 수정합니다 | 문맥상 복수가 자명할 때만 |
| 17 | `~하고 있습니다` (진행형 남용) | `~합니다` | 이 기능을 지원하고 있습니다 → 이 기능을 지원합니다 | 항구적 상태·능력 서술만; 실제 진행 중인 동작("서버가 재시작하고 있습니다")은 유지 |
| 18 | `가장 ~ 중 하나` (one of the most) | 단정·완화, 또는 `손꼽히는 ~` | 가장 널리 쓰이는 도구 중 하나입니다 → 널리 쓰이는 도구입니다 | 명제 강도가 바뀌므로, 사실 정확성이 중요한 문맥(비교 주장·수치 근거 서술)에서는 건너뜀 |
| 19 | `~로 인해` (due to) | `~ 때문에`, `~로` | 오류로 인해 실패했습니다 → 오류 때문에 실패했습니다 | — |
| 20 | `~함으로써` (by ~ing) | `~해(서)`, `~하여` | 캐시를 사용함으로써 성능을 높입니다 → 캐시를 사용해 성능을 높입니다 | — |
| 21 | 조사+`의` (`~로의`, `~에의`, `~와의`, `~에서의`) | 풀어쓰기 또는 삭제 | 데이터베이스로의 연결 → 데이터베이스 연결 | — |
| 22 | `~에도 불구하고` (despite) | `~는데도`, `~아/어도` | 경고에도 불구하고 실행됩니다 → 경고가 있어도 실행됩니다 | — |
| 23 | 동작명사+`을/를 진행하다` | `~하다` | 마이그레이션을 진행합니다 → 마이그레이션합니다 | 실제 절차의 진행 상황을 말하는 문맥이면 유지 |

**직역 어휘 (word-level).** AI 문서에는 구문만이 아니라 낱말 자체가 영어를 그대로 옮긴 듯한 경우가 있다 (exist→존재하다, perform→수행하다, successfully→성공적으로). 아래 어휘 표도 같은 치환 규칙을 따른다 — 단어(와 조사)만 바꾸고 문장 틀은 유지. **일반 어휘만 대상이다**: `<Protected_Regions>`의 기술 용어·고유명사·UI 라벨은 어색해 보여도 건드리지 않는다.

| # | 직역 어휘 | 교정 | 예시 (before → after) | 적용 조건·예외 |
|---|-----------|------|----------------------|----------------|
| W1 | `존재하다` (exist) | `있다` | 두 가지 옵션이 존재합니다 → 두 가지 옵션이 있습니다 | 부정형 `존재하지 않다`는 `없다`로 교정 (`있지 않다`는 비문에 가까움) |
| W2 | `수행하다` (perform) | `~하다`, `실행하다` | 검증을 수행합니다 → 검증합니다 | 목적어가 동작명사(검증, 마이그레이션 등)일 때만 `~하다` 축약; `역할·임무` 등 굳은 결합은 유지 |
| W3 | `활용하다` 남용 (utilize/leverage) | `사용하다`, `쓰다` | 캐시를 활용하여 조회 속도를 높입니다 → 캐시를 사용해 조회 속도를 높입니다 | '용도를 살려 응용한다'는 뉘앙스가 요점이면 유지 |
| W4 | `다양한`/`다수의` 남용 (various/multiple) | `여러`, `많은` | 다양한 옵션을 지원합니다 → 여러 옵션을 지원합니다 | 종류의 다양성 자체가 요점이면 유지; `다수`가 많음·과반을 함의하면 `많은`으로 |
| W5 | `동일한` (identical) | `같은` | 동일한 결과가 나옵니다 → 같은 결과가 나옵니다 | — |
| W6 | `상이한` (different) | `다른` | 상이한 결과가 반환됩니다 → 다른 결과가 반환됩니다 | — |
| W7 | `용이하다` (easy) | `쉽다` | 확장이 용이합니다 → 확장이 쉽습니다 | — |
| W8 | `요구되다` (is required) | `필요하다` | 인증이 요구됩니다 → 인증이 필요합니다 | — |
| W9 | `성공적으로` (successfully) | 삭제, 또는 `정상적으로` | 성공적으로 설치되었습니다 → 설치되었습니다 | 실패 경로와 대비하는 문맥이면 유지 |
| W10 | `해당` 남용 (the/corresponding) | `이`, `그`, 또는 삭제 | 해당 파일을 엽니다 → 그 파일을 엽니다 | 관형사 용법만; 동사 `해당하다`("조건에 해당하는")는 대상 아님. 지시 대상이 문맥상 명확할 때만 |
| W11 | `부재` (absence) | `없음`, `~이 없으면` | 설정 부재 시 기본값을 사용합니다 → 설정이 없으면 기본값을 사용합니다 | — |
| W12 | `~ 여부` 남용 (whether) | `~는지` | 파일 존재 여부를 확인합니다 → 파일이 있는지 확인합니다 | 표 헤더·필드명 등 명사형 자리는 유지; `여부와 관계없이/여부에 따라` 등 조사 결합형은 judgment로 이관 |
| W13 | `본` (this) | `이` | 본 문서에서는 설정 방법을 다룹니다 → 이 문서에서는 설정 방법을 다룹니다 | 관형사 용법만; `본질`, `기본` 등 합성어 내부는 제외 |
| W14 | `상기`/`하기` (the above/below) | `위`/`아래` | 상기 명령을 실행합니다 → 위 명령을 실행합니다 | — |
| W15 | `야기하다` (cause) | `일으키다` | 메모리 누수를 야기합니다 → 메모리 누수를 일으킵니다 | — |
| W16 | `기술하다` (describe) | `설명하다`, `적다` | 각 필드를 아래에 기술합니다 → 각 필드를 아래에 설명합니다 | 서술 동사 용법만 (명사 `기술(技術)`과 무관할 때) |

> 어휘 표 확장 시 주의: `생성하다`, `발생하다`, `제공하다`, `~ 시`는 기술 문서에서 관용으로 굳어 과잉 교정 위험이 크므로 **추가하지 않는다** (전문가 검증에서 명시 제외).

Substitution rule: the sentence frame stays; only the matched phrase or word (and its particles) changes. An entry's 적용 조건 is part of the pattern — when the condition fails, either leave the text or hand the sentence to judgment. If applying an entry would require touching anything beyond the phrase, hand the sentence to judgment (below) instead.
</Translation_Catalog>

<Judgment_Principles>
For awkwardness the catalog does not list. Ceiling: **rewrite within a single sentence**. Principles, in priority order:

1. **De-passivize (남용 시에만)** — `~받다`/`~되다` are legitimate Korean passives; target only double-passive residue and passives whose actor is clearly stated in the sentence. **Never introduce an actor the original does not name**: `개선이 이루어졌다` → `개선됐다` (행위자 불명 유지), not `개선했다`.
2. **De-nominalize** — noun-heavy constructions become verbs: `배포가 이루어졌다` → `배포됐다`, `검토를 수행합니다` → `검토합니다`.
3. **Restore Korean word order** — English SVO residue and trailing qualifiers move to natural Korean order; long pre-noun modifier chains (관형절 중첩) unwind *within the sentence*.
4. **Drop dummy pronouns** — `그것`, `이것`, `해당` referring to the obvious noun are deleted or replaced with the noun.
5. **Prune hedging fillers** — `~할 수 있습니다` used as decoration (not ability), `일반적으로` with no informational value. **Exception:** `기본적으로` meaning *by default* is a spec statement, not filler — never delete; clarify to `기본값으로` if anything.
6. **Preserve register (어체 보존)** — keep the document's existing 어체 (합쇼체/해요체/개조식 `~함`·`~하기`) exactly as found; never unfold 개조식 bullets into full sentences, never mix registers within a document.

If a principle-based rewrite risks nuance drift, skip it. Judgment covers less; that is the accepted trade.
</Judgment_Principles>

<Protected_Regions>
Never edited, regardless of what they contain:

- **Code**: fenced code blocks, inline code spans, indented code.
- **Machine strings**: URLs, file paths, identifiers (function/variable/flag/branch names), version strings, shell commands and their output.
- **Verbatim quotes**: blockquoted external text, **inline quotes inside 따옴표** (인용된 발화·원문), error messages, log excerpts — quoted material is evidence, not prose.
- **Metadata**: YAML frontmatter, HTML comments, badge/link reference definitions.
- **Terminology & proper nouns**: technical terms (원어든 음차든 그대로), product/library names.
- **UI strings**: product UI labels and menu paths (`설정 > 일반` 등) — they must match the real UI, awkward or not.
- **Anchor-target headings**: a heading referenced by an in-document `#anchor` link or TOC is protected — polishing it breaks the link. Check for references before touching any heading.
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

### Step 3: Catalog pass (phrase- and word-level)
1. Sweep the prose for `<Translation_Catalog>` patterns — both the phrase table and the 직역 어휘 word table.
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
