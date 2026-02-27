/**
 * edu-rag.js – KI-Assistent UI
 *
 * Steuert das KI-Assistent-Panel (Tab 2) der Edu-Search Web-UI.
 *
 * Features:
 * - Tab-Umschaltung zwischen Suche und KI-Assistent
 * - Formular-Handling für Klausur-Parameter
 * - SSE-Streaming der KI-Antwort (Token für Token)
 * - Einfaches Markdown → HTML Rendering (kein externe Lib)
 * - Copy-to-Clipboard
 *
 * Abhängigkeiten: edu-config.js, edu-utils.js (müssen vorher geladen sein)
 */

// =============================================================================
// Tab-Navigation
// =============================================================================

(function initTabs() {
    const btnSearch = document.getElementById('tab-btn-search');
    const btnRag    = document.getElementById('tab-btn-rag');
    const panelSearch = document.getElementById('panel-search');
    const panelRag    = document.getElementById('panel-rag');

    if (!btnSearch || !btnRag || !panelSearch || !panelRag) return;

    function switchTab(tab) {
        const isSearch = tab === 'search';

        btnSearch.classList.toggle('active', isSearch);
        btnRag.classList.toggle('active', !isSearch);
        btnSearch.setAttribute('aria-selected', String(isSearch));
        btnRag.setAttribute('aria-selected', String(!isSearch));

        panelSearch.style.display = isSearch ? '' : 'none';
        panelRag.style.display    = isSearch ? 'none' : '';

        // URL-Hash für Bookmarkability
        history.replaceState(null, '', isSearch ? '#suche' : '#ki-assistent');
    }

    btnSearch.addEventListener('click', () => switchTab('search'));
    btnRag.addEventListener('click', () => switchTab('rag'));

    // Beim Laden: Hash prüfen
    if (window.location.hash === '#ki-assistent') {
        switchTab('rag');
    }

    // Globale Funktion (für etwaige direkte Aufrufe)
    window.switchTab = switchTab;
})();

// =============================================================================
// Einfaches Markdown → HTML Rendering
// =============================================================================

function renderMarkdown(text) {
    if (!text) return '';

    // XSS-Schutz: HTML erst escapen, dann Markdown-Tags erlauben
    let html = text
        // HTML entities
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');

    // Überschriften (### ## #)
    html = html.replace(/^### (.+)$/gm, '<h3>$1</h3>');
    html = html.replace(/^## (.+)$/gm, '<h2>$1</h2>');
    html = html.replace(/^# (.+)$/gm, '<h1>$1</h1>');

    // Fett und Kursiv
    html = html.replace(/\*\*\*(.+?)\*\*\*/g, '<strong><em>$1</em></strong>');
    html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
    html = html.replace(/\*(.+?)\*/g, '<em>$1</em>');

    // Inline-Code
    html = html.replace(/`([^`]+)`/g, '<code>$1</code>');

    // Horizontale Linie
    html = html.replace(/^---+$/gm, '<hr>');

    // Nummerierte Listen (1. 2. 3.)
    html = html.replace(/^(\d+)\. (.+)$/gm, '<li data-n="$1">$2</li>');
    html = html.replace(/(<li data-n="\d+">[^]*?<\/li>\n?)+/g, (match) => {
        return '<ol>' + match.replace(/ data-n="\d+"/g, '') + '</ol>';
    });

    // Bullet-Listen (- * •)
    html = html.replace(/^[•\-\*] (.+)$/gm, '<li>$1</li>');
    html = html.replace(/(<li>[^]*?<\/li>\n?)+/g, (match) => {
        // Nur wenn nicht schon in <ol>
        if (!match.includes('data-n')) {
            return '<ul>' + match + '</ul>';
        }
        return match;
    });

    // [LÖSUNG]-Marker hervorheben
    html = html.replace(/\[LÖSUNG\]/g, '<span class="rag-loesung-marker">[LÖSUNG]</span>');
    html = html.replace(/\[LOESUNG\]/g, '<span class="rag-loesung-marker">[LÖSUNG]</span>');
    html = html.replace(/\[SOLUTION\]/g, '<span class="rag-loesung-marker">[LÖSUNG]</span>');

    // Absätze (Doppel-Newline)
    html = html.replace(/\n\n+/g, '</p><p>');
    html = '<p>' + html + '</p>';

    // Einzelne Newlines als <br> (innerhalb von <p>)
    html = html.replace(/<\/p><p>/g, '</p>\n<p>');
    html = html.replace(/([^>])\n([^<])/g, '$1<br>$2');

    // Leere Paragraphen entfernen
    html = html.replace(/<p>\s*<\/p>/g, '');

    return html;
}

// =============================================================================
// RAG-Formular & Streaming
// =============================================================================

(function initRag() {
    const form       = document.getElementById('rag-form');
    const genBtn     = document.getElementById('rag-generate-btn');
    const clearBtn   = document.getElementById('rag-clear-btn');
    const statusEl   = document.getElementById('rag-status');
    const outContainer = document.getElementById('rag-output-container');
    const outEl      = document.getElementById('rag-output');
    const copyBtn    = document.getElementById('rag-copy-btn');
    const outTitle   = document.getElementById('rag-output-title');

    if (!form || !genBtn) return;

    let currentController = null; // AbortController für laufende Anfragen
    let rawText = '';             // Volltext für Copy-Funktion

    // -------------------------------------------------------------------------
    // Hilfsfunktionen
    // -------------------------------------------------------------------------

    function setStatus(msg, type) {
        if (!statusEl) return;
        statusEl.style.display = msg ? '' : 'none';
        statusEl.className = 'rag-status' + (type ? ' rag-status-' + type : '');
        statusEl.textContent = msg;
    }

    function setLoading(loading) {
        genBtn.disabled = loading;
        genBtn.textContent = loading ? '⏳ Erstelle...' : '🤖 Erstellen';
        if (clearBtn) {
            clearBtn.style.display = loading ? '' : (rawText ? '' : 'none');
        }
    }

    function showOutput(title) {
        if (outContainer) outContainer.style.display = '';
        if (outTitle) outTitle.textContent = title;
    }

    function hideOutput() {
        if (outContainer) outContainer.style.display = 'none';
        if (outEl) outEl.innerHTML = '';
    }

    // -------------------------------------------------------------------------
    // Formular absenden
    // -------------------------------------------------------------------------

    form.addEventListener('submit', async (e) => {
        e.preventDefault();

        const fach    = document.getElementById('rag-fach')?.value?.trim() || '';
        const klasse  = document.getElementById('rag-klasse')?.value?.trim() || '';
        const thema   = document.getElementById('rag-thema')?.value?.trim() || '';
        const typ     = document.getElementById('rag-typ')?.value?.trim() || 'Test';
        const niveau  = document.getElementById('rag-niveau')?.value?.trim() || '';
        const zeitStr = document.getElementById('rag-zeit')?.value || '45';
        const anw     = document.getElementById('rag-anweisungen')?.value?.trim() || '';

        if (!fach || !klasse || !thema) {
            setStatus('Bitte Fach, Klasse und Thema ausfüllen.', 'error');
            return;
        }

        // Vorherige Anfrage abbrechen
        if (currentController) {
            currentController.abort();
        }
        currentController = new AbortController();

        setLoading(true);
        setStatus('KI sucht relevante Materialien und generiert ' + typ + '...', '');
        hideOutput();
        rawText = '';

        const payload = {
            fach,
            klasse,
            thema,
            typ,
            niveau: niveau || undefined,
            zeitaufwand_min: parseInt(zeitStr, 10) || 45,
            anweisungen: anw,
        };

        try {
            const response = await fetch(window.EDU_CONFIG?.ragEndpoint || '/api/rag/klausur', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload),
                signal: currentController.signal,
            });

            if (!response.ok) {
                const errText = await response.text();
                throw new Error(`Server-Fehler ${response.status}: ${errText}`);
            }

            setStatus('KI schreibt...', '');
            showOutput(`${typ}: ${fach} Klasse ${klasse} – ${thema}`);

            // SSE-Stream lesen
            const reader = response.body.getReader();
            const decoder = new TextDecoder();
            let buffer = '';

            while (true) {
                const { done, value } = await reader.read();
                if (done) break;

                buffer += decoder.decode(value, { stream: true });
                const lines = buffer.split('\n');
                buffer = lines.pop() || '';

                for (const line of lines) {
                    if (!line.startsWith('data: ')) continue;
                    const dataStr = line.slice(6).trim();
                    if (!dataStr) continue;

                    try {
                        const data = JSON.parse(dataStr);

                        if (data.error) {
                            setStatus('Fehler: ' + data.error, 'error');
                            setLoading(false);
                            return;
                        }

                        if (data.token) {
                            rawText += data.token;
                            // Live-Rendering: Markdown → HTML
                            if (outEl) {
                                outEl.innerHTML = renderMarkdown(rawText);
                                // Automatisch nach unten scrollen
                                outEl.scrollTop = outEl.scrollHeight;
                            }
                        }

                        if (data.done) {
                            setStatus('', '');
                            setLoading(false);
                            currentController = null;
                        }
                    } catch (_) {
                        // Kein valides JSON – ignorieren
                    }
                }
            }

        } catch (err) {
            if (err.name === 'AbortError') {
                setStatus('Generierung abgebrochen.', '');
            } else {
                setStatus('Fehler: ' + err.message, 'error');
                console.error('RAG-Fehler:', err);
            }
        } finally {
            setLoading(false);
            currentController = null;
        }
    });

    // -------------------------------------------------------------------------
    // Zurücksetzen
    // -------------------------------------------------------------------------

    if (clearBtn) {
        clearBtn.addEventListener('click', () => {
            if (currentController) {
                currentController.abort();
                currentController = null;
            }
            hideOutput();
            setStatus('', '');
            setLoading(false);
            rawText = '';
            clearBtn.style.display = 'none';

            // Formular zurücksetzen
            document.getElementById('rag-thema').value = '';
            document.getElementById('rag-anweisungen').value = '';
        });
    }

    // -------------------------------------------------------------------------
    // Copy-to-Clipboard
    // -------------------------------------------------------------------------

    if (copyBtn) {
        copyBtn.addEventListener('click', () => {
            if (!rawText) return;

            const doCopy = (text) => {
                if (navigator.clipboard && navigator.clipboard.writeText) {
                    return navigator.clipboard.writeText(text);
                }
                // Fallback für ältere Browser
                const ta = document.createElement('textarea');
                ta.value = text;
                ta.style.position = 'fixed';
                ta.style.opacity = '0';
                document.body.appendChild(ta);
                ta.focus();
                ta.select();
                try { document.execCommand('copy'); } catch (_) {}
                document.body.removeChild(ta);
                return Promise.resolve();
            };

            doCopy(rawText).then(() => {
                const orig = copyBtn.textContent;
                copyBtn.textContent = '✓ Kopiert!';
                copyBtn.disabled = true;
                setTimeout(() => {
                    copyBtn.textContent = orig;
                    copyBtn.disabled = false;
                }, 2000);
            }).catch(() => {
                copyBtn.textContent = '❌ Fehler';
                setTimeout(() => { copyBtn.textContent = '📋 Kopieren'; }, 2000);
            });
        });
    }
})();

// =============================================================================
// CSS für Tab-Navigation und RAG-Panel (dynamisch injiziert)
// =============================================================================
// Die Styles ergänzen das bestehende style.css um RAG-spezifische Klassen.
// So bleibt style.css unverändert und die RAG-Erweiterung ist self-contained.

(function injectRagStyles() {
    const style = document.createElement('style');
    style.textContent = `
/* Tab-Navigation */
.tab-nav {
    display: flex;
    gap: 0.25rem;
    margin-top: 1rem;
    border-bottom: 2px solid var(--border-color, #e2e8f0);
}

.tab-btn {
    padding: 0.5rem 1.25rem;
    border: none;
    background: transparent;
    cursor: pointer;
    font-size: 0.95rem;
    color: var(--text-secondary, #64748b);
    border-bottom: 2px solid transparent;
    margin-bottom: -2px;
    transition: color 0.15s, border-color 0.15s;
    border-radius: 0.375rem 0.375rem 0 0;
}

.tab-btn:hover {
    color: var(--primary, #3b82f6);
    background: var(--bg-hover, #f1f5f9);
}

.tab-btn.active {
    color: var(--primary, #3b82f6);
    border-bottom-color: var(--primary, #3b82f6);
    font-weight: 600;
}

/* RAG Container */
.rag-container {
    max-width: 900px;
    margin: 1.5rem auto;
}

.rag-intro {
    background: var(--bg-card, #f8fafc);
    border: 1px solid var(--border-color, #e2e8f0);
    border-radius: 0.5rem;
    padding: 0.75rem 1rem;
    margin-bottom: 1.25rem;
    color: var(--text-secondary, #64748b);
    font-size: 0.9rem;
}

/* RAG Formular */
.rag-form {
    background: var(--bg-card, #f8fafc);
    border: 1px solid var(--border-color, #e2e8f0);
    border-radius: 0.5rem;
    padding: 1.25rem;
    margin-bottom: 1rem;
}

.rag-form-row {
    display: flex;
    gap: 1rem;
    margin-bottom: 0.75rem;
    flex-wrap: wrap;
}

.rag-field {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    min-width: 130px;
}

.rag-field-wide {
    flex: 1;
    min-width: 250px;
}

.rag-field label {
    font-size: 0.8rem;
    font-weight: 600;
    color: var(--text-secondary, #64748b);
    text-transform: uppercase;
    letter-spacing: 0.03em;
}

.rag-field input,
.rag-field select,
.rag-field textarea {
    padding: 0.5rem 0.75rem;
    border: 1px solid var(--border-color, #e2e8f0);
    border-radius: 0.375rem;
    font-size: 0.95rem;
    background: white;
    color: var(--text-primary, #1e293b);
    font-family: inherit;
    transition: border-color 0.15s;
}

.rag-field input:focus,
.rag-field select:focus,
.rag-field textarea:focus {
    outline: none;
    border-color: var(--primary, #3b82f6);
    box-shadow: 0 0 0 2px rgba(59,130,246,0.15);
}

.rag-field textarea {
    resize: vertical;
    min-height: 60px;
}

.rag-form-actions {
    display: flex;
    gap: 0.75rem;
    align-items: center;
    margin-top: 0.5rem;
}

.rag-generate-btn {
    padding: 0.6rem 1.5rem;
    background: var(--primary, #3b82f6);
    color: white;
    border: none;
    border-radius: 0.375rem;
    font-size: 0.95rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s, opacity 0.15s;
}

.rag-generate-btn:hover:not(:disabled) {
    background: var(--primary-hover, #2563eb);
}

.rag-generate-btn:disabled {
    opacity: 0.65;
    cursor: not-allowed;
}

.rag-clear-btn {
    padding: 0.6rem 1rem;
    background: transparent;
    border: 1px solid var(--border-color, #e2e8f0);
    border-radius: 0.375rem;
    font-size: 0.9rem;
    cursor: pointer;
    color: var(--text-secondary, #64748b);
    transition: background 0.15s;
}

.rag-clear-btn:hover {
    background: var(--bg-hover, #f1f5f9);
}

/* Status */
.rag-status {
    padding: 0.6rem 1rem;
    border-radius: 0.375rem;
    margin-bottom: 0.75rem;
    font-size: 0.9rem;
    background: var(--bg-card, #f8fafc);
    border: 1px solid var(--border-color, #e2e8f0);
    color: var(--text-secondary, #64748b);
}

.rag-status-error {
    background: #fef2f2;
    border-color: #fca5a5;
    color: #dc2626;
}

/* Ausgabe */
.rag-output-container {
    border: 1px solid var(--border-color, #e2e8f0);
    border-radius: 0.5rem;
    overflow: hidden;
}

.rag-output-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.6rem 1rem;
    background: var(--bg-card, #f8fafc);
    border-bottom: 1px solid var(--border-color, #e2e8f0);
    font-weight: 600;
    font-size: 0.9rem;
}

.rag-copy-btn {
    padding: 0.3rem 0.75rem;
    background: transparent;
    border: 1px solid var(--border-color, #e2e8f0);
    border-radius: 0.25rem;
    font-size: 0.85rem;
    cursor: pointer;
    color: var(--text-secondary, #64748b);
    transition: background 0.15s;
}

.rag-copy-btn:hover:not(:disabled) {
    background: var(--bg-hover, #f1f5f9);
}

.rag-output {
    padding: 1.25rem 1.5rem;
    max-height: 70vh;
    overflow-y: auto;
    font-size: 0.95rem;
    line-height: 1.7;
    white-space: pre-wrap;
    word-wrap: break-word;
    background: white;
}

.rag-output h1, .rag-output h2, .rag-output h3 {
    margin: 1rem 0 0.5rem;
    color: var(--text-primary, #1e293b);
}

.rag-output h1 { font-size: 1.3rem; }
.rag-output h2 { font-size: 1.15rem; }
.rag-output h3 { font-size: 1.05rem; }

.rag-output p { margin: 0.5rem 0; }
.rag-output ul, .rag-output ol { padding-left: 1.5rem; margin: 0.5rem 0; }
.rag-output li { margin: 0.2rem 0; }
.rag-output hr { border: none; border-top: 1px solid var(--border-color, #e2e8f0); margin: 1rem 0; }
.rag-output code { background: #f1f5f9; padding: 0.1em 0.3em; border-radius: 0.2em; font-family: monospace; font-size: 0.9em; }
.rag-output strong { font-weight: 700; }
.rag-output em { font-style: italic; }

.rag-loesung-marker {
    display: inline-block;
    background: #fef3c7;
    border: 1px solid #fbbf24;
    color: #92400e;
    padding: 0.1em 0.5em;
    border-radius: 0.25em;
    font-size: 0.85em;
    font-weight: 600;
    margin: 0.5em 0;
}

@media (max-width: 640px) {
    .rag-form-row { flex-direction: column; }
    .rag-field { min-width: unset; }
    .tab-btn { padding: 0.5rem 0.75rem; font-size: 0.875rem; }
}
    `;
    document.head.appendChild(style);
})();
