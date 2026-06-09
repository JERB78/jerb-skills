#!/usr/bin/env node
/**
 * Forms Builder Pro — Slugify Question Text into Sheet Headers
 *
 * Converts a question's display text into a clean snake_case slug suitable
 * as a column header in the linked Google Sheet.
 *
 * Convierte el texto de una pregunta en un slug snake_case limpio,
 * apto como header de columna en la Google Sheet vinculada.
 *
 * USAGE / USO:
 *   node slugify.js "¿Cuál es tu nombre completo?"
 *   # → nombre
 *
 *   node slugify.js --batch '["¿Cuál es tu nombre?", "Años de experiencia", "Comentarios"]'
 *   # → ["nombre","años_experiencia","comentarios"]
 *
 *   node slugify.js --batch-resolve-collisions '[...]'
 *   # → adds _2, _3 suffixes to duplicates
 *
 * RULES / REGLAS:
 *   1. snake_case always
 *   2. strip stop words (el, la, los, las, un, una, the, a, ¿, ?, !, ., ,)
 *   3. take first 1-3 meaningful words, max 20 chars
 *   4. preserve Spanish accents (ñ, á, é, í, ó, ú)
 *   5. lowercase
 */

const STOP_WORDS_ES = new Set([
  'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas',
  'de', 'del', 'al', 'en', 'a', 'y', 'o', 'u', 'e',
  'es', 'son', 'fue', 'sea', 'ser', 'estar', 'esta', 'este',
  'tu', 'su', 'mi', 'me', 'te', 'se', 'que', 'qué', 'cuál', 'cuáles', 'cuanto', 'cuántos', 'cuanta', 'cuántas',
  'tienes', 'tiene', 'tienen', 'tuvieron', 'hay'
]);

const STOP_WORDS_EN = new Set([
  'the', 'a', 'an', 'of', 'in', 'on', 'at', 'to', 'for', 'with', 'by', 'from',
  'is', 'are', 'was', 'were', 'be', 'being', 'been',
  'your', 'my', 'his', 'her', 'their', 'our',
  'what', 'which', 'who', 'whom', 'whose', 'where', 'when', 'why', 'how',
  'do', 'does', 'did', 'have', 'has', 'had'
]);

const STOP_WORDS = new Set([...STOP_WORDS_ES, ...STOP_WORDS_EN]);

const MAX_LEN = 20;
const MAX_WORDS = 3;

/**
 * Convert one question string into a slug.
 * Convertir un string de pregunta en slug.
 */
function slugify(text) {
  if (!text || typeof text !== 'string') return 'untitled';

  // 1. Lowercase + strip punctuation that Google Forms questions usually have
  // 1. Lowercase + quitar puntuación común en preguntas de Google Forms
  let s = text.toLowerCase()
    .replace(/[¿?¡!.,;:()"'\[\]{}]/g, '')
    .replace(/[-/\\]/g, ' ')
    .trim();

  // 2. Split into words / Separar en palabras
  let words = s.split(/\s+/).filter(w => w.length > 0);

  // 3. Drop stop words / Quitar stop words
  words = words.filter(w => !STOP_WORDS.has(w));

  // 4. Take first MAX_WORDS / Tomar primeras MAX_WORDS
  words = words.slice(0, MAX_WORDS);

  // 5. Join with underscore / Unir con guión bajo
  let slug = words.join('_');

  // 6. Trim to MAX_LEN / Recortar a MAX_LEN
  if (slug.length > MAX_LEN) {
    slug = slug.substring(0, MAX_LEN).replace(/_[^_]*$/, ''); // trim at word boundary
  }

  // 7. Fallback if nothing left / Fallback si quedó vacío
  if (!slug) {
    slug = 'campo_' + Math.random().toString(36).substring(2, 6);
  }

  return slug;
}

/**
 * Resolve collisions in a list of slugs by appending _2, _3, etc.
 * Resolver colisiones en una lista de slugs agregando _2, _3, etc.
 */
function resolveCollisions(slugs) {
  const seen = {};
  return slugs.map(slug => {
    if (seen[slug] === undefined) {
      seen[slug] = 1;
      return slug;
    } else {
      seen[slug] += 1;
      return `${slug}_${seen[slug]}`;
    }
  });
}

/**
 * Slugify a batch of questions, optionally resolving collisions.
 * Slugify un batch de preguntas, opcionalmente resolviendo colisiones.
 */
function slugifyBatch(questions, resolveCol = true) {
  let slugs = questions.map(slugify);
  if (resolveCol) slugs = resolveCollisions(slugs);
  return slugs;
}

// ═══════════════════════════════════════════════════════════════════════════
// CLI
// ═══════════════════════════════════════════════════════════════════════════

if (require.main === module) {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.error('USAGE: slugify.js "question text" | --batch \'["q1","q2"]\' | --batch-resolve-collisions \'[...]\'');
    process.exit(1);
  }

  if (args[0] === '--batch' || args[0] === '--batch-resolve-collisions') {
    const questions = JSON.parse(args[1]);
    const resolveCol = args[0] === '--batch-resolve-collisions';
    const slugs = slugifyBatch(questions, resolveCol);
    console.log(JSON.stringify(slugs));
  } else {
    console.log(slugify(args[0]));
  }
}

module.exports = { slugify, slugifyBatch, resolveCollisions };
