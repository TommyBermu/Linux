#!/usr/bin/env bash
set -Eeuo pipefail

# Acciones posteriores al bootstrap que NO se pueden automatizar dentro de
# bootstrap.sh porque dependen de pasos interactivos ya hechos:
#   - La clave SSH ya subida y autorizada en GitHub (para pasar los remotes a git@).
#   - El login de Microsoft para OneDrive (autenticacion por navegador).
#
# Se ejecuta como el usuario normal (NO root): toca el home, remotes git y la
# config de OneDrive del usuario.
#
# Uso:  bash post-bootstrap.sh

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '[*] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }

if [[ $EUID -eq 0 ]]; then
	warn "Ejecuta este script como tu usuario normal, NO con sudo."
	exit 1
fi

# --- 1. Remotes git a SSH (git@) -------------------------------------------
# Todos los repos propios se clonan por HTTPS en el bootstrap (no requiere la
# clave SSH autorizada) y se pasan a SSH aqui, una vez la clave ya esta subida
# a GitHub, para poder hacer push. Son: nvim, tmux (en ~/.config) y linux (este
# repo). Se hace en el mismo punto para dejar los remotes coherentes.
set_ssh_remote() {
	local dir="$1" url="$2"
	if [[ -d "${dir}/.git" ]]; then
		git -C "$dir" remote set-url origin "$url" \
			&& log "remote de ${dir} -> ${url}" \
			|| warn "No se pudo cambiar el remote de ${dir}"
	else
		warn "No es un repo git: ${dir}; se omite"
	fi
}

log "Pasando los remotes de los repos propios a SSH (git@)"
set_ssh_remote "${HOME}/.config/nvim" "git@github.com:TommyBermu/nvim.git"
set_ssh_remote "${HOME}/.config/tmux" "git@github.com:TommyBermu/tmux.git"
set_ssh_remote "$REPO_DIR"            "git@github.com:TommyBermu/linux.git"

# --- 2. Carpetas bloat de XDG y user-dirs ----------------------------------
# xdg-user-dirs crea carpetas que no uso (Music, Templates, Public, Desktop,
# Projects). Se eliminan SOLO si estan vacias, para no borrar datos por error,
# y se apunta su entrada XDG a $HOME para que no se regeneren.
log "Limpiando carpetas bloat de XDG"
BLOAT=(Music Templates Public Desktop Projects Proyects)
for d in "${BLOAT[@]}"; do
	target="${HOME}/${d}"
	if [[ -d "$target" ]]; then
		if [[ -z "$(find "$target" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
			rmdir "$target" && log "  eliminada carpeta vacia: ${d}"
		else
			warn "  ${d} NO esta vacia; se deja intacta (revisar a mano)"
		fi
	fi
done

# Reapunta las entradas XDG de esas carpetas a $HOME para que
# xdg-user-dirs-update no las vuelva a crear en el siguiente arranque.
if command -v xdg-user-dirs-update >/dev/null 2>&1; then
	xdg-user-dirs-update --set DESKTOP     "$HOME" 2>/dev/null || true
	xdg-user-dirs-update --set TEMPLATES   "$HOME" 2>/dev/null || true
	xdg-user-dirs-update --set PUBLICSHARE "$HOME" 2>/dev/null || true
	xdg-user-dirs-update --set MUSIC       "$HOME" 2>/dev/null || true
	log "Entradas XDG de carpetas bloat apuntadas a \$HOME"
fi

# --- 3. OneDrive (abraunegg) -----------------------------------------------
# El paquete (onedrive-abraunegg) ya se instala en el bootstrap. Aqui se
# autentica (login interactivo de Microsoft en el navegador) y se habilita la
# sincronizacion automatica como servicio de usuario. Si ya hay un token de
# refresco, no se re-autentica.
if command -v onedrive >/dev/null 2>&1; then
	if [[ -f "${HOME}/.config/onedrive/refresh_token" ]]; then
		log "OneDrive ya esta autenticado (hay refresh_token); no se repite el login"
	else
		log "Autenticando OneDrive (se abrira el navegador para el login de Microsoft)"
		onedrive || warn "La autenticacion de OneDrive no se completo"
	fi

	# Servicio de usuario: sincroniza en segundo plano al iniciar sesion.
	if systemctl --user list-unit-files onedrive.service >/dev/null 2>&1; then
		systemctl --user enable --now onedrive.service >/dev/null 2>&1 \
			&& log "Servicio de usuario onedrive habilitado" \
			|| warn "No se pudo habilitar el servicio de usuario onedrive"
	else
		warn "No existe la unit de usuario onedrive.service; sincroniza a mano con 'onedrive --sync'"
	fi
else
	warn "onedrive no instalado; se omite (¿quedo en paquetes-aur.txt?)"
fi

# Los symlinks ~/Documents -> OneDrive/Documents y ~/Pictures -> OneDrive/Pictures
# los crea bootstrap.sh (apply_overlays). Quedan validos en cuanto OneDrive baje
# esas carpetas.

log "post-bootstrap completo"
