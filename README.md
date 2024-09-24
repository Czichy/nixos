# My NixOS Dotfiles

This is my NixOS dotfiles based on [nixos-starter-config](https://github.com/Misterio77/nix-starter-configs). Feel free to use it as a starting point for your own configuration.

## Why NixOS & Flakes?

Nix allows for easy-to-manage, collaborative, reproducible deployments. This means that once
something is setup and configured once, it works (almost) forever. If someone else shares their
configuration, anyone else can just use it (if you really understand what you're copying/refering
now).

As for Flakes, refer to
[Introduction to Flakes - NixOS & Nix Flakes Book](https://nixos-and-flakes.thiscute.world/nixos-with-flakes/introduction-to-flakes)

**Want to know NixOS & Flaks in detail? Looking for a beginner-friendly tutorial or best practices?
You don't have to go through the pain I've experienced again! Check out my
[NixOS & Nix Flakes Book - 🛠️ ❤️ An unofficial & opinionated :book: for beginners](https://github.com/ryan4yin/nixos-and-flakes-book)!**

## Setup OPNSense & Unifi

https://homenetworkguy.com/how-to/set-up-a-fully-functioning-home-network-using-opnsense/

## Hosts

|  | Type | Name | Hardware | Purpose
---|---|---|---|---
💻 | Laptop | nom | Gigabyte AERO 15-W8 (i7-8750H) | My laptop and my main portable development machine <sub>Framework when?</sub>
🖥️ | Desktop | kroma | PC (AMD Ryzen 9 5900X) | Main workstation and development machine, also for some occasional gaming
🖥️ | Server | ward | ODROID H3 | Energy efficient SBC for my home firewall and some lightweight services using containers and microvms.
🖥️ | Server | sire | Threadripper 1950X | Home media server and data storage. Runs all services as microvms.
🥔 | Server | zackbiene | ODROID N2+ | ARM SBC for home automation, isolating the sketchy stuff from my main network
☁️  | VPS | sentinel | Hetzner Cloud server | Proxies and protects my local services
☁️  | VPS | envoy | Hetzner Cloud server | Mailserver

### Host Naming Convention
 HL-#-ZZZ-FFF-$$

HL - Homelab

# - A number for the physical characteristics of the server

    1 is for physical servers at my house

    2 is for physical servers at my offsite location

    3 is for virtual servers hosted in my infrastructure

    4 is for virtual servers hosted in the cloud

ZZZ - Which security zone it belongs in, PAZ, RZ, etc

FFF - Function of the server, WEB, DNS, FW, etc

$$ - Serial number for duplicates 

### Security Zones

Name| Zone | VLAN | IP-Range |Purpose
---|---|---|---|---
Internet|  | VLAN1 | 10.15.1.254/24 | ISP
Trust | OZ | VLAN10 | 10.15.10.0/24 | Operations Zone, Family
Guest | GUEST | VLAN20 | 10.15.20.0/24 | No servers in this, internet only
Security | RZ | VLAN30 | 10.15.30.0/24 | MAC based access, internet only
Servers | RZ | VLAN40 | 10.15.40.0/24 | Restricted access
IoT | RZ | VLAN60 | 10.15.60.0/24 | Internet only
DMZ | DMZ | VLAN70 | 10.15.70.0/24 | Port specific access to servers
MGMT | MRZ |VLAN100 | 10.15.100.0/24 | Management Restricted Zone, where my management devices live, such as my hypervisors, switches, firewalls, etc

<!-- I operate 10 zones -->

    <!-- PAZ - Public Access Zone (also known as a DMZ by some), where anything public-facing lives, such as my reverse proxy and Mumble server -->

    <!-- RZ - Restricted Zone, a catch-all for general purpose servers such as Plex, OpenEats, etc -->

    <!-- IOG - Internet of Garbage, where all of my Google Homes, Roku, Chromecast, and basically all my "smart" shit lives -->

    <!-- DEV - Development VMs that I don't want mingling with the general population -->

    <!-- HRZ - Highly Restricted Zone, very sensitive things such as my intermediate CA -->

    <!-- VPN - If you're VPNing into my infrastructure, you're dumped into here -->

<!-- Most of the zones I run are outlined in ITSG-22 and ITSG-38, which are the Canadian Government's guidelines for network zoning. I work IT Security for the federal government, so it only makes sense that I practice what I preach. --> 

## :wrench: <samp>Installation</samp>

1. Download iso

### Prepare a ISO with activated SSH key

Ran the following to generate a custom ISO with an SSH public key already embedded:

```bash
cd ISO
nix run github:nix-community/nixos-generators -- --flake .#sshInstallIso --format iso
```

The ISO file will be generated in a directory called result.

## How to install NixOS

#Boot into the installer.

login via ssh

```bash
ssh nixos@<ip-addr>
```

Switch to root
```bash
sudo su
```
Switch to root
```bash
HOST=HL-4-PAZ-PROXY-01
```

# Clone Repo

Register key in Github

```bash
ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -C "root@installer"
cat /root/.ssh/id_ed25519.pub
```

```bash
git clone git@github.com:Czichy/nixos.git
cd nixos
```

1. change the disk device path in ./disko.nix to the disk you want to use
1. partition & format the disk via disko

```bash
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko --flake .#"${HOST}"
```

Check Disk Layout

```bash
lsblk --output "NAME,SIZE,FSTYPE,FSVER,LABEL,PARTLABEL,UUID,FSAVAIL,FSUSE%,MOUNTPOINTS,DISC-MAX"
```

Run following command to generate new ssh key pair:

```bash
sudo mkdir -p /mnt/persist/etc/ssh/
sudo ssh-keygen -t ed25519 -f /mnt/persist/etc/ssh/ssh_host_ed25519_key -C ""
cp /mnt/persist/etc/ssh/ssh_host_ed25519_key* /etc/ssh/
cat /mnt/persist/etc/ssh/ssh_host_ed25519_key.pub
```

Add key to Secret Repo

Rekey:

```bash
sudo ragenix -r -i ~/.ssh/czichy_desktop_ed25519
```

Update Flake

```bash
nix flake lock --update-input private
```

install nixos
```bash
sudo nixos-install --root /mnt --flake .#"${HOST}" --show-trace --verbose --impure --no-root-passwd
```

Create SSH Key for initrd-ssh (LUKS)
```bash
mkdir /mnt/nix/secret/initrd -p
ssh-keygen -t ed25519 -N "" -C "" -f /mnt/nix/secret/initrd/ssh_host_ed25519_key
```

Move Repo

```bash
mv /root/nixos /mnt/persist/etc/
```

enter into the installed system, check password & users
if login failed, check the password you set in install-1, and try again

```bash
nixos-enter
```
** Unmount filesystems:
```bash
umount -Rl /mnt
zpool export -a
```

** Reboot:

```bash
reboot
```



## Deploying the main flake's NixOS configuration

After rebooting, we need to generate a new SSH key for the new machine, and add it to GitHub, so
that the new machine can pull my private secrets repo:

```bash
# 1. Generate a new SSH key with a strong passphrase
ssh-keygen -t ed25519 -a 256 -C "ryan@idols-ai" -f ~/.ssh/idols_ai
# 2. Add the ssh key to the ssh-agent, so that nixos-rebuild can use it to pull my private secrets repo.
ssh-add ~/.ssh/idols_ai
```

Then follow the instructions in [../secrets/README.md](../secrets/README.md) to rekey all my secrets
with the new host's system-level SSH key(`/etc/ssh/ssh_host_ed25519_key`), so that agenix can
decrypt them automatically on the new host when I deploy my NixOS configuration.

After all these steps, we can finally deploy the main flake's NixOS configuration by:

````bash
sudo mv /etc/nixos ~/nix-config
sudo chown -R ryan:ryan ~/nix-config

cd ~/nix-config


### 1. Prepare a USB LUKS key

Generate LUKS keyfile to encrypt the root partition, it's used by disko.

```bash
# partition the usb stick
DEV=/dev/sdX
parted ${DEV} -- mklabel gpt
parted ${DEV} -- mkpart primary 2M 512MB
mkfs.fat -F 32 -n OPI5_DSC ${DEV}1


# Generate a keyfile from the true random number generator
KEYFILE=./orangepi5-luks-keyfile
dd bs=512 count=64 iflag=fullblock if=/dev/random of=$KEYFILE

# copy the keyfile and token to the usb stick
KEYFILE=./orangepi5-luks-keyfile
DEVICE=/dev/disk/by-label/OPI5_DSC
# seek=128 skip N obs-sized output blocks to avoid overwriting the filesystem header
dd bs=512 count=64 iflag=fullblock seek=128 if=$KEYFILE of=$DEVICE
````

Generate initial NixOS configuration

With the disk partitioned, we are ready to follow the usual NixOS installation process. The first step is to generate the initial NixOS configuration under /mnt.

```bash
sudo nixos-generate-config --no-filesystems --root /mnt
```

Why --no-filesystems and --root?

```
The fileSystems configuration will automatically be added by disko’s nixosModule (see below). Therefore, we use --no-filesystems to avoid generating it here.
--root is to specify the mountpoint to generate configuration.nix and hardware-configuration.nix in. Here, our configuration will be generated in /mnt/etc/nixos.
```

Enable flakes

```bash
nix-shell -p nixFlakes git
```

Enable Feature

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
```

Partition Harddrive

```bash
./scripts/partition.sh
```

Install nixos from flake

```bash
nixos-install --flake ./#virtual_home --impure
```

Apply your home configuration.

```bash
home-manager switch --flake .#czichy@virtual_home
```

If you don't have home-manager installed, try

```bash
nix shell nixpkgs#home-manager
```

[anyrun]: https://github.com/Kirottu/anyrun
[btop]: https://github.com/aristocratos/btop
[btrfs]: https://btrfs.readthedocs.io
[catppuccin]: https://github.com/catppuccin/catppuccin
[doomemacs]: https://github.com/doomemacs/doomemacs
[dunst]: https://github.com/dunst-project/dunst
[fcitx5]: https://github.com/fcitx/fcitx5
[flameshot]: https://github.com/flameshot-org/flameshot
[gdm]: https://wiki.archlinux.org/title/GDM
[grim]: https://github.com/emersion/grim
[hyprland]: https://github.com/hyprwm/Hyprland
[i3]: https://github.com/i3/i3
[imv]: https://sr.ht/~exec64/imv/
[kitty]: https://github.com/kovidgoyal/kitty
[lanzaboote]: https://github.com/nix-community/lanzaboote
[luks]: https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system
[mako]: https://github.com/emersion/mako
[mpc]: https://github.com/MusicPlayerDaemon/mpc
[mpd]: https://github.com/MusicPlayerDaemon/MPD
[mpv]: https://github.com/mpv-player/mpv
[ncmpcpp]: https://github.com/ncmpcpp/ncmpcpp
[neovim]: https://github.com/neovim/neovim
[nerd fonts]: https://github.com/ryanoasis/nerd-fonts
[netease-cloud-music-gtk]: https://github.com/gmg137/netease-cloud-music-gtk
[networkmanager]: https://wiki.gnome.org/Projects/NetworkManager
[nushell]: https://github.com/nushell/nushell
[obs]: https://obsproject.com
[polybar]: https://github.com/polybar/polybar
[rofi]: https://github.com/davatorium/rofi
[starship]: https://github.com/starship/starship
[thunar]: https://gitlab.xfce.org/xfce/thunar
[waybar]: https://github.com/Alexays/Waybar
[yazi]: https://github.com/sxyazi/yazi
[zellij]: https://github.com/zellij-org/zellij
