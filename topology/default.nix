{config, ...}: let
  inherit
    (config.lib.topology)
    mkInternet
    mkDevice
    mkSwitch
    mkRouter
    mkConnection
    ;
in {
  icons.services.opnsense.file = ./icons/opnsense.svg;
  # TODO: collect networks from globals
  networks = {
    trust = {
      name = "Trust VLAN10";
      cidrv4 = "10.15.10.0/24";
    };
    guest = {
      name = "Guest VLAN20";
      cidrv4 = "10.15.20.0/24";
    };
    security = {
      name = "Security VLAN30";
      cidrv4 = "10.15.30.0/24";
    };
    servers = {
      name = "Servers VLAN40";
      cidrv4 = "10.15.40.0/24";
    };
    iot = {
      name = "IoT VLAN60";
      cidrv4 = "10.15.60.0/24";
    };
    dmz = {
      name = "DMZ VLAN70";
      cidrv4 = "10.15.70.0/24";
    };
    mgmt = {
      name = "MGMT VLAN100";
      cidrv4 = "10.15.100.0/24";
    };

    internet = {
      name = "Internet";
    };

    lan = {
      name = "Home-Lan";
      cidrv4 = "10.15.1.0/24";
    };
    proxy-vps = {
      name = "Wireguard-Tunnel";
      cidrv4 = "10.46.0.0/24";
    };
  };

  nodes.internet = mkInternet {
    connections = [
      (mkConnection "HL-4-PAZ-PROXY-01" "10-wan")
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
      # addresses = ["10.15.100.250"];
      network = "internet";
    };
  };

  # |----------------------------------------------------------------------| #
  nodes.switch-keller = mkSwitch "Switch Keller" {
    info = "TP-Link TL-SG2218 - 16 Port Switch";
    # address: 10.15.100.251/24
    image = ./images/TPLINK_TL-SG2218_02.png;
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

    interfaces = {
      trust = {
        network = "trust";
        # addresse = [];
        virtual = true;
      };

      guest = {
        network = "guest";
        # addresse = [];
        virtual = true;
      };
      # guest.name = "Guest VLAN20";
      # security.name = "Security VLAN30";
      # servers.name = "Servers VLAN40";
      # iot.name = "IoT VLAN60";
      # dmz.name = "DMZ VLAN70";
      # mgmt.name = "MGMT VLAN100";
    };
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

    interfaces = {
      trust = {
        network = "trust";
        virtual = true;
        physicalConnections = [
          (mkConnection "switch-keller" "eth1")
          # (mkConnection "HL-1-OZ-PC-01" "eth2")
        ];
      };

      guest = {
        network = "guest";
        virtual = true;
        physicalConnections = [(mkConnection "switch-keller" "eth1")];
      };
    };
    connections.eth1 = mkConnection "switch-keller" "eth1";
    connections.eth2 = mkConnection "HL-1-OZ-PC-01" "trust";
    # connections.eth7 = mkConnection "zackbiene" "lan1";
  };
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

  nodes.uap-ap-pro = mkSwitch "Wi-Fi AP" {
    info = "Unifi UAP-AP-PRO";
    # image = "./images/UAP-Pro1.png";
    interfaceGroups = [
      [
        "eth1"
        "wifi"
      ]
    ];
    interfaces = {
      mgmt = {
        network = "mgmt";
        addresses = ["10.15.100.1/24"];
        virtual = true;
        physicalConnections = [(mkConnection "switch-keller" "eth2")];
      };
    };
    # connections.eth1 = mkConnection "switch-keller" "eth2";
  };

  nodes.uap-lr-ap = mkSwitch "Wi-Fi AP" {
    info = "Unifi UAP-AC-LR";
    # image = "./images/UAP-LR.png";
    interfaceGroups = [
      [
        "eth1"
        "wifi"
      ]
    ];
    interfaces = {
      mgmt = {
        network = "mgmt";
        addresses = ["10.15.100.2/24"];
        virtual = true;
        physicalConnections = [(mkConnection "switch-keller" "eth4")];
      };
    };
    # connections.eth1 = mkConnection "switch-keller" "eth4";
  };

  nodes.printer = mkDevice "Drucker Büro" {
    info = "Brother MFC3750-CDW";
    image = ./images/MFCL3750CDW.png;
    interfaceGroups = [
      [
        "eth1"
        "wifi"
      ]
    ];
    interfaces = {
      trust = {
        network = "trust";
        addresses = ["10.15.10.253"];
        virtual = true;
        physicalConnections = [(mkConnection "switch-office" "eth4")];
      };
    };
    # connections.eth1 = mkConnection "switch-office" "eth4";
  };

  # nodes.opnsense = {
  #   # guestType = "qemu";
  #   deviceType = "cloud-server";
  #   # deviceIcon = ./icons/server-svgrepo-com.svg;
  #   parent = "HL-1-MRZ-SBC-01";
  #   guestType = "qemu";
  #   interfaces.wan = {
  #     # addresses = ["10.15.1.99"];
  #     network = "internet";
  #     physicalConnections = [(mkConnection "vigor" "p1")];
  #   };
  #   interfaces = {
  #     lan = {
  #       addresses = ["10.15.1.99"];
  #       network = "lan";
  #       physicalConnections = [(mkConnection "switch-keller" "eth16")];
  #     };
  #     trust = {
  #       network = "trust";
  #       addresses = ["10.15.10.99/24"];
  #       virtual = true;
  #       physicalConnections = [(mkConnection "switch-keller" "eth16")];
  #     };
  #     mgmt = {
  #       network = "mgmt";
  #       addresses = ["10.15.100.99/24"];
  #       virtual = true;
  #       physicalConnections = [(mkConnection "switch-keller" "eth16")];
  #     };
  #   };
  # };
}
