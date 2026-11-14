# Démon « helper » de Sho Metrics Linux (plugin OpenDeck de capteurs matériels) :
# lit hwmon, drm, powercap (RAPL), LACT (NVIDIA) et MangoHud, et les sert au
# plugin en gRPC sur un socket unix. https://github.com/emaspa/sho-metrics-linux
#
# Mise à jour : changer `version`, remettre les deux hash à lib.fakeHash,
# lancer le build et recopier à chaque fois le hash « got: » affiché.
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
  makeWrapper,
}:

buildNpmPackage (finalAttrs: {
  pname = "sho-metrics-helper";
  version = "0.3.0-linux.8";

  src = fetchFromGitHub {
    owner = "emaspa";
    repo = "sho-metrics-linux";
    tag = "v${finalAttrs.version}";
    hash = "sha256-F0Xq/pHdrSGwXsoTgjsqCXonlxGhXgTr7TxD27pbROs=";
  };

  # Le démon est dans packages/source-linux ; il a aussi besoin de contracts/proto
  sourceRoot = "${finalAttrs.src.name}/packages/source-linux";

  npmDepsHash = "sha256-s3Sm+xomTRiApL2VIaT5dI0xP76XMSja/0Q4xzDXmsI=";
  dontNpmBuild = true; # pur JavaScript, rien à compiler

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/sho-metrics-helper $out/share/sho-metrics
    cp -r server.mjs package.json node_modules $out/lib/sho-metrics-helper/
    cp -r ../../contracts/proto $out/share/sho-metrics/proto
    makeWrapper ${lib.getExe nodejs} $out/bin/shometrics-linux-helper \
      --add-flags $out/lib/sho-metrics-helper/server.mjs \
      --set-default SHOMETRICS_PROTO_DIR $out/share/sho-metrics/proto
    runHook postInstall
  '';

  meta = {
    description = "Démon de capteurs Linux pour le plugin OpenDeck Sho Metrics";
    homepage = "https://github.com/emaspa/sho-metrics-linux";
    license = lib.licenses.gpl3Only;
    mainProgram = "shometrics-linux-helper";
    platforms = lib.platforms.linux;
  };
})
