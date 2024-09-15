{lib, ...}:
with lib; let
  inherit (builtins) filter map toString elem hasAttr head tail length;
  inherit (lib.filesystem) listFilesRecursive;
  inherit (lib.strings) hasSuffix splitString;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.types) str int;

  # <nixpkgs>/lib/modules.nix priorities:
  # mkOptionDefault = 1500: priority of option defaults
  # mkDefault = 1000: used in config sections of non-user modules to set a default
  # mkImageMediaOverride = 60:
  # mkForce = 50:
  # mkVMOverride = 10: used by ‘nixos-rebuild build-vm’

  /*
  mkOverride function with a preset priority set for all of the
  home-manager modules.

  *Type*: `mkOverrideAtModuleLevel :: AttrSet a -> { _type :: String; priority :: Int; content :: AttrSet a; }`
  */
  mkOverrideAtHmModuleLevel = mkOverride 700;

  /*
  mkOverride function with a preset priority set for all of the
  home-manager profile modules.

  *Type*: `mkOverrideAtHmProfileLevel :: AttrSet a -> { _type :: String; priority :: Int; content :: AttrSet a; }`
  */
  mkOverrideAtHmProfileLevel = mkOverride 600;

  /*
  mkOverride function with a preset priority set for all of the nixos
  modules.

  *Type*: `mkOverrideAtModuleLevel :: AttrSet a -> { _type :: String; priority :: Int; content :: AttrSet a; }`
  */
  mkOverrideAtModuleLevel = mkOverride 500;

  /*
  mkOverride function with a preset priority set for all of the nixos
  profiles, that is, modules that preconfigure other modules.

  *Type*: `mkOverrideAtProfileLevel :: AttrSet a -> { _type :: String; priority :: Int; content :: AttrSet a; }`
  */
  mkOverrideAtProfileLevel = mkOverride 400;

  # Recursively checks the presence of a nixos/home-manager module and whether
  # its enabled.

  # One might ask why not `?` or `hasAttr` instead?
  # 1. The `?` operator is indeed able to handle nested attributes, however, I've
  #    had some errors while linting and running the `check` command during
  #    development, which seems to be due to the inline direct syntax with a
  #    potentially nonexisting attributes.
  # 2. The `hasAttr` takes a string identifier instead, which is more safe, however,
  #     it doesn't support nested attributes.

  # The solution is then to construct a recursive traverse over the identifier
  # using the `hasAttr` function.

  # *Type*: `isModuleLoadedAndEnabled :: AttrSet -> String -> Bool`
  isModuleLoadedAndEnabled = cfg: identifier: let
    aux = acc: parts: let
      elem = head parts;
      rest = tail parts;
    in
      if length rest == 0
      then (hasAttr elem acc) && (hasAttr "enable" acc.${elem}) && acc.${elem}.enable
      else (hasAttr elem acc) && (aux acc.${elem} rest);
  in
    aux cfg (splitString "." identifier);

  # `mkModuleTree` is used to recursively import all Nix file in a given directory, assuming the
  # given directory to be the module root, where rest of the modules are to be imported. This
  # retains a sense of explicitness in the module tree, and allows for a more organized module
  # imports, discarding the vague `default.nix` name for directories that are *modules*.
  mkModuleTree = {
    path,
    ignoredPaths ? [./default.nix],
  }:
    filter (hasSuffix ".nix") (
      map toString (
        # List all files in the given path, and filter out paths that are in
        # the ignoredPaths list
        filter (path: !elem path ignoredPaths) (listFilesRecursive path)
      )
    );

  # A variant of mkModuleTree that provides more granular control over the files that are imported.
  # While `mkModuleTree` imports all Nix files in the given directory, `mkModuleTree'` will look
  # for a specific
  mkModuleTree' = {
    path,
    ignoredPaths ? [],
  }: (
    # Two conditions fill satisfy filter here:
    #  - The path should end with a module.nix, indicating
    #   that it is in fact a module file.
    #  - The path is not contained in the ignoredPaths list.
    # If we cannot satisfy both of the conditions, then the path will be ignored
    filter (hasSuffix "module.nix") (
      map toString (
        filter (path: !elem path ignoredPaths) (listFilesRecursive path)
      )
    )
  );

  # The `mkService` function takes a few arguments to generate
  # a module for a service without repeating the same options
  # over and over: every online service needs a host and a port.
  # I can't exactly tell you why, but if I am to be honest
  # this is actually a horrendous abstraction
  mkService = {
    name,
    type ? "", # type being an empty string means it can be skipped, omitted
    host ? "127.0.0.1", # default to listening only on localhost
    port ? 0, # default port should be a stub
    extraOptions ? {}, # used to define additional modules
  }: {
    enable = mkEnableOption "${name} ${type} service";
    settings =
      {
        host = mkOption {
          type = str;
          default = host;
          description = "The host ${name} will listen on";
        };

        port = mkOption {
          type = int;
          default = port;
          description = "The port ${name} will listen on";
        };
      }
      // extraOptions;
  };
in {
  inherit mkService mkModuleTree mkModuleTree' isModuleLoadedAndEnabled mkOverrideAtHmModuleLevel mkOverrideAtHmProfileLevel mkOverrideAtModuleLevel mkOverrideAtProfileLevel;
}
