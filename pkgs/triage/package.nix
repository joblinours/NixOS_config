# Exemple de paquet maison : un script de triage rapide d'un dossier.
# Construit avec : nix build .#triage   → ./result/bin/triage
{
  writeShellApplication,
  coreutils,
  findutils,
  file,
  gnugrep,
  yara,
}:

writeShellApplication {
  name = "triage";

  # Ajoutés au PATH du script, quelle que soit la machine
  runtimeInputs = [
    coreutils
    findutils
    file
    gnugrep
    yara
  ];

  text = ''
    usage() {
      echo "usage: triage <dossier> [-d jours] [-r regles.yar]"
      echo "  Liste les fichiers modifiés récemment, repère les exécutables,"
      echo "  calcule leurs SHA-256 et lance YARA si des règles sont fournies."
      exit 1
    }

    [ $# -ge 1 ] || usage
    target="$1"; shift
    days=1
    rules=""
    while getopts "d:r:" opt; do
      case "$opt" in
        d) days="$OPTARG" ;;
        r) rules="$OPTARG" ;;
        *) usage ;;
      esac
    done

    [ -d "$target" ] || { echo "Dossier introuvable : $target" >&2; exit 2; }

    echo "== Fichiers modifiés depuis $days jour(s) dans $target"
    find "$target" -type f -mtime "-$days" -printf '%TY-%Tm-%Td %TH:%TM  %10s  %p\n' 2>/dev/null | sort -r | head -n 50

    echo
    echo "== Exécutables (ELF / PE / scripts) + SHA-256"
    find "$target" -type f -mtime "-$days" -print0 2>/dev/null \
      | while IFS= read -r -d "" f; do
          kind="$(file -b "$f")"
          if echo "$kind" | grep -Eqi 'ELF|PE32|executable|script'; then
            printf '%s  %s\n    -> %s\n' "$(sha256sum "$f" | cut -d' ' -f1)" "$f" "$kind"
          fi
        done

    if [ -n "$rules" ]; then
      echo
      echo "== YARA ($rules)"
      yara -r "$rules" "$target" 2>/dev/null || true
    fi
  '';
}
