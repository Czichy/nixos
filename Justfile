## This is also wrapped up into the command "world" which is available
## anywhere - even outside this repo. See: utils/world.nix

set shell := ["nu", "-c"]

alias help := default

default:
  @just --list -f {{justfile()}} -d {{invocation_directory()}}
  @if (echo {{invocation_directory()}} | str contains "world") { echo "\n    lint\n    check" }

# search for packages
search query:
  @nix search nixpkgs {{query}} --json | from json | transpose | flatten | select column0 version description | rename --column { column0: attribute }

# open a shell with given packages available
shell +args:
  @nix shell (echo '{{args}}' | each { |it| if ($it | str contains '#') { $it } else { $"nixpkgs#($it)" } } )

# open a shell with given packages available allowing unfree packages
shell-unfree +args:
  @with-env [NIXPKGS_ALLOW_UNFREE 1] { nix shell --impure (echo '{{args}}' | each { |it| if ($it | str contains '#') { $it } else { $"nixpkgs#($it)" } } ) }

# garbage collect the system
gc:
  @nix-collect-garbage -d

cachix +args:
  with-env [CACHIX_SIGNING_KEY (rbw get cachix)] { cachix push insane {{args}} }

# upgrade the system using given flake ref
upgrade flake="github:johnae/world":
  @rm -rf ~/.cache/nix/fetcher-cache-v1.sqlite*
  @nixos-rebuild boot --flake '{{flake}}' --use-remote-sudo -L
  @if (echo initrd kernel kernel-modules | all { |it| (readlink $"/run/booted-system/($it)") != (readlink $"/nix/var/nix/profiles/system/($it)") }) { echo "The system must be rebooted for the changes to take effect" } else { nixos-rebuild switch --flake '{{flake}}' --use-remote-sudo -L }

# build the system using given flake ref
build flake="github:johnae/world":
  @nixos-rebuild build --flake '{{flake}}' --use-remote-sudo -L

# =====================================================================
# | REMOTE DEPLOYMENT (build local, deploy remote)                    |
# | All builds happen on HL-1-OZ-PC-01, deployed via SSH              |
# | Strategy: build first, switch only on success                     |
# =====================================================================

# central host -> target IP mapping (single source of truth)
remote_targets := '{"HL-1-MRZ-HOST-01": "10.15.100.10", "HL-1-MRZ-HOST-02": "10.15.100.20", "HL-1-MRZ-HOST-03": "10.15.100.30", "HL-3-MRZ-FW-01": "10.15.100.99", "HL-4-PAZ-PROXY-01": "37.120.178.230"}'

# host -> target IP mapping (used internally)
[private]
target host:
  @let targets = ('{{remote_targets}}' | from json); if ($targets | get -o "{{host}}" | is-empty) { error make {msg: $"Unknown host '{{host}}'. Available: ($targets | columns | str join ', ')"} } else { $targets | get "{{host}}" }

# deploy to a specific host (build locally first, then switch remotely)
deploy host:
  #!/usr/bin/env nu
  let host = "{{host}}"
  let target = (just target $host | str trim)
  print $"(ansi yellow_bold)Host: ($host) -> IP: ($target)(ansi reset)"
  let confirm = (input $"(ansi cyan)Deploy to ($target)? [y/N] (ansi reset)" | str trim | str downcase)
  if $confirm != "y" { print $"(ansi red_bold)Aborted.(ansi reset)"; exit 1 }
  print $"(ansi green_bold)Building ($host)...(ansi reset)"
  nixos-rebuild build --flake $".#($host)" --verbose
  print $"(ansi green_bold)Build successful. Switching ($host) -> ($target)...(ansi reset)"
  nixos-rebuild switch --flake $".#($host)" --target-host $"root@($target)" --verbose
  print $"(ansi green_bold)Deploy ($host) complete.(ansi reset)"

# deploy to a host with boot (for kernel updates, requires reboot)
deploy-boot host:
  #!/usr/bin/env nu
  let host = "{{host}}"
  let target = (just target $host | str trim)
  print $"(ansi yellow_bold)Host: ($host) -> IP: ($target)(ansi reset)"
  let confirm = (input $"(ansi cyan)Deploy boot to ($target)? [y/N] (ansi reset)" | str trim | str downcase)
  if $confirm != "y" { print $"(ansi red_bold)Aborted.(ansi reset)"; exit 1 }
  print $"(ansi green_bold)Building ($host)...(ansi reset)"
  nixos-rebuild build --flake $".#($host)" --verbose
  print $"(ansi green_bold)Build successful. Setting boot on ($host) -> ($target)...(ansi reset)"
  nixos-rebuild boot --flake $".#($host)" --target-host $"root@($target)" --verbose
  print $"(ansi green_bold)Boot set for ($host). Reboot required.(ansi reset)"

# build a host configuration without deploying
build-host host:
  @print $"(ansi green_bold)Building {{host}}...(ansi reset)"
  @nixos-rebuild build --flake $".#{{host}}" --verbose

# deploy to all remote hosts sequentially (build first, then switch each)
deploy-all:
  #!/usr/bin/env nu
  let hosts = ('{{remote_targets}}' | from json | columns)
  for host in $hosts {
    print $"(ansi cyan_bold)--- ($host) ---(ansi reset)"
    just deploy $host
  }

# switch the local machine (build first, then switch)
# use --no-cache to build without any binary cache (when cache.nixos.org is unreachable)
local *flags:
  #!/usr/bin/env nu
  let no_cache = ("{{flags}}" | str contains "--no-cache")
  let trusted_settings = ($env.HOME | path join ".local/share/nix/trusted-settings.json")
  let trusted_settings_bak = ($trusted_settings + ".bak")
  if $no_cache and ($trusted_settings | path exists) {
    print $"(ansi yellow_bold)Cache disabled - hiding trusted-settings.json temporarily(ansi reset)"
    mv $trusted_settings $trusted_settings_bak
  }
  let extra = if $no_cache { ["--option" "substituters" ""] } else { ["--option" "connect-timeout" "5"] }
  print $"(ansi green_bold)Building HL-1-OZ-PC-01...(ansi reset)"
  do --env { nixos-rebuild build --flake ".#HL-1-OZ-PC-01" --verbose ...$extra }
  let build_ok = $env.LAST_EXIT_CODE == 0
  if $no_cache and ($trusted_settings_bak | path exists) { mv $trusted_settings_bak $trusted_settings }
  if not $build_ok { error make {msg: "Build failed"} }
  print $"(ansi green_bold)Build successful. Switching...(ansi reset)"
  sudo nixos-rebuild switch --flake ".#HL-1-OZ-PC-01" --verbose ...$extra

# build and set boot on local machine (for kernel updates)
# use --no-cache to build without any binary cache (when cache.nixos.org is unreachable)
local-boot *flags:
  #!/usr/bin/env nu
  let no_cache = ("{{flags}}" | str contains "--no-cache")
  let trusted_settings = ($env.HOME | path join ".local/share/nix/trusted-settings.json")
  let trusted_settings_bak = ($trusted_settings + ".bak")
  if $no_cache and ($trusted_settings | path exists) {
    print $"(ansi yellow_bold)Cache disabled - hiding trusted-settings.json temporarily(ansi reset)"
    mv $trusted_settings $trusted_settings_bak
  }
  let extra = if $no_cache { ["--option" "substituters" ""] } else { ["--option" "connect-timeout" "5"] }
  print $"(ansi green_bold)Building HL-1-OZ-PC-01...(ansi reset)"
  do --env { nixos-rebuild build --flake ".#HL-1-OZ-PC-01" --verbose ...$extra }
  let build_ok = $env.LAST_EXIT_CODE == 0
  if $no_cache and ($trusted_settings_bak | path exists) { mv $trusted_settings_bak $trusted_settings }
  if not $build_ok { error make {msg: "Build failed"} }
  print $"(ansi green_bold)Build successful. Setting boot...(ansi reset)"
  sudo nixos-rebuild boot --flake ".#HL-1-OZ-PC-01" --verbose ...$extra
  print $"(ansi yellow_bold)Reboot required.(ansi reset)"

# list all available hosts
hosts:
  @let remote = ('{{remote_targets}}' | from json | transpose Host Target); [["Host", "Target"]; ["HL-1-OZ-PC-01", "local"]] | append $remote | table

# =====================================================================

[private]
echo +args:
  @echo '{{args}}'

[private]
gh-release-update:
  ./misc/gh-release-update.nu

[private]
lint:
  @echo '-------- [Linting] ---------'
  @let out = (statix check . | complete); if ($out.exit_code > 0) { let span = (metadata $out).span; error make {msg: "Linting failed", label: {text: $out.stdout, span: $span}} } else { print "Lint ok\n\n"; print $out.stdout }

[private]
dead:
  @echo '-------- [Check for dead code] ---------'
  @let out = (deadnix -f . | complete); if ($out.exit_code > 0) { let span = (metadata $out).span; error make {msg: "Dead code check failed", label: {text: $out.stdout, span: $span}} } else { print "No dead code\n\n"; print $out.stdout }

[private]
dscheck:
  @echo '-------- [Flake checker] ---------'
  @let out = (nix run github:DeterminateSystems/flake-checker | complete); if ($out.exit_code > 0) { let span = (metadata $out).span; error make {msg: "Flake checker failed", label: {text: $out.stdout, span: $span}} } else { print "Flake is good\n\n"; print $out.stdout }

[private]
check:
  @nix flake check --impure # impure because of devenv
