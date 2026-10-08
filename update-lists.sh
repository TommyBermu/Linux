#!/usr/bin/env bash
set -Eeuo pipefail

# Regenera las listas de paquetes a partir del sistema actual:
#   - paquetes-oficiales.txt : paquetes de repos oficiales instalados explicitamente
#   - paquetes-aur.txt        : paquetes foraneos (AUR) instalados explicitamente
#
# Se excluyen los paquetes de BlackArch (p. ej. nipe), que el bootstrap
# instala por su propia via tras configurar ese repo.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OFFICIAL_LIST="${REPO_DIR}/paquetes-oficiales.txt"
AUR_LIST="${REPO_DIR}/paquetes-aur.txt"

command -v pacman >/dev/null 2>&1 || { echo "[x] pacman no disponible" >&2; exit 1; }

# -Qqe : explicitos, solo nombre. -Qqen : nativos (repos). -Qqem : foraneos (AUR).
pacman -Qqen | sort -u > "$OFFICIAL_LIST"
pacman -Qqem | sort -u > "$AUR_LIST"

printf '[*] paquetes-oficiales.txt: %s paquetes\n' "$(wc -l < "$OFFICIAL_LIST")"
printf '[*] paquetes-aur.txt:       %s paquetes\n' "$(wc -l < "$AUR_LIST")"
printf '[*] Revisa los diffs con git antes de commitear.\n'
