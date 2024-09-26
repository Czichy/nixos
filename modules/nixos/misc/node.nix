{
  localFlake,
  inputs,
}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; {
  options.node = {
    name = mkOption {
      description = "A unique name for this node (host) in the repository. Defines the default hostname, but this can be overwritten.";
      type = types.str;
    };
  };

  options.node.secretsPath = lib.mkOption {
    type = path;
    default = "${inputs.private}";
    description = "Path to the actual secrets directory";
  };
}
