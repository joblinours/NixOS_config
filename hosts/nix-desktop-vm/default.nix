# VM VirtualBox de test. Réglages VirtualBox requis :
#   EFI activé, réseau en « Accès par pont », contrôleur graphique VMSVGA + 3D,
#   ≥ 60 Gio de disque, ≥ 8 Gio de RAM, ≥ 4 vCPU.
{ hostname, ... }:
{
  imports = [
    ../../modules
    ./hardware-configuration.nix
  ];

  networking.hostName = hostname;
  lucas.network.address = "192.168.1.201";
  lucas.disk.device = "/dev/sda";

  # Additions invité : presse-papiers partagé, redimensionnement de l'écran
  virtualisation.virtualbox.guest = {
    enable = true;
    clipboard = true;
  };

  # VirtualBox hôte dans la VM = virtualisation imbriquée (VT-x imbriqué à
  # activer dans VirtualBox). Désactivé par défaut pour garder la VM légère.
  lucas.vbox.enable = false;

  # Contournements GPU (Electron sans GPU, Ghostty en rendu logiciel) : modules/vm.nix
  lucas.vm.enable = true;

  # Version de NixOS à l'INSTALLATION. Ne jamais la changer ensuite.
  system.stateVersion = "26.05";
}
