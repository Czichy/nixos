{
  inputs,
  lib,
  ...
}: {
  imports = [
    inputs.agenix.nixosModules.default
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.default
  ];
}
