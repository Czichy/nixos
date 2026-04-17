# NixOS Homelab

A production NixOS homelab managed entirely with Nix Flakes. Reproducible, declaratively configured, with MicroVM guests, ZFS-backed impermanence, agenix secrets, and Kanidm SSO.

## Host Naming Convention

```
HL-#-ZZZ-FFF-##
```

| Segment | Meaning |
|---------|---------|
| `HL` | Homelab |
| `#` | `1` = physical on-site · `2` = physical off-site · `3` = virtual (MicroVM) · `4` = cloud VPS |
| `ZZZ` | Security zone: `OZ` Trust · `MRZ` Management · `RZ` Servers · `PAZ` Public Access |
| `FFF` | Function: `HOST` hypervisor · `FW` firewall · `PROXY` reverse-proxy · service name |
| `##` | Serial number |

---

## Physical Hosts

| Host | Hardware | Role |
|------|----------|------|
| `HL-1-OZ-PC-01` | AMD Ryzen 9 7950X · RX 7900 XTX | Workstation (daily driver, gaming) |
| `HL-1-MRZ-HOST-01` | AMD Ryzen 9 7950X · 128 GB RAM | Hypervisor – primary compute |
| `HL-1-MRZ-HOST-02` | Intel NUC i7 · 64 GB RAM | Hypervisor – services & auth |
| `HL-1-MRZ-HOST-03` | Intel NUC i7 · 32 GB RAM | Hypervisor – home automation & media |
| `HL-3-MRZ-FW-01` | OPNsense (PC Engines APU) | Firewall / router |
| `HL-4-PAZ-PROXY-01` | Hetzner VPS | WireGuard ingress + Caddy reverse proxy |

---

## Network Zones (VLANs)

| Zone | VLAN | Subnet | Purpose |
|------|------|--------|---------|
| Home LAN | 1 | `10.15.1.0/24` | Physical LAN baseline |
| Trust (OZ) | 10 | `10.15.10.0/24` | Family devices, workstations |
| Guest | 20 | `10.15.20.0/24` | Internet-only guest Wi-Fi |
| Security | 30 | `10.15.30.0/24` | MAC-restricted, internet-only |
| Servers (RZ) | 40 | `10.15.40.0/24` | MicroVM guests |
| IoT | 60 | `10.15.60.0/24` | Smart home devices, internet-only |
| DMZ | 70 | `10.15.70.0/24` | Port-specific access to servers |
| MGMT (MRZ) | 100 | `10.15.100.0/24` | Hypervisors, switches, firewall |
| WireGuard Tunnel | — | `10.46.0.0/24` | VPS ↔ homelab tunnel |

---

## MicroVM Guests

All guests run under [microvm.nix](https://github.com/astro/microvm.nix) on their respective hypervisors.

| Guest | Host | IP | Services |
|-------|------|----|----------|
| `HL-3-RZ-CADDY-01` | HOST-02 | `10.15.40.10` | Internal reverse proxy (Caddy) |
| `HL-3-RZ-AUTH-01` | HOST-02 | `10.15.40.15` | Kanidm identity provider |
| `HL-3-RZ-DNS-01` | HOST-02 | `10.15.40.20` | AdGuard Home (DNS) |
| `HL-3-RZ-VAULT-01` | HOST-02 | `10.15.40.25` | Vaultwarden |
| `HL-3-RZ-SYNC-02` | HOST-02 | `10.15.40.26` | Syncthing |
| `HL-3-RZ-KARA-01` | HOST-02 | `10.15.40.30` | Karakeep (bookmarks) |
| `HL-3-RZ-CAL-01` | HOST-02 | `10.15.40.35` | Radicale (CalDAV/CardDAV) |
| `HL-3-RZ-FAVA-01` | HOST-01 | `10.15.40.41` | Fava (Beancount/Ledger) |
| `HL-3-RZ-S3-01` | HOST-01 | `10.15.40.50` | Garage (S3-compatible storage) |
| `HL-3-RZ-SMB-01` | HOST-01 | `10.15.40.55` | Samba file share |
| `HL-3-RZ-UNIFI-01` | HOST-01 | `10.15.40.60` | Unifi controller |
| `HL-3-RZ-INFLUX-01` | HOST-01 | `10.15.40.65` | InfluxDB |
| `HL-3-RZ-METRICS-01` | HOST-01 | `10.15.40.70` | Grafana + Prometheus |
| `HL-3-RZ-LOG-01` | HOST-01 | `10.15.40.75` | Loki (log aggregation) |
| `HL-3-RZ-MQTT-01` | HOST-03 | `10.15.40.80` | Mosquitto (MQTT broker) |
| `HL-3-RZ-HASS-01` | HOST-03 | `10.15.40.85` | Home Assistant |
| `HL-3-RZ-RED-01` | HOST-03 | `10.15.40.90` | Node-RED |
| `HL-3-RZ-N8N-01` | HOST-03 | `10.15.40.95` | n8n (automation) |
| `HL-3-RZ-POWER-02` | HOST-03 | `10.15.40.100` | Powerhome (energy monitoring) |
| `HL-3-RZ-MC-01` | HOST-01 | `10.15.40.110` | Minecraft server |
| `HL-3-DMZ-PROXY-01` | HOST-02 | `10.15.70.10` | DMZ Caddy (external entry) |

---

## Key Technologies

| Area | Tool |
|------|------|
| Configuration | [Nix Flakes](https://nixos.wiki/wiki/Flakes) + [flake-parts](https://flake.parts) |
| Virtualisation | [microvm.nix](https://github.com/astro/microvm.nix) (QEMU/virtiofs) |
| Disk partitioning | [disko](https://github.com/nix-community/disko) |
| Impermanence | [impermanence](https://github.com/nix-community/impermanence) + ZFS |
| Secrets | [ragenix](https://github.com/yaxitech/ragenix) (age-encrypted) |
| Identity / SSO | [Kanidm](https://kanidm.com) (OAuth2/OIDC + LDAP) |
| Reverse proxy | [Caddy](https://caddyserver.com) |
| Deployment | [deploy-rs](https://github.com/serokell/deploy-rs) |
| Network diagram | [nix-topology](https://github.com/oddlama/nix-topology) |
| Home manager | [home-manager](https://github.com/nix-community/home-manager) |
| Shell | [Nushell](https://www.nushell.sh) |
| Window manager | [Niri](https://github.com/YaLTeR/niri) (Wayland) |

---

## Repository Layout

```
nixos/
├── flake.nix                  # Flake inputs & outputs
├── flake.lock
├── justfile                   # Task runner (just)
├── globals.nix                # Shared host/network/user definitions
├── hosts/
│   ├── HL-1-OZ-PC-01/        # Workstation
│   ├── HL-1-MRZ-HOST-01/     # Hypervisor + guest declarations
│   ├── HL-1-MRZ-HOST-02/
│   ├── HL-1-MRZ-HOST-03/
│   ├── HL-3-MRZ-FW-01/       # OPNsense (non-NixOS, reference only)
│   └── HL-4-PAZ-PROXY-01/    # VPS
├── modules/
│   ├── nixos/                 # NixOS modules
│   └── home-manager/          # Home-manager modules
├── packages/                  # Custom packages
├── topology/                  # nix-topology network diagram
│   ├── default.nix            # Non-NixOS nodes (router, switches, APs…)
│   └── icons/ images/
└── lib/                       # Helper functions
```

---

## Common Tasks (Justfile)

```nu
just local          # Rebuild current host (nixos-rebuild switch)
just remote <HOST>  # Deploy to a remote host via deploy-rs
just update         # Update all flake inputs
just rekey          # Re-encrypt all agenix secrets after adding a new host key
just topology       # Build & open network diagram SVGs
just fmt            # Format all .nix files
just check          # Run flake checks
```

---

## Installation (New Host)

### 1. Boot NixOS installer

```bash
ssh nixos@<ip>
sudo su
HOST=HL-1-MRZ-HOST-01
```

### 2. Clone the repo

```bash
ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -C "root@installer"
cat /root/.ssh/id_ed25519.pub   # add to GitHub
git clone git@github.com:Czichy/nixos.git
cd nixos
```

### 3. Partition with disko

```bash
nix --experimental-features "nix-command flakes" \
  run github:nix-community/disko/latest -- --mode disko --flake .#"${HOST}"
```

### 4. Generate host SSH key (for agenix)

```bash
mkdir -p /mnt/persist/etc/ssh
ssh-keygen -t ed25519 -f /mnt/persist/etc/ssh/ssh_host_ed25519_key -C ""
cp /mnt/persist/etc/ssh/ssh_host_ed25519_key* /etc/ssh/
cat /mnt/persist/etc/ssh/ssh_host_ed25519_key.pub
```

Add the public key to `nix-secrets` as an agenix recipient, then rekey:

```bash
cd ~/projects/nix-secrets
ragenix -r -i ~/.ssh/czichy_desktop_ed25519
```

Update the flake lock to pick up re-encrypted secrets:

```bash
cd ~/projects/nixos
nix flake lock --update-input private
```

### 5. Install

```bash
nixos-install --root /mnt --flake .#"${HOST}" --no-root-passwd --show-trace
mv /root/nixos /mnt/persist/etc/
umount -Rl /mnt && zpool export -a
reboot
```

---

## Secrets (agenix/ragenix)

Secrets live in a private repo (`nix-secrets`) referenced as a flake input.  
Each secret is encrypted with the public keys of all hosts and users that need it.

- Add a new secret: create `<name>.age`, add recipients, run `ragenix -r`.
- Rotate after adding a new host: `just rekey`.
- Runtime path: `/run/agenix/<secret-name>` (decrypted by agenix at boot/activation).

---

## Network Diagram

The topology is generated from the NixOS configurations automatically via
[nix-topology](https://github.com/oddlama/nix-topology).
Non-NixOS nodes (routers, switches, APs) are declared manually in `topology/default.nix`.

```nu
just topology   # builds SVGs and opens them
# or manually:
nix build .#topology.x86_64-linux.config.output
```

---

## Kanidm SSO

Kanidm runs on `HL-3-RZ-AUTH-01` (`10.15.40.15`, LDAPS on port `3636`).

Current OAuth2/OIDC integrations: Grafana, Forgejo, Karakeep, Fava, Vaultwarden (oauth2-proxy).  
LDAP integrations: Radicale (CalDAV/CardDAV).

All client secrets are age-encrypted in `nix-secrets/hosts/HL-1-MRZ-HOST-02/guests/kanidm/`.
