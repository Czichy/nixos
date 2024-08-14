# --- parts/secrets/pubkeys.nix
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
let
  # spinorbundle = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH1693g0EVyChehwAjJqkKLWD8ZysLbo9TbRZ2B9BcKe root@spinorbundle";
  # jetbundle = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAQpLfZTRGfeVkh0tTCZ7Ads5fwYnl3cIj34Fukkymhp root@jetbundle";
  czichy = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKKAL9mtLn2ASGNkOsS38GXrLDNmLLedb0XNJzhOxtAB christian@czichy.com";
  vm_test = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHDjI1ua3F0+HmVmctChbmMt1LBFbrrf8lP0H5NDy5gP czichy@vmtest";
  czichy-vm_test = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGPMF0Sz9e6JoHudF11U2F9U/S5KFINlU9556C2zA82X czichy@vmtest";
in {
  common = {};
  hosts = {
    desktop = {
      users = {
        root = {
          sshKey = null;
          authorizedKeys = [];
        };
        czichy = {
          sshKey = null;
          authorizedKeys = [czichy];
        };
      };
    };

    HL-1-OZ-PC-01 = {
      users = {
        root = {
          sshKey = null;
          authorizedKeys = [];
        };
        czichy = {
          sshKey = null;
          authorizedKeys = [czichy];
        };
      };
    };
    home_server_test = {
      users = {
        root = {
          sshKey = null;
          authorizedKeys = [];
        };
        czichy = {
          sshKey = czichy-vm_test;
          authorizedKeys = [czichy vm_test czichy-vm_test];
        };
      };
    };

    HL-1-MRZ-SBC-01 = {
      users = {
        root = {
          sshKey = null;
          authorizedKeys = [];
        };
        czichy = {
          sshKey = null;
          authorizedKeys = [czichy];
        };
      };
    };

    HL-4-PAZ-PROXY-01 = {
      users = {
        root = {
          sshKey = null;
          authorizedKeys = [];
        };
        czichy = {
          sshKey = null;
          authorizedKeys = [czichy];
        };
      };
    };
  };
}
