# GPU-Konfiguration für NVIDIA GeForce GTX 1660 SUPER (TU116) auf HOST-01
# PCI: 2d:00.0, Turing-Architektur, 6GB VRAM
# Bestätigt via: lspci → "TU116 [GeForce GTX 1660 SUPER] (rev a1)"
#
# Dieser Treiber wird benötigt für:
# - Ollama LLM-Inference mit CUDA-Beschleunigung
# - nvidia-smi Monitoring
#
# HINWEIS: Dies ist ein Headless-Server – kein Display-Manager oder X11/Wayland nötig.
# Der Treiber wird nur für CUDA-Compute geladen.
{
  config,
  pkgs,
  ...
}: {
  # ---------------------------------------------------------------------------
  # NVIDIA-Treiber (proprietär, headless)
  # ---------------------------------------------------------------------------
  hardware.nvidia = {
    # Modesetting ist auch auf headless-Servern sinnvoll für stabiles Laden
    modesetting.enable = true;

    # Power-Management nicht nötig auf Server (GPU läuft dauerhaft)
    powerManagement.enable = false;
    powerManagement.finegrained = false;

    # TU116 (Turing) braucht den proprietären Treiber.
    # Das Open-Source-Kernel-Modul unterstützt Turing NICHT vollständig.
    open = false;

    # Kein GUI-Settings-Tool auf headless Server
    nvidiaSettings = false;

    # Stabiler Treiberast für GTX 1660 SUPER (Turing)
    # Alternativen: .production (konservativer), .beta, .vulkan_beta
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # ---------------------------------------------------------------------------
  # Graphics / OpenGL (für CUDA-Compute)
  # ---------------------------------------------------------------------------
  hardware.graphics = {
    enable = true;
    # 32-Bit nicht nötig auf reinem Server
    # enable32Bit = false;
  };

  # ---------------------------------------------------------------------------
  # Kernel-Module
  # ---------------------------------------------------------------------------
  # nvidia Kernel-Modul im initrd laden damit es früh verfügbar ist
  boot.initrd.kernelModules = ["nvidia"];
  boot.extraModulePackages = [config.boot.kernelPackages.nvidiaPackages.stable];

  # ---------------------------------------------------------------------------
  # Video-Treiber registrieren
  # ---------------------------------------------------------------------------
  # Auf headless-Servern: Kein Display-Manager, aber der Treiber wird dadurch
  # korrekt geladen und nvidia-smi + CUDA funktionieren.
  services.xserver.videoDrivers = ["nvidia"];

  # ---------------------------------------------------------------------------
  # Nützliche Pakete für GPU-Monitoring und -Debugging
  # ---------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    # GPU-Monitoring (wie htop, aber für NVIDIA GPUs)
    nvtopPackages.nvidia
    # pciutils für lspci (GPU-Diagnose)
    pciutils
  ];

  # ---------------------------------------------------------------------------
  # Firewall / Netzwerk
  # ---------------------------------------------------------------------------
  # Keine Ports nötig – die GPU wird nur lokal via CUDA angesprochen.
  # Ollama öffnet seinen eigenen Port in ollama.nix.
}
