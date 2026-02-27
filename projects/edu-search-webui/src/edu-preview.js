// =============================================================================
// Edu-Search – Vorschau-Modal
// =============================================================================
// Lazily erstelltes Modal für Dokumentenvorschau:
//   PDF    → <object> mit <iframe>-Fallback
//   Bilder → <img>
//   Audio  → <audio> mit Controls
//   Video  → <video> mit Controls
//   Text   → <pre> via fetch
//   Office → HTML via Apache Tika (doc, docx, odt, pptx, xlsx, rtf, epub …)
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
    } else if (previewType === "office") {
      renderOffice(fileUrl, filename);
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
      '<p class="preview-hint">' +
      E.escapeHtml(message) +
      "</p>";
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
        pre.textContent =
          text.length > 100000
            ? text.substring(0, 100000) + "\n\n[… gekürzt …]"
            : text;
        bodyEl.appendChild(pre);
      })
      .catch(function (err) {
        bodyEl.innerHTML = "";
        renderUnavailable("Text konnte nicht geladen werden: " + err.message);
      });
  }

  // -------------------------------------------------------------------------
  // Office-Dokument-Vorschau via Apache Tika (HTML-Extraktion)
  // -------------------------------------------------------------------------
  // 1. Datei vom Server als Blob holen (/files/…)
  // 2. Blob an Tika senden (PUT /api/tika/ mit Accept: text/html)
  // 3. Tika gibt HTML zurück (mit Formatierung: fett, kursiv, Tabellen…)
  // 4. HTML in einem sandboxed <iframe> im Preview-Modal anzeigen
  // -------------------------------------------------------------------------

  function renderOffice(url, filename) {
    // Ladeanimation
    var loading = document.createElement("div");
    loading.className = "loading";
    loading.textContent = "Konvertiere Dokument\u2026";
    bodyEl.appendChild(loading);

    fetch(url)
      .then(function (resp) {
        if (!resp.ok)
          throw new Error("Datei nicht ladbar (HTTP " + resp.status + ")");
        return resp.blob();
      })
      .then(function (blob) {
        // Tika erwartet den Datei-Inhalt als Request-Body (PUT).
        // Accept: text/html  → Tika liefert strukturiertes HTML statt Plaintext.
        return fetch(E.TIKA_URL, {
          method: "PUT",
          headers: {
            Accept: "text/html",
            "Content-Type": blob.type || "application/octet-stream",
          },
          body: blob,
        });
      })
      .then(function (resp) {
        if (!resp.ok)
          throw new Error(
            "Tika-Konvertierung fehlgeschlagen (HTTP " + resp.status + ")",
          );
        return resp.text();
      })
      .then(function (html) {
        bodyEl.innerHTML = "";

        if (!html || html.trim().length < 20) {
          renderUnavailable(
            "Das Dokument enth\u00E4lt keinen extrahierbaren Text.",
          );
          return;
        }

        // Minimales Wrapper-HTML mit eingebettetem Stylesheet für
        // saubere Darstellung im iframe (Schriftart, Zeilenabstand, Tabellen).
        var styledHtml =
          '<!DOCTYPE html><html><head><meta charset="utf-8">' +
          "<style>" +
          "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;" +
          "font-size:14px;line-height:1.7;color:#1a1a2e;padding:24px 32px;margin:0;max-width:none;}" +
          "h1,h2,h3,h4,h5,h6{color:#16213e;margin-top:1.4em;margin-bottom:0.6em;}" +
          "h1{font-size:1.6em;border-bottom:2px solid #e8e8e8;padding-bottom:0.3em;}" +
          "h2{font-size:1.3em;}" +
          "table{border-collapse:collapse;width:100%;margin:1em 0;}" +
          "th,td{border:1px solid #d0d0d0;padding:6px 10px;text-align:left;}" +
          "th{background:#f4f4f8;font-weight:600;}" +
          "tr:nth-child(even){background:#fafafa;}" +
          "ul,ol{padding-left:1.8em;}" +
          "li{margin-bottom:0.3em;}" +
          "p{margin:0.6em 0;}" +
          "img{max-width:100%;height:auto;}" +
          "a{color:#0a84ff;}" +
          "blockquote{border-left:3px solid #d0d0d0;margin:1em 0;padding:0.4em 1em;color:#555;}" +
          "pre,code{background:#f4f4f8;border-radius:4px;font-size:0.9em;}" +
          "pre{padding:12px;overflow-x:auto;}" +
          "code{padding:2px 4px;}" +
          "</style></head><body>" +
          html +
          "</body></html>";

        var iframe = document.createElement("iframe");
        iframe.className = "preview-office-frame";
        // Sandbox: keine Script-Ausführung, kein Formular, keine Navigation
        iframe.setAttribute("sandbox", "allow-same-origin");
        iframe.setAttribute("referrerpolicy", "no-referrer");

        bodyEl.appendChild(iframe);

        // srcdoc ist sicherer als blob-URL und erlaubt sandbox
        iframe.srcdoc = styledHtml;
      })
      .catch(function (err) {
        bodyEl.innerHTML = "";
        renderUnavailable("Dokumentvorschau fehlgeschlagen: " + err.message);
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
      "F\u00FCr diesen Dateityp (<strong>" +
      ext +
      "</strong>) ist keine Vorschau verf\u00FCgbar.";

    var hintP = document.createElement("p");
    hintP.className = "preview-hint";
    hintP.textContent =
      "Klicke auf \u201EHerunterladen\u201C um die Datei zu \u00F6ffnen.";

    container.appendChild(iconDiv);
    container.appendChild(msgP);
    container.appendChild(hintP);
    bodyEl.appendChild(container);
  }
})(window.EduSearch);
