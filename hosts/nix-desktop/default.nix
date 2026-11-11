# Tour : Intel + RTX 4060. OS quotidien après validation dans la VM.
# Avant l'installation : vérifier le disque (lsblk) et régénérer
# hardware-configuration.nix (voir README, « Passage à la tour »).
{ hostname, ... }:
{
  imports = [
    ../../modules
    ../../modules/nvidia.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = hostname;
  lucas.network.address = "192.168.1.200";
  # ⚠ TOUS les disques listés ici sont EFFACÉS à l'installation.
  # Utiliser les chemins stables /dev/disk/by-id/… (ls -l /dev/disk/by-id/), jamais
  # /dev/sdX ou /dev/nvmeXn1 : leur numérotation peut changer d'un démarrage à l'autre.
  # Ne JAMAIS y mettre les disques USB externes (T7 Shield, Toshiba).
  # Disque système : Lexar 1 To (où était Kali)
  lucas.disk.device = "/dev/disk/by-id/nvme-Lexar_SSD_NM710_1TB_NLE2352000512P2209";
  # /data (1,5 To) : Lexar 1 To (où était Windows) + Kingston 512 Go (modèles Ollama)
  # Le Samsung 256 Go (nvme-SAMSUNG_MZVLB256HBHQ-000H1_S4GNNF1N208969) reste libre.
  lucas.disk.dataDevices = [
    "/dev/disk/by-id/nvme-Lexar_SSD_NM710_1TB_NLE2352008726P2209"
    "/dev/disk/by-id/nvme-KINGSTON_OM8PCP3512F-AI1_50026B76842BBC7D"
  ];

  # VirtualBox hôte (VMs de test, labs)
  lucas.vbox.enable = true;

  # Version de NixOS à l'INSTALLATION. Ne jamais la changer ensuite.
  system.stateVersion = "26.05";
}
