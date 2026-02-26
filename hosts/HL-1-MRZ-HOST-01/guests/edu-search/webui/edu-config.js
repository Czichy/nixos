// =============================================================================
// Edu-Search – Konfiguration & Konstanten
// =============================================================================
// Shared namespace: window.EduSearch
// Alle Module registrieren sich hier.
// =============================================================================

window.EduSearch = window.EduSearch || {};

(function (E) {
  "use strict";

  // ---------------------------------------------------------------------------
  // API-Konfiguration
  // ---------------------------------------------------------------------------

  E.MEILI_URL = "/meili";
  E.INDEX_NAME = "edu_documents";
  E.RESULTS_PER_PAGE = 30;
  E.DEBOUNCE_MS = 250;

  // Dateien werden via /files/ von Nginx direkt ausgeliefert.
  // filepath im Index ist z.B. "/nas/ina/schule/test.pdf"
  // → URL wird: "/files/ina/schule/test.pdf"
  E.FILES_BASE = "/files";

  // ---------------------------------------------------------------------------
  // Datei-Icon Mapping (Extension → Emoji)
  // ---------------------------------------------------------------------------

  E.FILE_ICONS = {
    ".pdf": "\uD83D\uDCC4",
    ".docx": "\uD83D\uDDD2\uFE0F",
    ".doc": "\uD83D\uDDD2\uFE0F",
    ".pptx": "\uD83D\uDCCA",
    ".ppt": "\uD83D\uDCCA",
    ".xlsx": "\uD83D\uDCCA",
    ".xls": "\uD83D\uDCCA",
    ".odt": "\uD83D\uDCC4",
    ".odp": "\uD83D\uDCCA",
    ".ods": "\uD83D\uDCCA",
    ".txt": "\uD83D\uDCC3",
    ".rtf": "\uD83D\uDCC3",
    ".html": "\uD83C\uDF10",
    ".htm": "\uD83C\uDF10",
    ".epub": "\uD83D\uDCD6",
    ".csv": "\uD83D\uDCCA",
    ".mp3": "\uD83C\uDFB5",
    ".mp4": "\uD83C\uDFAC",
    ".m4a": "\uD83C\uDFB5",
    ".wav": "\uD83C\uDFB5",
    ".ogg": "\uD83C\uDFB5",
    ".flac": "\uD83C\uDFB5",
    ".webm": "\uD83C\uDFAC",
    ".jpg": "\uD83D\uDDBC\uFE0F",
    ".jpeg": "\uD83D\uDDBC\uFE0F",
    ".png": "\uD83D\uDDBC\uFE0F",
    ".gif": "\uD83D\uDDBC\uFE0F",
    ".svg": "\uD83D\uDDBC\uFE0F",
  };

  // ---------------------------------------------------------------------------
  // Vorschau-fähige Dateitypen
  // ---------------------------------------------------------------------------
  // Schlüssel = Preview-Kategorie, Wert = Liste von Extensions (ohne Punkt)

  E.PREVIEW_TYPES = {
    pdf: ["pdf"],
    image: ["jpg", "jpeg", "png", "gif", "svg", "webp", "bmp", "tiff", "tif"],
    audio: ["mp3", "m4a", "wav", "ogg", "flac"],
    video: ["mp4", "webm"],
    text: ["txt", "csv", "md", "xml", "json"],
  };

  // Menschenlesbare Labels für den Vorschau-Button
  E.PREVIEW_LABELS = {
    pdf: "\uD83D\uDCC4 Vorschau",
    image: "\uD83D\uDDBC\uFE0F Vorschau",
    audio: "\uD83C\uDFB5 Anh\u00F6ren",
    video: "\uD83C\uDFAC Abspielen",
    text: "\uD83D\uDCC3 Textvorschau",
  };

  // ---------------------------------------------------------------------------
  // Hilfsfunktionen
  // ---------------------------------------------------------------------------

  /**
   * Emoji-Icon für eine Dateiendung ermitteln.
   * @param {string|null} extension - z.B. ".pdf"
   * @returns {string} Emoji
   */
  E.getFileIcon = function (extension) {
    if (!extension) return "\uD83D\uDCC1";
    return E.FILE_ICONS[extension.toLowerCase()] || "\uD83D\uDCC1";
  };

  /**
   * Preview-Kategorie für eine Dateiendung ermitteln.
   * @param {string|null} extension - z.B. ".pdf" oder "pdf"
   * @returns {string|null} "pdf", "image", "audio", "video", "text" oder null
   */
  E.getPreviewType = function (extension) {
    if (!extension) return null;
    var ext = extension.toLowerCase().replace(/^\./, "");
    for (var type in E.PREVIEW_TYPES) {
      if (E.PREVIEW_TYPES.hasOwnProperty(type)) {
        if (E.PREVIEW_TYPES[type].indexOf(ext) !== -1) {
          return type;
        }
      }
    }
    return null;
  };

  /**
   * Menschenlesbares Label für den Vorschau-Button.
   * @param {string|null} extension
   * @returns {string|null} Label oder null wenn keine Vorschau möglich
   */
  E.getPreviewLabel = function (extension) {
    var type = E.getPreviewType(extension);
    return type ? E.PREVIEW_LABELS[type] || "Vorschau" : null;
  };
})(window.EduSearch);
