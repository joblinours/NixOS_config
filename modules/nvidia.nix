# RTX 4060 (Ada Lovelace) — importé uniquement par hosts/nix-desktop.
{ config, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ]; # requis aussi sous Wayland

  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Steam / Proton
  };

  hardware.nvidia = {
    open = true; # modules noyau ouverts, recommandés pour Turing et plus récent
    modesetting.enable = true; # requis pour Wayland / COSMIC
    powerManagement.enable = true; # sauvegarde de la VRAM en veille
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # GPU dans les conteneurs (Exegol, LM Studio en conteneur, hashcat…) :
  #   docker run --rm --device nvidia.com/gpu=all ubuntu nvidia-smi
  hardware.nvidia-container-toolkit.enable = true;

  # NVENC/NVDEC pour OBS, mpv, navigateurs
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
  };
}
