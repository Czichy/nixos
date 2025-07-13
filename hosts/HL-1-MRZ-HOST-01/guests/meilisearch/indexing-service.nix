# modules/indexing-service.nix
{
  config,
  pkgs,
  ...
}: {
  # Python Umgebung für das Indizierungsskript
  # Wir erstellen eine dedizierte Python-Umgebung mit den benötigten Paketen
  # Dies ist besser als globale Pakete zu installieren, da es Konflikte vermeidet.
  environment.systemPackages = [
    (pkgs.python3.withPackages (pythonPackages:
      with pythonPackages; [
        meilisearch # Meilisearch Python Client
        sentence-transformers # Für Text-Embeddings
        faiss-cpu # Für Vektor-Ähnlichkeitssuche (In-Memory, bei Bedarf Vektor-DB)
        watchdog # Für Dateisystem-Ereignisüberwachung
        pypdf # Für PDF-Text-Extraktion
        python-docx # Für DOCX-Text-Extraktion
        lxml # Für HTML/XML Parsing, oft für Doc-Extraktion benötigt
        # Fügen Sie hier weitere Bibliotheken für Ihre Dokumenttypen hinzu (z.B. openpyxl für Excel)
      ]))
  ];

  systemd.services.document-indexer = {
    description = "Continuously index documents from NAS to Meilisearch";
    # Benötigt den Mount-Punkt, bevor es startet
    after = ["network-online.target"];
    # after = ["network-online.target" "mnt-nas_docs.mount"];
    # wants = ["mnt-nas_docs.mount"]; # Wird auch gestartet, wenn der Mount erfolgreich ist
    requires = ["meilisearch.service"]; # Meilisearch muss laufen
    wantedBy = ["multi-user.target"];

    # Ausführung als unser Benutzer, der Zugriff auf die gemounteten Dateien hat
    user = "meilisearch";
    group = "users";

    # Typ der Ausführung
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "10s";
      ExecStart = "${pkgs.python3.withPackages (p: [p.meilisearch p.sentence-transformers p.faiss-cpu p.watchdog p.pypdf p.python-docx p.lxml])}/bin/python ${config.system.build.scriptPath}/scripts/index_documents.py";
      # Übergabe von Umgebungsvariablen an das Skript
      Environment = [
        "MEILISEARCH_URL=http://127.0.0.1:7700"
        "MEILISEARCH_API_KEY=YOUR_MEILISEARCH_MASTER_KEY" # Muss mit dem Schlüssel in meilisearch-search.nix übereinstimmen
        "DOCUMENTS_PATH=/mnt/nas_docs"
        "MEILISEARCH_INDEX_NAME=nas_documents"
      ];
    };
  };

  # Dies erstellt den Pfad zum Skript im Nix-Store
  system.build.scriptPath = pkgs.runCommand "indexing-script" {} ''
    mkdir -p $out/scripts
    cp ${self}/scripts/index_documents.py $out/scripts/index_documents.py
    chmod +x $out/scripts/index_documents.py
  '';
}
