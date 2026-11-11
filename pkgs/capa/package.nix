# capa (Mandiant) : identifie les capacités d'un exécutable (PE/ELF/.NET).
# Absent de nixpkgs 26.05 → binaire officiel autonome (PyInstaller).
# Mise à jour : changer `version`, mettre hash = lib.fakeHash, rebuild, recopier le hash affiché.
{
  lib,
  stdenv,
  fetchzip,
  autoPatchelfHook,
  zlib,
}:

stdenv.mkDerivation rec {
  pname = "capa";
  version = "10.0.0";

  src = fetchzip {
    url = "https://github.com/mandiant/capa/releases/download/v${version}/capa-v${version}-linux.zip";
    hash = "sha256-pJudA9ZJb7m6Fk5FSAUxmtGv11cDYzyl1SQoJhZlTMA=";
    stripRoot = false;
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ zlib ];

  # Binaire PyInstaller : l'archive Python est collée à la fin du fichier,
  # strip la détruirait
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 capa $out/bin/capa
    runHook postInstall
  '';

  meta = {
    description = "Identifie les capacités d'un exécutable";
    homepage = "https://github.com/mandiant/capa";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "capa";
  };
}
