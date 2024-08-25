#
# Author:  czichy <christian@czichy.com>
# URL:     https://github.com/czichy/tensorfiles
# License: MIT
#
# 888                                                .d888 d8b 888
# 888                                               d88P"  Y8P 888
# 888                                               888        888
# 888888 .d88b.  88888b.  .d8888b   .d88b.  888d888 888888 888 888  .d88b.  .d8888b
# 888   d8P  Y8b 888 "88b 88K      d88""88b 888P"   888    888 888 d8P  Y8b 88K
# 888   88888888 888  888 "Y8888b. 888  888 888     888    888 888 88888888 "Y8888b.
# Y88b. Y8b.     888  888      X88 Y88..88P 888     888    888 888 Y8b.          X88
#  "Y888 "Y8888  888  888  88888P'  "Y88P"  888     888    888 888  "Y8888   88888P'
{localFlake}: {config, ...}: let
  inherit
    (config.lib.topology)
    mkInternet
    mkDevice
    mkSwitch
    mkRouter
    mkConnection
    ;
in {
  # TODO: collect networks from globals
  networks.trust.name = "Trust VLAN10";
  networks.guest.name = "Guest VLAN20";
  networks.security.name = "Security VLAN30";
  networks.servers.name = "Servers VLAN40";
  networks.iot.name = "IoT VLAN60";
  networks.dmz.name = "DMZ VLAN70";
  networks.mgmt.name = "MGMT VLAN100";

  networks.internet = {
    name = "Internet VLAN1";
    cidrv4 = "192.168.178.0/24";
  };

  nodes.internet = mkInternet {
    connections = [
      # (mkConnection "sentinel" "wan")
      (mkConnection "vigor" "wan")
    ];
  };

  nodes.vigor = mkRouter "Vigor 166" {
    info = "DrayTek Vigor 166";
    image = ./images/Vigor166.jpg;
    interfaceGroups = [
      [
        "p1"
        # "eth2"
        # "eth3"
        # "eth4"
      ]
      ["wan"]
    ];
    # connections.p1 = mkConnection "internet" "wan";
    interfaces.wan = {
      addresses = ["10.15.100.1"];
      network = "internet";
    };
  };

  # |----------------------------------------------------------------------| #
  nodes.switch-keller = mkSwitch "Switch Keller" {
    info = "TP-Link TL-SG2218 - 16 Port Switch";
    # address: 10.15.100.251/24
    image = ./images/dlink-dgs105.png;
    interfaceGroups = [
      [
        "eth1"
        "eth2"
        "eth3"
        "eth4"
        "eth5"
        "eth6"
        "eth7"
        "eth8"
      ]
      [
        "eth9"
        "eth10"
        "eth11"
        "eth12"
        "eth13"
        "eth14"
        "eth15"
        "eth16"
      ]
      ["sfp1" "sfp2"]
    ];
    # connections.eth1 = mkConnection "ward" "lan-self";
    # connections.eth2 = mkConnection "sire" "lan-self";
    # connections.eth7 = mkConnection "zackbiene" "lan1";
  };

  nodes.switch-office = mkSwitch "Switch Office" {
    info = "NETGEAR GS108Ev3 - 8 Port Switch";
    # address: 10.15.100.252/24
    image = ./images/dlink-dgs1016d.png;
    interfaceGroups = [
      [
        "eth1"
        "eth2"
        "eth3"
        "eth4"
        "eth5"
        "eth6"
        "eth7"
        "eth8"
      ]
    ];
    # connections.eth1 = mkConnection "ward" "lan-self";
    # connections.eth2 = mkConnection "sire" "lan-self";
    # connections.eth7 = mkConnection "zackbiene" "lan1";
  };

  # nodes.switch-office = mkSwitch "Switch Office" {
  #   info = "NETGEAR GS105Ev2 - 5 Port Switch";
  #   image = ./images/dlink-dgs105.png;
  #   interfaceGroups = [
  #     [
  #       "eth1"
  #       "eth2"
  #       "eth3"
  #       "eth4"
  #       "eth5"
  #     ]
  #   ];
  #   # connections.eth1 = mkConnection "ward" "lan-self";
  #   # connections.eth2 = mkConnection "sire" "lan-self";
  #   # connections.eth7 = mkConnection "zackbiene" "lan1";
  # };
  # |----------------------------------------------------------------------| #

  nodes.tv-livingroom = mkDevice "TV Wohnzimmer" {
    info = "LG OLED65B6D";
    # image = ./images/lg-oled65b6d.png;
    interfaces.eth1 = {};
  };

  nodes.tv-hobby = mkDevice "TV Hobbyraum" {
    info = "LG OLED65B6D";
    # image = ./images/lg-oled65b6d.png;
    interfaces.eth1 = {};
  };

  nodes.uap-lr-ap = mkSwitch "Wi-Fi AP" {
    info = "Unifi UAP-AC-LR";
    # image = "./images/Unifi UAP-AC-LR.webp";
    interfaceGroups = [
      [
        "eth1"
        "wifi"
      ]
    ];
    connections.eth1 = mkConnection "switch-office" "eth4";
  };

  nodes.printer = mkDevice "Drucker Büro" {
    info = "Brother MFC3750-cdf";
    # image = ./images/brother-mfc-l3750cdw.JPG;
    connections.eth1 = mkConnection "switch-office" "eth5";
  };
}
