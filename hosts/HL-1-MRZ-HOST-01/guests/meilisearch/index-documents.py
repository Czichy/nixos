# scripts/index_documents.py
import os
import sys
import time
import json
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from meilisearch import Client
from sentence_transformers import SentenceTransformer
import pypdf
import docx
from lxml import html # Für robustere HTML/XML-Extraktion

# --- KONFIGURATION (aus Umgebungsvariablen) ---
MEILISEARCH_URL = os.getenv("MEILISEARCH_URL", "http://127.0.0.1:7700")
MEILISEARCH_API_KEY = os.getenv("MEILISEARCH_API_KEY", "YOUR_MEILISEARCH_MASTER_KEY")
DOCUMENTS_PATH = os.getenv("DOCUMENTS_PATH", "/mnt/nas_docs")
MEILISEARCH_INDEX_NAME = os.getenv("MEILISEARCH_INDEX_NAME", "nas_documents")

# Meilisearch Client
client = Client(MEILISEARCH_URL, MEILISEARCH_API_KEY)

# Sentence Transformer Modell für Embeddings
# Wählen Sie ein ressourcenschonendes Modell
# Beispiele: "all-MiniLM-L6-v2", "multi-qa-MiniLM-L6-dot-v1"
EMBEDDING_MODEL_NAME = "all-MiniLM-L6-v2"
model = None # Wird bei Bedarf geladen

# --- HILFSFUNKTIONEN ZUR TEXTEXTRAKTION ---
def extract_text_from_pdf(filepath):
    try:
        with open(filepath, 'rb') as f:
            reader = pypdf.PdfReader(f)
            text = ""
            for page in reader.pages:
                text += page.extract_text() or ""
            return text
    except Exception as e:
        print(f"Error extracting text from PDF {filepath}: {e}", file=sys.stderr)
        return ""

def extract_text_from_docx(filepath):
    try:
        doc = docx.Document(filepath)
        text = ""
        for para in doc.paragraphs:
            text += para.text + "\n"
        return text
    except Exception as e:
        print(f"Error extracting text from DOCX {filepath}: {e}", file=sys.stderr)
        return ""

def extract_text_from_txt(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return f.read()
    except Exception as e:
        print(f"Error extracting text from TXT {filepath}: {e}", file=sys.stderr)
        return ""

def extract_text_from_file(filepath):
    # Unterstützte Dateitypen
    if filepath.lower().endswith(".pdf"):
        return extract_text_from_pdf(filepath)
    elif filepath.lower().endswith((".docx", ".doc")): # .doc benötigt möglicherweise pywin32 auf Windows oder libgs auf Linux
        return extract_text_from_docx(filepath)
    elif filepath.lower().endswith(".txt"):
        return extract_text_from_txt(filepath)
    # Fügen Sie hier weitere Dateitypen hinzu (z.B. .xlsx mit openpyxl, .pptx mit python-pptx)
    print(f"Unsupported file type for extraction: {filepath}", file=sys.stderr)
    return None

# --- INDIZIERUNGSFUNKTION ---
def index_document(filepath):
    global model
    print(f"Processing document: {filepath}")
    doc_id = os.path.relpath(filepath, DOCUMENTS_PATH) # Relative Pfade als ID nutzen
    doc_id = doc_id.replace("/", "_").replace("\\", "_") # Für Meilisearch ID-freundlich machen

    extracted_text = extract_text_from_file(filepath)
    if extracted_text is None:
        print(f"Skipping {filepath} due to unsupported type or extraction error.", file=sys.stderr)
        return

    # Reduziere Text, falls er zu lang ist, für Embeddings
    # LLMs haben Token-Limits. Für Embeddings kann es auch nützlich sein, relevante Teile zu nehmen.
    summary_text = extracted_text[:5000] # Nehmen wir die ersten 5000 Zeichen als Zusammenfassung für Embeddings

    document_data = {
        "id": doc_id,
        "filepath": filepath,
        "filename": os.path.basename(filepath),
        "content": extracted_text,
        "last_modified": os.path.getmtime(filepath),
        "file_size": os.path.getsize(filepath)
    }

    # Erstelle Embeddings für die semantische Suche
    try:
        if model is None:
            print(f"Loading Sentence Transformer model: {EMBEDDING_MODEL_NAME}")
            model = SentenceTransformer(EMBEDDING_MODEL_NAME)
        # Erstelle ein Embedding für den zusammenfassenden Text
        embedding = model.encode(summary_text).tolist()
        document_data["embedding"] = embedding
    except Exception as e:
        print(f"Error creating embedding for {filepath}: {e}", file=sys.stderr)
        document_data["embedding"] = None # Füge kein Embedding hinzu, wenn es fehlschlägt

    try:
        # Fügen Sie das Dokument zu Meilisearch hinzu
        # create_index() erstellt den Index, falls er nicht existiert
        client.index(MEILISEARCH_INDEX_NAME).add_documents([document_data])
        print(f"Successfully indexed: {filepath}")
    except Exception as e:
        print(f"Error indexing {filepath} to Meilisearch: {e}", file=sys.stderr)

def delete_document(filepath):
    doc_id = os.path.relpath(filepath, DOCUMENTS_PATH)
    doc_id = doc_id.replace("/", "_").replace("\\", "_")
    try:
        client.index(MEILISEARCH_INDEX_NAME).delete_document(doc_id)
        print(f"Successfully deleted: {filepath}")
    except Exception as e:
        print(f"Error deleting {filepath} from Meilisearch: {e}", file=sys.stderr)

# --- DATEISYSTEM-Ereignis-Handler ---
class DocumentEventHandler(FileSystemEventHandler):
    def on_created(self, event):
        if not event.is_directory:
            index_document(event.src_path)

    def on_modified(self, event):
        if not event.is_directory:
            index_document(event.src_path) # Re-indexieren bei Änderung

    def on_deleted(self, event):
        if not event.is_directory:
            delete_document(event.src_path)

    def on_moved(self, event):
        if not event.is_directory:
            delete_document(event.src_path) # Alte Datei löschen
            index_document(event.dest_path) # Neue Datei indizieren


# --- INITIALE INDIZIERUNG (beim Start des Skripts) ---
def initial_indexing():
    print(f"Starting initial indexing of {DOCUMENTS_PATH}...")
    for root, _, files in os.walk(DOCUMENTS_PATH):
        for file in files:
            filepath = os.path.join(root, file)
            index_document(filepath)
    print("Initial indexing complete.")

# --- HAUPTLOGIK ---
if __name__ == "__main__":
    if not os.path.exists(DOCUMENTS_PATH):
        print(f"Error: Documents path '{DOCUMENTS_PATH}' does not exist. Make sure NAS is mounted.", file=sys.stderr)
        sys.exit(1)

    # Initialisiere Meilisearch Index und setze durchsuchbare/sortierbare Felder
    try:
        client.create_index(MEILISEARCH_INDEX_NAME, {'primaryKey': 'id'})
        index_instance = client.index(MEILISEARCH_INDEX_NAME)
        # Durchsuchbare Attribute für Stichwortsuche
        index_instance.update_searchable_attributes(['content', 'filename', 'filepath'])
        # Für semantische Suche wird das 'embedding' Feld nicht direkt durchsucht,
        # sondern für Vektorsuche verwendet, die Meilisearch selbst nicht nativ kann (Stand 2025).
        # Wir werden das Embedding im Dokument speichern und bei einer Anfrage extern vergleichen.
        # Wenn Meilisearch später Vektor-Suche unterstützt, kann dies angepasst werden.
        # Bis dahin: Das 'embedding' Feld wird nur gespeichert, nicht direkt durchsucht.
        print(f"Meilisearch index '{MEILISEARCH_INDEX_NAME}' initialized/updated.")
    except Exception as e:
        print(f"Error initializing Meilisearch index: {e}", file=sys.stderr)
        sys.exit(1)

    initial_indexing()

    event_handler = DocumentEventHandler()
    observer = Observer()
    observer.schedule(event_handler, DOCUMENTS_PATH, recursive=True)
    observer.start()

    print(f"Monitoring '{DOCUMENTS_PATH}' for changes...")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
    print("Document indexer stopped.")
