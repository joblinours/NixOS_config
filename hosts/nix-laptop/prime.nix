# Adresses PCI des GPU pour PRIME offload (modules/nvidia.nix).
# Remplies automatiquement par scripts/install.sh (lspci), à committer ensuite.
# À la main : `lspci | grep -E 'VGA|3D'` → « 01:00.0 » devient "PCI:1:0:0"
# (bus et device en DÉCIMAL : 0a:00.0 → "PCI:10:0:0").
{
  lucas.nvidia.prime = {
    nvidiaBusId = null; # ex. "PCI:1:0:0"
    intelBusId = null; # ex. "PCI:0:2:0"  (iGPU Intel)
    amdgpuBusId = null; # ex. "PCI:5:0:0" (iGPU AMD)
  };
}
