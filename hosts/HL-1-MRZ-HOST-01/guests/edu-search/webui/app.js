// =============================================================================
// Edu-Search Frontend – MeiliSearch Client
// =============================================================================
//
// Verbindet sich mit MeiliSearch via /meili/ Nginx-Proxy.
// Keine externen Abhängigkeiten – reines Vanilla JS.
//
// Features:
// - Debounced Volltextsuche (250ms Verzögerung)
// - Faceted Filtering (Fach, Klasse, Typ, Niveau)
// - Ergebnis-Rendering mit Highlighting
// - SMB/UNC-Links zum Öffnen der Dateien
// - "Pfad kopieren" Funktionalität
// - Responsive (funktioniert auf Desktop + Tablet + Handy)
// =============================================================================

(function () {
  "use strict";

  // ---------------------------------------------------------------------------
  // Konfiguration
  // ---------------------------------------------------------------------------

  var MEILI_URL = "/meili";
  var INDEX_NAME = "edu_documents";
  var RESULTS_PER_PAGE = 30;
  var DEBOUNCE_MS = 250;

  // MeiliSearch Auth wird serverseitig durch Nginx injiziert (/run/edu-search/meili-auth.conf).
  // Das Frontend sendet KEINE API-Keys – der Nginx-Proxy fügt den Authorization-Header
  // beim Weiterleiten an MeiliSearch automatisch hinzu. Siehe webui.nix + meilisearch.nix.

  // ---------------------------------------------------------------------------
  // DOM-Referenzen
  // ---------------------------------------------------------------------------

  var searchInput = document.getElementById("search-input");
  var clearSearchBtn = document.getElementById("clear-search");
  var filterFach = document.getElementById("filter-fach");
  var filterKlasse = document.getElementById("filter-klasse");
  var filterTyp = document.getElementById("filter-typ");
  var filterNiveau = document.getElementById("filter-niveau");
  var resetFiltersBtn = document.getElementById("reset-filters");
  var resultsDiv = document.getElementById("results");
  var statsDiv = document.getElementById("stats");
  var totalDocsSpan = document.getElementById("total-docs");
  var loadMoreContainer = document.getElementById("load-more-container");
  var loadMoreBtn = document.getElementById("load-more-btn");

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  var debounceTimer = null;
  var currentOffset = 0;
  var currentHits = [];
  var lastQuery = null;
  var lastFilters = null;
  var isLoading = false;

  // ---------------------------------------------------------------------------
  // File type → Emoji mapping
  // ---------------------------------------------------------------------------

  var FILE_ICONS = {
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

  function getFileIcon(extension) {
    if (!extension) return "\uD83D\uDCC1";
    return FILE_ICONS[extension.toLowerCase()] || "\uD83D\uDCC1";
  }

  // ---------------------------------------------------------------------------
  // Escape HTML (XSS prevention)
  // ---------------------------------------------------------------------------

  function escapeHtml(str) {
    if (!str) return "";
    var div = document.createElement("div");
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  }

  // Allow <mark> tags from MeiliSearch highlighting but escape everything else
  function safeHighlight(str) {
    if (!str) return "";
    // First escape everything
    var escaped = escapeHtml(str);
    // Then restore <mark> and </mark> tags that MeiliSearch uses for highlighting
    escaped = escaped.replace(/&lt;mark&gt;/g, "<mark>");
    escaped = escaped.replace(/&lt;\/mark&gt;/g, "</mark>");
    return escaped;
  }

  // ---------------------------------------------------------------------------
  // Build MeiliSearch filter string
  // ---------------------------------------------------------------------------

  function buildFilterString() {
    var filters = [];
    if (filterFach.value) {
      filters.push('fach = "' + filterFach.value + '"');
    }
    if (filterKlasse.value) {
      filters.push('klasse = "' + filterKlasse.value + '"');
    }
    if (filterTyp.value) {
      filters.push('typ = "' + filterTyp.value + '"');
    }
    if (filterNiveau.value) {
      filters.push('niveau = "' + filterNiveau.value + '"');
    }
    return filters.length > 0 ? filters.join(" AND ") : undefined;
  }

  // ---------------------------------------------------------------------------
  // Copy text to clipboard
  // ---------------------------------------------------------------------------

  function copyToClipboard(text, buttonEl) {
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
  }

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

  function showCopyFeedback(buttonEl, success) {
    if (!buttonEl) return;
    var originalText = buttonEl.textContent;
    buttonEl.textContent = success ? "\u2705 Kopiert!" : "\u274C Fehler";
    buttonEl.disabled = true;
    setTimeout(function () {
      buttonEl.textContent = originalText;
      buttonEl.disabled = false;
    }, 1500);
  }

  // ---------------------------------------------------------------------------
  // Render a single result card
  // ---------------------------------------------------------------------------

  function renderCard(hit) {
    var hl = hit._formatted || hit;
    var fachLower = (hit.fach || "").toLowerCase();
    var fachClass = "";
    if (fachLower.indexOf("englisch") !== -1) fachClass = "fach-englisch";
    else if (fachLower.indexOf("spanisch") !== -1) fachClass = "fach-spanisch";

    var icon = getFileIcon(hit.file_extension);

    // Build tags HTML
    var tagsHtml = "";
    if (hit.fach && hit.fach !== "unbekannt") {
      tagsHtml +=
        '<span class="tag ' +
        fachClass +
        '">' +
        escapeHtml(hit.fach) +
        "</span>";
    }
    if (hit.klasse && hit.klasse !== "unbekannt") {
      tagsHtml +=
        '<span class="tag">Klasse ' + escapeHtml(hit.klasse) + "</span>";
    }
    if (hit.typ && hit.typ !== "Sonstiges") {
      tagsHtml += '<span class="tag">' + escapeHtml(hit.typ) + "</span>";
    }
    if (hit.niveau && hit.niveau !== "unbekannt") {
      tagsHtml += '<span class="tag">' + escapeHtml(hit.niveau) + "</span>";
    }
    if (hit.file_extension) {
      tagsHtml +=
        '<span class="tag">' + escapeHtml(hit.file_extension) + "</span>";
    }

    // Thema
    var themaHtml = "";
    if (hit.thema) {
      var themaText = hl.thema || hit.thema;
      themaHtml = '<div class="thema">' + safeHighlight(themaText) + "</div>";
    }

    // UNC path for Windows (shown on hover, with copy button)
    var uncPath = hit.unc_path || "";
    var pathInfoHtml = "";
    if (uncPath) {
      pathInfoHtml =
        '<div class="path-info">' +
        '<span class="path-text">' +
        escapeHtml(uncPath) +
        "</span> " +
        '<button class="copy-path-btn" data-path="' +
        escapeHtml(uncPath) +
        '" ' +
        'onclick="event.preventDefault();event.stopPropagation();" ' +
        'title="Pfad in die Zwischenablage kopieren">' +
        "\uD83D\uDCCB Pfad kopieren</button>" +
        "</div>";
    }

    // The card links to the SMB URL (may or may not work depending on OS/browser)
    // The UNC path is shown as copyable text as a more reliable alternative
    var smbUrl = hit.smb_url || "#";

    return (
      '<a class="result-card" href="' +
      escapeHtml(smbUrl) +
      '" ' +
      'title="Klicke um die Datei zu \u00f6ffnen &#10;' +
      escapeHtml(uncPath) +
      '">' +
      '<div class="card-header">' +
      '<span class="file-icon">' +
      icon +
      "</span>" +
      '<span class="filename">' +
      safeHighlight(hl.filename || hit.filename) +
      "</span>" +
      "</div>" +
      '<div class="meta">' +
      tagsHtml +
      "</div>" +
      themaHtml +
      pathInfoHtml +
      "</a>"
    );
  }

  // ---------------------------------------------------------------------------
  // Render results
  // ---------------------------------------------------------------------------

  function renderResults(data, append) {
    var hits = data.hits || [];
    var total = data.estimatedTotalHits || data.totalHits || hits.length;
    var timeMs = data.processingTimeMs || 0;

    // Update stats
    if (total === 0) {
      statsDiv.textContent = "Keine Ergebnisse gefunden.";
    } else if (total === 1) {
      statsDiv.textContent = "1 Ergebnis (" + timeMs + "ms)";
    } else {
      statsDiv.textContent = total + " Ergebnisse (" + timeMs + "ms)";
    }

    // Empty state
    if (hits.length === 0 && !append) {
      resultsDiv.innerHTML =
        '<div class="placeholder">' +
        '<div class="placeholder-icon">\uD83D\uDD0D</div>' +
        "<p>Keine Ergebnisse gefunden.<br>Versuche andere Suchbegriffe oder Filter.</p>" +
        "</div>";
      loadMoreContainer.style.display = "none";
      return;
    }

    // Build HTML
    var html = hits.map(renderCard).join("");

    if (append) {
      resultsDiv.insertAdjacentHTML("beforeend", html);
    } else {
      resultsDiv.innerHTML = html;
    }

    // Track hits for "load more"
    if (append) {
      currentHits = currentHits.concat(hits);
    } else {
      currentHits = hits;
    }

    // Show/hide "load more" button
    if (currentHits.length < total) {
      loadMoreContainer.style.display = "block";
    } else {
      loadMoreContainer.style.display = "none";
    }

    // Attach copy-button event listeners
    attachCopyListeners();
  }

  // ---------------------------------------------------------------------------
  // Attach copy-path button listeners (delegated)
  // ---------------------------------------------------------------------------

  function attachCopyListeners() {
    var buttons = resultsDiv.querySelectorAll(".copy-path-btn");
    for (var i = 0; i < buttons.length; i++) {
      // Remove old listener (by replacing node) to avoid duplicates
      var btn = buttons[i];
      if (!btn.dataset.listenerAttached) {
        btn.dataset.listenerAttached = "true";
        btn.addEventListener("click", function (e) {
          e.preventDefault();
          e.stopPropagation();
          var path = this.dataset.path;
          if (path) {
            copyToClipboard(path, this);
          }
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Execute search
  // ---------------------------------------------------------------------------

  function doSearch(append) {
    if (isLoading) return;

    var query = searchInput.value.trim();
    var filterStr = buildFilterString();

    // Show/hide clear button
    clearSearchBtn.style.display = query ? "block" : "none";

    // Nothing to search?
    if (!query && !filterStr) {
      resultsDiv.innerHTML =
        '<div class="placeholder">' +
        '<div class="placeholder-icon">\uD83D\uDCDA</div>' +
        "<p>Gib einen Suchbegriff ein oder w\u00e4hle einen Filter,<br>" +
        "um Unterrichtsmaterialien zu finden.</p>" +
        "</div>";
      statsDiv.textContent = "";
      loadMoreContainer.style.display = "none";
      currentHits = [];
      currentOffset = 0;
      lastQuery = null;
      lastFilters = null;
      return;
    }

    // If not appending, reset offset
    if (!append) {
      currentOffset = 0;
      currentHits = [];
    }

    // Save for "load more"
    lastQuery = query;
    lastFilters = filterStr;

    // Show loading state
    isLoading = true;
    if (!append) {
      resultsDiv.innerHTML = '<div class="loading">Suche l\u00e4uft</div>';
    }

    // Build request body
    var body = {
      q: query || "",
      limit: RESULTS_PER_PAGE,
      offset: currentOffset,
      attributesToHighlight: ["filename", "thema"],
      highlightPreTag: "<mark>",
      highlightPostTag: "</mark>",
    };

    if (filterStr) {
      body.filter = filterStr;
    }

    // Build headers (Auth wird serverseitig von Nginx injiziert)
    var headers = {
      "Content-Type": "application/json",
    };

    // Execute search request
    fetch(MEILI_URL + "/indexes/" + INDEX_NAME + "/search", {
      method: "POST",
      headers: headers,
      body: JSON.stringify(body),
    })
      .then(function (resp) {
        if (!resp.ok) {
          throw new Error("HTTP " + resp.status + " " + resp.statusText);
        }
        return resp.json();
      })
      .then(function (data) {
        isLoading = false;
        currentOffset += (data.hits || []).length;
        renderResults(data, append);
      })
      .catch(function (err) {
        isLoading = false;
        console.error("Suchfehler:", err);
        if (!append) {
          resultsDiv.innerHTML =
            '<div class="error-message">' +
            "<p>\u274C Fehler bei der Suche: " +
            escapeHtml(err.message) +
            "</p>" +
            "<p>Ist der Suchserver erreichbar?</p>" +
            "</div>";
        }
        statsDiv.textContent = "";
        loadMoreContainer.style.display = "none";
      });
  }

  // ---------------------------------------------------------------------------
  // Load more results
  // ---------------------------------------------------------------------------

  function loadMore() {
    if (lastQuery !== null || lastFilters !== null) {
      doSearch(true);
    }
  }

  // ---------------------------------------------------------------------------
  // Debounced input handler
  // ---------------------------------------------------------------------------

  function onInputChange() {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(function () {
      doSearch(false);
    }, DEBOUNCE_MS);
  }

  // ---------------------------------------------------------------------------
  // Reset all filters
  // ---------------------------------------------------------------------------

  function resetFilters() {
    filterFach.value = "";
    filterKlasse.value = "";
    filterTyp.value = "";
    filterNiveau.value = "";
    searchInput.value = "";
    clearSearchBtn.style.display = "none";
    doSearch(false);
  }

  // ---------------------------------------------------------------------------
  // Clear search input
  // ---------------------------------------------------------------------------

  function clearSearch() {
    searchInput.value = "";
    clearSearchBtn.style.display = "none";
    searchInput.focus();
    doSearch(false);
  }

  // ---------------------------------------------------------------------------
  // Fetch total document count for footer
  // ---------------------------------------------------------------------------

  function fetchTotalDocs() {
    fetch(MEILI_URL + "/indexes/" + INDEX_NAME + "/stats")
      .then(function (resp) {
        if (resp.ok) return resp.json();
        throw new Error("stats failed");
      })
      .then(function (data) {
        var count = data.numberOfDocuments || 0;
        if (totalDocsSpan) {
          totalDocsSpan.textContent = count.toLocaleString("de-DE");
        }
      })
      .catch(function () {
        if (totalDocsSpan) {
          totalDocsSpan.textContent = "?";
        }
      });
  }

  // ---------------------------------------------------------------------------
  // Event listeners
  // ---------------------------------------------------------------------------

  // Search input (debounced)
  searchInput.addEventListener("input", onInputChange);

  // Filter dropdowns (immediate search)
  filterFach.addEventListener("change", function () {
    doSearch(false);
  });
  filterKlasse.addEventListener("change", function () {
    doSearch(false);
  });
  filterTyp.addEventListener("change", function () {
    doSearch(false);
  });
  filterNiveau.addEventListener("change", function () {
    doSearch(false);
  });

  // Reset filters button
  resetFiltersBtn.addEventListener("click", resetFilters);

  // Clear search button
  clearSearchBtn.addEventListener("click", clearSearch);

  // Load more button
  loadMoreBtn.addEventListener("click", loadMore);

  // Keyboard shortcut: Escape to clear search
  searchInput.addEventListener("keydown", function (e) {
    if (e.key === "Escape") {
      clearSearch();
    }
  });

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  // Fetch total document count for the footer
  fetchTotalDocs();

  // If URL has a search query (for bookmarkable searches), execute it
  var urlParams = new URLSearchParams(window.location.search);
  var urlQuery = urlParams.get("q");
  if (urlQuery) {
    searchInput.value = urlQuery;
    doSearch(false);
  }
})();
