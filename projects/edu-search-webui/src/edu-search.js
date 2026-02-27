// =============================================================================
// Edu-Search – Suchlogik, Ergebnis-Rendering & Initialisierung
// =============================================================================
// Hauptmodul: Verbindet MeiliSearch-Suche mit dem UI.
//
// Verantwortlich für:
//   - Debounced Volltextsuche via MeiliSearch
//   - Filter-Auswertung (Fach, Klasse, Typ, Niveau)
//   - Ergebnis-Rendering (Karten + Statistik)
//   - "Mehr laden" Pagination
//   - Event-Binding (Inputs, Dropdowns, Buttons, Keyboard)
//   - Initialisierung (Dokumenten-Zähler, URL-Parameter)
//
// API:
//   EduSearch.doSearch(append) – Suche ausführen
//   EduSearch.resetFilters()  – Alle Filter zurücksetzen
//   EduSearch.clearSearch()   – Suchfeld leeren
// =============================================================================

(function (E) {
  "use strict";

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
  var viewListBtn = document.getElementById("view-list-btn");
  var viewGridBtn = document.getElementById("view-grid-btn");

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  var debounceTimer = null;
  var currentOffset = 0;
  var currentHits = [];
  var lastQuery = null;
  var lastFilters = null;
  var isLoading = false;
  var currentView = localStorage.getItem("edu-view") || "list";

  // ---------------------------------------------------------------------------
  // MeiliSearch Filter-String bauen
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
  // Ergebnisse rendern
  // ---------------------------------------------------------------------------

  function renderResults(data, append) {
    var hits = data.hits || [];
    var total = data.estimatedTotalHits || data.totalHits || hits.length;
    var timeMs = data.processingTimeMs || 0;

    // Statistik aktualisieren
    if (total === 0) {
      statsDiv.textContent = "Keine Ergebnisse gefunden.";
    } else if (total === 1) {
      statsDiv.textContent = "1 Ergebnis (" + timeMs + "ms)";
    } else {
      statsDiv.textContent = total + " Ergebnisse (" + timeMs + "ms)";
    }

    // Leerer Zustand
    if (hits.length === 0 && !append) {
      resultsDiv.innerHTML =
        '<div class="placeholder">' +
        '<div class="placeholder-icon">\uD83D\uDD0D</div>' +
        "<p>Keine Ergebnisse gefunden.<br>" +
        "Versuche andere Suchbegriffe oder Filter.</p>" +
        "</div>";
      loadMoreContainer.style.display = "none";
      return;
    }

    // Offset für data-hit-index berechnen (für append)
    var indexOffset = append ? currentHits.length : 0;

    // HTML aus Karten zusammenbauen
    var html = "";
    for (var i = 0; i < hits.length; i++) {
      html += E.renderCard(hits[i], indexOffset + i);
    }

    if (append) {
      resultsDiv.insertAdjacentHTML("beforeend", html);
      currentHits = currentHits.concat(hits);
    } else {
      resultsDiv.innerHTML = html;
      currentHits = hits;
    }

    // "Mehr laden" Button ein-/ausblenden
    if (currentHits.length < total) {
      loadMoreContainer.style.display = "block";
    } else {
      loadMoreContainer.style.display = "none";
    }

    // Event-Listener an neue Karten binden
    E.attachCardListeners(resultsDiv, currentHits);
  }

  // ---------------------------------------------------------------------------
  // Suche ausführen
  // ---------------------------------------------------------------------------

  E.doSearch = function (append) {
    if (isLoading) return;

    var query = searchInput.value.trim();
    var filterStr = buildFilterString();

    // Clear-Button ein-/ausblenden
    clearSearchBtn.style.display = query ? "block" : "none";

    // Nichts zu suchen?
    if (!query && !filterStr) {
      resultsDiv.innerHTML =
        '<div class="placeholder">' +
        '<div class="placeholder-icon">\uD83D\uDCDA</div>' +
        "<p>Gib einen Suchbegriff ein oder w\u00E4hle einen Filter,<br>" +
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

    // Bei neuer Suche Offset zurücksetzen
    if (!append) {
      currentOffset = 0;
      currentHits = [];
    }

    // Für "Mehr laden" merken
    lastQuery = query;
    lastFilters = filterStr;

    // Ladeanimation
    isLoading = true;
    if (!append) {
      resultsDiv.innerHTML = '<div class="loading">Suche l\u00E4uft</div>';
    }

    // MeiliSearch Request-Body
    var body = {
      q: query || "",
      limit: E.RESULTS_PER_PAGE,
      offset: currentOffset,
      attributesToHighlight: ["filename", "thema"],
      highlightPreTag: "<mark>",
      highlightPostTag: "</mark>",
    };

    if (filterStr) {
      body.filter = filterStr;
    }

    // Suche ausführen (Auth wird serverseitig von Nginx injiziert)
    fetch(E.MEILI_URL + "/indexes/" + E.INDEX_NAME + "/search", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
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
            E.escapeHtml(err.message) +
            "</p>" +
            "<p>Ist der Suchserver erreichbar?</p>" +
            "</div>";
        }
        statsDiv.textContent = "";
        loadMoreContainer.style.display = "none";
      });
  };

  // ---------------------------------------------------------------------------
  // Mehr Ergebnisse laden
  // ---------------------------------------------------------------------------

  function loadMore() {
    if (lastQuery !== null || lastFilters !== null) {
      E.doSearch(true);
    }
  }

  // ---------------------------------------------------------------------------
  // Debounced Input-Handler
  // ---------------------------------------------------------------------------

  function onInputChange() {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(function () {
      E.doSearch(false);
    }, E.DEBOUNCE_MS);
  }

  // ---------------------------------------------------------------------------
  // Filter zurücksetzen
  // ---------------------------------------------------------------------------

  E.resetFilters = function () {
    filterFach.value = "";
    filterKlasse.value = "";
    filterTyp.value = "";
    filterNiveau.value = "";
    searchInput.value = "";
    clearSearchBtn.style.display = "none";
    E.doSearch(false);
  };

  // ---------------------------------------------------------------------------
  // Suchfeld leeren
  // ---------------------------------------------------------------------------

  E.clearSearch = function () {
    searchInput.value = "";
    clearSearchBtn.style.display = "none";
    searchInput.focus();
    E.doSearch(false);
  };

  // ---------------------------------------------------------------------------
  // Gesamt-Dokumentenzahl im Footer anzeigen
  // ---------------------------------------------------------------------------

  function fetchTotalDocs() {
    fetch(E.MEILI_URL + "/indexes/" + E.INDEX_NAME + "/stats")
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
  // Event-Listener binden
  // ---------------------------------------------------------------------------

  // Suchfeld (debounced)
  searchInput.addEventListener("input", onInputChange);

  // Filter-Dropdowns (sofortige Suche)
  filterFach.addEventListener("change", function () {
    E.doSearch(false);
  });
  filterKlasse.addEventListener("change", function () {
    E.doSearch(false);
  });
  filterTyp.addEventListener("change", function () {
    E.doSearch(false);
  });
  filterNiveau.addEventListener("change", function () {
    E.doSearch(false);
  });

  // Buttons
  resetFiltersBtn.addEventListener("click", E.resetFilters);
  clearSearchBtn.addEventListener("click", E.clearSearch);
  loadMoreBtn.addEventListener("click", loadMore);

  // Tastatur: Escape leert die Suche
  searchInput.addEventListener("keydown", function (e) {
    if (e.key === "Escape") {
      E.clearSearch();
    }
  });

  // ---------------------------------------------------------------------------
  // List / Grid View Toggle
  // ---------------------------------------------------------------------------

  function setView(view) {
    currentView = view;
    localStorage.setItem("edu-view", view);

    if (view === "grid") {
      resultsDiv.classList.add("view-grid");
    } else {
      resultsDiv.classList.remove("view-grid");
    }

    if (viewListBtn && viewGridBtn) {
      viewListBtn.classList.toggle("active", view === "list");
      viewGridBtn.classList.toggle("active", view === "grid");
    }
  }

  if (viewListBtn) {
    viewListBtn.addEventListener("click", function () {
      setView("list");
    });
  }
  if (viewGridBtn) {
    viewGridBtn.addEventListener("click", function () {
      setView("grid");
    });
  }

  // ---------------------------------------------------------------------------
  // Initialisierung
  // ---------------------------------------------------------------------------

  // Gespeicherte Ansicht wiederherstellen
  setView(currentView);

  // Gesamt-Dokumentenzahl laden
  fetchTotalDocs();

  // URL-Parameter auswerten (für bookmarkbare Suchen: ?q=suchbegriff)
  var urlParams = new URLSearchParams(window.location.search);
  var urlQuery = urlParams.get("q");
  if (urlQuery) {
    searchInput.value = urlQuery;
    E.doSearch(false);
  }
})(window.EduSearch);
