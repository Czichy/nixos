---
title: "Setup"
date: 2023-03-19T21:42:49-04:00
publishDate: 2023-03-19T21:42:49-04:00
draft: true
description: "How I setup my systems"
categories:
- homelab
- vpn
- firewall
tags:
- home lab
- homelab
- lab
- opnsense
- openvpn
- open vpn
- opensense
- microstack
- openstack
- firewall
- vpn
- nas
menu:
  sidebar:
    name: "Setup"
    identifier: setup
    parent: homelab
    weight: 1
---

### Opener
I have always day dreamed about being able to have my own home lab setup. Luckily I was gifted some older machines from a friend of mine who has also been very helpful in getting most of this setup. And so the fun has begun.

I have been gifted 3x r610s, 1x T610, 1x T420, and 1x MD3100. And now the journey to figure out what I will do with all this, and how I want to accomplish my goals has begun. So thank you greatly my good friend.

### Main content
The first thing I wanted to do was to replace the router portion of my Orbi RBR50 with a system designed specifically for routing and let my Orbi's be the access points for now. I had heard glowing recomendations about OPNsense for hardware support so I chose that, but I knew I didn't need the full specs of [Sonic](/notes/servers) to be able to use this software. So, I went down the rabbit hole of launching OPNsense in a virtual machine.

### Chosing the OS
I started off trying to use VMware's ESXI (hypervisor), however V7 doesn't support my hardware, and they no longer provide V6.7 keys or downloads. So I had to go for something else. I am fairly confident in linux machines so I went with Ubuntu 22.04 server edition. I then made sure to install KVM on this machine so that I can virtualize the work.

```bash
sudo apt -y install bridge-utils cpu-checker libvirt-clients libvirt-daemon qemu qemu-kvm avahi-daemon bzip2 virt-manager;
```

### Virtualizing OPNsense
The first thing to note is that the OPNsense suggested I use the DVD version for virtual machines. However, every time I tried to boot that image up inside a virtual env I ended up with a message complaining that there was no boot device. So instead I followed some different steps that allowed me to get the image where I needed. I made sure to increase the image size to give it a little extra HDD room.

```bash
wget https://mirror.ams1.nl.leaseweb.net/opnsense/releases/23.1/OPNsense-23.1-OpenSSL-nano-amd64.img.bz2
bzip2 -d OPNsense-23.1-OpenSSL-nano-amd64.img.bz2
qemu-img convert -f raw -O qcow2 OPNsense-23.1-OpenSSL-nano-amd64.img OPNsense-23.1-OpenSSL-nano-amd64.qcow2
qemu-img resize OPNsense-23.1-OpenSSL-nano-amd64.qcow2 +8G
mv ~/OPNsense-23.1-OpenSSL-nano-amd64.qcow2 /var/lib/libvirt/images/opnsense231.qcow2
```

I then had to configure the KVM information by making an opnsense.xml in my home directory.

```xml
<domain type='kvm'>
  <name>opnsense</name>
  <memory unit='MiB'>2048</memory>
  <currentMemory unit='MiB'>2048</currentMemory>
  <vcpu>2</vcpu>
  <os>
    <type arch='x86_64'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features><acpi/><apic/><pae/></features>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>restart</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <controller type='pci' index='0' model='pci-root'/>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='none'/>
      <source file='/var/lib/libvirt/images/opnsense231.qcow2'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <interface type='bridge'>
      <source bridge='lanbr'/>
      <model type='virtio'/>
      <target dev='vtnet0'/>
      <alias name='net0'/>
    </interface>
    <interface type='bridge'>
      <source bridge='wanbr'/>
      <model type='virtio'/>
      <target dev='vtnet1'/>
      <alias name='net1'/>
    </interface>
    <serial type='pty'><target port='0'/></serial>
    <console type='pty'><target port='0'/></console>
    <memballoon model='none'></memballoon>
  </devices>
</domain>
```

But wait we have to get networking setup to be able to handle those wan and lan bridges mentioned in the file.

#### Networking
Let's first start off with saying this excersize reinforced why I don't pursue a career in networking. However, after a lot of struggling googling, and talking with a friend I got things to work out in my favor.

To start with I have 8 network ports total split between two cards. These ports are labeled as follows:

```yaml
  Card 1:
    - eno1
    - eno2
    - eno3
    - eno4
  Card 2:
    - enp6s0f0
    - enp6s0f1
    - enp7s0f0
    - enp7s0f1
```

I decided that Card 2's enp6s0f0 would be my WAN port based on where it was located, and eno4 will eventually become a maintenance port when I figure out how to handle that. All other ports will be used as a lan bridge.

Ubuntu 22.04 uses netplan by default. Using this I had to turn off dhcp on all ports first to avoid a public IP being assigned outside of the scope I am looking for. All IP, gateway, and routing will be handled with OPNsense so there is not a lot of configuration we have to do.

I then created a WAN bridge using the single interface I had designated and gave it a default search and address for DNS resolution. DHCP is off for this because we want OPNsense to handle the WAN by itself.

For the LAN bridge, I want to make sure that the host machine also gets an IP so I set dhcp4 to true to allow OPNsense to provide this IP.

This file on my machine was at `/etc/netplan/00-installer-config.yaml`, but my understanding is that netplan reads `/etc/netplan/*.yaml` so use that to your advantage if you need to.

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp6s0f0:
      dhcp4: false
    enp6s0f1:
      dhcp4: false
    enp7s0f0:
      dhcp4: false
    enp7s0f1:
      dhcp4: false
    eno1:
      dhcp4: false
    eno2:
      dhcp4: false
    eno3:
      dhcp4: false
  bridges:
    wanbr:
      dhcp4: false
      interfaces:
        - enp6s0f0
      nameservers:
        search: [local]
        addresses:
          - 8.8.8.8
          - 1.1.1.1
    lanbr:
      dhcp4: true
      interfaces:
        - enp6s0f1
        - enp7s0f0
        - enp7s0f1
        - eno1
        - eno2
        - eno3
```

Make sure to apply your changes

```bash
sudo netplan apply;
```

#### Back to virtualizing
Now we can go ahead and work with KVM to start the image and load up the console. 

```bash
sudo virsh define opnsense.xml
sudo virs list --all
sudo virsh start opnsense && wait 5 && sudo virsh console opnsense
```

The default username and password for me was as follows.
```yaml
username: root
password: opnsense
```

I then configured my wan and lan interfaces and then set the LAN interfaces IPs. I beleive this can be done through the web portal, but when I got to this step I had already had issues with my network and was going through everything I could to get the access I expected.

You should now go ahead and try pinging out and making sure you are able to connect to the internet.

Now comes the tricky part for me. Since I was running the server edition of Ubuntu on my host machine I didn't have a browser. So I had to plug in a second machine that I did to access the web portal for OPNsense. If I have one criticisim of OPNsense so far, it's that I shouldn't need the web portal, but it is helpful.

MAKE SURE TO CHANGE YOUR PASSWORD.

Allow opnsense to autostart with
```yaml
sudo virsh autostart opnsense;
```

### Summary
So now we have OPNsense installed. I went ahead and installed OpenVPN as well, but I don't plan on keeping this. I only installed it until I feel comfortable actually replacing the router.


(Installing OPNsense firewall on KVM)[https://www.linkedin.com/pulse/installing-opnsense-firewall-kvm-sergio-maeso-jim%C3%A9nez/?trk=public_post-content_share-article] was a good resource to get me started, but there was some major differences in how the network had to be handled for my machines.
