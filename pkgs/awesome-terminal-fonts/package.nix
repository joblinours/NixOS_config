# Awesome Terminal Fonts : icônes FontAwesome, Octicons, Devicons, Pomicons…
# requises par powerlevel10k en mode « awesome-fontconfig » (home/p10k.zsh).
# Absent de nixpkgs 26.05.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation {
  pname = "awesome-terminal-fonts";
  version = "1.1.0-unstable-2024-01-16";

  src = fetchFromGitHub {
    owner = "gabrielelana";
    repo = "awesome-terminal-fonts";
    rev = "8d8cf0159fbb60e838df4e4a15a540f12866b65d";
    hash = "sha256-K+d8L6o87PMgknyBEMqrdEt9m6U+J6dpBTpsaKClHI8=";
  };

  installPhase = ''
    runHook preInstall
    install -Dm644 build/*.ttf -t $out/share/fonts/truetype/awesome-terminal-fonts
    # Associe les icônes aux polices de repli (fontconfig)
    install -Dm644 config/10-symbols.conf $out/etc/fonts/conf.d/10-symbols.conf
    runHook postInstall
  '';

  meta = {
    description = "Polices d'icônes pour le terminal (mode awesome-fontconfig de powerlevel10k)";
    homepage = "https://github.com/gabrielelana/awesome-terminal-fonts";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
