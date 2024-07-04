# --- parts/modules/nixos/services/networking/networkmanager.nix
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
{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit (inputs.flake-parts.lib) importApply;
  inherit (localFlake.lib) isModuleLoadedAndEnabled mkImpermanenceEnableOption;

  cfg = config.tensorfiles.services.virtualisation.microvm;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.system.impermanence
    else {};
in {
  options.tensorfiles.services.virtualisation.microvm = with types; {
    enable = mkEnableOption ''
      Enables Micro-VM host.
    '';

    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      imports = [
        # Include the microvm host module
        microvm.nixosModules.host
      ];

      # guests = let
      #   mkGuest = guestName: {
      #     autostart = true;
      #     restartIfChanged = true;
      #     # zfs."/state" = {
      #     #   pool = "rpool";
      #     #   dataset = "local/guests/${guestName}";
      #     # };
      #     # zfs."/persist" = {
      #     #   pool = "rpool";
      #     #   dataset = "safe/guests/${guestName}";
      #     # };
      #     modules = [
      #       ../../config
      #       # ./common.nix
      #       ./${guestName}.nix
      #       {
      #         node.secretsDir = ./secrets/${guestName};
      #         networking.nftables.firewall = {
      #           zones.untrusted.interfaces = [config.guests.${guestName}.networking.mainLinkName];
      #         };
      #       }
      #     ];
      #   };

      #   mkMicrovm = guestName: {
      #     ${guestName} =
      #       mkGuest guestName
      #       // {
      #         backend = "microvm";
      #         microvm = {
      #           system = "x86_64-linux";
      #           macvtap = "lan";
      #           baseMac = config.repo.secrets.local.networking.interfaces.lan.mac;
      #         };
      #         extraSpecialArgs = {
      #           inherit (inputs.self) nodes globals;
      #           inherit (inputs.self.pkgs.x86_64-linux) lib;
      #           inherit inputs minimal;
      #         };
      #       };
      #   };
      # deadnix: skip
      # mkContainer = guestName: {
      #   ${guestName} =
      #     mkGuest guestName
      #     // {
      #       backend = "container";
      #       container.macvlan = "lan";
      #       extraSpecialArgs = {
      #         inherit (inputs.self) nodes globals;
      #         inherit (inputs.self.pkgs.x86_64-linux) lib;
      #         inherit inputs minimal;
      #       };
      #     };
      # };
      # in
      #   # lib.mkIf (!minimal)
      #   (
      #     {}
      #     // mkMicrovm "adguardhome"
      #     // mkMicrovm "forgejo"
      #     // mkMicrovm "home-gateway"
      #     // mkMicrovm "kanidm"
      #     // mkMicrovm "netbird"
      #     // mkMicrovm "radicale"
      #     // mkMicrovm "vaultwarden"
      #     // mkMicrovm "web-proxy"
      #   );
      services_microvm_test = importApply ./test.nix {inherit localFlake microvm;};
    }
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      environment.persistence."${impermanence.persistentRoot}" = {
        directories = ["/var/lib/microvms"];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
