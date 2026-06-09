/**
 * Forms Builder Pro — Dashboard Tab Template
 *
 * This is the implementation that gets pasted into setupDashboard() in the master template.
 * The skill parameterizes it per form: which slugs to chart and what chart type each.
 *
 * Esta es la implementación que se pega en setupDashboard() del master template.
 * El skill la parametriza por form: qué slugs graficar y qué tipo de chart para cada uno.
 *
 * Supported chart types / Tipos de chart soportados:
 *  - 'bar'       (BAR / COLUMN)        — distribution of values for choice/dropdown/scale
 *  - 'donut'     (PIE/DOUGHNUT)        — share of total for choice/checkbox
 *  - 'timeseries' (LINE)               — responses over time (uses timestamp column)
 *  - 'nps'       (custom calculation)  — Net Promoter Score with gauge + breakdown
 *  - 'kpi'       (single number tile)  — count, avg, max, min of a column
 */

function setupDashboard(spreadsheet) {
  // Configuration: which charts to build (skill auto-generates this from form questions)
  // Configuración: qué charts construir (skill auto-genera esto desde las preguntas del form)
  const DASHBOARD_CONFIG = __DASHBOARD_CHARTS_CONFIG__;
  // Example structure / Estructura ejemplo:
  // [
  //   { type: 'kpi', title: 'Total Respuestas', source: 'count_all' },
  //   { type: 'kpi', title: 'Última Respuesta', source: 'max_timestamp' },
  //   { type: 'nps', title: 'NPS Score', source: 'nps' },
  //   { type: 'donut', title: 'Distribución por Rol', source: 'rol' },
  //   { type: 'bar', title: 'Años de Experiencia', source: 'años_experiencia' },
  //   { type: 'timeseries', title: 'Respuestas por Día', source: 'timestamp' }
  // ]

  // Create the Dashboard tab / Crear la tab Dashboard
  let dashboard = spreadsheet.getSheetByName('Dashboard');
  if (dashboard) {
    // Tab existed from a previous run — clear it
    // Tab existía de un run anterior — limpiar
    dashboard.clear();
    dashboard.getCharts().forEach(c => dashboard.removeChart(c));
  } else {
    dashboard = spreadsheet.insertSheet('Dashboard');
  }

  // Header / Encabezado
  dashboard.getRange('A1').setValue('📊 Dashboard — ' + CONFIG.formTitle);
  dashboard.getRange('A1').setFontSize(18).setFontWeight('bold').setFontColor('#1e293b');
  dashboard.getRange('A2').setValue('Actualizado automáticamente con cada respuesta');
  dashboard.getRange('A2').setFontSize(10).setFontColor('#64748b').setFontStyle('italic');

  let currentRow = 4;
  const responseSheet = spreadsheet.getSheetByName('Respuestas');
  const headerRow = responseSheet.getRange(1, 1, 1, CONFIG.customHeaders.length).getValues()[0];

  for (const chartConfig of DASHBOARD_CONFIG) {
    currentRow = renderChart(dashboard, responseSheet, headerRow, chartConfig, currentRow);
    currentRow += 2; // gap between charts
  }

  // Auto-resize columns / Auto-resize columnas
  dashboard.autoResizeColumns(1, 8);
}

/**
 * Render one chart/KPI on the Dashboard tab based on its config.
 * Renderiza un chart/KPI en la tab Dashboard según su config.
 */
function renderChart(dashboard, responseSheet, headerRow, chartConfig, startRow) {
  // Find the column for this source / Buscar la columna para este source
  const sourceCol = headerRow.indexOf(chartConfig.source) + 1;
  if (chartConfig.source !== 'count_all' && chartConfig.source !== 'max_timestamp' && sourceCol === 0) {
    Logger.log('⚠ Source not found in headers: ' + chartConfig.source + ' (skipping)');
    return startRow;
  }
  const colLetter = columnToLetter(sourceCol);

  // Title for this chart / Título para este chart
  dashboard.getRange(startRow, 1).setValue(chartConfig.title);
  dashboard.getRange(startRow, 1).setFontSize(14).setFontWeight('bold').setFontColor('#1e293b');
  startRow += 1;

  switch (chartConfig.type) {
    case 'kpi':
      return renderKpi(dashboard, responseSheet, chartConfig, startRow, colLetter);
    case 'nps':
      return renderNps(dashboard, responseSheet, chartConfig, startRow, colLetter);
    case 'bar':
      return renderBarChart(dashboard, responseSheet, chartConfig, startRow, colLetter);
    case 'donut':
      return renderDonutChart(dashboard, responseSheet, chartConfig, startRow, colLetter);
    case 'timeseries':
      return renderTimeSeries(dashboard, responseSheet, chartConfig, startRow, colLetter);
    default:
      Logger.log('⚠ Unknown chart type: ' + chartConfig.type);
      return startRow;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// KPI TILE — single big number with caption
// ═══════════════════════════════════════════════════════════════════════════
function renderKpi(dashboard, responseSheet, config, row, colLetter) {
  const responseSheetName = "'Respuestas'!";

  let formula;
  switch (config.source) {
    case 'count_all':
      formula = '=COUNTA(' + responseSheetName + 'A2:A)';
      break;
    case 'max_timestamp':
      formula = '=IFERROR(TEXT(MAX(' + responseSheetName + 'A2:A), "dd-mm-yyyy HH:mm"), "Sin respuestas")';
      break;
    default:
      // Numeric column: show avg
      formula = '=IFERROR(ROUND(AVERAGE(' + responseSheetName + colLetter + '2:' + colLetter + '), 2), 0)';
  }

  const kpiCell = dashboard.getRange(row, 1);
  kpiCell.setFormula(formula);
  kpiCell.setFontSize(32).setFontWeight('bold').setFontColor('#0ea5e9').setHorizontalAlignment('left');

  return row + 1;
}

// ═══════════════════════════════════════════════════════════════════════════
// NPS — Net Promoter Score calculation + breakdown
// Promoters (9-10) - Detractors (0-6), Passives (7-8) excluded
// ═══════════════════════════════════════════════════════════════════════════
function renderNps(dashboard, responseSheet, config, row, colLetter) {
  const responseSheetName = "'Respuestas'!";
  const range = responseSheetName + colLetter + '2:' + colLetter;

  // Promoters (9-10) %
  dashboard.getRange(row, 1).setValue('Promoters (9-10)');
  dashboard.getRange(row, 2).setFormula(
    '=IFERROR(ROUND(COUNTIFS(' + range + ',">=9")/COUNTA(' + range + ')*100,1) & "%","0%")'
  );

  // Passives (7-8) %
  dashboard.getRange(row + 1, 1).setValue('Passives (7-8)');
  dashboard.getRange(row + 1, 2).setFormula(
    '=IFERROR(ROUND(COUNTIFS(' + range + ',">=7",' + range + ',"<=8")/COUNTA(' + range + ')*100,1) & "%","0%")'
  );

  // Detractors (0-6) %
  dashboard.getRange(row + 2, 1).setValue('Detractors (0-6)');
  dashboard.getRange(row + 2, 2).setFormula(
    '=IFERROR(ROUND(COUNTIFS(' + range + ',"<=6")/COUNTA(' + range + ')*100,1) & "%","0%")'
  );

  // NPS = % Promoters - % Detractors
  dashboard.getRange(row + 4, 1).setValue('NPS Score');
  dashboard.getRange(row + 4, 1).setFontWeight('bold');
  dashboard.getRange(row + 4, 2).setFormula(
    '=IFERROR(ROUND(' +
      '(COUNTIFS(' + range + ',">=9") - COUNTIFS(' + range + ',"<=6"))' +
      '/COUNTA(' + range + ')*100, 1),0)'
  );
  dashboard.getRange(row + 4, 2).setFontSize(24).setFontWeight('bold').setFontColor('#0ea5e9');

  return row + 6;
}

// ═══════════════════════════════════════════════════════════════════════════
// BAR CHART — distribution of values
// ═══════════════════════════════════════════════════════════════════════════
function renderBarChart(dashboard, responseSheet, config, row, colLetter) {
  // Build a summary table from the response data using QUERY
  // Construir tabla resumen desde la data de respuestas usando QUERY
  const responseSheetName = "'Respuestas'!";

  // Place summary at columns A-B starting at row
  // Colocar resumen en columnas A-B desde row
  dashboard.getRange(row, 1).setFormula(
    '=QUERY(' + responseSheetName + colLetter + '2:' + colLetter + ',' +
    '"SELECT ' + colLetter + ', COUNT(' + colLetter + ') WHERE ' + colLetter + ' IS NOT NULL ' +
    'GROUP BY ' + colLetter + ' ORDER BY COUNT(' + colLetter + ') DESC LABEL ' + colLetter + ' \'\'", 0)'
  );

  // Build the chart
  // Wait for the QUERY to populate before building the chart
  Utilities.sleep(500);

  const lastRow = dashboard.getLastRow();
  const dataRange = dashboard.getRange(row, 1, Math.max(lastRow - row + 1, 2), 2);

  const chart = dashboard.newChart()
    .setChartType(Charts.ChartType.BAR)
    .addRange(dataRange)
    .setPosition(row, 4, 0, 0)
    .setOption('title', config.title + ' — Distribución')
    .setOption('width', 500)
    .setOption('height', 300)
    .setOption('legend', { position: 'none' })
    .setOption('colors', ['#0ea5e9'])
    .build();

  dashboard.insertChart(chart);

  return row + 12; // chart takes ~12 rows of vertical space
}

// ═══════════════════════════════════════════════════════════════════════════
// DONUT CHART — share of total
// ═══════════════════════════════════════════════════════════════════════════
function renderDonutChart(dashboard, responseSheet, config, row, colLetter) {
  const responseSheetName = "'Respuestas'!";

  dashboard.getRange(row, 1).setFormula(
    '=QUERY(' + responseSheetName + colLetter + '2:' + colLetter + ',' +
    '"SELECT ' + colLetter + ', COUNT(' + colLetter + ') WHERE ' + colLetter + ' IS NOT NULL ' +
    'GROUP BY ' + colLetter + ' LABEL ' + colLetter + ' \'\'", 0)'
  );

  Utilities.sleep(500);
  const lastRow = dashboard.getLastRow();
  const dataRange = dashboard.getRange(row, 1, Math.max(lastRow - row + 1, 2), 2);

  const chart = dashboard.newChart()
    .setChartType(Charts.ChartType.PIE)
    .addRange(dataRange)
    .setPosition(row, 4, 0, 0)
    .setOption('title', config.title)
    .setOption('width', 500)
    .setOption('height', 300)
    .setOption('pieHole', 0.4) // donut style / estilo dona
    .setOption('colors', ['#0ea5e9', '#8b5cf6', '#10b981', '#f59e0b', '#ef4444', '#64748b'])
    .build();

  dashboard.insertChart(chart);
  return row + 12;
}

// ═══════════════════════════════════════════════════════════════════════════
// TIME SERIES — responses over time
// ═══════════════════════════════════════════════════════════════════════════
function renderTimeSeries(dashboard, responseSheet, config, row, colLetter) {
  const responseSheetName = "'Respuestas'!";

  // Group responses by day / Agrupar respuestas por día
  dashboard.getRange(row, 1).setFormula(
    '=QUERY(' + responseSheetName + 'A2:A,' +
    '"SELECT TODATE(A), COUNT(A) WHERE A IS NOT NULL ' +
    'GROUP BY TODATE(A) ORDER BY TODATE(A) LABEL TODATE(A) \'Fecha\', COUNT(A) \'Respuestas\'", 0)'
  );

  Utilities.sleep(500);
  const lastRow = dashboard.getLastRow();
  const dataRange = dashboard.getRange(row, 1, Math.max(lastRow - row + 1, 2), 2);

  const chart = dashboard.newChart()
    .setChartType(Charts.ChartType.LINE)
    .addRange(dataRange)
    .setPosition(row, 4, 0, 0)
    .setOption('title', config.title)
    .setOption('width', 600)
    .setOption('height', 300)
    .setOption('legend', { position: 'none' })
    .setOption('colors', ['#0ea5e9'])
    .setOption('hAxis', { format: 'd MMM' })
    .build();

  dashboard.insertChart(chart);
  return row + 12;
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPER: column number → letter (1 → A, 27 → AA)
// ═══════════════════════════════════════════════════════════════════════════
function columnToLetter(col) {
  let letter = '';
  while (col > 0) {
    const mod = (col - 1) % 26;
    letter = String.fromCharCode(65 + mod) + letter;
    col = Math.floor((col - mod) / 26);
  }
  return letter;
}
