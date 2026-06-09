# Conventions — Forms Builder Pro

> Concrete rules for headers, visual hierarchy (Claude Code style), and rich-content
> decision-making. Read this when authoring a new form.

---

## §1 — Headers naming conventions

### Default rules

1. **snake_case** always (no spaces, no camelCase, no kebab-case)
2. Strip stop words: `el la los las un una the a de del`, articles, punctuation
3. Take first 1-3 meaningful words from the question
4. Max 20 characters
5. Preserve Spanish accents (ñ, á, é, í, ó, ú) — they're valid identifiers and reduce ambiguity
6. Lowercase
7. **Always include `timestamp`** as column 1 (Google Forms creates this column automatically; the script renames it to `timestamp`)
8. Resolve collisions with `_2`, `_3` suffix

### Examples

| Pregunta | Slug |
|---|---|
| ¿Cuál es tu nombre completo? | `nombre` |
| ¿En qué empresa trabajas actualmente? | `empresa` |
| Años de experiencia con herramientas AI | `años_experiencia` |
| ¿Recomendarías esta plataforma a un colega? | `recomendarias` |
| Comentarios adicionales | `comentarios` |
| ¿Qué casos de uso te interesan más? (multi) | `casos_uso` |
| Sube tu CV (PDF) | `cv_upload` |
| What's your full name? | `name` |
| How many years of experience? | `years_experience` |
| Rate your satisfaction (1-10) | `satisfaccion` (or `satisfaction`) |

### Edge cases

| Scenario | Resolution |
|---|---|
| Two questions slug to the same thing | Append `_2`, `_3`: `comentarios`, `comentarios_2` |
| Question is "Otra cosa importante" | `otra_cosa` (3 words max, no stop words) |
| Question is a single emoji or symbol | Use placeholder: `campo_<n>` where n is question index |
| Question is in mixed Spanish/English | Slug in the dominant language; ask user if unclear |
| Long compound question like "If yes, why?" | Slug to `por_que_si` or `why_yes`; check with user |
| NPS-style "Recomendarías..." (numeric scale) | Always `nps` (well-known industry shorthand) |

### Always show user the proposed slugs

The skill MUST display the proposed slugs to the user as a table BEFORE generating
the Apps Script. Format:

```
| Pregunta | Slug propuesto | Cambiar a |
|---|---|---|
| ¿Cuál es tu nombre? | nombre |  |
| ¿En qué empresa? | empresa |  |
```

Ask: "¿Apruebas estos slugs o cambias alguno? Responde con lista de cambios o 'ok'."

Wait for confirmation before generating.

---

## §2 — Visual hierarchy (Claude Code style)

Claude Code's `AskUserQuestion` UI is the design inspiration. Translate its patterns:

### Anatomy of a Claude Code question

```
┌─────────────────────────────────────────────────────────────┐
│ [HEADER CHIP: 12 chars max, e.g. "Auth method"]            │
│                                                             │
│  Main question text in conversational tone?                 │
│  Optional helper text under the question (smaller, gray).   │
│                                                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Option 1 Label (Recommended)                           │ │
│  │ Description of what this option means or implies       │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Option 2 Label                                         │ │
│  │ Description of what this option means or implies       │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Translation to Google Forms

| Claude Code | Google Forms equivalent |
|---|---|
| Header chip (short label) | Question title (`item.setTitle()`) — keep terse |
| Main question | Use `addSectionHeaderItem()` BEFORE the question for context, or just use the title verbatim |
| Helper text under question | `item.setHelpText()` — keep under 200 chars |
| Option label | Choice text in `createChoice('Label')` |
| Option description | Google Forms doesn't have per-option descriptions ⚠ |
| "(Recommended)" badge | Append in option text: `'Option 1 (Recommended)'` |

### Workaround: per-option descriptions

Google Forms has **no native field** for "description of this option." Three workarounds:

1. **Append in the option text**: `'Option 1 — explanation of what this implies'`
   - Pro: zero overhead
   - Con: long option lines look cluttered, browser wraps awkwardly

2. **Bundle in a preceding image**: render a table where left column is option, right column is explanation
   - Pro: looks beautiful, supports rich formatting
   - Con: requires generating PNG, user must upload to Drive
   - **Recommended for forms where option clarity matters (e.g., evaluation rubrics, technical choices)**

3. **Section header with the descriptions, question with just labels**: use `addSectionHeaderItem()` to list option descriptions, then `addMultipleChoiceItem` with just the labels
   - Pro: no images needed
   - Con: visual separation between explanation and choice

### Helper text patterns

DO:
- Tone: conversational, brief, action-oriented
- Examples: `"Si no estás seguro, elige lo que mejor describa tu rol actual"`
- Examples: `"Tu respuesta queda anónima si dejas tu email vacío"`
- Examples: `"Escala: 0 = nada probable, 10 = recomendaría sin dudar"`

DON'T:
- Repeat the question
- Use jargon without explanation
- Exceed 200 chars (Forms truncates ugly on mobile)
- Use markdown — it renders as literal `**` characters

### Section dividers for cognitive load

Use `addPageBreakItem()` for forms > 8 questions. Group by theme. Each section
gets a title like `"§2. Experiencia con AI"` and optional `helpText` describing what's coming.

This is critical for "Claude Code feel" — the form should feel like a guided
conversation, not a wall of inputs.

---

## §3 — Rich content decision tree

The user wants tables, charts, lists, images, videos. Google Forms supports none of
these natively in question text. Use this decision tree:

```
Need to convey content alongside a question?
│
├─ Is it text only?
│  ├─ <200 chars        → setHelpText() on the question
│  ├─ 200-500 chars     → addSectionHeaderItem() BEFORE the question
│  └─ >500 chars OR
│     formatted text    → render as PNG via scripts/generate_rich_image.py
│
├─ Is it a video?
│  ├─ YouTube           → addVideoItem() with URL
│  └─ Other host        → render thumbnail PNG + addSectionHeaderItem with link
│
├─ Is it structured data (table, comparison, schema)?
│  └─ → ALWAYS render PNG via scripts/generate_rich_image.py (type: table)
│
├─ Is it a chart (trend, distribution, breakdown)?
│  └─ → ALWAYS render PNG via scripts/generate_rich_image.py (type: chart)
│
└─ Is it a styled list (numbered with descriptions, checklist, icons)?
   └─ → ALWAYS render PNG via scripts/generate_rich_image.py (type: list)
```

### Decision examples

| Scenario | Right choice |
|---|---|
| "Rate your satisfaction 1-10" + 1-line note about meaning | `setHelpText()` |
| Pricing table with 4 plans × 8 features | `generate_rich_image.py table` |
| NPS explanation with 3 categories (Detractor/Passive/Promoter) | `generate_rich_image.py list` (style: bulleted) |
| 3-min tutorial video about the topic | `addVideoItem(youtubeUrl)` |
| "Here's the org chart of our team" | `generate_rich_image.py` with a chart or import existing image |
| 5-step process to follow before answering | `generate_rich_image.py list` (style: numbered) |
| Long instructions (300+ words) | `addSectionHeaderItem()` (text only, no formatting) |
| Long instructions with code blocks / lists | `generate_rich_image.py` rendered as paragraphs |

### Placement rules

- **Image item goes IMMEDIATELY BEFORE the question** it supports
- **Video item goes IMMEDIATELY BEFORE the question** that asks about it
- **Section header CAN group multiple questions** under one explanation
- **Don't pile multiple images before one question** — pick the strongest one. If you need multiple, split into multiple questions or section + table.

### Cap on rich content per form

Forms with >5 image items + >2 video items start to feel heavy. Mobile especially.

Default cap: **3 images max, 1 video max per form.** Exceeding requires explicit user opt-in.

---

## §4 — Branching strategies

Google Forms supports "go to section X based on answer" only on `addMultipleChoiceItem`
and `addListItem`. NOT on text, scale, checkbox, grid.

### Common branching patterns

1. **Eligibility filter**: Q1 "Do you qualify? Yes/No" → No → submit immediately
2. **Persona routing**: Q1 "Are you a designer / dev / PM?" → 3 different sections
3. **Skip optional sections**: Q1 "Want to provide extra feedback?" → Yes → section, No → submit
4. **Multi-step funnel**: Section 1 (mandatory), Section 2 (gated by Section 1 answer)

### How to wire in the script

```javascript
// 1. Create the section break first (so we have a reference)
const section_designer = form.addPageBreakItem().setTitle('Para Designers');
const section_dev = form.addPageBreakItem().setTitle('Para Devs');

// 2. The routing question references the page breaks
const routing = form.addMultipleChoiceItem();
routing.setTitle('¿Cuál es tu rol?');
routing.setChoices([
  routing.createChoice('Designer', section_designer),
  routing.createChoice('Developer', section_dev),
  routing.createChoice('Other', FormApp.PageNavigationType.SUBMIT) // skip rest
]);

// 3. At the END of each branch section, set what happens after
section_designer.setGoToPage(FormApp.PageNavigationType.SUBMIT); // skip the dev section
```

⚠ Branching is invisible in the editor view. Always test by submitting at least once
per branch to verify routing works.

---

## §5 — Form metadata defaults

For every form generated by this skill, default these settings unless the user
overrides:

```javascript
form.setShowLinkToRespondAgain(false);   // don't encourage spam re-submissions
form.setAllowResponseEdits(false);        // responses are immutable post-submit
form.setAcceptingResponses(true);         // form is live as soon as it's created
form.setProgressBar(true);                // show progress (helps mobile UX)
form.setShuffleQuestions(false);          // preserve question order (semantics matter)
form.setCollectEmail(false);              // privacy default; opt-in if user wants it
form.setIsQuiz(false);                    // not a quiz unless explicitly asked
```

For Spanish forms:
```javascript
form.setConfirmationMessage('¡Gracias por tu respuesta! La revisaremos pronto.');
```

For English forms:
```javascript
form.setConfirmationMessage('Thanks for your response! We\'ll review it soon.');
```

---

## §6 — Brand assets reusable across forms

The user often has assets (logos, brand imagery, screenshots, headers) that should appear on multiple forms. Don't re-upload to Drive every time.

### Pattern: persistent brand assets registry

Encourage the user to maintain a small "brand assets" folder in Drive with permanent File IDs they can reuse across all forms. The skill keeps a registry in a sheet or markdown file (per the user's preference).

#### Suggested Drive structure

```
📁 My Drive
└── 📁 Brand Assets (Forms Builder Pro)
    ├── logo_empresa.png          ← always-used logo (top of every form)
    ├── footer_separator.png      ← divider between sections
    ├── brand_header_banner.jpg   ← richer header for certain forms
    ├── ceo_signature.png         ← personalization touch for important forms
    ├── product_hero.png          ← if the user has a product/service
    └── 📁 generated/             ← skill-generated PNGs (per-form, can be deleted later)
        ├── form_<date>_table.png
        ├── form_<date>_chart.png
        └── ...
```

#### Maintaining a registry file

When the user uses the skill repeatedly, suggest creating `~/forms-builder-pro-assets.json` (or similar) that maps slot names to File IDs:

```json
{
  "logo_empresa": "1ABC123xyz...",
  "footer_separator": "1DEF456abc...",
  "brand_header_banner": "1GHI789def...",
  "ceo_signature": "1JKL012ghi...",
  "_metadata": {
    "drive_folder_url": "https://drive.google.com/drive/folders/...",
    "last_audited": "2026-06-04",
    "owner": "jerbco"
  }
}
```

The skill reads this file on each invocation (optional) and pre-populates `CONFIG.IMAGE_IDS` for known slots. The user only needs to provide File IDs for NEW assets specific to that form.

#### Naming convention for slots

| Pattern | Use for |
|---|---|
| `logo_<entity>` | Logos (logo_empresa, logo_cliente_x, logo_evento) |
| `header_<purpose>` | Header banners (header_onboarding, header_feedback) |
| `footer_<purpose>` | Footer elements (footer_separator, footer_legal) |
| `brand_<element>` | Brand identity elements (brand_color_palette_visual) |
| `screenshot_<context>` | UI screenshots (screenshot_dashboard, screenshot_onboarding_step3) |
| `chart_<topic>` | Generated charts (chart_nps_explanation, chart_pricing_compare) |
| `table_<topic>` | Generated tables (table_feature_compare, table_plan_pricing) |
| `list_<topic>` | Generated rich lists (list_dimensions, list_evaluation_rubric) |
| `photo_<subject>` | Photos (photo_team, photo_office, photo_event_speakers) |
| `illustration_<topic>` | Decorative illustrations (illustration_welcome, illustration_thank_you) |

Snake_case always. Make slots specific enough that another agent reading the registry understands what each is.

### Use logo on every form (recommended brand pattern)

For forms where brand consistency matters, place the logo as the very first item:

```javascript
// Inside createForm(), before any sections or questions:
insertImage(form, 'logo_empresa', null);  // null = no caption, just the image
```

The logo renders centered, 600px wide by default (override with `.setWidth(N)`).

For forms where you want a richer header (logo + banner image):

```javascript
insertImage(form, 'brand_header_banner', null);  // wider, visual banner
form.setDescription('Descripción del form aquí, en plain text below the banner.');
```

---

## §7 — Video sourcing decision tree

When the user wants a video in a form, the choice of where it's hosted determines what's possible.

### The tree

```
User has a video they want in the form:
│
├─ Where is it currently hosted?
│
├─ YouTube (public or unlisted)
│  └─ ✅ EMBED DIRECTLY
│     insertYoutubeVideo(form, url, caption);
│     Works for public AND unlisted (unlisted = no search appearance, but URL-shareable).
│     Private videos NOT embeddable — respondent gets "you don't have access".
│
├─ Google Drive (.mp4, .mov, .webm, etc.)
│  └─ ❌ NOT embeddable via addVideoItem (Forms only supports YouTube URLs)
│     RECOMMENDED: have the user upload to YouTube as Unlisted (5 min, one-time).
│     FALLBACK: thumbnail PNG + link to Drive preview via addSectionHeaderItem.
│
├─ Vimeo / Wistia / self-hosted / S3
│  └─ ❌ Same as Drive — not embeddable.
│     RECOMMENDED: YouTube Unlisted (re-upload).
│     FALLBACK: thumbnail + link.
│
└─ User wants to RECORD a new video (didn't shoot yet)
   └─ Suggest: record with Loom (free for short videos), then download + upload to YouTube Unlisted.
      Loom is faster than going through editing for casual screencasts.
```

### The "YouTube Unlisted" pitch

When the user has a Drive/Vimeo/self-hosted video, **always offer this**:

> "Por simplicidad y mejor UX, te recomiendo subir el video a YouTube como **No listada (Unlisted)**:
> - **No aparece en búsquedas** — solo gente con el link la ve
> - **No requiere cuenta** del respondent para verlo
> - **Embed inline en el form** — no se va a otra tab
> - **Toma 5 minutos** de upload, una sola vez
>
> Si no podés/querés (regulación, NDA, etc.), seguimos con el workaround: thumbnail + link a tu Drive."

### Workaround: thumbnail + link (when YouTube isn't an option)

```javascript
// 1. Generate a thumbnail PNG from the video (or use a key frame manually)
//    Suggest to user: ffmpeg -i video.mp4 -ss 00:00:30 -vframes 1 thumbnail.png
//
// 2. Upload thumbnail to Drive, get File ID, add to CONFIG.IMAGE_IDS

// 3. In the form questions block:
insertImage(form, 'video_thumbnail', '🎥 Video explicativo (3 min)');
insertSection(
  form,
  'Ver el video',
  'Click aquí para verlo: https://drive.google.com/file/d/VIDEO_ID/preview'
);

// Then your question that references the video
form.addParagraphTextItem()
  .setTitle('¿Qué aprendiste del video?')
  .setRequired(false);
```

⚠ The fallback opens in a new tab. Respondents will need to come back to the form, which hurts completion rates.  Always offer YouTube Unlisted first.

### Brand video reuse pattern

Same as logos — if the user has 2-3 brand videos they reuse (intro, product demo, testimonials), upload them all to YouTube as Unlisted, save URLs in a registry:

```json
{
  "videos": {
    "intro_ceo": "https://www.youtube.com/watch?v=ABC123...",
    "product_demo": "https://www.youtube.com/watch?v=DEF456...",
    "testimonial_cliente_x": "https://www.youtube.com/watch?v=GHI789..."
  }
}
```

Skill can pre-populate these on subsequent form generations.

### Video accessibility note

If the user's audience may be deaf/hard of hearing or watch with sound off:
- Recommend YouTube auto-captions (enable them on the video)
- Or: add a transcript as `setHelpText` on the video item:
  ```javascript
  insertYoutubeVideo(form, url, 'Video del CEO (2 min)');
  // The skill could then add a section right after with the transcript:
  insertSection(form, 'Transcripción', 'CEO: Hola equipo, hoy quiero compartir...');
  ```

This is a 30-second add that significantly improves accessibility. Default behavior of the skill should be: ASK the user "¿quieres que incluya la transcripción del video como texto?" when video items are present.

