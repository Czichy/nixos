// =============================================================================
// Edu-Search – Ergebnis-Karten Rendering
// =============================================================================
// Erzeugt die HTML-Karten für Suchergebnisse. Jede Karte enthält:
//   - Dateiname mit Highlighting
//   - Metadaten-Tags (Fach, Klasse, Typ, Niveau, Extension)
//   - Thema-Beschreibung mit Highlighting
//   - Aktions-Buttons (Vorschau, Herunterladen, Pfad kopieren)
//   - UNC-Pfad (sichtbar bei Hover)
//
// API:
//   EduSearch.renderCard(hit)           – HTML-String für eine Ergebnis-Karte
//   EduSearch.attachCardListeners(root) – Event-Listener an Karten binden
// =============================================================================

(function (E) {
  "use strict";

  // ---------------------------------------------------------------------------
  // Einzelne Ergebnis-Karte als HTML rendern
  // ---------------------------------------------------------------------------

  /**
   * Erzeugt den HTML-String für eine Ergebnis-Karte.
   *
   * @param {Object} hit – MeiliSearch-Hit (mit _formatted für Highlighting)
   * @param {number} index – Index in der aktuellen Ergebnisliste (für data-attr)
   * @returns {string} HTML-String
   */
  E.renderCard = function (hit, index) {
    var hl = hit._formatted || hit;
    var fachLower = (hit.fach || "").toLowerCase();
    var fachClass = "";
    if (fachLower.indexOf("englisch") !== -1) fachClass = " fach-englisch";
    else if (fachLower.indexOf("spanisch") !== -1) fachClass = " fach-spanisch";

    var icon = E.getFileIcon(hit.file_extension);
    var fileUrl = E.filepathToUrl(hit.filepath);
    var previewType = E.getPreviewType(hit.file_extension);
    var previewLabel = E.getPreviewLabel(hit.file_extension);
    var uncPath = hit.unc_path || "";

    // --- Tags ---
    var tagsHtml = buildTagsHtml(hit, fachClass);

    // --- Thema ---
    var themaHtml = "";
    if (hit.thema) {
      var themaText = hl.thema || hit.thema;
      themaHtml = '<div class="thema">' + E.safeHighlight(themaText) + "</div>";
    }

    // --- Aktions-Buttons ---
    var actionsHtml = buildActionsHtml(hit, index, fileUrl, previewLabel, uncPath);

    // --- UNC-Pfad (nur bei Hover sichtbar) ---
    var pathInfoHtml = "";
    if (uncPath) {
      pathInfoHtml =
        '<div class="path-info">' +
        '<span class="path-text">' + E.escapeHtml(uncPath) + "</span>" +
        "</div>";
    }

    // --- Karte zusammenbauen ---
    return (
      '<div class="result-card" data-hit-index="' + index + '">' +
      '<div class="card-header">' +
      '<span class="file-icon">' + icon + "</span>" +
      '<span class="filename">' +
      E.safeHighlight(hl.filename || hit.filename) +
      "</span>" +
      "</div>" +
      '<div class="meta">' + tagsHtml + "</div>" +
      themaHtml +
      '<div class="card-actions">' + actionsHtml + "</div>" +
      pathInfoHtml +
      "</div>"
    );
  };

  // ---------------------------------------------------------------------------
  // Tags-HTML zusammenbauen
  // ---------------------------------------------------------------------------

  function buildTagsHtml(hit, fachClass) {
    var tags = [];

    if (hit.fach && hit.fach !== "unbekannt") {
      tags.push(
        '<span class="tag' + fachClass + '">' +
        E.escapeHtml(hit.fach) +
        "</span>"
      );
    }
    if (hit.klasse && hit.klasse !== "unbekannt") {
      tags.push(
        '<span class="tag">Klasse ' + E.escapeHtml(hit.klasse) + "</span>"
      );
    }
    if (hit.typ && hit.typ !== "Sonstiges") {
      tags.push('<span class="tag">' + E.escapeHtml(hit.typ) + "</span>");
    }
    if (hit.niveau && hit.niveau !== "unbekannt") {
      tags.push('<span class="tag">' + E.escapeHtml(hit.niveau) + "</span>");
    }
    if (hit.file_extension) {
      tags.push(
        '<span class="tag tag-ext">' +
        E.escapeHtml(hit.file_extension) +
        "</span>"
      );
    }

    return tags.join("");
  }

  // ---------------------------------------------------------------------------
  // Aktions-Buttons zusammenbauen
  // ---------------------------------------------------------------------------

  function buildActionsHtml(hit, index, fileUrl, previewLabel, uncPath) {
    var buttons = [];

    // Vorschau-Button (nur wenn Vorschau möglich)
    if (previewLabel && fileUrl) {
      buttons.push(
        '<button class="card-action-btn action-preview" ' +
        'data-hit-index="' + index + '" ' +
        'title="Vorschau \u00F6ffnen">' +
        previewLabel +
        "</button>"
      );
    }

    // Download-Button (immer wenn URL vorhanden)
    if (fileUrl) {
      buttons.push(
        '<a class="card-action-btn action-download" ' +
        'href="' + E.escapeHtml(fileUrl) + '" ' +
        'download="' + E.escapeHtml(hit.filename || "") + '" ' +
        'title="Datei herunterladen">' +
        "\u2B07\uFE0F Download" +
        "</a>"
      );
    }

    // Pfad-kopieren-Button (wenn UNC-Pfad vorhanden)
    if (uncPath) {
      buttons.push(
        '<button class="card-action-btn action-copy" ' +
        'data-path="' + E.escapeHtml(uncPath) + '" ' +
        'title="Netzwerkpfad in die Zwischenablage kopieren">' +
        "\uD83D\uDCCB Pfad kopieren" +
        "</button>"
      );
    }

    return buttons.join("");
  }

  // ---------------------------------------------------------------------------
  // Event-Listener an Karten-Buttons binden
  // ---------------------------------------------------------------------------

  /**
   * Bindet Event-Listener an alle Aktions-Buttons innerhalb des gegebenen
   * Container-Elements. Muss nach jedem renderCard/renderResults aufgerufen
   * werden (für die neu eingefügten Elemente).
   *
   * @param {HTMLElement} root – Container (z.B. #results)
   * @param {Array} hitsArray – Die aktuelle Liste der MeiliSearch-Hits
   */
  E.attachCardListeners = function (root, hitsArray) {
    // --- Vorschau-Buttons ---
    var previewBtns = root.querySelectorAll(".action-preview");
    for (var i = 0; i < previewBtns.length; i++) {
      attachPreviewListener(previewBtns[i], hitsArray);
    }

    // --- Copy-Buttons ---
    var copyBtns = root.querySelectorAll(".action-copy");
    for (var j = 0; j < copyBtns.length; j++) {
      attachCopyListener(copyBtns[j]);
    }

    // --- Download-Buttons: Stop propagation ---
    var dlBtns = root.querySelectorAll(".action-download");
    for (var k = 0; k < dlBtns.length; k++) {
      attachDownloadListener(dlBtns[k]);
    }

    // --- Klick auf die Karte selbst → Vorschau oder Download ---
    var cards = root.querySelectorAll(".result-card");
    for (var m = 0; m < cards.length; m++) {
      attachCardClickListener(cards[m], hitsArray);
    }
  };

  function attachPreviewListener(btn, hitsArray) {
    if (btn.dataset.listenerAttached) return;
    btn.dataset.listenerAttached = "true";
    btn.addEventListener("click", function (e) {
      e.preventDefault();
      e.stopPropagation();
      var idx = parseInt(this.dataset.hitIndex, 10);
      if (hitsArray[idx]) {
        E.openPreview(hitsArray[idx]);
      }
    });
  }

  function attachCopyListener(btn) {
    if (btn.dataset.listenerAttached) return;
    btn.dataset.listenerAttached = "true";
    btn.addEventListener("click", function (e) {
      e.preventDefault();
      e.stopPropagation();
      var path = this.dataset.path;
      if (path) {
        E.copyToClipboard(path, this);
      }
    });
  }

  function attachDownloadListener(btn) {
    if (btn.dataset.listenerAttached) return;
    btn.dataset.listenerAttached = "true";
    btn.addEventListener("click", function (e) {
      e.stopPropagation();
      // Download-Link normal folgen lassen (kein preventDefault)
    });
  }

  function attachCardClickListener(card, hitsArray) {
    if (card.dataset.cardListenerAttached) return;
    card.dataset.cardListenerAttached = "true";
    card.addEventListener("click", function (e) {
      // Nur reagieren wenn kein Button/Link geklickt wurde
      if (
        e.target.closest(".card-action-btn") ||
        e.target.closest("a")
      ) {
        return;
      }
      var idx = parseInt(this.dataset.hitIndex, 10);
      var hit = hitsArray[idx];
      if (!hit) return;

      var fileUrl = E.filepathToUrl(hit.filepath);
      var previewType = E.getPreviewType(hit.file_extension);

      if (previewType && fileUrl) {
        // Vorschau-fähig → Modal öffnen
        E.openPreview(hit);
      } else if (fileUrl) {
        // Nicht vorschau-fähig → Download starten
        var a = document.createElement("a");
        a.href = fileUrl;
        a.download = hit.filename || "";
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
      }
    });
  }
})(window.EduSearch);
