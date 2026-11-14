# Laptop. Même socle que la tour, sans NVIDIA ni périphériques de bureau
# (OpenRGB, OpenDeck). Réseau en DHCP partout, sauf 192.168.1.202 sur le wifi maison.
# Avant l'installation : renseigner le disque (lsblk, ls -l /dev/disk/by-id/) ;
# install.sh régénère hardware-configuration.nix sur la machine.
{ hostname, ... }:
{
  imports = [
    ../../modules
    ./hardware-configuration.nix
    # GPU NVIDIA dédié ? Pour un laptop hybride (Optimus), nvidia.nix ne suffit pas :
    # il faut en plus hardware.nvidia.prime (bus ID iGPU/dGPU, voir `lspci`).
  ];

  networking.hostName = hostname;

  # ── Réseau ────────────────────────────────────────────────────────
  # Ethernet et autres wifis : DHCP (lucas.network.address laissé à null)
  lucas.network.wifi = {
    ssid = "Jobl'Internet"; # casse exacte du SSID
    address = "192.168.1.202";
  };

  # ── Disque ────────────────────────────────────────────────────────
  # ⚠ EFFACÉ à l'installation. Remplacer par le chemin stable du SSD interne :
  #   ls -l /dev/disk/by-id/  →  "/dev/disk/by-id/nvme-<modèle>_<n° de série>"
  # Ne JAMAIS y mettre une clé USB ou un disque externe.
  lucas.disk.device = "/dev/nvme0n1";

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
