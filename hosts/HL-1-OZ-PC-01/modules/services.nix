{
  config.tensorfiles.services = {
    flatpak.enable = true;
    networking.networkd.enable = true;
    printing.enable = true;
    syncthing = {
      enable = true;
      user = "czichy";
    };
    virtualisation.enable = true;
  };
}
