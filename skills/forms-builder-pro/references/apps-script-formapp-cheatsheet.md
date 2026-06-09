# Apps Script FormApp Cheatsheet

> Reference of every FormApp method needed for `forms-builder-pro`.
> Use this when the master template or snippets need extending.
> Full API: https://developers.google.com/apps-script/reference/forms

---

## Form-level methods

```javascript
const form = FormApp.create('Title');                       // creates new form
const form = FormApp.openById('formId');                    // opens existing
const form = FormApp.openByUrl('https://...');              // opens existing

form.setTitle('New Title');
form.setDescription('Description shown at top');
form.setConfirmationMessage('Shown after submission');
form.setShowLinkToRespondAgain(false);                      // hide "Submit another"
form.setLimitOneResponsePerUser(true);                      // requires sign-in
form.setCollectEmail(true);                                 // captures respondent email
form.setAllowResponseEdits(true);                           // lets respondent edit later
form.setAcceptingResponses(true);                           // toggle accepting on/off
form.setIsQuiz(true);                                       // quiz mode (with scoring)
form.setProgressBar(true);                                  // show progress at top
form.setShuffleQuestions(false);                            // randomize question order

form.getEditUrl();                                          // editor URL (private)
form.getPublishedUrl();                                     // public URL to fill
form.getId();                                               // form ID
form.getResponses();                                        // FormResponse[]
form.deleteResponse('responseId');                          // delete a single response
form.deleteAllResponses();

form.setDestination(FormApp.DestinationType.SPREADSHEET, sheetId); // link to Sheet
```

---

## Adding items (questions + content)

All `add*Item` methods return the item object, which you then configure.
All return the item; chainable in some cases but not all.

### Question types

```javascript
// Multiple choice (radio buttons)
const mc = form.addMultipleChoiceItem();
mc.setTitle('Question?')
  .setHelpText('Helper below title')
  .setRequired(true)
  .setChoices([
    mc.createChoice('Option 1'),
    mc.createChoice('Option 2', someNavigationTarget), // optional 2nd arg for branching
  ])
  .showOtherOption(true);                              // adds "Other: [text input]"

// Short answer (single line)
const text = form.addTextItem();
text.setTitle('Q?').setHelpText('...').setRequired(true);
// Optional validation
const v = FormApp.createTextValidation()
  .setHelpText('Validation error msg')
  .requireTextMatchesPattern('^[\\w._%+-]+@[\\w.-]+\\.[A-Za-z]{2,}$') // email regex
  .build();
text.setValidation(v);
// Other validations: requireNumber, requireNumberBetween(min,max), requireWholeNumber,
//  requireTextContainsPattern, requireTextDoesNotContainPattern, requireTextLengthGreaterThanOrEqualTo(n)

// Paragraph (multi-line)
const p = form.addParagraphTextItem();
p.setTitle('Q?').setRequired(false);
const pv = FormApp.createParagraphTextValidation()
  .requireTextLengthGreaterThanOrEqualTo(50)
  .build();
p.setValidation(pv);

// Checkbox (multi-select)
const cb = form.addCheckboxItem();
cb.setTitle('Q?').setChoiceValues(['A', 'B', 'C']).setRequired(true);
const cbv = FormApp.createCheckboxValidation()
  .requireSelectAtLeast(2)
  .requireSelectAtMost(3)
  .build();
cb.setValidation(cbv);

// Dropdown (list — single answer from longer list)
const dd = form.addListItem();
dd.setTitle('Q?').setChoiceValues(['Argentina', 'Brasil', 'Chile']).setRequired(true);

// Linear scale (1-5, 0-10, etc)
const scale = form.addScaleItem();
scale.setTitle('NPS — How likely to recommend?')
     .setBounds(0, 10)               // min, max (0-5 or 1-10 etc)
     .setLabels('Not likely', 'Very likely')
     .setRequired(true);

// Multiple choice grid (matrix of questions w/ same options)
const grid = form.addGridItem();
grid.setTitle('Rate each:')
    .setRows(['Item A', 'Item B', 'Item C'])
    .setColumns(['Poor', 'Fair', 'Good', 'Excellent'])
    .setRequired(true);

// Checkbox grid (matrix with multi-select per row)
const cbg = form.addCheckboxGridItem();
cbg.setTitle('Available times:')
   .setRows(['Mon', 'Tue', 'Wed'])
   .setColumns(['Morning', 'Afternoon', 'Evening'])
   .setRequired(true);

// Date
const d = form.addDateItem();
d.setTitle('Date?').setIncludesYear(true).setRequired(true);

// DateTime
const dt = form.addDateTimeItem();
dt.setTitle('Date+Time?').setIncludesYear(true).setRequired(true);

// Time
const t = form.addTimeItem();
t.setTitle('What time?').setRequired(true);

// Duration (hours/minutes/seconds)
const dur = form.addDurationItem();
dur.setTitle('How long?').setRequired(true);

// File upload (requires Google Workspace + collectEmail or domain restriction)
const fu = form.addFileUploadItem();
fu.setTitle('Upload file:')
  .setMaxNumberOfFiles(1)              // 1, 5, or 10
  .setMaxFileSize(10)                  // MB: 1, 10, 100, 1000, 10000
  .setAllowedFileTypes([
    FormApp.FileType.PDF,
    FormApp.FileType.IMAGE,
    FormApp.FileType.DOCUMENT,
    FormApp.FileType.SPREADSHEET,
    FormApp.FileType.PRESENTATION,
    FormApp.FileType.VIDEO,
    FormApp.FileType.AUDIO,
    FormApp.FileType.DRAWING,
  ])
  .setRequired(true);
```

### Non-question items (content)

```javascript
// Image (insert PNG/JPG from Drive)
const img = form.addImageItem();
img.setImage(DriveApp.getFileById('FILE_ID').getBlob())
   .setTitle('Caption shown above image')
   .setHelpText('Alt text / description below')
   .setAlignment(FormApp.Alignment.CENTER)  // LEFT, CENTER, RIGHT
   .setWidth(600);                          // px, max 740

// Video (YouTube embed ONLY)
const vid = form.addVideoItem();
vid.setVideoUrl('https://www.youtube.com/watch?v=VIDEO_ID')
   .setTitle('Caption above video')
   .setHelpText('Description below')
   .setAlignment(FormApp.Alignment.CENTER)
   .setWidth(600);

// Section header (title + description, no input)
const sh = form.addSectionHeaderItem();
sh.setTitle('Section Heading')
  .setHelpText('Longer descriptive text shown below the heading');

// Page break (creates a new section/page — required for branching)
const pb = form.addPageBreakItem();
pb.setTitle('Section 2: Demographics')
  .setHelpText('Optional intro for this section')
  .setGoToPage(FormApp.PageNavigationType.CONTINUE);
  // Other options: SUBMIT (skip rest), RESTART, or pass another PageBreakItem for branching
```

---

## Branching (conditional navigation)

Only `MultipleChoiceItem` and `ListItem` support branching, and only when the form
has multiple sections (added via `addPageBreakItem`).

```javascript
const pb_section2 = form.addPageBreakItem().setTitle('Section 2');
const pb_section3 = form.addPageBreakItem().setTitle('Section 3');

// Then on the question:
const q = form.addMultipleChoiceItem();
q.setTitle('Are you new or returning?');
q.setChoices([
  q.createChoice('New', pb_section2),       // go to Section 2
  q.createChoice('Returning', pb_section3), // go to Section 3
  q.createChoice('Skip', FormApp.PageNavigationType.SUBMIT) // submit immediately
]);
```

---

## Response retrieval (post-submission)

```javascript
// Iterate all responses
const responses = form.getResponses();
for (const r of responses) {
  const ts = r.getTimestamp();
  const email = r.getRespondentEmail(); // null if not collected
  const id = r.getId();
  const editUrl = r.getEditResponseUrl();
  const items = r.getItemResponses();   // ItemResponse[]
  for (const it of items) {
    const itemTitle = it.getItem().getTitle();
    const answer = it.getResponse();    // string | string[] | Date | etc per question type
  }
}

// In an onFormSubmit trigger, you have:
function onFormSubmit(e) {
  e.response                            // FormResponse
  e.source                              // Form
  e.values                              // [timestamp, q1, q2, ...] sheet-style array
  e.namedValues                         // {questionTitle: [answer]} keyed by question
}
```

---

## Triggers (event-driven automation)

```javascript
// Install a trigger that runs onFormSubmit whenever the form receives a submission
ScriptApp.newTrigger('myHandler')
  .forForm(form)
  .onFormSubmit()
  .create();

// Other triggers:
ScriptApp.newTrigger('myHandler').forSpreadsheet(ss).onChange().create();
ScriptApp.newTrigger('myHandler').timeBased().everyHours(1).create();
ScriptApp.newTrigger('myHandler').timeBased().atHour(9).everyDays(1).create();

// List + delete existing triggers (avoid duplicates)
const triggers = ScriptApp.getProjectTriggers();
triggers.forEach(t => {
  if (t.getEventType() === ScriptApp.EventType.ON_FORM_SUBMIT) ScriptApp.deleteTrigger(t);
});
```

---

## Common pitfalls & gotchas

1. **`addImageItem` requires `DriveApp.getFileById(id).getBlob()`.** You can't pass a URL directly.
2. **Image File IDs must be uploaded to Drive BEFORE running the script.** The script can't create the image; the user provides it.
3. **`addFileUploadItem` only works for Google Workspace accounts.** Personal Gmail users see an error. Detect and warn.
4. **`form.setDestination(SPREADSHEET, sheetId)` is one-time per form.** To switch destination, you must call `form.removeDestination()` first.
5. **The auto-created "Form Responses" sheet is appended to the destination spreadsheet.** It's the LAST sheet in `ss.getSheets()`. Don't assume index 0.
6. **Custom headers must be set AFTER `setDestination` AND AFTER waiting ~2s** for Google to create the linked tab.
7. **`onFormSubmit` trigger requires authorization on FIRST submission.** Test by submitting yourself once.
8. **`MailApp.sendEmail` is rate-limited to 100 emails/day on consumer accounts**, 1500/day on Workspace.
9. **`UrlFetchApp.fetch` external requests need user authorization** the first time per script.
10. **YouTube embed: only `youtube.com/watch?v=X` URLs work.** Not `youtu.be/X` shortened, not embed URLs. Convert before passing.

---

## Useful helpers

```javascript
// Sleep / wait
Utilities.sleep(2000); // ms

// Format date
Utilities.formatDate(new Date(), 'America/Argentina/Buenos_Aires', 'dd-MM-yyyy HH:mm');

// Generate UUID
Utilities.getUuid();

// Hash a string (e.g., for anonymization)
const digest = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, 'input', Utilities.Charset.UTF_8);
const hex = digest.map(b => ('0' + (b & 0xff).toString(16)).slice(-2)).join('');

// Log to console (visible in Apps Script editor)
Logger.log('Message');
console.log('Also works in newer runtimes');
```
