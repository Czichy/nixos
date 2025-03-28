{
  config.tensorfiles.services = {
    flatpak.enable = true;
    networking.networkd.enable = true;
    printing.enable = true;
    virtualisation.enable = true;
    syncthing = {
      enable = true;
      user = "czichy";
    };
  };
}
