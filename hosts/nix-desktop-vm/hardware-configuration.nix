# Matériel virtuel VirtualBox. Les systèmes de fichiers viennent de disko
# (modules/disk.nix) : pas de fileSystems ici.
{ ... }:
{
  boot.initrd.availableKernelModules = [
    "ata_piix"
    "ohci_pci"
    "ehci_pci"
    "ahci"
    "sd_mod"
    "sr_mod"
  ];
}
