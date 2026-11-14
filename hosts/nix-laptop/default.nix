# Laptop (GTX 1660 Ti, hybride). Même socle que la tour, sans périphériques de
# bureau (OpenRGB, OpenDeck). Réseau en DHCP partout, sauf 192.168.1.202 sur le wifi maison.
# Avant l'installation : renseigner le disque (lsblk, ls -l /dev/disk/by-id/) ;
# install.sh régénère hardware-configuration.nix sur la machine.
{ hostname, ... }:
{
  imports = [
    ../../modules
    ./hardware-configuration.nix
    ../../modules/nvidia.nix
    ./prime.nix # adresses PCI des GPU (remplies par install.sh)
  ];

  # GTX 1660 Ti + iGPU : PRIME offload (`nvidia-offload <appli>`)
  lucas.nvidia.hybrid = true;

  networking.hostName = hostname;

  # ── Réseau ────────────────────────────────────────────────────────
  # Ethernet et autres wifis : DHCP (lucas.network.address laissé à null)
  lucas.network.wifi = {
    ssid = "Jobl'Internet"; # casse exacte du SSID
    address = "192.168.1.202";
  };

  # ── Disques ───────────────────────────────────────────────────────
  # ⚠ Les DEUX SSD internes (ex-Windows et ex-Kali) sont EFFACÉS à l'installation :
  # le 1er porte le système, le 2e devient /data (comme sur la tour).
  # Avec 2 NVMe, nvme0/nvme1 peuvent s'inverser d'un démarrage à l'autre : sans
  # importance ici (les deux sont effacés, install.sh affiche les modèles avant
  # confirmation ; ensuite tout est monté par étiquette). Chemins stables :
  #   ls -l /dev/disk/by-id/ | grep nvme | grep -v part
  # Ne JAMAIS y mettre une clé USB ou un disque externe (T7 Shield…).
  lucas.disk.device = "/dev/nvme0n1";
  lucas.disk.dataDevices = [ "/dev/nvme1n1" ];

  # ── Spécificités portable ─────────────────────────────────────────
  # Profils d'énergie (Économie / Équilibré / Performance) dans la barre de KDE
  services.power-profiles-daemon.enable = true;
  # Modules capteurs proposés par `sudo sensors-detect`, s'il y en a :
  boot.kernelModules = [ ];

  # VirtualBox hôte (VMs de test, labs), comme sur la tour
  lucas.vbox.enable = true;

  # Version de NixOS à l'INSTALLATION. Ne jamais la changer ensuite.
  system.stateVersion = "26.05";
}
