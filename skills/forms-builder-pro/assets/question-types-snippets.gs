/**
 * Forms Builder Pro — Question Type Snippets
 *
 * Copy the snippet matching each question you need into the QUESTIONS BLOCK
 * of apps-script-master-template.gs. Fill in title, helpText, options as needed.
 *
 * Copia el snippet correspondiente a cada pregunta que necesites en el QUESTIONS BLOCK
 * de apps-script-master-template.gs. Llena title, helpText, options según necesidad.
 *
 * Each snippet is wrapped in `// ── BEGIN <type> ──` and `// ── END <type> ──`
 * markers for easy programmatic extraction.
 */

// ═══════════════════════════════════════════════════════════════════════════
// 1. MULTIPLE CHOICE (RADIO) — una sola respuesta de N opciones cortas
// ═══════════════════════════════════════════════════════════════════════════
// ── BEGIN multiple-choice ──
{
  // OPTIONAL: insert image before this question
  // insertImage(form, '__IMAGE_SLOT_NAME__', '__IMAGE_CAPTION__');

  const item = form.addMultipleChoiceItem();
  item.setTitle('__QUESTION_TITLE__');
  item.setHelpText('__HELPER_TEXT__'); // optional, <200 chars; describes the question
  item.setRequired(true); // change to false if optional

  // Each choice has a label; some can route to a different section (branching)
  // Cada opción tiene un label; algunas pueden ir a una sección distinta (branching)
  item.setChoices([
    item.createChoice('Option 1'),
    item.createChoice('Option 2'),
    item.createChoice('Option 3'),
    // .createChoice('Option 4', form.getItems(FormApp.ItemType.PAGE_BREAK)[0]) // branching example
  ]);

  // OPTIONAL: enable "Other" / Habilitar "Otro"
  // item.showOtherOption(true);
}
// ── END multiple-choice ──


// ═══════════════════════════════════════════════════════════════════════════
// 2. SHORT ANSWER (TEXT) — texto corto (nombre, email, número)
// ═══════════════════════════════════════════════════════════════════════════
// ── BEGIN short-answer ──
{
  // insertImage(form, '__IMAGE_SLOT_NAME__', '__IMAGE_CAPTION__'); // OPTIONAL

  const item = form.addTextItem();
  item.setTitle('__QUESTION_TITLE__');
  item.setHelpText('__HELPER_TEXT__');
  item.setRequired(true);

  // OPTIONAL: validation (email, number, regex, etc.)
  // const validation = FormApp.createTextValidation()
  //   .setHelpText('Por favor ingresá un email válido')
  //   .requireTextMatchesPattern('^[\\w._%+-]+@[\\w.-]+\\.[A-Za-z]{2,}$')
  //   .build();
  // item.setValidation(validation);
}
// ── END short-answer ──


// ═══════════════════════════════════════════════════════════════════════════
// 3. PARAGRAPH (LONG TEXT) — comentarios, descripciones largas
// ═══════════════════════════════════════════════════════════════════════════
// ── BEGIN paragraph ──
{
  // insertImage(form, '__IMAGE_SLOT_NAME__', '__IMAGE_CAPTION__'); // OPTIONAL

  const item = form.addParagraphTextItem();
  item.setTitle('__QUESTION_TITLE__');
  item.setHelpText('__HELPER_TEXT__');
  item.setRequired(false); // paragraph fields are usually optional
}
// ── END paragraph ──


// ═══════════════════════════════════════════════════════════════════════════
// 4. CHECKBOX (MULTI-SELECT) — múltiples respuestas de un set
// ═══════════════════════════════════════════════════════════════════════════
// ── BEGIN checkbox ──
{
  // insertImage(form, '__IMAGE_SLOT_NAME__', '__IMAGE_CAPTION__'); // OPTIONAL

  const item = form.addCheckboxItem();
  item.setTitle('__QUESTION_TITLE__');
  item.setHelpText('__HELPER_TEXT__');
  item.setRequired(true);
  item.setChoiceValues([
    'Option A',
    'Option B',
    'Option C',
    'Option D'
  ]);

  // OPTIONAL: limit min/max selections
  // const validation = FormApp.createCheckboxValidation()
  //   .requireSelectAtLeast(2)
  //   .requireSelectAtMost(3)
  //   .build();
  // item.setValidation(validation);
}
// ── END checkbox ──


// ═══════════════════════════════════════════════════════════════════════════
// 5. DROPDOWN (LIST) — una respuesta de 8+ opciones (donde radio se vuelve largo)
// ═══════════════════════════════════════════════════════════════════════════
// ── BEGIN dropdown ──
{
  // insertImage(form, '__IMAGE_SLOT_NAME__', '__IMAGE_CAPTION__'); // OPTIONAL

  const item = form.addListItem();
  item.setTitle('__QUESTION_TITLE__');
  item.setHelpText('__HELPER_TEXT__');
  item.setRequired(true);
  item.setChoiceValues([
    'Argentina',
    'Bolivia',
    'Chile',
    'Colombia',
    'Costa Rica',
    'Ecuador',
    'México',
    'Perú',
    'Uruguay',
    'Venezuela'
  ]);
}
// ── END dropdown ──


// ═══════════════════════════════════════════════════════════════════════════
// 6. LINEAR SCALE — NPS, ratings 1-5/1-10, satisfacción
// ═══════════════════════════════════════════════════════════════════════════
// ── BEGIN linear-scale ──
{
  // insertImage(form, '__IMAGE_SLOT_NAME__', '__IMAGE_CAPTION__'); // OPTIONAL

  const item = form.addScaleItem();
  item.setTitle('__QUESTION_TITLE__');
  item.setHelpText('__HELPER_TEXT__');
  item.setRequired(true);

  // Lower bound: 0 or 1 / Cota inferior: 0 o 1
  // Upper bound: 5 or 10 / Cota superior: 5 o 10
  item.setBounds(0, 10);

  // Labels for the endpoints / Labels en los extremos
  item.setLabels('Nada probable', 'Muy probable');
}
// ── END linear-scale ──


// ═══════════════════════════════════════════════════════════════════════════
// 7. MULTIPLE CHOICE GRID — múltiples preguntas con misma escala (matriz)
// ═══════════════════════════════════════════════════════════════════════════
// ── BEGIN grid-multi ──
{
  // insertImage(form, '__IMAGE_SLOT_NAME__', '__IMAGE_CAPTION__'); // OPTIONAL

  const item = form.addGridItem();
  item.setTitle('__QUESTION_TITLE__');
  item.setHelpText('__HELPER_TEXT__');
  item.setRequired(true);

  // Rows = items being rated / Filas = items que se rankean
  item.setRows([
    'Item A',
    'Item B',
    'Item C'
  ]);

  // Columns = rating options / Columnas = opciones de rating
  item.setColumns([
    'Pobre',
    'Regular',
    'Bueno',
    'Excelente'
  ]);
}
// ── END grid-multi ──


// ═══════════════════════════════════════════════════════════════════════════
// 8. CHECKBOX GRID — múltiples preguntas con multi-select
// ═══════════════════════════════════════════════════════════════════════════
// ── BEGIN checkbox-grid ──
{
  // insertImage(form, '__IMAGE_SLOT_NAME__', '__IMAGE_CAPTION__'); // OPTIONAL

  const item = form.addCheckboxGridItem();
  item.setTitle('__QUESTION_TITLE__');
  item.setHelpText('__HELPER_TEXT__');
  item.setRequired(true);

  item.setRows([
    'Día Lunes',
    'Día Martes',
    'Día Miércoles'
  ]);

  item.setColumns([
    'Mañana',
    'Tarde',
    'Noche'
  ]);
}
// ── END checkbox-grid ──


// ═══════════════════════════════════════════════════════════════════════════
// 9. DATE / DATETIME — fecha de nacimiento, fecha del evento
// ═══════════════════════════════════════════════════════════════════════════
// ── BEGIN date ──
{
  // insertImage(form, '__IMAGE_SLOT_NAME__', '__IMAGE_CAPTION__'); // OPTIONAL

  const item = form.addDateItem();
  item.setTitle('__QUESTION_TITLE__');
  item.setHelpText('__HELPER_TEXT__');
  item.setRequired(true);

  // OPTIONAL: include year and/or time
  // item.setIncludesYear(true);
}
// ── END date ──

// ── BEGIN datetime ──
{
  const item = form.addDateTimeItem();
  item.setTitle('__QUESTION_TITLE__');
  item.setHelpText('__HELPER_TEXT__');
  item.setRequired(true);
  // item.setIncludesYear(true);
}
// ── END datetime ──


// ═══════════════════════════════════════════════════════════════════════════
// 10. TIME — hora del día, duración
// ═══════════════════════════════════════════════════════════════════════════
// ── BEGIN time ──
{
  // insertImage(form, '__IMAGE_SLOT_NAME__', '__IMAGE_CAPTION__'); // OPTIONAL

  const item = form.addTimeItem();
  item.setTitle('__QUESTION_TITLE__');
  item.setHelpText('__HELPER_TEXT__');
  item.setRequired(true);
}
// ── END time ──


// ═══════════════════════════════════════════════════════════════════════════
// 11. FILE UPLOAD — CV, imagen, documento (requires Google Workspace)
// ═══════════════════════════════════════════════════════════════════════════
// ── BEGIN file-upload ──
{
  // NOTE: addFileUploadItem requires:
  //  - Google Workspace account (NOT personal Gmail)
  //  - Authenticated respondents (form.setCollectEmail or domain restriction)
  //
  // NOTA: addFileUploadItem requiere:
  //  - Cuenta Google Workspace (NO Gmail personal)
  //  - Respondents autenticados (form.setCollectEmail o restricción de dominio)

  // insertImage(form, '__IMAGE_SLOT_NAME__', '__IMAGE_CAPTION__'); // OPTIONAL

  const item = form.addFileUploadItem();
  item.setTitle('__QUESTION_TITLE__');
  item.setHelpText('__HELPER_TEXT__');
  item.setRequired(true);

  // Number of files allowed / Cantidad de archivos permitidos
  item.setMaxNumberOfFiles(1); // 1, 5, or 10

  // Max size in MB (1, 10, 100, 1000, 10000)
  // Tamaño máximo en MB
  item.setMaxFileSize(10);

  // Allowed file types / Tipos de archivo permitidos
  item.setAllowedFileTypes([
    FormApp.FileType.PDF,
    // FormApp.FileType.DOCUMENT,
    // FormApp.FileType.SPREADSHEET,
    // FormApp.FileType.PRESENTATION,
    // FormApp.FileType.IMAGE,
    // FormApp.FileType.VIDEO,
  ]);
}
// ── END file-upload ──


// ═══════════════════════════════════════════════════════════════════════════
// 12. SECTION DIVIDER (PAGE BREAK) — separa el form en chapters; habilita branching
// ═══════════════════════════════════════════════════════════════════════════
// ── BEGIN section-divider ──
{
  const item = form.addPageBreakItem();
  item.setTitle('§N. __SECTION_TITLE__');
  item.setHelpText('__SECTION_DESCRIPTION__'); // optional intro for this section

  // OPTIONAL: control what happens after this section
  // item.setGoToPage(FormApp.PageNavigationType.CONTINUE); // default: continue to next
  // item.setGoToPage(FormApp.PageNavigationType.SUBMIT);   // skip rest, submit
  // item.setGoToPage(someOtherPageBreakItem);              // branch to specific page
}
// ── END section-divider ──


// ═══════════════════════════════════════════════════════════════════════════
// 13. SECTION HEADER (NO INPUT) — título + descripción larga, sin pregunta
// Useful for adding narrative/explanation BEFORE a series of questions.
// Útil para agregar narrativa/explicación ANTES de una serie de preguntas.
// ═══════════════════════════════════════════════════════════════════════════
// ── BEGIN section-header ──
{
  // insertImage(form, '__IMAGE_SLOT_NAME__', '__IMAGE_CAPTION__'); // OPTIONAL

  const item = form.addSectionHeaderItem();
  item.setTitle('__HEADER_TITLE__');
  item.setHelpText('__HEADER_DESCRIPTION__'); // can be longer than question helpText
}
// ── END section-header ──


// ═══════════════════════════════════════════════════════════════════════════
// 14. IMAGE INSERT (NO INPUT) — display a generated PNG (table, chart, etc.)
// Use insertImage() helper from the master template; this is the raw snippet.
// Usá el helper insertImage() del master template; este es el snippet crudo.
// ═══════════════════════════════════════════════════════════════════════════
// ── BEGIN image-item ──
{
  const fileId = CONFIG.IMAGE_IDS['__IMAGE_SLOT_NAME__'];
  const blob = DriveApp.getFileById(fileId).getBlob();
  const imageItem = form.addImageItem();
  imageItem.setImage(blob);
  imageItem.setTitle('__IMAGE_CAPTION__'); // shown above the image
  imageItem.setHelpText('__IMAGE_ALT_TEXT__'); // shown below, smaller font
  imageItem.setAlignment(FormApp.Alignment.CENTER); // LEFT, CENTER, RIGHT
  imageItem.setWidth(600); // pixels, max 740
}
// ── END image-item ──


// ═══════════════════════════════════════════════════════════════════════════
// 15. VIDEO ITEM (NO INPUT) — embed YouTube video
// Usá el helper insertYoutubeVideo() del master template; este es el snippet crudo.
// ═══════════════════════════════════════════════════════════════════════════
// ── BEGIN video-item ──
{
  const videoItem = form.addVideoItem();
  videoItem.setVideoUrl('https://www.youtube.com/watch?v=__VIDEO_ID__');
  videoItem.setTitle('__VIDEO_CAPTION__');
  videoItem.setHelpText('__VIDEO_DESCRIPTION__');
  videoItem.setAlignment(FormApp.Alignment.CENTER);
  videoItem.setWidth(600);
}
// ── END video-item ──
