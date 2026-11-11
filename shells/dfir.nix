# Boîte à outils forensique, versions figées par flake.lock.
# Entrer :            nix develop .#dfir
# Lancer une commande : nix develop .#dfir -c vol -h
{ pkgs }:

pkgs.mkShell {
  name = "dfir";

  packages = with pkgs; [
    # Mémoire
    volatility3 # commande : vol

    # Disque / système de fichiers
    sleuthkit
    libewf # ewfacquire, ewfmount, ewfinfo (images E01)
    ddrescue
    testdisk

    # Fichiers / malware
    yara
    binwalk
    exiftool
    radare2
    hexyl
    ssdeep

    # Réseau
    wireshark-cli # tshark
    tcpdump

    # Scripts Python
    (python3.withPackages (
      ps: with ps; [
        pefile
        yara-python
        requests
      ]
    ))
  ];

  shellHook = ''
    echo "🔍 Shell DFIR — nixpkgs ${pkgs.lib.version}"
    echo "   vol, fls, ewfinfo, yara, binwalk, exiftool, r2, tshark, python3 (pefile, yara-python)"
  '';
}
