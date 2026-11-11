# Claude Desktop — paquet .deb OFFICIEL d'Anthropic (beta Linux, Debian/Ubuntu),
# exécuté dans un environnement FHS (arborescence /usr comme sur Debian).
# Doc : https://code.claude.com/docs/en/desktop-linux
#
# Cowork (tâches dans une VM QEMU/KVM) attend, en chemins écrits en dur :
#   /usr/bin/qemu-system-x86_64, /usr/share/OVMF/OVMF_CODE{_4M,}.fd, /usr/bin/virtiofsd
# → fournis ci-dessous. Côté système : groupe kvm + module vhost_vsock (modules/apps.nix).
#
# Mise à jour : l'app ne se met pas à jour seule. Version et sha256 dans l'index :
#   curl -s https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages \
#     | grep -E '^(Version|SHA256):' | tail -2
{
  lib,
  stdenvNoCC,
  fetchurl,
  dpkg,
  buildFHSEnv,
  runCommand,
  OVMF,
  # Options Chromium ajoutées au lancement (ex. "--disable-gpu" dans la VM)
  extraArgs ? "",
}:

let
  version = "5.1231.2";

  unwrapped = stdenvNoCC.mkDerivation {
    pname = "claude-desktop-unwrapped";
    inherit version;

    src = fetchurl {
      url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_${version}_amd64.deb";
      sha256 = "eb4d16c9aff0a696366d88728f74fa55136be7cfde3c1fe35af4062b45955b6f";
    };

    nativeBuildInputs = [ dpkg ];
    # chrome-sandbox est setuid dans le .deb : interdit dans le store Nix.
    # Chromium utilise alors son sandbox par namespaces (disponible sur NixOS).
    unpackPhase = ''
      dpkg-deb --fsys-tarfile $src | tar -x --no-same-owner --no-same-permissions
      chmod u-s,g-s usr/lib/claude-desktop/chrome-sandbox
    '';
    dontBuild = true;
    dontStrip = true;
    dontPatchELF = true; # binaires Electron prévus pour l'environnement FHS

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r usr/lib usr/share $out/
      rm -rf $out/share/doc
      runHook postInstall
    '';
  };

  # Arborescence OVMF « à la Debian » attendue par Cowork
  ovmfDebian = runCommand "ovmf-debian-layout" { } ''
    mkdir -p $out/share/OVMF
    for f in OVMF_CODE OVMF_VARS; do
      ln -s ${OVMF.fd}/FV/$f.fd $out/share/OVMF/$f.fd
      ln -s ${OVMF.fd}/FV/$f.fd $out/share/OVMF/''${f}_4M.fd
    done
  '';
in
buildFHSEnv {
  pname = "claude-desktop";
  inherit version;

  targetPkgs =
    pkgs: with pkgs; [
      unwrapped

      # Dépendances du .deb (Depends)
      gtk3
      libnotify
      nss
      nspr
      xdg-utils
      at-spi2-atk
      at-spi2-core
      libdrm
      libgbm
      mesa
      libGL
      vulkan-loader
      libxcb
      libsecret
      glib
      libx11
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxtst
      libxkbcommon
      libxshmfence
      util-linux # libuuid
      pipewire
      xdg-desktop-portal
      cups
      dbus
      expat
      pango
      cairo
      systemd # libudev
      alsa-lib
      libayatana-appindicator
      gvfs

      # Recommends : outils et Cowork
      bubblewrap
      socat
      openssh
      cacert
      qemu_kvm # /usr/bin/qemu-system-x86_64
      ovmfDebian # /usr/share/OVMF/*.fd
      virtiofsd # /usr/bin/virtiofsd
    ];

  runScript = "${unwrapped}/lib/claude-desktop/claude-desktop${
    lib.optionalString (extraArgs != "") " ${extraArgs}"
  }";

  extraInstallCommands = ''
    mkdir -p $out/share
    cp -r ${unwrapped}/share/applications ${unwrapped}/share/icons $out/share/
    [ -d ${unwrapped}/share/mime ] && cp -r ${unwrapped}/share/mime $out/share/ || true
  '';

  meta = {
    description = "Claude Desktop (beta Linux officielle d'Anthropic)";
    homepage = "https://code.claude.com/docs/en/desktop-linux";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "claude-desktop";
  };
}
