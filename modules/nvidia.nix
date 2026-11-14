# GPU NVIDIA — importé par la tour (RTX 4060) et le laptop (GTX 1660 Ti).
# Turing et plus récent : modules noyau ouverts recommandés.
# Laptop hybride (lucas.nvidia.hybrid) : l'iGPU gère l'écran, la NVIDIA ne sert
# qu'à la demande (PRIME offload) : `nvidia-offload <appli>`, ou dans Steam :
# `nvidia-offload %command%`. Adresses PCI : hosts/<host>/prime.nix (install.sh).
{ config, lib, ... }:
let
  cfg = config.lucas.nvidia;
  p = cfg.prime;
  primeReady = p.nvidiaBusId != null && (p.intelBusId != null || p.amdgpuBusId != null);
  busId = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "PCI:1:0:0";
  };
in
{
  options.lucas.nvidia = {
    hybrid = lib.mkEnableOption "le mode laptop hybride (iGPU + NVIDIA en PRIME offload)";
    prime = {
      nvidiaBusId = busId;
      intelBusId = busId;
      amdgpuBusId = busId;
    };
  };

  config = lib.mkMerge [
    {
      # requis aussi sous Wayland ; en hybride, le pilote de l'iGPU d'abord
      services.xserver.videoDrivers =
        lib.optional cfg.hybrid (if p.amdgpuBusId != null then "amdgpu" else "modesetting")
        ++ [ "nvidia" ];

      hardware.graphics = {
        enable = true;
        enable32Bit = true; # Steam / Proton
      };

      hardware.nvidia = {
        open = true; # modules noyau ouverts, recommandés pour Turing et plus récent
        modesetting.enable = true; # requis pour Wayland
        powerManagement.enable = true; # sauvegarde de la VRAM en veille
        nvidiaSettings = true;
        package = config.boot.kernelPackages.nvidiaPackages.stable;
      };

      # GPU dans les conteneurs (Exegol, LM Studio en conteneur, hashcat…) :
      #   docker run --rm --device nvidia.com/gpu=all ubuntu nvidia-smi
      hardware.nvidia-container-toolkit.enable = true;
    }

    # Tour : tout passe par la NVIDIA (NVENC/NVDEC pour OBS, mpv, navigateurs)
    (lib.mkIf (!cfg.hybrid) {
      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = "nvidia";
        NVD_BACKEND = "direct";
      };
    })

    # Laptop : PRIME offload, la NVIDIA s'éteint quand elle ne sert pas
    (lib.mkIf (cfg.hybrid && primeReady) {
      hardware.nvidia.powerManagement.finegrained = true;
      hardware.nvidia.prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true; # commande nvidia-offload
        };
      }
      // lib.filterAttrs (_: v: v != null) p;
    })

    (lib.mkIf (cfg.hybrid && !primeReady) {
      warnings = [
        "lucas.nvidia.hybrid sans adresses PCI : PRIME offload désactivé. Lancer `lspci | grep -E 'VGA|3D'` et remplir hosts/<host>/prime.nix (install.sh le fait tout seul)."
      ];
    })
  ];
}
