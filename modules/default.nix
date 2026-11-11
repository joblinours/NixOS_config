# Socle commun aux deux hosts (VM et tour). nvidia.nix est importé par la tour seule.
{
  imports = [
    ./common.nix
    ./auto-upgrade.nix
    ./disk.nix
    ./network.nix
    ./desktop.nix
    ./plasma.nix
    ./virtualisation.nix
    ./security.nix
    ./apps.nix
    ./network-tools.nix
    ./gaming.nix
    ./vm.nix
    ./dev.nix
    ./pentest.nix
    ./dfir.nix
    ./flatpak.nix
    ./secrets.nix
    ./home.nix
  ];
}
