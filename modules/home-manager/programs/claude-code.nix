{
  localFlake,
}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit
    (localFlake.lib)
    isModuleLoadedAndEnabled
    mkImpermanenceEnableOption
    mkAgenixEnableOption
    ;

  cfg = config.tensorfiles.hm.programs.claude-code;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.hm.system.impermanence
    else {};

  # Build the MCP servers attrset, filtering out disabled ones
  enabledMcpServers = filterAttrs (_: srv: srv.enable) cfg.mcpServers;

  # Build a single MCP server's JSON representation
  mkMcpServerJson = _name: srv: let
    base =
      {inherit (srv) type url;}
      // optionalAttrs (srv.headers != {}) {
        headers = mapAttrs (_: v: v) srv.headers;
      };
  in
    base;

  # The full settings.json structure
  settingsJson =
    {
      mcpServers = mapAttrs mkMcpServerJson enabledMcpServers;
    }
    // cfg.extraSettings;

  # Serialize to pretty JSON
  settingsJsonStr = builtins.toJSON settingsJson;

  # Secrets that need placeholder replacement at runtime
  # Map of placeholder string -> agenix secret path
  secretPlaceholders = filterAttrs (_: v: v != null) (
    concatMapAttrs (
      _name: srv:
        concatMapAttrs (
          _hName: hVal: let
            match = builtins.match ".*@SECRET[{]([^}]+)[}].*" hVal;
          in
            if match != null
            then {"@SECRET{${head match}}" = config.age.secrets.${head match}.path;}
            else {}
        )
        srv.headers
    )
    enabledMcpServers
  );

  # Script to generate settings.json with secrets injected
  generateSettingsScript = pkgs.writeShellScript "generate-claude-settings" ''
    CLAUDE_DIR="$HOME/.claude"
    SETTINGS_FILE="$CLAUDE_DIR/settings.json"

    mkdir -p "$CLAUDE_DIR"

    # Start with the Nix-generated template
    CONTENT=${escapeShellArg settingsJsonStr}

    ${concatStringsSep "\n" (mapAttrsToList (pholder: secretPath: ''
        if [ -f "${secretPath}" ]; then
          SECRET_VAL="$(cat "${secretPath}" | tr -d '\n')" || true
          if [ -n "$SECRET_VAL" ]; then
            CONTENT="$(echo "$CONTENT" | ${pkgs.gnused}/bin/sed "s|${escapeShellArg pholder}|$SECRET_VAL|g")"
          else
            echo "WARNING: Secret file ${secretPath} is empty, keeping placeholder" >&2
          fi
        else
          echo "WARNING: Secret file ${secretPath} not found, keeping placeholder" >&2
        fi
      '')
      secretPlaceholders)}

    # Write atomically
    TMPFILE="$(mktemp "$CLAUDE_DIR/.settings.json.XXXXXX")"
    echo "$CONTENT" | ${pkgs.jq}/bin/jq '.' > "$TMPFILE"
    chmod 600 "$TMPFILE"
    mv "$TMPFILE" "$SETTINGS_FILE"
  '';
in {
  options.tensorfiles.hm.programs.claude-code = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles Claude Code (claude CLI)
      with declarative MCP server configuration and agenix-based secret injection.
    '';

    impermanence = {
      enable = mkImpermanenceEnableOption;
    };

    agenix = {
      enable = mkAgenixEnableOption;
    };

    package = mkOption {
      type = nullOr package;
      default = null;
      description = ''
        The Claude Code package to install. Set to null to not install
        (e.g., if installed globally or via npm).
      '';
    };

    mcpServers = mkOption {
      type = attrsOf (submodule ({...}: {
        options = {
          enable = mkOption {
            type = bool;
            default = true;
            description = "Whether to enable this MCP server.";
          };

          type = mkOption {
            type = str;
            default = "url";
            description = "MCP server type (url, stdio, etc.).";
          };

          url = mkOption {
            type = str;
            description = "URL of the MCP server endpoint.";
          };

          headers = mkOption {
            type = attrsOf str;
            default = {};
            description = ''
              HTTP headers to send with MCP requests.

              Values can use the `@SECRET{secret_name}` syntax to reference
              agenix secrets. At activation time, these placeholders will be
              replaced with the actual secret values.

              Example:
                headers.Authorization = "Bearer @SECRET{n8n_mcp_api_key}";
              This will be replaced at runtime with the content of
              `config.age.secrets.n8n_mcp_api_key.path`.
            '';
          };
        };
      }));
      default = {};
      description = ''
        MCP (Model Context Protocol) server configurations for Claude Code.
        These are written to ~/.claude/settings.json.
      '';
      example = literalExpression ''
        {
          n8n = {
            url = "https://n8n.example.com/mcp";
            headers.Authorization = "Bearer @SECRET{n8n_mcp_api_key}";
          };
        }
      '';
    };

    extraSettings = mkOption {
      type = attrs;
      default = {};
      description = ''
        Additional settings to merge into ~/.claude/settings.json.
        These are merged at the top level alongside mcpServers.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home.packages =
        (optional (cfg.package != null) cfg.package)
        ++ [pkgs.jq];

      # Generate settings.json via activation script to handle secrets
      home.activation.generateClaudeSettings = lib.hm.dag.entryAfter ["writeBoundary" "agenix"] ''
        run ${generateSettingsScript}
      '';
    }
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      home.persistence."${impermanence.persistentRoot}" = {
        directories = [
          ".claude"
        ];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
