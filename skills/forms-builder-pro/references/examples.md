# Examples — Forms Builder Pro

> 3 complete worked examples. Use these as templates / inspiration when authoring
> similar forms. Each example shows: user intent → structure → slugs → Apps Script
> excerpts → dashboard config.

---

## Example 1 — Onboarding Survey (Corporate)

### User intent
> "Necesito una encuesta de onboarding para nuevos miembros del equipo de AI.
> 8 preguntas mix de multi-choice, scale, paragraph. Quiero que tenga una tabla
> comparativa de las herramientas que usamos y un video corto del CEO dando bienvenida.
> Dashboard con NPS de la experiencia."

### Proposed structure

```
Form: "Onboarding AI Team 2026" (Spanish, 3 sections, 8 questions)

§1. Identificación (3 preguntas)
  1. nombre              — short answer, required
  2. fecha_inicio        — date, required
  3. rol                 — dropdown [PM, Eng, Designer, Researcher, Other], required

§2. Experiencia previa (3 preguntas)
  [video] YouTube embed "Bienvenida del CEO" (2 min)
  [image] Tabla comparativa Claude vs ChatGPT vs Copilot vs Gemini
  4. herramienta_anterior — multiple choice (radio), required
  5. años_experiencia_ai — linear scale 0-10, required
  6. proyectos_relevantes — paragraph, optional

§3. Onboarding feedback (2 preguntas)
  7. nps_onboarding      — linear scale 0-10 (Detractor → Promoter), required
  8. comentarios_extra   — paragraph, optional
```

### Slugs proposed

| Question | Slug |
|---|---|
| Timestamp (auto) | `timestamp` |
| ¿Cuál es tu nombre completo? | `nombre` |
| ¿Fecha de inicio en el equipo? | `fecha_inicio` |
| ¿Cuál es tu rol principal? | `rol` |
| ¿Qué herramienta AI usabas antes? | `herramienta_anterior` |
| Años de experiencia con herramientas AI | `años_experiencia_ai` |
| Proyectos AI relevantes en los que trabajaste | `proyectos_relevantes` |
| ¿Cómo calificarías tu experiencia de onboarding? | `nps_onboarding` |
| ¿Comentarios adicionales? | `comentarios_extra` |

### Apps Script excerpt (questions block)

```javascript
// §1. Identificación
insertPageBreak(form, '§1. Identificación', 'Cuéntanos quién eres');

form.addTextItem()
  .setTitle('¿Cuál es tu nombre completo?')
  .setHelpText('Para personalizar nuestra comunicación contigo')
  .setRequired(true);

form.addDateItem()
  .setTitle('¿Fecha de inicio en el equipo?')
  .setIncludesYear(true)
  .setRequired(true);

const rolItem = form.addListItem();
rolItem.setTitle('¿Cuál es tu rol principal?');
rolItem.setRequired(true);
rolItem.setChoiceValues(['Product Manager', 'Engineer', 'Designer', 'Researcher', 'Other']);

// §2. Experiencia previa
insertPageBreak(form, '§2. Experiencia previa', 'Mira el video del CEO antes de responder');

insertYoutubeVideo(form, 'https://www.youtube.com/watch?v=WELCOME_VID_ID', 'Bienvenida del CEO (2 min)');

insertImage(form, 'comparison_table', 'Comparación de las 4 herramientas AI principales');

const herramientaItem = form.addMultipleChoiceItem();
herramientaItem.setTitle('¿Qué herramienta AI usabas antes de unirte al equipo?');
herramientaItem.setHelpText('Mira la tabla de arriba si necesitas refrescar diferencias');
herramientaItem.setRequired(true);
herramientaItem.setChoices([
  herramientaItem.createChoice('Claude (Anthropic)'),
  herramientaItem.createChoice('ChatGPT (OpenAI)'),
  herramientaItem.createChoice('Copilot (GitHub/Microsoft)'),
  herramientaItem.createChoice('Gemini (Google)'),
  herramientaItem.createChoice('Otra'),
  herramientaItem.createChoice('Ninguna')
]);

form.addScaleItem()
  .setTitle('Años de experiencia con herramientas AI')
  .setHelpText('0 = ninguna experiencia, 10 = experto avanzado')
  .setBounds(0, 10)
  .setLabels('Ninguna', '10+ años')
  .setRequired(true);

form.addParagraphTextItem()
  .setTitle('¿Proyectos AI relevantes en los que trabajaste?')
  .setHelpText('Breve descripción, opcional')
  .setRequired(false);

// §3. Onboarding feedback
insertPageBreak(form, '§3. Onboarding feedback', 'Tu opinión nos ayuda a mejorar');

form.addScaleItem()
  .setTitle('¿Cómo calificarías tu experiencia de onboarding?')
  .setHelpText('0-6 = Detractor, 7-8 = Pasivo, 9-10 = Promoter')
  .setBounds(0, 10)
  .setLabels('Muy mala', 'Excelente')
  .setRequired(true);

form.addParagraphTextItem()
  .setTitle('¿Comentarios adicionales?')
  .setRequired(false);
```

### Dashboard config

```javascript
const DASHBOARD_CONFIG = [
  { type: 'kpi',        title: 'Total Respuestas',           source: 'count_all' },
  { type: 'kpi',        title: 'Última Respuesta',            source: 'max_timestamp' },
  { type: 'nps',        title: 'NPS Onboarding',             source: 'nps_onboarding' },
  { type: 'donut',      title: 'Distribución por Rol',        source: 'rol' },
  { type: 'donut',      title: 'Herramienta Previa',          source: 'herramienta_anterior' },
  { type: 'bar',        title: 'Años de Experiencia AI',      source: 'años_experiencia_ai' },
  { type: 'timeseries', title: 'Respuestas por Día',          source: 'timestamp' }
];
```

### Rich content needed

- `comparison_table.png` — table 4×5 (Headers: Tool, Strengths, Weaknesses, Best for, Price)
  - Generate with: `python generate_rich_image.py table --spec comparison_spec.json --output ./images/comparison_table.png`

---

## Example 2 — Customer Feedback NPS

### User intent
> "Encuesta de satisfacción post-compra. 5 preguntas cortas. NPS, dropdown categoría,
> comentarios. Webhook a mi backend en `https://api.misitio.com/feedback` cada vez
> que alguien responda. Email al admin cuando NPS < 6."

### Proposed structure

```
Form: "Customer Feedback Q1 2026" (Spanish, 1 section, 5 questions)

  1. nombre              — short answer, optional
  2. email_cliente       — short answer with email validation, required
  3. categoria_producto  — dropdown, required
  4. nps                 — linear scale 0-10, required
  5. comentarios         — paragraph, optional
```

### Slugs proposed

| Question | Slug |
|---|---|
| Timestamp (auto) | `timestamp` |
| ¿Cuál es tu nombre? | `nombre` |
| Email | `email_cliente` |
| ¿Qué categoría de producto compraste? | `categoria_producto` |
| ¿Qué tan probable es que nos recomiendes? | `nps` |
| Comentarios | `comentarios` |

### Apps Script excerpt

```javascript
form.addTextItem()
  .setTitle('¿Cuál es tu nombre?')
  .setRequired(false);

const emailItem = form.addTextItem();
emailItem.setTitle('Email');
emailItem.setHelpText('Para responder a tu feedback si es necesario');
emailItem.setRequired(true);
emailItem.setValidation(FormApp.createTextValidation()
  .setHelpText('Por favor ingresá un email válido')
  .requireTextMatchesPattern('^[\\w._%+-]+@[\\w.-]+\\.[A-Za-z]{2,}$')
  .build());

const catItem = form.addListItem();
catItem.setTitle('¿Qué categoría de producto compraste?');
catItem.setRequired(true);
catItem.setChoiceValues([
  'Electrónicos',
  'Ropa',
  'Hogar',
  'Salud y Belleza',
  'Deportes',
  'Otros'
]);

form.addScaleItem()
  .setTitle('¿Qué tan probable es que nos recomiendes a un amigo?')
  .setHelpText('0 = nunca lo haría, 10 = totalmente recomendaría')
  .setBounds(0, 10)
  .setLabels('No recomendaría', 'Recomendaría sin dudar')
  .setRequired(true);

form.addParagraphTextItem()
  .setTitle('Comentarios')
  .setHelpText('Cuéntanos qué te gustó o qué podríamos mejorar')
  .setRequired(false);
```

### L3 features config

```javascript
const CONFIG = {
  ...,
  enableDashboard: true,
  enableEmailNotify: true,
  enableWebhook: true,
  emailNotifyTo: 'admin@misitio.com',
  webhookUrl: 'https://api.misitio.com/feedback'
};
```

### Submit handler customization (Spanish-specific email logic)

```javascript
function onFormSubmitHandler(e) {
  const payload = buildPayload(e);

  // Always send webhook
  if (CONFIG.enableWebhook && CONFIG.webhookUrl) {
    try { sendWebhook(payload); } catch (err) { retryWebhook(payload, 1); }
  }

  // ONLY send email if NPS < 6 (detractor — needs immediate attention)
  if (CONFIG.enableEmailNotify && payload.answers.nps !== undefined && payload.answers.nps < 6) {
    try { sendNotificationEmail(payload); } catch (err) { Logger.log(err); }
  }
}
```

### Dashboard config

```javascript
const DASHBOARD_CONFIG = [
  { type: 'kpi',        title: 'Total Feedback',              source: 'count_all' },
  { type: 'nps',        title: 'NPS Score',                   source: 'nps' },
  { type: 'donut',      title: 'Por Categoría',                source: 'categoria_producto' },
  { type: 'timeseries', title: 'Respuestas Diarias',          source: 'timestamp' }
];
```

---

## Example 3 — Employee Engagement Survey

### User intent
> "Encuesta de engagement anual. 12 preguntas en 3 secciones. Incluye una matriz
> donde rankean diferentes aspectos del trabajo. File upload opcional para
> 'comentarios privados al CEO' (PDF). Dashboard sin webhook."

### Proposed structure

```
Form: "Encuesta Engagement Anual 2026" (Spanish, 3 sections, 12 questions)

§1. Sobre vos (4 preguntas)
  1. anonimo             — checkbox, optional ("Marca si quieres permanecer anónimo")
  2. departamento        — dropdown, required (10 opciones)
  3. años_empresa        — linear scale 0-15+, required
  4. modalidad_trabajo   — multiple choice [Remote, Hybrid, Office], required

§2. Engagement (5 preguntas)
  [section header] "Califica cada dimensión de 1 (muy mal) a 5 (excelente)"
  [image] Lista de dimensiones con descripciones (qué significa cada una)
  5. matriz_dimensiones  — multiple choice grid (5 rows × 5 cols), required
  6. nps_empresa         — linear scale 0-10 "¿Recomendarías la empresa?"
  7. probabilidad_quedarse — linear scale 1-5 "¿Probabilidad de seguir 1 año más?"
  8. razon_quedarse      — checkbox multi (8 opciones), optional
  9. razon_irse          — paragraph, optional

§3. Cierre (3 preguntas)
  10. iniciativa_a_priorizar — checkbox multi (6 opciones), required
  11. sugerencias_abierta    — paragraph, optional
  12. comentarios_privados   — file upload (PDF, opcional, "Solo lo lee el CEO")
```

### Slugs proposed

| Question | Slug |
|---|---|
| Timestamp (auto) | `timestamp` |
| Permanecer anónimo | `anonimo` |
| Departamento | `departamento` |
| Años en la empresa | `años_empresa` |
| Modalidad de trabajo | `modalidad_trabajo` |
| Matriz dimensiones engagement | `matriz_dimensiones` |
| ¿Recomendarías la empresa? (NPS) | `nps_empresa` |
| ¿Probabilidad de seguir 1 año más? | `probabilidad_quedarse` |
| ¿Por qué te quedarías? | `razon_quedarse` |
| ¿Por qué te irías? | `razon_irse` |
| Iniciativas a priorizar | `iniciativa_a_priorizar` |
| Sugerencias abiertas | `sugerencias_abierta` |
| Comentarios privados al CEO (PDF) | `comentarios_privados` |

### Rich content needed

- `dimensiones_explanation.png` — list (style: bulleted) with 5 items, each with title + description
  - Title: "Autonomía"            Description: "Libertad para decidir cómo hacer tu trabajo"
  - Title: "Crecimiento"          Description: "Oportunidades reales de aprender y subir"
  - Title: "Equipo"               Description: "Calidad de las relaciones con tus colegas"
  - Title: "Liderazgo"            Description: "Claridad y soporte de tu manager directo"
  - Title: "Impacto"              Description: "Visión de cómo tu trabajo mueve la aguja"

### Apps Script excerpt (the grid item is the interesting part)

```javascript
const gridItem = form.addGridItem();
gridItem.setTitle('Califica cada dimensión de tu trabajo');
gridItem.setHelpText('1 = muy mal, 5 = excelente — mira la lista de arriba para definiciones');
gridItem.setRequired(true);
gridItem.setRows([
  'Autonomía',
  'Crecimiento',
  'Equipo',
  'Liderazgo',
  'Impacto'
]);
gridItem.setColumns([
  '1 — Muy mal',
  '2 — Mal',
  '3 — OK',
  '4 — Bien',
  '5 — Excelente'
]);
```

### File upload (with Workspace warning)

```javascript
// ⚠ WARNING: file upload requires Google Workspace account.
// If user is on personal Gmail, comment out this block and use paragraph instead.
const fileItem = form.addFileUploadItem();
fileItem.setTitle('Comentarios privados al CEO (PDF, opcional)');
fileItem.setHelpText('Solo lo lee el CEO. Máximo 1 archivo, 10 MB. Anónimo si marcaste arriba.');
fileItem.setRequired(false);
fileItem.setMaxNumberOfFiles(1);
fileItem.setMaxFileSize(10);
fileItem.setAllowedFileTypes([FormApp.FileType.PDF]);
```

### Dashboard config

```javascript
const DASHBOARD_CONFIG = [
  { type: 'kpi',        title: 'Total Respuestas',                source: 'count_all' },
  { type: 'kpi',        title: 'Tasa Anónimos',                   source: 'anonimo' }, // % checked
  { type: 'nps',        title: 'NPS Empresa',                     source: 'nps_empresa' },
  { type: 'donut',      title: 'Distribución por Departamento',   source: 'departamento' },
  { type: 'donut',      title: 'Modalidad de Trabajo',            source: 'modalidad_trabajo' },
  { type: 'bar',        title: 'Probabilidad de Quedarse (1-5)',  source: 'probabilidad_quedarse' },
  { type: 'timeseries', title: 'Respuestas en el Tiempo',         source: 'timestamp' }
];
```

---

## Common patterns across examples

1. **First section is always identification/demographics** — quick to fill, sets context
2. **Rich content (images, videos) goes in middle sections** — where comprehension matters most
3. **Open-ended/optional questions go LAST** — respondents drop off; protect the must-haves
4. **NPS is its own dedicated chart** in the dashboard (different from regular bar)
5. **File upload only with explicit Workspace check + fallback note**
6. **Helper text is conversational and brief** — never repeats the question
7. **Section breaks include a 1-line intro** to set expectations
8. **Required-vs-optional is conscious** — over-requiring kills response rates
