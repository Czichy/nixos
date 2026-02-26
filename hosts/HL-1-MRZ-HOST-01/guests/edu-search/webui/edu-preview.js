// =============================================================================
// Edu-Search – Vorschau-Modal
// =============================================================================
// Lazily erstelltes Modal für Dokumentenvorschau:
//   PDF    → <object> mit <iframe>-Fallback
//   Bilder → <img>
//   Audio  → <audio> mit Controls
//   Video  → <video> mit Controls
//   Text   → <pre> via fetch
//   Andere → Download-Hinweis
//
// API:
//   EduSearch.openPreview(hit)   – Modal öffnen für einen MeiliSearch-Hit
//   EduSearch.closePreview()     – Modal schließen
// =============================================================================

(function (E) {
  "use strict";

  var overlayEl = null;
  var titleEl = null;
  var bodyEl = null;
  var downloadBtn = null;

  // ---------------------------------------------------------------------------
  // Modal-DOM einmalig erzeugen (lazy)
  // ---------------------------------------------------------------------------

  function ensureModal() {
    if (overlayEl) return;

    overlayEl = document.createElement("div");
    overlayEl.id = "preview-overlay";
    overlayEl.className = "preview-overlay";

    var modal = document.createElement("div");
    modal.className = "preview-modal";

    // --- Header ---
    var header = document.createElement("div");
    header.className = "preview-header";

    titleEl = document.createElement("span");
    titleEl.className = "preview-title";

    var actions = document.createElement("div");
    actions.className = "preview-header-actions";

    downloadBtn = document.createElement("a");
    downloadBtn.className = "preview-action-btn preview-download-link";
    downloadBtn.title = "Herunterladen";
    downloadBtn.textContent = "\u2B07\uFE0F Herunterladen";

    var closeBtn = document.createElement("button");
    closeBtn.className = "preview-action-btn preview-close-btn";
    closeBtn.title = "Schlie\u00DFen";
    closeBtn.textContent = "\u2715";
    closeBtn.addEventListener("click", E.closePreview);

    actions.appendChild(downloadBtn);
    actions.appendChild(closeBtn);
    header.appendChild(titleEl);
    header.appendChild(actions);

    // --- Body ---
    bodyEl = document.createElement("div");
    bodyEl.className = "preview-body";

    modal.appendChild(header);
    modal.appendChild(bodyEl);
    overlayEl.appendChild(modal);
    document.body.appendChild(overlayEl);

    // Klick auf Overlay (außerhalb Modal) schließt
    overlayEl.addEventListener("click", function (e) {
      if (e.target === overlayEl) {
        E.closePreview();
      }
    });

    // Escape-Taste schließt
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && overlayEl.classList.contains("visible")) {
        E.closePreview();
        e.stopPropagation();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Modal schließen
  // ---------------------------------------------------------------------------

  E.closePreview = function () {
    if (!overlayEl) return;
    overlayEl.classList.remove("visible");
    // Medien stoppen (Audio/Video weiterlaufen verhindern)
    var media = bodyEl.querySelectorAll("audio, video");
    for (var i = 0; i < media.length; i++) {
      media[i].pause();
    }
    bodyEl.innerHTML = "";
    document.body.style.overflow = "";
  };

  // ---------------------------------------------------------------------------
  // Modal öffnen für einen MeiliSearch-Hit
  // ---------------------------------------------------------------------------

  E.openPreview = function (hit) {
    ensureModal();

    var fileUrl = E.filepathToUrl(hit.filepath);
    var previewType = E.getPreviewType(hit.file_extension);
    var filename = hit.filename || "Dokument";
    var icon = E.getFileIcon(hit.file_extension);

    // Titel
    titleEl.textContent = icon + " " + filename;

    // Download-Link
    if (fileUrl) {
      downloadBtn.href = fileUrl;
      downloadBtn.setAttribute("download", filename);
      downloadBtn.style.display = "inline-flex";
    } else {
      downloadBtn.removeAttribute("href");
      downloadBtn.removeAttribute("download");
      downloadBtn.style.display = "none";
    }

    // Body leeren
    bodyEl.innerHTML = "";

    // Kein URL → Fehler
    if (!fileUrl) {
      renderUnavailable("Der Dateipfad konnte nicht aufgel\u00F6st werden.");
    } else if (previewType === "pdf") {
      renderPdf(fileUrl);
    } else if (previewType === "image") {
      renderImage(fileUrl, filename);
    } else if (previewType === "audio") {
      renderAudio(fileUrl, filename);
    } else if (previewType === "video") {
      renderVideo(fileUrl);
    } else if (previewType === "text") {
      renderText(fileUrl);
    } else {
      renderNoPreview(hit, fileUrl, filename);
    }

    // Modal anzeigen
    overlayEl.classList.add("visible");
    document.body.style.overflow = "hidden";
  };

  // ---------------------------------------------------------------------------
  // Render-Funktionen je Dateityp
  // ---------------------------------------------------------------------------

  function renderUnavailable(message) {
    var div = document.createElement("div");
    div.className = "preview-unavailable";
    div.innerHTML =
      "<p>\u26A0\uFE0F Dateivorschau nicht verf\u00FCgbar</p>" +
      '<p class="preview-hint">' + E.escapeHtml(message) + "</p>";
    bodyEl.appendChild(div);
  }

  function renderPdf(url) {
    // <object> mit <iframe>-Fallback für maximale Browser-Kompatibilität
    var obj = document.createElement("object");
    obj.className = "preview-pdf";
    obj.setAttribute("data", url + "#toolbar=1&navpanes=0");
    obj.setAttribute("type", "application/pdf");

    var iframe = document.createElement("iframe");
    iframe.className = "preview-pdf";
    iframe.src = url;
    obj.appendChild(iframe);

    bodyEl.appendChild(obj);
  }

  function renderImage(url, alt) {
    var img = document.createElement("img");
    img.className = "preview-image";
    img.src = url;
    img.alt = alt;
    img.onerror = function () {
      bodyEl.innerHTML = "";
      renderUnavailable("Bild konnte nicht geladen werden.");
    };
    bodyEl.appendChild(img);
  }

  function renderAudio(url, filename) {
    var container = document.createElement("div");
    container.className = "preview-media-container";

    var iconDiv = document.createElement("div");
    iconDiv.className = "preview-media-icon";
    iconDiv.textContent = "\uD83C\uDFB5";

    var nameP = document.createElement("p");
    nameP.className = "preview-media-filename";
    nameP.textContent = filename;

    var audio = document.createElement("audio");
    audio.className = "preview-audio";
    audio.controls = true;
    audio.preload = "metadata";
    audio.src = url;

    container.appendChild(iconDiv);
    container.appendChild(nameP);
    container.appendChild(audio);
    bodyEl.appendChild(container);
  }

  function renderVideo(url) {
    var video = document.createElement("video");
    video.className = "preview-video";
    video.controls = true;
    video.preload = "metadata";
    video.src = url;
    bodyEl.appendChild(video);
  }

  function renderText(url) {
    var loading = document.createElement("div");
    loading.className = "loading";
    loading.textContent = "Lade Textvorschau";
    bodyEl.appendChild(loading);

    fetch(url)
      .then(function (resp) {
        if (!resp.ok) throw new Error("HTTP " + resp.status);
        return resp.text();
      })
      .then(function (text) {
        bodyEl.innerHTML = "";
        var pre = document.createElement("pre");
        pre.className = "preview-text";
        // Limit auf 100 KB für Performance
        pre.textContent = text.length > 100000
          ? text.substring(0, 100000) + "\n\n[… gekürzt …]"
          : text;
        bodyEl.appendChild(pre);
      })
      .catch(function (err) {
        bodyEl.innerHTML = "";
        renderUnavailable("Text konnte nicht geladen werden: " + err.message);
      });
  }

  function renderNoPreview(hit, fileUrl, filename) {
    var container = document.createElement("div");
    container.className = "preview-unavailable";

    var iconDiv = document.createElement("div");
    iconDiv.className = "preview-media-icon";
    iconDiv.textContent = E.getFileIcon(hit.file_extension);

    var msgP = document.createElement("p");
    var ext = E.escapeHtml(hit.file_extension || "unbekannt");
    msgP.innerHTML =
      "F\u00FCr diesen Dateityp (<strong>" + ext +
      "</strong>) ist keine Vorschau verf\u00FCgbar.";

    var hintP = document.createElement("p");
    hintP.className = "preview-hint";
    hintP.textContent = "Klicke auf \u201EHerunterladen\u201C um die Datei zu \u00F6ffnen.";

    container.appendChild(iconDiv);
    container.appendChild(msgP);
    container.appendChild(hintP);
    bodyEl.appendChild(container);
  }
})(window.EduSearch);
