{
  description = "custom nixos iso";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: {
    nixosConfigurations = {
      sshInstallIso = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ({pkgs, ...}: {
            environment.systemPackages = with pkgs; [
              curl
              diskrsync
              helix
              httpie
              neovim
              ntfs3g
              ntfsprogs
              partclone
              wget
              git
            ];

            nix = {
              settings.experimental-features = ["nix-command" "flakes"];
              extraOptions = "experimental-features = nix-command flakes";
            };

            users.users.nixos = {
              openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKKAL9mtLn2ASGNkOsS38GXrLDNmLLedb0XNJzhOxtAB christian@czichy.com"
              ];
            };
          })
        ];
      };
    };
  };
}
