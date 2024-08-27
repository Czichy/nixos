{
  media = import ./media.nix;
  network = import ./network.nix;
  ports = import ./ports.nix;
  users = import ./users.nix;
  services = import ./services.nix;
}
