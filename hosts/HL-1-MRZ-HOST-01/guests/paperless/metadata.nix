# Auto-Tagging Metadaten für Paperless-NGX
#
# Definiert Document Types und Correspondents mit Regex-Matchern.
# Wird via systemd-Service `paperless-provision-metadata` idempotent in die
# paperless DB provisioniert (siehe paperless.nix).
#
# Matching-Algorithmen (paperless DocumentMatching):
#   1=Any, 2=All, 3=Literal, 4=Regex, 5=Fuzzy, 6=Auto
{
  # ---------------------------------------------------------------------------
  # Document Types
  # Reihenfolge ist wichtig: Spezifische Types sollten VOR generischen kommen,
  # damit "Steuerbescheid" nicht als "Bescheid" klassifiziert wird.
  # ---------------------------------------------------------------------------
  documentTypes = [
    # Spezifische Bescheide & Verträge zuerst
    { name = "Steuerbescheid"; match = "(?i)steuerbescheid"; algorithm = 4; }
    { name = "Mietvertrag"; match = "(?i)mietvertrag"; algorithm = 4; }
    { name = "Gehaltsabrechnung"; match = "(?i)(gehaltsabrechnung|lohnabrechnung|verdienstabrechnung)"; algorithm = 4; }
    { name = "Nebenkostenabrechnung"; match = "(?i)(nebenkostenabrechnung|betriebskostenabrechnung)"; algorithm = 4; }
    { name = "Versicherungspolice"; match = "(?i)versicherungs(schein|police)"; algorithm = 4; }
    { name = "Auftragsbestätigung"; match = "(?i)(auftragsbestätigung|bestellbestätigung)"; algorithm = 4; }
    { name = "Lieferschein"; match = "(?i)lieferschein"; algorithm = 4; }
    { name = "Kontoauszug"; match = "(?i)kontoauszug"; algorithm = 4; }
    { name = "Wertpapierabrechnung"; match = "(?i)(wertpapierabrechnung|depotauszug)"; algorithm = 4; }

    # Generische Types
    { name = "Rechnung"; match = "(?i)\\brechnung\\b"; algorithm = 4; }
    { name = "Mahnung"; match = "(?i)\\bmahnung\\b"; algorithm = 4; }
    { name = "Vertrag"; match = "(?i)\\bvertrag\\b"; algorithm = 4; }
    { name = "Angebot"; match = "(?i)\\bangebot\\b"; algorithm = 4; }
    { name = "Antrag"; match = "(?i)\\bantrag\\b"; algorithm = 4; }
    { name = "Bescheid"; match = "(?i)\\bbescheid\\b"; algorithm = 4; }
    { name = "Quittung"; match = "(?i)\\bquittung\\b"; algorithm = 4; }
    { name = "Beleg"; match = "(?i)\\bbeleg\\b"; algorithm = 4; }
    { name = "Bestätigung"; match = "(?i)\\bbestätigung\\b"; algorithm = 4; }
    { name = "Kündigung"; match = "(?i)kündigung"; algorithm = 4; }
    { name = "Widerruf"; match = "(?i)\\bwiderruf\\b"; algorithm = 4; }
    { name = "Zeugnis"; match = "(?i)\\bzeugnis\\b"; algorithm = 4; }

    # Medizinisch
    { name = "Arztbrief"; match = "(?i)arztbrief"; algorithm = 4; }
    { name = "Rezept"; match = "(?i)\\brezept\\b"; algorithm = 4; }
    { name = "Befund"; match = "(?i)\\bbefund\\b"; algorithm = 4; }
    { name = "Attest"; match = "(?i)\\battest\\b"; algorithm = 4; }
  ];

  # ---------------------------------------------------------------------------
  # Correspondents
  # Patterns toleranter halten (OCR-Fehler kompensieren), case-insensitive.
  # ---------------------------------------------------------------------------
  correspondents = [
    # Banken / Bausparkassen
    { name = "Aareal Bank"; match = "(?i)aareal"; algorithm = 4; }
    { name = "Commerzbank"; match = "(?i)commerzbank"; algorithm = 4; }
    { name = "Comdirect"; match = "(?i)comdirect"; algorithm = 4; }
    { name = "Deutsche Bank"; match = "(?i)deutsche\\s+bank"; algorithm = 4; }
    { name = "1822direkt (Frankfurter Sparkasse)"; match = "(?i)1822direkt"; algorithm = 4; }
    { name = "ING"; match = "(?i)\\bING(\\s+(DiBa|Bank))?\\b"; algorithm = 4; }
    { name = "Postbank"; match = "(?i)postbank"; algorithm = 4; }
    { name = "Volksbank"; match = "(?i)volksbank"; algorithm = 4; }
    { name = "Raiffeisenbank"; match = "(?i)raiffeisenbank"; algorithm = 4; }
    { name = "Hypovereinsbank"; match = "(?i)hypovereinsbank|hypo\\s+vereinsbank"; algorithm = 4; }
    { name = "Santander"; match = "(?i)santander"; algorithm = 4; }
    { name = "Wüstenrot"; match = "(?i)wüstenrot"; algorithm = 4; }
    { name = "Debeka"; match = "(?i)debeka"; algorithm = 4; }
    { name = "LBS"; match = "\\bLBS\\b"; algorithm = 4; }
    { name = "Schwäbisch Hall"; match = "(?i)schwäbisch\\s+hall"; algorithm = 4; }

    # Krankenkassen / Versicherer
    { name = "HKK Krankenkasse"; match = "\\bHKK\\b"; algorithm = 4; }
    { name = "AOK"; match = "\\bAOK\\b"; algorithm = 4; }
    { name = "Allianz"; match = "(?i)allianz"; algorithm = 4; }
    { name = "Continentale"; match = "(?i)continentale"; algorithm = 4; }
    { name = "Provinzial"; match = "(?i)provinzial"; algorithm = 4; }
    { name = "HUK"; match = "\\bHUK(-COBURG)?\\b"; algorithm = 4; }
    { name = "VHV"; match = "\\bVHV\\b"; algorithm = 4; }
    { name = "ADAC"; match = "\\bADAC\\b"; algorithm = 4; }
    { name = "R+V"; match = "R\\+V"; algorithm = 4; }
    { name = "Union Krankenversicherung"; match = "(?i)union\\s+krankenversicherung"; algorithm = 4; }

    # Strom / Gas / Wasser
    { name = "Vattenfall"; match = "(?i)vattenfall"; algorithm = 4; }
    { name = "E.ON"; match = "(?i)\\b(e\\.?on)\\b"; algorithm = 4; }
    { name = "Syna"; match = "(?i)\\bsyna\\b"; algorithm = 4; }
    { name = "Süwag"; match = "(?i)süwag"; algorithm = 4; }
    { name = "Energie Deutschland"; match = "(?i)energie\\s+deutschland"; algorithm = 4; }

    # Telekommunikation
    { name = "Telekom"; match = "(?i)\\btelekom\\b"; algorithm = 4; }
    { name = "Vodafone"; match = "(?i)vodafone"; algorithm = 4; }
    { name = "1&1"; match = "1\\s*&\\s*1\\b"; algorithm = 4; }
    { name = "O2 / Telefónica"; match = "(?i)(\\bO2\\b|telef[oó]nica)"; algorithm = 4; }

    # Behörden / öffentliche Stellen
    { name = "Finanzamt"; match = "(?i)finanzamt"; algorithm = 4; }
    { name = "Stadt Idstein"; match = "(?i)stadt\\s+idstein"; algorithm = 4; }
    { name = "Familienkasse"; match = "(?i)familienkasse"; algorithm = 4; }
    { name = "Bundesagentur für Arbeit"; match = "(?i)bundesagentur\\s+für\\s+arbeit"; algorithm = 4; }
    { name = "Deutsche Rentenversicherung"; match = "(?i)deutsche\\s+rentenversicherung"; algorithm = 4; }

    # Online-Händler / Big Tech
    { name = "Amazon"; match = "(?i)\\bamazon\\b"; algorithm = 4; }
    { name = "PayPal"; match = "(?i)paypal"; algorithm = 4; }
    { name = "Apple"; match = "(?i)\\bapple\\b"; algorithm = 4; }
    { name = "Microsoft"; match = "(?i)microsoft"; algorithm = 4; }
    { name = "Google"; match = "(?i)\\bgoogle\\b"; algorithm = 4; }
    { name = "Klarna"; match = "(?i)klarna"; algorithm = 4; }
    { name = "Otto"; match = "(?i)\\botto\\s+(versand|gmbh|gruppe)\\b"; algorithm = 4; }
    { name = "Zalando"; match = "(?i)zalando"; algorithm = 4; }
    { name = "Cyberport"; match = "(?i)cyberport"; algorithm = 4; }

    # Bau- und Heimwerkermärkte / Lokal
    { name = "OBI"; match = "\\bOBI\\b"; algorithm = 4; }
    { name = "Bauhaus"; match = "(?i)\\bbauhaus\\b"; algorithm = 4; }
    { name = "IKEA"; match = "(?i)\\bikea\\b"; algorithm = 4; }
    { name = "Graulich Baustoff"; match = "(?i)graulich.{0,5}baustoff"; algorithm = 4; }
    { name = "Jedina Bau"; match = "(?i)jedina\\s+bau"; algorithm = 4; }

    # Sonstige
    { name = "Buhl Data Service (WISO)"; match = "(?i)buhl\\s+data"; algorithm = 4; }
  ];
}
