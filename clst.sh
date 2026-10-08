#!/usr/bin/env bash
set -Eeuo pipefail

# Reaplica la config propia de quickshell (Caelestia) tras actualizarlo,
# ya que la actualizacion sobrescribe estos archivos.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QS_DIR="${REPO_DIR}/overlays/etc/quickshell"

if [[ $EUID -ne 0 ]]; then
	printf '[x] Ejecuta con sudo: sudo %s/clst.sh\n' "$REPO_DIR" >&2
	exit 1
fi

cp -f "${QS_DIR}/bongocat.gif" /etc/xdg/quickshell/caelestia/assets/
cp -f "${QS_DIR}/Content.qml" /etc/xdg/quickshell/caelestia/modules/session/

printf '[*] Config de quickshell reaplicada\n'
