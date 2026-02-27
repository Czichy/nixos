// =============================================================================
// Edu-Search – Hilfsfunktionen
// =============================================================================
// HTML-Escaping, Highlighting, URL-Encoding, Clipboard, Filepath-Konvertierung
// =============================================================================

(function (E) {
  "use strict";

  // ---------------------------------------------------------------------------
  // HTML-Escaping (XSS-Schutz)
  // ---------------------------------------------------------------------------

  /**
   * Escaped alle HTML-Sonderzeichen in einem String.
   * @param {string} str
   * @returns {string} Escaped HTML
   */
  E.escapeHtml = function (str) {
    if (!str) return "";
    var div = document.createElement("div");
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  };

  /**
   * Escaped HTML, lässt aber <mark>/<\/mark> Tags von MeiliSearch-Highlighting
   * bestehen. Wird für Dateinamen und Thema-Felder verwendet.
   * @param {string} str
   * @returns {string} HTML mit erlaubten <mark>-Tags
   */
  E.safeHighlight = function (str) {
    if (!str) return "";
    var escaped = E.escapeHtml(str);
    escaped = escaped.replace(/&lt;mark&gt;/g, "<mark>");
    escaped = escaped.replace(/&lt;\/mark&gt;/g, "</mark>");
    return escaped;
  };

  // ---------------------------------------------------------------------------
  // URL-Encoding
  // ---------------------------------------------------------------------------

  /**
   * Encoded einen Dateipfad für URLs – jedes Segment einzeln encoden,
   * damit Schrägstriche erhalten bleiben, Sonderzeichen aber encoded werden.
   * @param {string} path - z.B. "ina/schule/Klasse 7/test (1).pdf"
   * @returns {string} Encoded Pfad
   */
  E.encodeURIPath = function (path) {
    return path
      .split("/")
      .map(function (segment) {
        return encodeURIComponent(segment);
      })
      .join("/");
  };

  /**
   * Konvertiert einen lokalen NAS-Pfad in eine Browser-URL.
   * Nginx mapped /files/ → /nas/ (alias in webui.nix).
   *
   * @param {string|null} filepath - z.B. "/nas/ina/schule/test.pdf"
   * @returns {string|null} URL z.B. "/files/ina/schule/test.pdf" oder null
   */
  E.filepathToUrl = function (filepath) {
    if (!filepath) return null;
    if (filepath.indexOf("/nas/") === 0) {
      return E.FILES_BASE + "/" + E.encodeURIPath(filepath.substring(5));
    }
    return null;
  };

  // ---------------------------------------------------------------------------
  // Clipboard
  // ---------------------------------------------------------------------------

  /**
   * Text in die Zwischenablage kopieren mit visueller Rückmeldung am Button.
   * Nutzt die moderne Clipboard API mit Fallback auf execCommand.
   * @param {string} text - Zu kopierender Text
   * @param {HTMLElement} buttonEl - Button für visuelles Feedback
   */
  E.copyToClipboard = function (text, buttonEl) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard
        .writeText(text)
        .then(function () {
          showCopyFeedback(buttonEl, true);
        })
        .catch(function () {
          fallbackCopy(text, buttonEl);
        });
    } else {
      fallbackCopy(text, buttonEl);
    }
  };

  /**
   * Fallback-Clipboard-Kopie via verstecktes textarea + execCommand.
   * Für ältere Browser oder wenn die Clipboard API nicht verfügbar ist.
   */
  function fallbackCopy(text, buttonEl) {
    var textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.style.position = "fixed";
    textarea.style.opacity = "0";
    document.body.appendChild(textarea);
    textarea.select();
    try {
      document.execCommand("copy");
      showCopyFeedback(buttonEl, true);
    } catch (e) {
      showCopyFeedback(buttonEl, false);
    }
    document.body.removeChild(textarea);
  }

  /**
   * Zeigt visuelles Feedback am Copy-Button (✅ Kopiert! / ❌ Fehler).
   * Stellt nach 1.5s den Original-Inhalt wieder her.
   */
  function showCopyFeedback(buttonEl, success) {
    if (!buttonEl) return;
    var originalHtml = buttonEl.innerHTML;
    buttonEl.innerHTML = success ? "\u2705 Kopiert!" : "\u274C Fehler";
    buttonEl.disabled = true;
    setTimeout(function () {
      buttonEl.innerHTML = originalHtml;
      buttonEl.disabled = false;
    }, 1500);
  }
})(window.EduSearch);
