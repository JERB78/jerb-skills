---
name: forms-builder-pro
description: Generate professional Google Forms via Apps Script with rich question content (tables, charts, lists, images, videos), custom-slugged Google Sheet headers, live Dashboard tab with charts, and optional email/webhook notifications. Use this skill whenever the user asks to create a form, questionnaire, survey, poll, encuesta, cuestionario, or Google Form — even casually like "necesito un formulario para X", "armar una encuesta de Y", "Google Form con Z preguntas", or "convertir estas preguntas en form". Replaces the manual UI-clicking workflow with a single Apps Script paste-and-run that produces form + linked Sheet + analytics dashboard in one step. Strongly prefer this skill over telling the user "just open Google Forms" — the entire value is automating away that manual setup.
version: 1.0.0
---

# Forms Builder Pro

> Generate a complete Google Form + linked Sheet + Dashboard tab + (optional) webhook + email notifications from a single Apps Script. The user pastes the script into Google Apps Script editor and clicks Run. Setup time: 30 seconds.

## Why this skill exists

The user wants forms that look and feel like Claude Code's `AskUserQuestion` interactions: clear hierarchy, helper text per question, descriptive options, and rich visual support (tables / charts / lists / images / videos) where text alone is insufficient. Google Forms via the standard UI can't do most of this efficiently. This skill closes that gap by:

1. **Authoring forms programmatically** via the FormApp Apps Script API (rich enough, no OAuth setup).
2. **Rendering rich content as images** (tables, charts, comparison matrices) before the form even exists, so each can be inserted as an image item per question.
3. **Auto-linking** to a Sheet with cleanly-slugged headers (not the raw question text).
4. **Adding a Dashboard tab** with live charts on top of the response data.
5. **Wiring optional automation** (email notification on submit, webhook to external service).

The output is always one Apps Script + any PNG image attachments. The user runs it once and has a production-ready form + analytics in their Drive.

---

## When to trigger this skill

Trigger on any of these phrases or close variants (Spanish + English):

- "crea(r) un form / formulario / encuesta / cuestionario / questionnaire / survey / poll"
- "necesito un formulario para [X]"
- "armar una encuesta de [tema]"
- "Google Form con [N] preguntas sobre [tema]"
- "convertir estas preguntas en form"
- "feedback form / NPS survey / employee engagement / customer satisfaction"
- "form de aplicación / scoring / evaluación"
- "form que reciba [tipo de respuesta] y guarde en sheet"

Do NOT trigger for:
- Generating a generic HTML form (use `frontend-ui-engineering` skill)
- Building form validation logic in code (use the relevant stack skill)
- Reading or analyzing existing form responses (use spreadsheet/data skills)

---

## The flow (6 steps)

When the user invokes this skill, follow this exact sequence:

### Step 1: Capture intent

Ask the user for:
- **Purpose** of the form in 1 sentence
- **Audience** (who fills it — employees, customers, leads, applicants, etc.)
- **Questions list** in any format (bullet list, paragraph, screenshot of an existing form). Don't require a formal spec.
- **Language** (Spanish / English / both)
- **Any rich content** they want — they may say "agrega una tabla comparativa de planes", "embed este video YouTube", "una lista numerada con los pasos del proceso", etc.

Don't ask for slugs, IDs, or technical config. Those are inferred.

### Step 2: Propose structure

Analyze the questions and present a draft structure as a table. Include:

- Section dividers (Google Forms supports sections — use them to group related questions, especially for forms > 8 questions)
- Question type per item (see "Question types" below)
- Required vs optional
- Where rich content goes (image insert before question, video embed, etc.)
- Any branching logic (Google Forms supports "go to section X based on answer")

Present like this:

```
Form: "Encuesta Onboarding 2026" (Spanish, 3 sections, 9 questions)

§1. Identificación (3 preguntas)
  1. nombre              — short answer, required
  2. empresa             — short answer, required
  3. rol                 — dropdown [PM, Dev, Designer, Other], required

§2. Experiencia con AI (4 preguntas)
  [image insert] tabla comparativa Claude vs ChatGPT vs Copilot
  4. herramienta_principal — single choice (radio), required
  5. años_uso              — linear scale 0-10, required
  6. casos_uso             — checkboxes (multi), required
  [video insert] YouTube embed "Claude Code Demo" (3 min)
  7. opinion_video         — paragraph, optional

§3. Feedback (2 preguntas)
  8. nps                   — linear scale 0-10, required (drives Dashboard)
  9. comentarios           — paragraph, optional

¿Apruebas esta estructura o ajustamos algo?
```

Wait for explicit OK before proceeding to Step 3.

### Step 3: Propose Sheet headers (auto-slug + confirmation)

CRITICAL — auto-slug strategy:
- Take each question's text
- Strip articles (el/la/los/las/un/una, the/a)
- Take the most meaningful 1-3 words
- snake_case it
- Resolve duplicates with `_2`, `_3` suffix

Present the proposed slugs as a table the user can edit inline:

```
Headers de la Sheet (auto-slug propuesto):

| Pregunta                          | Slug propuesto       | Cambiar a |
|---|---|---|
| ¿Cuál es tu nombre completo?      | nombre               |           |
| ¿En qué empresa trabajas?         | empresa              |           |
| ¿Cuál es tu rol principal?        | rol                  |           |
| Herramienta AI principal          | herramienta_principal|           |
| Años de uso de AI                 | años_uso             |           |
| ...                               | ...                  |           |

¿Apruebas estos slugs o cambias alguno? (responde con la lista de cambios o "ok")
```

Wait for OK or edits before proceeding.

### Step 4: Generate rich content images (if any)

For any question that needs a table, chart, comparison matrix, or rich list:

- Use `scripts/generate_rich_image.py` to produce a PNG (see scripts/ for usage)
- Save PNGs to a folder the user can find: tell them "los PNGs están en `./forms-output/<form-slug>/images/`"
- Each image gets referenced by filename in the Apps Script (via `DriveApp.getFileById` or upload step)
- For videos: use YouTube embed item (FormApp has `addVideoItem`) — no PNG needed.

If no rich content is needed, skip this step.

### Step 5: Generate the Apps Script

Use `assets/apps-script-master-template.gs` as the base. The template has clearly-marked placeholders for:

- `__FORM_TITLE__`, `__FORM_DESCRIPTION__`
- `__QUESTIONS_BLOCK__` (gets filled with all the question snippets concatenated)
- `__SHEET_NAME__`, `__SHEET_HEADERS__` (the slugs from Step 3)
- `__DASHBOARD_ENABLED__` (true/false) and `__DASHBOARD_CHARTS__` (the chart configs)
- `__WEBHOOK_URL__` (if user enabled)
- `__EMAIL_NOTIFY__` (if user enabled, comma-separated)

For each question, pull the right snippet from `assets/question-types-snippets.gs` and fill in:
- Question title (the raw text)
- Helper text (the explanation — IMPORTANT: this is where the "Claude Code style" comes in; see `references/visual-hierarchy-claude-code-style.md`)
- Options (for choice questions) with optional per-option description
- Required flag
- Image to insert before (if applicable)

Concatenate everything into one Apps Script file. Use clear section comments + bilingual comments (per user convention).

### Step 6: Hand it off

Present the final output to the user:

```
✅ Form generado. Output:

📄 D:\AI_LOCAL_SERVICES\<output-folder>\<form-slug>.gs       ← copiar este al Apps Script editor
🖼️  D:\AI_LOCAL_SERVICES\<output-folder>\<form-slug>\images\  ← subir estos PNGs a Drive primero, después actualizar los IDs en el script (línea 47 marcada con TODO)

Pasos:
1. Sube los PNGs a tu Drive (un folder cualquiera)
2. Copia los File IDs de cada uno
3. Pega los IDs en el script donde dice `__IMAGE_FILE_ID_<n>__`
4. Abre https://script.google.com → New Project → pega el script → click Run
5. Authoriza permisos (Drive + Forms + Sheets) cuando lo pida
6. El script imprime los URLs del form + sheet + dashboard en logs

Tiempo total: ~2-3 min.

¿Algún ajuste antes de generar?
```

If user says go, you're done. If they iterate, go back to the relevant Step.

---

## Question types supported (10 + section)

All of these have snippets ready in `assets/question-types-snippets.gs`. Read that file for exact syntax.

| Tipo | FormApp method | Cuándo usarlo |
|---|---|---|
| **Multiple choice (radio)** | `addMultipleChoiceItem()` | Una respuesta de N opciones cortas (3-7) |
| **Single answer (short text)** | `addTextItem()` | Texto corto (nombre, email, número) |
| **Paragraph** | `addParagraphTextItem()` | Texto largo (comentarios, descripción) |
| **Checkbox (multi-select)** | `addCheckboxItem()` | Varias respuestas de un set |
| **Dropdown** | `addListItem()` | Una respuesta de 8+ opciones (donde radio se vuelve largo) |
| **Linear scale** | `addScaleItem()` | NPS, ratings 1-5/1-10, satisfacción |
| **Multiple choice grid** | `addGridItem()` | Múltiples preguntas con misma escala (matriz) |
| **Checkbox grid** | `addCheckboxGridItem()` | Múltiples preguntas con multi-select |
| **Date** | `addDateItem()` / `addDateTimeItem()` | Fecha de nacimiento, fecha del evento, etc |
| **Time** | `addTimeItem()` | Hora del día, duración |
| **File upload** | `addFileUploadItem()` | CV, imagen, documento (requires auth + Drive) |
| **Section divider** | `addPageBreakItem()` | Separa el form en chapters; permite branching |

For rich content (NOT a question, but inserts content):

| Item | Method | Para |
|---|---|---|
| **Image** | `addImageItem()` | Insertar tabla/chart/diagrama (PNG generado) |
| **Video** | `addVideoItem()` | Embed YouTube video |
| **Section header text** | `addSectionHeaderItem()` | Título + descripción larga sin pregunta |

---

## Rich content rules (critical for "Claude Code style")

Google Forms' native description field is **plain text only, no markdown, no tables, no inline images**. The way to get richness is:

### Rule 1: tables, charts, comparison matrices → PNG via `scripts/generate_rich_image.py`

Use this when the user wants:
- Comparison of options (feature matrix)
- Reference data the respondent needs (pricing table, schema)
- A chart that contextualizes the question (trend, distribution)
- A numbered/bulleted list with rich formatting (icons, colors)

Insert as `addImageItem()` immediately BEFORE the related question.

### Rule 2: videos → YouTube embed via `addVideoItem()`

If the user provides a YouTube URL, embed it directly. No PNG needed. Forms renders the video player inline.

If the video is NOT on YouTube (Vimeo, self-hosted): generate a PNG with a thumbnail + "Ver video: [link]" text. Less elegant but works.

### Rule 3: short explanatory text → `helpText` of the question itself

For 1-2 sentence explanations, use the question's `setHelpText()` method. This shows below the question title in lighter font. Equivalent to Claude Code's option description.

Keep helpText under 200 chars. If longer, push to an image (Rule 1) or split into a Section Header item.

### Rule 4: longer narrative → Section Header item before the question

If you need a paragraph of explanation, use `addSectionHeaderItem()` BEFORE the question. This gives you a title + description block with no input field.

### Decision tree: "I have content to add to a question — what do I use?"

```
Is it a video?
  └─ YouTube? → addVideoItem (Rule 2)
  └─ Other host? → PNG with thumbnail + link (Rule 1 + Rule 4)

Is it text only?
  └─ <200 chars → setHelpText (Rule 3)
  └─ >200 chars but no structure → addSectionHeaderItem (Rule 4)
  └─ Needs table/chart/colors/icons → PNG via script (Rule 1)

Is it data (chart, comparison)? → PNG via script (Rule 1)
```

---

## Bring your own assets (logos, images, videos)

The skill treats **user-provided assets identically to skill-generated PNGs**. The user owns the source, the skill handles the wiring.

### User-provided images (logos, screenshots, photos, illustrations)

The `insertImage(form, slot, caption)` helper only needs a Drive File ID. Whether that ID points to a PNG generated by `scripts/generate_rich_image.py` or to the user's corporate logo uploaded 3 years ago — same flow.

**Workflow when user wants their own image:**

1. Ask: "¿es un asset tuyo (logo, screenshot, foto)? ¿O lo generamos vía script?"
2. If user has it already: "Subilo a Drive (cualquier folder). Pasame el link, yo extraigo el File ID."
3. Add to `CONFIG.IMAGE_IDS` with a descriptive slot name:
   ```javascript
   IMAGE_IDS: {
     'logo_empresa': 'ABC123...',           // user's corporate logo
     'screenshot_dashboard': 'DEF456...',    // user's screenshot
     'tabla_comparativa': 'GHI789...'       // PNG generated by script
   }
   ```
4. Reference in the questions block via `insertImage()` as usual.

**Brand consistency pattern** — if the user wants the same logo on every form they ever generate:
- Suggest uploading the logo ONCE to a permanent Drive location
- Use a consistent slot name (`logo_empresa`, `brand_header`)
- The user can reuse the same File ID across all future forms with zero re-upload
- Place `insertImage(form, 'logo_empresa', null)` as the FIRST item in the questions block (above any sections) for header-style branding

Supported formats: PNG (transparency), JPG/JPEG, GIF (static only), WebP. Max width 740px (Forms auto-scales larger).

### User-provided videos (recordings, screencasts, marketing clips)

⚠ **Google Forms only embeds YouTube URLs natively.** This is a Forms limitation, not a skill limitation. Three paths depending on where the video lives:

| Where is the user's video? | What to do |
|---|---|
| **Already on YouTube** (public or **unlisted**) | Use the URL directly: `insertYoutubeVideo(form, url, caption)`. Works the same whether public or unlisted. |
| **On Google Drive** (.mp4, .mov, .webm) | NOT embeddable. Workaround: extract a thumbnail PNG (screenshot at a key moment), insert as image, then add `addSectionHeaderItem` with "Ver el video aquí: [Drive preview link]". |
| **Self-hosted / Vimeo / S3 / other** | Same workaround as Drive: thumbnail + link. |

**Strong recommendation for the user**: if they have a video they'll use frequently, upload it to YouTube as **Unlisted** (no listed/private accounts needed for viewers — only people with the URL see it). One-time 5-min upload eliminates all workarounds and keeps the video embedded inline.

**When proposing the form structure (Step 2 of the flow)**, ask the user:
- "¿Tenés el video en YouTube o en otro lado?"
- If "otro lado": "Recomiendo subirlo a YouTube como **No listada** (unlisted) — no aparece en búsquedas, solo gente con el link la ve, y el embed funciona perfecto. ¿Lo haces tú o seguimos con thumbnail+link?"

---

## Headers naming conventions

For the linked Sheet, the skill auto-generates slugs. Rules:

1. **snake_case** always (no spaces, no camelCase)
2. **Strip stop words**: el, la, los, las, un, una, the, a, etc.
3. **Strip question punctuation**: ¿?¡!.,
4. **Take first 1-3 meaningful words**, max 20 chars
5. **Resolve collisions** with `_2`, `_3` suffixes
6. **Preserve Spanish characters** (ñ, á, é, í, ó, ú) — they're valid in slugs for the user's preference
7. **Always include `timestamp` as first column** (Google Forms auto-adds this; the script just renames it)

### Examples

| Pregunta | Slug |
|---|---|
| ¿Cuál es tu nombre completo? | nombre |
| ¿En qué empresa trabajas actualmente? | empresa |
| Años de experiencia con herramientas AI | años_experiencia |
| ¿Recomendarías esta plataforma a un colega? (NPS 0-10) | nps |
| Comentarios adicionales | comentarios |
| ¿Qué casos de uso te interesan más? (multi) | casos_uso |
| Sube tu CV (PDF) | cv_upload |

Always present the auto-slugged list to the user for approval before generating. They will edit anything that doesn't sound right.

---

## L3 features (always included)

This skill always generates L3 (full). Don't ask the user to opt-in per feature unless they explicitly say "minimal" — instead, generate all and let them comment out what they don't want.

### Custom headers in the Sheet
Per "Headers naming conventions" above. Master template handles this in the `setupSheetHeaders()` function.

### Dashboard tab
A second tab in the Sheet named "Dashboard" with:
- Summary stats at top (total responses, last response date, response rate if known)
- 1-3 charts based on question types in the form:
  - Linear scale questions → bar chart of distribution
  - Multiple choice / dropdown → donut chart of counts
  - NPS specifically → calculation + gauge-style chart
  - Date questions → time-series chart of responses over time
- All charts use `=ARRAYFORMULA()` so they update automatically with each new response.

See `assets/dashboard-tab-template.gs` for the exact chart configurations.

### Email notification on submit
Optional — ask the user if they want this. If yes:
- Ask for the email addresses (comma-separated)
- Ask what data to include in the email (default: all responses, formatted)
- The script installs an `onFormSubmit` trigger that sends the email

See `assets/webhook-email-template.gs`.

### Webhook on submit
Optional — ask the user if they have an HTTP endpoint to call. If yes:
- Ask for the URL
- The script POSTs the response payload as JSON
- Includes retry logic (3 attempts with exponential backoff)

See `assets/webhook-email-template.gs` (same file, separate function).

---

## Output mode: Apps Script paste-and-run

The user copies one `.gs` file → pastes into [script.google.com](https://script.google.com) → clicks Run.

The first run will prompt for permissions:
- Google Forms (create/edit forms)
- Google Sheets (create/write sheets)
- Google Drive (save form to Drive; required for image insertion)
- Gmail (only if email notification enabled)
- External requests (only if webhook enabled)

After authorizing, the script runs in 5-15 seconds and prints URLs to the Apps Script console:
- Form URL (for sharing)
- Sheet URL (for analytics)
- Edit URL (for further form tweaks)

The user can then share the Form URL with their audience.

---

## Files in this skill

- `SKILL.md` — this file (entry point, you're reading it)
- `assets/apps-script-master-template.gs` — the master template with all sections; placeholders to fill
- `assets/question-types-snippets.gs` — one snippet per question type, copy-paste into the master template
- `assets/dashboard-tab-template.gs` — Dashboard tab setup function
- `assets/webhook-email-template.gs` — onFormSubmit trigger for email + webhook
- `references/apps-script-formapp-cheatsheet.md` — full FormApp API reference (look up obscure methods)
- `references/rich-content-decision-tree.md` — extended version of the decision tree above
- `references/headers-naming-conventions.md` — full slug rules with edge cases
- `references/visual-hierarchy-claude-code-style.md` — how to translate Claude Code AskUserQuestion patterns to web form hierarchy
- `references/examples.md` — 3 complete examples (onboarding, NPS, employee engagement) — use these as templates
- `scripts/generate_rich_image.py` — Python script that produces PNG from a simple spec (table/chart/list)
- `scripts/slugify.js` — Node script for slug generation (also implementable inline in the master template)
- `evals/evals.json` — test cases for skill-creator's eval loop

---

## Common pitfalls

1. **Don't try to render markdown in the question text.** Google Forms strips it. Use the image rule.
2. **Don't forget to upload PNGs to Drive BEFORE running the script.** The script needs the File IDs to call `addImageItem(driveImage)`. The master template has a TODO comment marking where to paste them.
3. **YouTube video URLs only.** Vimeo / self-hosted won't embed. Fall back to PNG thumbnail + link.
4. **`addFileUploadItem()` requires Google Workspace.** Personal Google accounts can't enable file upload in forms. Warn the user if they have file-upload questions.
5. **Sheet headers can be customized BEFORE first response.** After the first response, Google preserves them and just appends data — but if you change them mid-collection, columns get misaligned. Generate-once at form creation.
6. **Dashboard charts update on every form submit ONLY IF** the chart is built from `ARRAYFORMULA` ranges. Don't hardcode ranges like `A2:A10` — use `A2:A` (open-ended).
7. **For Spanish forms, set the form's language** with `form.setConfirmationMessage()` and helper text in Spanish. The respondent's Google account language doesn't override the form's content.

---

## How to use this skill across iterations

This is v1. As the user runs more forms with this skill, capture patterns that don't work and refine:

- If a question type comes up repeatedly that this skill doesn't handle well → add a new snippet
- If a rich-content pattern is common (e.g., always a price comparison table) → add it as a parameterized helper in `scripts/generate_rich_image.py`
- If the headers slugger keeps getting it wrong for a specific kind of question → tune the rules in `references/headers-naming-conventions.md`
- If the user often wants the same Dashboard layout → make it a preset in `assets/dashboard-tab-template.gs`

The skill is designed to evolve. Don't keep recreating from scratch.
