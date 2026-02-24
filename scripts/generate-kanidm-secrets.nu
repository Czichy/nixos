#!/usr/bin/env nu

# ==============================================================================
# generate-kanidm-secrets.nu
#
# Erzeugt alle fehlenden agenix-.age-Dateien fuer die Kanidm-Implementierung.
#
# Voraussetzungen:  age, openssl, ssh-to-age (nur bei SSH-Keys)
#
# Verwendung:
#   nu scripts/generate-kanidm-secrets.nu <secrets-repo-pfad>
#   nu scripts/generate-kanidm-secrets.nu ~/nix-secrets --recipient-file ./recipients.txt
#   nu scripts/generate-kanidm-secrets.nu ~/nix-secrets --host02-key "ssh-ed25519 AA..."
#
# Idempotent: vorhandene .age-Dateien werden uebersprungen.
#
# Jedes OAuth2-Secret wird DOPPELT gespeichert:
#   1. Fuer Kanidm-Guest (HOST-02) -> provisioning
#   2. Fuer Consumer-Guest (HOST-01/PROXY) -> Service-OIDC-Config
# ==============================================================================

const KANIDM_DOMAIN = "auth.czichy.com"
const KANIDM_BASE = "hosts/HL-1-MRZ-HOST-02/guests/kanidm"

def generate-password []: nothing -> string {
    ^openssl rand -base64 32 | str trim
}

def check-command [cmd: string]: nothing -> bool {
    (which $cmd | length) > 0
}

def to-age-key [key: string]: nothing -> string {
    if ($key | str starts-with "age1") {
        $key
    } else if (check-command "ssh-to-age") {
        $key | ^ssh-to-age | str trim
    } else {
        print "FEHLER: ssh-to-age nicht gefunden. nix-shell -p ssh-to-age"
        exit 1
    }
}

def encrypt-to-age [plaintext: string, output_path: string, recipients: list<string>]: nothing -> bool {
    if ($output_path | path exists) { return false }
    let parent = ($output_path | path dirname)
    mkdir $parent
    let args = ($recipients | each {|r|
        if ($r | path exists) { ["-R" $r] } else { ["-r" $r] }
    } | flatten)
    $plaintext | ^age ...$args -o $output_path
    true
}

def save-plain [plaintext: string, category: string, filename: string] {
    let d = $"/tmp/kanidm-secrets/($category)"
    mkdir $d
    $plaintext | save -f ($d | path join $filename)
    print $"    PLAIN ($filename) -> ($d)/($filename)"
}

def do-secret [val: string, age_path: string, recip: list<string>, cat: string, fname: string, dry: bool]: nothing -> string {
    if ($age_path | path exists) {
        print $"    SKIP  ($fname)"
        return "skipped"
    }
    if $dry {
        print $"    DRY   ($fname)"
        return "created"
    }
    if ($recip | length) > 0 {
        encrypt-to-age $val $age_path $recip
        print $"    OK    ($fname)"
    } else {
        save-plain $val $cat $fname
    }
    "created"
}

def main [
    secrets_repo: string
    --host02-key: string
    --host01-key: string
    --proxy-key: string
    --recipient-file: string
    --dry-run
] {
    for cmd in ["age" "openssl"] {
        if not (check-command $cmd) {
            print $"FEHLER: ($cmd) nicht gefunden. nix-shell -p ($cmd)"
            exit 1
        }
    }
    let secrets_repo = ($secrets_repo | path expand)
    if not ($secrets_repo | path exists) {
        print $"FEHLER: Secrets-Repo nicht gefunden: ($secrets_repo)"
        exit 1
    }

    let has_keys = ($recipient_file != null) or ($host02_key != null)

    let rk = if ($recipient_file != null) { [$recipient_file] } else if ($host02_key != null) { [(to-age-key $host02_key)] } else { [] }
    let r1 = if ($recipient_file != null) { [$recipient_file] } else if ($host01_key != null) { [(to-age-key $host01_key)] } else { [] }
    let rp = if ($recipient_file != null) { [$recipient_file] } else if ($proxy_key != null) { [(to-age-key $proxy_key)] } else { [] }

    if not $has_keys {
        print ""
        print "WARNING: Keine Empfaenger-Keys angegeben!"
        print "  Secrets -> PLAINTEXT in /tmp/kanidm-secrets/"
        print "  Optionen: --recipient-file | --host02-key | --host01-key | --proxy-key"
        print "  Guest-SSH-Key auslesen: ssh-keyscan -t ed25519 <ip> 2>/dev/null"
        print "  Parent-Host-Keys (pubkeys.nix):"
        print "    HOST-01: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIELTffOa/Vh2x/CxDqKJXnwfji/aHLYbbG3ewwjFMHxZ"
        print "    HOST-02: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDPR8KYYsWTQ+sOFMlKXTJU6ZDG84ebHtqI4wotvCYzH"
        print "  ACHTUNG: MicroVM-Guests haben EIGENE SSH-Keys!"
        print ""
    }

    print "======= Kanidm Secrets Generator ======="
    print $"  Repo:   ($secrets_repo)"
    print $"  Modus:  (if $has_keys { "age-verschluesselt" } else { "Plaintext" })(if $dry_run { " (DRY-RUN)" } else { "" })"
    print ""

    let kb = ($secrets_repo | path join $KANIDM_BASE)
    mut created = 0
    mut skipped = 0

    # === 1. TLS-Zertifikat ===
    print "-- 1. TLS-Zertifikat --"
    let crt_p = ($kb | path join "kanidm-self-signed.crt.age")
    let key_p = ($kb | path join "kanidm-self-signed.key.age")

    if ($crt_p | path exists) and ($key_p | path exists) {
        print "    SKIP  TLS cert+key existieren"
        $skipped = $skipped + 2
    } else if $dry_run {
        print $"    DRY   TLS cert+key fuer ($KANIDM_DOMAIN)"
        $created = $created + 2
    } else {
        let td = (mktemp -d)
        let tk = ($td | path join "k.key")
        let tc = ($td | path join "k.crt")
        ^openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout $tk -out $tc -subj $"/CN=($KANIDM_DOMAIN)" -addext $"subjectAltName=DNS:($KANIDM_DOMAIN)" err> /dev/null
        let cc = (open $tc --raw)
        let kc = (open $tk --raw)
        if ($rk | length) > 0 {
            encrypt-to-age $cc $crt_p $rk; print "    OK    kanidm-self-signed.crt.age"
            encrypt-to-age $kc $key_p $rk; print "    OK    kanidm-self-signed.key.age"
        } else {
            save-plain $cc "tls" "kanidm-self-signed.crt"
            save-plain $kc "tls" "kanidm-self-signed.key"
        }
        rm -rf $td
        $created = $created + 2
    }

    # === 2. Admin-Passwoerter ===
    print "-- 2. Admin-Passwoerter --"
    for entry in [{name: "admin", file: "admin-password"}, {name: "idm-admin", file: "idm-admin-password"}] {
        let ap = ($kb | path join $"($entry.file).age")
        let pw = (generate-password)
        let r = (do-secret $pw $ap $rk "admin" $entry.file $dry_run)
        if $r == "skipped" { $skipped = $skipped + 1 } else { $created = $created + 1 }
    }

    # === 3. OAuth2 Client-Secrets ===
    print "-- 3. OAuth2 Client-Secrets --"
    print "  Pro Client: a) Kanidm-Seite (HOST-02) + b) Consumer-Seite"
    print ""

    let clients = [
        {name: "grafana",      cdir: "hosts/HL-1-MRZ-HOST-01/guests/grafana",      cr: $r1}
        {name: "forgejo",      cdir: "hosts/HL-1-MRZ-HOST-01/guests/forgejo",      cr: $r1}
        {name: "paperless",    cdir: "hosts/HL-1-MRZ-HOST-01/guests/paperless",    cr: $r1}
        {name: "immich",       cdir: "hosts/HL-1-MRZ-HOST-01/guests/immich",       cr: $r1}
        {name: "linkwarden",   cdir: "hosts/HL-1-MRZ-HOST-01/guests/linkwarden",   cr: $r1}
        {name: "web-sentinel", cdir: "hosts/HL-4-PAZ-PROXY-01/secrets",            cr: $rp}
    ]

    for c in $clients {
        print $"  ($c.name):"
        let secret = (generate-password)

        # a) Kanidm-Seite
        let ka = ($kb | path join $"oauth2-($c.name).age")
        let r1x = (do-secret $secret $ka $rk "oauth2" $"oauth2-($c.name).age" $dry_run)
        if $r1x == "skipped" { $skipped = $skipped + 1 } else { $created = $created + 1 }

        # b) Consumer-Seite
        let ca = ($secrets_repo | path join $c.cdir | path join "oauth2-client-secret.age")
        let r2x = (do-secret $secret $ca $c.cr "oauth2" $"($c.name)/oauth2-client-secret.age" $dry_run)
        if $r2x == "skipped" { $skipped = $skipped + 1 } else { $created = $created + 1 }
    }

    # === Zusammenfassung ===
    print ""
    print "======= Zusammenfassung ======="
    print $"  Erstellt:       ($created)"
    print $"  Uebersprungen:  ($skipped)"
    if not $has_keys and $created > 0 {
        print ""
        print "  Naechster Schritt: Plaintext-Secrets in /tmp/kanidm-secrets/"
        print "  manuell mit age verschluesseln:"
        print "    age -R <recipient-file> -o <output.age> < <plaintext-file>"
    }
    if $dry_run {
        print ""
        print "  DRY-RUN: Keine Dateien wurden geschrieben."
    }
    print ""
}
