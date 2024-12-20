{config, ...}: let
  inherit
    (config.lib.topology)
    mkInternet
    mkDevice
    mkSwitch
    mkRouter
    mkConnection
    mkConnectionRev
    ;
in {
  icons.services.opnsense.file = ./icons/opnsense.svg;
  icons.services.uptime-kuma.file = ./icons/uptime-kuma.svg;
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
      ]
      ["wan"]
    ];
    interfaces.wan = {
      # addresses = ["10.15.100.250"];
      network = "internet";
    };

    interfaces.p1 = {
      virtual = false;
      physicalConnections = [(mkConnection "HL-3-MRZ-FW-01" "enp1s0")];
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
      eth9 = {
        virtual = false;
        physicalConnections = [(mkConnection "HL-1-MRZ-HOST-01" "enp4s0")];
      };
      eth11 = {
        virtual = false;
        physicalConnections = [(mkConnection "HL-1-MRZ-HOST-02" "enp4s0")];
      };
      eth12 = {
        virtual = false;
        physicalConnections = [(mkConnection "HL-1-MRZ-HOST-01" "enp1s0")];
        network = "mgmt";
      };
      eth13 = {
        virtual = false;
        physicalConnections = [(mkConnection "HL-1-MRZ-HOST-03" "enp2s0")];
      };
      eth16 = {
        virtual = false;
        physicalConnections = [
          (mkConnectionRev "HL-3-MRZ-FW-01" "enp2s0")
        ];
      };
      servers = {
        virtual = true;
        network = "servers";
        physicalConnections = [
          (mkConnection "HL-1-MRZ-HOST-01" "30-servers")
          # (mkConnection "HL-1-MRZ-HOST-02" "servers")
          (mkConnection "HL-1-MRZ-HOST-02" "enp4s0")
          (mkConnection "HL-1-MRZ-HOST-03" "servers")
          # (mkConnectionRev "HL-3-MRZ-FW-01" "servers")
        ];
      };
      iot = {
        virtual = true;
        network = "iot";
        physicalConnections = [
          (mkConnection "HL-3-MRZ-FW-01" "iot")
        ];
      };
      trust = {
        virtual = true;
        network = "trust";
        # physicalConnections = [
        # (mkConnection "HL-3-MRZ-FW-01" "trust")
        # ];
      };
      guest = {
        virtual = true;
        network = "guest";
        # physicalConnections = [
        # (mkConnection "HL-3-MRZ-FW-01" "guest")
        # ];
      };
      mgmt = {
        virtual = true;
        network = "mgmt";
        physicalConnections = [
          (mkConnection "HL-1-MRZ-HOST-01" "30-mgmt")
          (mkConnection "HL-1-MRZ-HOST-02" "mgmt")
          (mkConnection "HL-1-MRZ-HOST-03" "mgmt")
          # (mkConnection "HL-3-MRZ-FW-01" "mgmt")
        ];
      };
    };
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
      eth1 = {
        virtual = false;
        physicalConnections = [
          (mkConnection "switch-keller" "eth1")
        ];
      };

      eth2 = {
        virtual = false;
        physicalConnections = [
          (mkConnection "HL-1-OZ-PC-01" "enp39s0")
        ];
      };
      trust = {
        virtual = true;
        physicalConnections = [
          (mkConnection "switch-keller" "trust")
        ];
      };
    };
    # connections.trust = mkConnection "switch-keller" "trust";
    # connections.mgmt = mkConnection "switch-keller" "mgmt";
    # connections.guest = mkConnection "switch-keller" "guest";
    # connections.trust = mkConnection "switch-keller" "eth1";
    # connections.mgmt = mkConnection "switch-keller" "eth1";
    # connections.guest = mkConnection "switch-keller" "eth1";
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
      eth1 = {
        # network = "mgmt";
        addresses = ["10.15.100.1/24"];
        virtual = true;
        physicalConnections = [(mkConnection "switch-office" "eth2")];
      };
    };
    # connections.mgmt = mkConnection "switch-office" "eth2";
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
      eth1 = {
        # network = "mgmt";
        addresses = ["10.15.100.2/24"];
        virtual = false;
        physicalConnections = [(mkConnection "switch-keller" "eth4")];
      };
    };
    # connections.mgmt = mkConnection "switch-keller" "eth4";
    # connections.trust = mkConnection "switch-keller" "eth4";
    # connections.guest = mkConnection "switch-keller" "eth4";
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
      eth1 = {
        network = "trust";
        # addresses = ["10.15.10.253"];
        virtual = true;
        physicalConnections = [(mkConnection "switch-office" "eth4")];
      };
    };
    # connections.trust = mkConnection "switch-office" "eth4";
  };
}
