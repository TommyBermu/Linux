#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAYS_DIR="${REPO_DIR}/overlays"
OFFICIAL_LIST="${REPO_DIR}/paquetes-oficiales.txt"
AUR_LIST="${REPO_DIR}/paquetes-aur.txt"

TARGET_USER="${SUDO_USER:-$(whoami)}"
TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
SWAP_SIZE_GB="${SWAP_SIZE_GB:-16}"
SWAP_FILE="${SWAP_FILE:-/swapfile}"

log() {
	printf '[*] %s\n' "$*"
}

warn() {
	printf '[!] %s\n' "$*" >&2
}

die() {
	printf '[x] %s\n' "$*" >&2
	exit 1
}

require_root() {
	if [[ $EUID -ne 0 ]]; then
		die "Ejecuta con sudo: sudo ${REPO_DIR}/bootstrap.sh"
	fi
}

require_files() {
	[[ -d "$OVERLAYS_DIR" ]] || die "No existe overlays en ${OVERLAYS_DIR}"
	[[ -f "$OFFICIAL_LIST" ]] || die "No existe ${OFFICIAL_LIST}"
	[[ -f "$AUR_LIST" ]] || warn "No existe ${AUR_LIST}; se omitira AUR"
}

require_target_user() {
	[[ -n "${TARGET_USER}" ]] || die "No se pudo detectar usuario objetivo"
	id "${TARGET_USER}" >/dev/null 2>&1 || die "No existe el usuario ${TARGET_USER}"
	[[ -n "${TARGET_HOME}" ]] || die "No se pudo detectar HOME para ${TARGET_USER}"
	[[ -d "${TARGET_HOME}" ]] || die "No existe HOME de ${TARGET_USER}: ${TARGET_HOME}"
}

setup_oh_my_bash() {
	local omb_dir="${TARGET_HOME}/.config/oh-my-bash"

	log "Configurando oh-my-bash en .config/oh-my-bash"
	pacman -S --noconfirm --needed git || true
	sudo -u "${TARGET_USER}" mkdir -p "${TARGET_HOME}/.config"

	if [[ ! -d "${omb_dir}/.git" ]]; then
		rm -rf "${omb_dir}"
		sudo -u "${TARGET_USER}" git clone --depth 1 https://github.com/ohmybash/oh-my-bash.git "${omb_dir}"
	else
		sudo -u "${TARGET_USER}" git -C "${omb_dir}" pull --ff-only || true
	fi

    cp -f "${OVERLAYS_DIR}/home/.config/oh-my-bash/lambda.theme.sh" "${omb_dir}/themes/lambda/lambda.theme.sh"

	chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.config"
}

setup_nvim_tmux() {
	local nvim_dir="${TARGET_HOME}/.config/nvim"
	local tmux_dir="${TARGET_HOME}/.config/tmux"
	local tpm_dir="${tmux_dir}/plugins/tpm"

	log "Configurando nvim desde GitHub"
	sudo -u "${TARGET_USER}" mkdir -p "${TARGET_HOME}/.config"
	if [[ ! -d "${nvim_dir}/.git" ]]; then
		rm -rf "${nvim_dir}"
		sudo -u "${TARGET_USER}" git clone --depth 1 https://github.com/TommyBermu/nvim.git "${nvim_dir}"
	else
		sudo -u "${TARGET_USER}" git -C "${nvim_dir}" pull --ff-only || true
	fi

	log "Configurando tmux desde GitHub"
	if [[ ! -d "${tmux_dir}/.git" ]]; then
		rm -rf "${tmux_dir}"
		sudo -u "${TARGET_USER}" git clone --depth 1 https://github.com/TommyBermu/tmux.git "${tmux_dir}"
	else
		sudo -u "${TARGET_USER}" git -C "${tmux_dir}" pull --ff-only || true
	fi

	log "Instalando TPM"
	sudo -u "${TARGET_USER}" mkdir -p "${tmux_dir}/plugins"
	if [[ ! -d "${tpm_dir}/.git" ]]; then
		rm -rf "${tpm_dir}"
		sudo -u "${TARGET_USER}" git clone --depth 1 https://github.com/tmux-plugins/tpm "${tpm_dir}"
	else
		sudo -u "${TARGET_USER}" git -C "${tpm_dir}" pull --ff-only || true
	fi

	log "Instalando plugins de tmux con TPM"
	if [[ -x "${tpm_dir}/bin/install_plugins" ]]; then
		sudo -u "${TARGET_USER}" bash -lc "HOME='${TARGET_HOME}' '${tpm_dir}/bin/install_plugins'" || warn "No se pudieron instalar plugins de tmux automaticamente"
	else
		warn "No existe install_plugins en ${tpm_dir}/bin"
	fi

	chown -R "${TARGET_USER}:${TARGET_USER}" "${nvim_dir}" "${tmux_dir}"
}

copy_repo_config() {
	log "Aplicando configuracion de pacman"

	if [[ -f "${OVERLAYS_DIR}/etc/pacman.conf" ]]; then
		cp -f "${OVERLAYS_DIR}/etc/pacman.conf" /etc/pacman.conf
	fi

	setup_blackarch_repo

	pacman -Syy --noconfirm
}

setup_blackarch_repo() {
	log "Configurando BlackArch (obligatorio) con strap.sh oficial"
	command -v curl >/dev/null 2>&1 || die "Falta curl; instala curl y vuelve a ejecutar"

	local tmp_strap
	tmp_strap="$(mktemp /tmp/blackarch-strap.XXXXXX.sh)"
	if ! curl -fsSL https://blackarch.org/strap.sh -o "$tmp_strap"; then
		rm -f "$tmp_strap"
		die "No se pudo descargar strap.sh de BlackArch"
	fi

	chmod +x "$tmp_strap"
	if ! bash "$tmp_strap"; then
		rm -f "$tmp_strap"
		die "Fallo ejecutando strap.sh de BlackArch"
	fi

	rm -f "$tmp_strap"

	if [[ ! -f /etc/pacman.d/blackarch-mirrorlist ]]; then
		die "BlackArch no quedo configurado: falta /etc/pacman.d/blackarch-mirrorlist"
	fi
}

read_pkg_list() {
	local file="$1"
	grep -Ev '^[[:space:]]*(#|$)' "$file" || true
}

install_official_packages() {
	log "Instalando paquetes oficiales"
	mapfile -t pkgs < <(read_pkg_list "$OFFICIAL_LIST")

	if (( ${#pkgs[@]} == 0 )); then
		warn "Lista oficial vacia"
		return 0
	fi

	pacman -Syu --noconfirm

	local pkg
	for pkg in "${pkgs[@]}"; do
		if pacman -Si "$pkg" >/dev/null 2>&1; then
			pacman -S --noconfirm --needed "$pkg" || warn "Fallo instalando ${pkg}"
		else
			warn "Paquete no encontrado en repos actuales: ${pkg}"
		fi
	done
}

ensure_paru() {
	if command -v paru >/dev/null 2>&1; then
		return 0
	fi

	log "Instalando paru desde AUR"
	pacman -S --noconfirm --needed base-devel git

	sudo -u "$TARGET_USER" bash -lc '
		set -euo pipefail
		cd "$HOME"
		rm -rf paru
		git clone https://aur.archlinux.org/paru.git
		cd paru
		makepkg -si --noconfirm
	'
}

install_aur_packages() {
	[[ -f "$AUR_LIST" ]] || return 0

	log "Instalando paquetes AUR"
	ensure_paru

	mapfile -t aur_pkgs < <(read_pkg_list "$AUR_LIST")
	if (( ${#aur_pkgs[@]} == 0 )); then
		warn "Lista AUR vacia"
		return 0
	fi

	local aur_payload
	aur_payload="$(printf '%s\n' "${aur_pkgs[@]}")"

	if ! sudo -u "$TARGET_USER" AUR_PAYLOAD="$aur_payload" bash -lc '
		set -euo pipefail
		mapfile -t aur_pkgs <<< "$AUR_PAYLOAD"
		paru -S --noconfirm --needed --sudoloop "${aur_pkgs[@]}"
	'; then
		warn "Fallo instalando uno o mas paquetes AUR en la ejecucion conjunta"
	fi
}

setup_caelestia_from_github() {
	local caelestia_dir="${TARGET_HOME}/.local/share/caelestia"

	log "Instalando Caelestia desde GitHub"
	command -v fish >/dev/null 2>&1 || die "Falta fish; agrega fish a paquetes oficiales"
	sudo -u "${TARGET_USER}" mkdir -p "${TARGET_HOME}/.local/share"

	if [[ ! -d "${caelestia_dir}/.git" ]]; then
		rm -rf "${caelestia_dir}"
		sudo -u "${TARGET_USER}" git clone --depth 1 https://github.com/caelestia-dots/caelestia.git "${caelestia_dir}"
	else
		sudo -u "${TARGET_USER}" git -C "${caelestia_dir}" pull --ff-only || true
	fi

	[[ -f "${caelestia_dir}/install.fish" ]] || die "No existe ${caelestia_dir}/install.fish"
	if ! sudo -u "${TARGET_USER}" env HOME="${TARGET_HOME}" fish "${caelestia_dir}/install.fish" --noconfirm; then
		die "Fallo instalando Caelestia desde GitHub"
	fi
}

apply_overlays() {
	local home_dst="${TARGET_HOME}"

	log "Aplicando overlays de binarios"
	if [[ -d "${OVERLAYS_DIR}/bin" ]]; then
		mkdir -p /usr/local/bin
		cp -rf --no-preserve=ownership "${OVERLAYS_DIR}/bin/." /usr/local/bin/
		chmod -R a+rx /usr/local/bin
	fi

	log "Aplicando overlays de HOME"
	if [[ -d "${OVERLAYS_DIR}/home" ]]; then
		# Copia HOME completo excepto .config/hypr para evitar conflicto dir -> symlink.
		(
			cd "${OVERLAYS_DIR}/home"
			tar --exclude='.config/hypr' -cf - .
		) | (
			cd "$home_dst"
			tar -xf -
		)

		# Hypr vive en Caelestia; copiamos solo el contenido al destino de .config/hypr.
		if [[ -e "${OVERLAYS_DIR}/home/.config/hypr" ]]; then
			cp -aLf "${OVERLAYS_DIR}/home/.config/hypr/." "$home_dst/.local/share/caelestia/hypr/" || warn "No se pudo copiar overlay de hypr"
		fi

		chown -R "${TARGET_USER}:${TARGET_USER}" "$home_dst"
	fi

	log "Aplicando overlays de share"
	if [[ -d "${OVERLAYS_DIR}/share" ]]; then
		mkdir -p "$home_dst/share"
		cp -af "${OVERLAYS_DIR}/share/." "$home_dst/share/"
		chown -R "${TARGET_USER}:${TARGET_USER}" "$home_dst/share"
	fi

	log "Aplicando overlays de quickshell"
	if [[ -d "${OVERLAYS_DIR}/etc/quickshell" ]]; then
		cp -f --no-preserve=ownership "${OVERLAYS_DIR}/etc/quickshell/bongocat.gif" /etc/xdg/quickshell/caelestia/assets/bongocat.gif
        cp -f --no-preserve=ownership "${OVERLAYS_DIR}/etc/quickshell/Content.qml" /etc/xdg/quickshell/caelestia/modules/session/Content.qml
	fi

	log "Aplicando overlays de SDDM"
	if [[ -f "${OVERLAYS_DIR}/etc/sddm/sddm.conf" ]]; then
		cp -f --no-preserve=ownership "${OVERLAYS_DIR}/etc/sddm/sddm.conf" /etc/sddm.conf
	fi
	if [[ -d "${OVERLAYS_DIR}/etc/sddm/sugar-candy" ]]; then
		mkdir -p /usr/share/sddm/themes/sugar-candy
		cp -rf --no-preserve=ownership "${OVERLAYS_DIR}/etc/sddm/sugar-candy/." /usr/share/sddm/themes/sugar-candy/
	fi

	log "Aplicando overlays de GRUB"
	if [[ -f "${OVERLAYS_DIR}/etc/grub/grub" ]]; then
		cp -f --no-preserve=ownership "${OVERLAYS_DIR}/etc/grub/grub" /etc/default/grub
	fi
	if [[ -d "${OVERLAYS_DIR}/etc/grub/grub.d" ]]; then
		mkdir -p /etc/grub.d
		cp -rf --no-preserve=ownership "${OVERLAYS_DIR}/etc/grub/grub.d/." /etc/grub.d/
		chmod -R a+rx /etc/grub.d
	fi
	if [[ -d "${OVERLAYS_DIR}/etc/grub/yorha" ]]; then
		mkdir -p /boot/grub/themes/yorha
		cp -rf --no-preserve=ownership "${OVERLAYS_DIR}/etc/grub/yorha/." /boot/grub/themes/yorha/
	fi
}

get_swap_offset() {
	local fstype
	fstype="$(findmnt -no FSTYPE -T "$SWAP_FILE")"

	if [[ "$fstype" == "btrfs" ]] && command -v btrfs >/dev/null 2>&1; then
		btrfs inspect-internal map-swapfile -r "$SWAP_FILE"
	else
		filefrag -v "$SWAP_FILE" | awk '$1=="0:"{gsub(/\.+/,"",$4); print $4; exit}'
	fi
}

configure_swap_hibernate() {
	log "Configurando swap e hibernacion"

	if [[ ! -f "$SWAP_FILE" ]]; then
		fallocate -l "${SWAP_SIZE_GB}G" "$SWAP_FILE" || \
			dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$((SWAP_SIZE_GB * 1024))" status=progress
		chmod 600 "$SWAP_FILE"
		mkswap "$SWAP_FILE"
	fi

	swapon "$SWAP_FILE" || true
	grep -qE '^/swapfile[[:space:]]' /etc/fstab || echo '/swapfile none swap defaults 0 0' >> /etc/fstab

	local resume_uuid resume_offset
	resume_uuid="$(findmnt -no UUID -T "$SWAP_FILE")"
	resume_offset="$(get_swap_offset)"

	[[ -n "$resume_uuid" ]] || die "No se pudo calcular UUID de resume"
	[[ -n "$resume_offset" ]] || die "No se pudo calcular resume_offset"

	if [[ ! -f /etc/default/grub ]]; then
		touch /etc/default/grub
	fi

	local current_cmdline cleaned_cmdline new_cmdline
	current_cmdline="$(awk -F= '/^GRUB_CMDLINE_LINUX_DEFAULT=/{sub(/^GRUB_CMDLINE_LINUX_DEFAULT=/,""); print; exit}' /etc/default/grub || true)"
	# Quita comillas simples/dobles externas si existen.
	current_cmdline="${current_cmdline#\"}"
	current_cmdline="${current_cmdline%\"}"
	current_cmdline="${current_cmdline#\'}"
	current_cmdline="${current_cmdline%\'}"

	cleaned_cmdline="$(printf '%s' "$current_cmdline" | sed -E 's/(^|[[:space:]])resume=UUID=[^[:space:]]+//g; s/(^|[[:space:]])resume_offset=[^[:space:]]+//g; s/[[:space:]]+/ /g; s/^ //; s/ $//')"
	if [[ -n "$cleaned_cmdline" ]]; then
		new_cmdline="${cleaned_cmdline} resume=UUID=${resume_uuid} resume_offset=${resume_offset}"
	else
		new_cmdline="resume=UUID=${resume_uuid} resume_offset=${resume_offset}"
	fi

	if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
		sed -i -E "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*$|GRUB_CMDLINE_LINUX_DEFAULT=\"${new_cmdline}\"|" /etc/default/grub
	else
		echo "GRUB_CMDLINE_LINUX_DEFAULT=\"${new_cmdline}\"" >> /etc/default/grub
	fi

	if [[ -f /etc/mkinitcpio.conf ]] && ! grep -qE '(^|[[:space:]])resume([[:space:]]|$)' /etc/mkinitcpio.conf; then
		sed -i -E 's/^HOOKS=\((.*)filesystems(.*)\)/HOOKS=(\1resume filesystems\2)/' /etc/mkinitcpio.conf
	fi

	mkinitcpio -P || warn "mkinitcpio fallo"
	grub-mkconfig -o /boot/grub/grub.cfg || warn "grub-mkconfig fallo"
}

enable_services() {
	log "Habilitando servicios base"
	systemctl enable sddm >/dev/null 2>&1 || warn "No se pudo habilitar sddm"
	systemctl enable docker >/dev/null 2>&1 || true
	systemctl enable bluetooth >/dev/null 2>&1 || true
	systemctl enable ufw >/dev/null 2>&1 || true
}

main() {
	require_root
	require_files
	require_target_user
    setup_oh_my_bash
	copy_repo_config
	install_official_packages
	install_aur_packages
	setup_caelestia_from_github
	apply_overlays
	setup_nvim_tmux
	configure_swap_hibernate
	enable_services

	mkdir -p "${TARGET_HOME}/Pictures/"
    cp -r "${REPO_DIR}/share/Wallpapers" "${TARGET_HOME}/Pictures/"
	chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/Pictures/Wallpapers"
 
	log "Bootstrap completo para ${TARGET_USER} (${TARGET_HOME})"
	log "Reinicia para validar SDDM, GRUB theme y hibernacion"
}

main "$@"