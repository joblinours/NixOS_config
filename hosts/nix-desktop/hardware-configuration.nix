# ⚠ Valeurs génériques pour une tour Intel. À régénérer sur la machine :
#   nixos-generate-config --no-filesystems --show-hardware-config > hardware-configuration.nix
# (--no-filesystems : les montages sont gérés par disko)
{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
}
