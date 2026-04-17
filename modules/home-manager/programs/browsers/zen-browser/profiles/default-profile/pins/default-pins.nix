# Pinned tabs for the Default space.
# workspace UUID must match the space id defined in spaces/default-space.nix.
_inputs: let
  # UUID of the "Default" space (must match spaces/default-space.nix)
  defaultWorkspace = "a1b2c3d4-0001-4000-8000-000000000001";
  # Container id for Default (must match containers.nix)
  defaultContainer = 1;
in {
  "keybr" = {
    id = "c0000001-0000-4000-8000-000000000001";
    url = "https://www.keybr.com/";
    workspace = defaultWorkspace;
    container = defaultContainer;
    position = 1000;
    isEssential = true;
  };
}
