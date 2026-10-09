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

setup_ssh_key() {
	local ssh_dir="${TARGET_HOME}/.ssh"
	local key_file="${ssh_dir}/id_ed25519"

	log "Configurando clave SSH para ${TARGET_USER}"
	pacman -S --noconfirm --needed openssh || true

	sudo -u "${TARGET_USER}" mkdir -p "${ssh_dir}"
	chmod 700 "${ssh_dir}"

	if [[ ! -f "${key_file}" ]]; then
		local host
		host="$(cat /etc/hostname 2>/dev/null)"
		[[ -z "$host" ]] && host="$(hostname 2>/dev/null || uname -n)"
		sudo -u "${TARGET_USER}" ssh-keygen -t ed25519 -C "${TARGET_USER}@${host}" -f "${key_file}" -N ""
	else
		log "Ya existe ${key_file}; se reutiliza"
	fi

	if ! sudo -u "${TARGET_USER}" grep -q '^github\.com ' "${ssh_dir}/known_hosts" 2>/dev/null; then
		sudo -u "${TARGET_USER}" bash -c "ssh-keyscan -t ed25519 github.com >> '${ssh_dir}/known_hosts' 2>/dev/null" || true
	fi

	chown -R "${TARGET_USER}:${TARGET_USER}" "${ssh_dir}"
	chmod 600 "${key_file}"
	chmod 644 "${key_file}.pub"
	[[ -f "${ssh_dir}/known_hosts" ]] && chmod 644 "${ssh_dir}/known_hosts"
}

setup_git_global() {
	log "Configurando git global: rama por defecto main"
	sudo -u "${TARGET_USER}" git config --global init.defaultBranch main
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
	# Repo propio: se clona por HTTPS (no requiere que la clave SSH ya este
	# autorizada en GitHub) pero el remote queda en SSH para poder hacer push.
	sudo -u "${TARGET_USER}" git -C "${nvim_dir}" remote set-url origin git@github.com:TommyBermu/nvim.git

	log "Configurando tmux desde GitHub"
	if [[ ! -d "${tmux_dir}/.git" ]]; then
		rm -rf "${tmux_dir}"
		sudo -u "${TARGET_USER}" git clone --depth 1 https://github.com/TommyBermu/tmux.git "${tmux_dir}"
	else
		sudo -u "${TARGET_USER}" git -C "${tmux_dir}" pull --ff-only || true
	fi
	sudo -u "${TARGET_USER}" git -C "${tmux_dir}" remote set-url origin git@github.com:TommyBermu/tmux.git

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

setup_cachyos_repo() {
	log "Configurando repos de CachyOS con cachyos-repo.sh oficial"
	command -v curl >/dev/null 2>&1 || die "Falta curl; instala curl y vuelve a ejecutar"
	pacman -S --noconfirm --needed gawk || true

	local tmp_dir
	tmp_dir="$(mktemp -d /tmp/cachyos-repo.XXXXXX)"

	if ! curl -fsSL https://mirror.cachyos.org/cachyos-repo.tar.xz -o "${tmp_dir}/cachyos-repo.tar.xz"; then
		rm -rf "$tmp_dir"
		die "No se pudo descargar cachyos-repo.tar.xz de CachyOS"
	fi

	if ! tar -xf "${tmp_dir}/cachyos-repo.tar.xz" -C "$tmp_dir"; then
		rm -rf "$tmp_dir"
		die "No se pudo extraer cachyos-repo.tar.xz"
	fi

	if ! (cd "${tmp_dir}/cachyos-repo" && bash ./cachyos-repo.sh --install); then
		rm -rf "$tmp_dir"
		die "Fallo ejecutando cachyos-repo.sh de CachyOS"
	fi

	rm -rf "$tmp_dir"
}

install_cachyos_kernels() {
	log "Instalando kernels de CachyOS (normal + hardened con headers)"

	local kernels=(
		linux-cachyos
		linux-cachyos-headers
		linux-cachyos-hardened
		linux-cachyos-hardened-headers
	)

	# Refresca la base de datos para ver los paquetes del repo recien agregado.
	pacman -Sy --noconfirm || warn "No se pudo refrescar la base de datos de pacman"

	local pkg
	for pkg in "${kernels[@]}"; do
		if pacman -Si "$pkg" >/dev/null 2>&1; then
			pacman -S --noconfirm --needed "$pkg" || warn "Fallo instalando kernel ${pkg}"
		else
			warn "Kernel no encontrado en repos (¿CachyOS configurado?): ${pkg}"
		fi
	done
}

setup_blackarch_repo() {
    pacman -Syy --noconfirm
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

setup_nipe() {
	log "Configurando nipe (instalacion desde BlackArch + Status.pm propio)"

	# nipe no esta en repos oficiales ni AUR; viene del repo BlackArch.
	if ! pacman -Qq nipe >/dev/null 2>&1; then
		pacman -S --noconfirm --needed nipe || warn "No se pudo instalar nipe desde los repos (¿BlackArch configurado?)"
	else
		log "nipe ya esta instalado"
	fi

	local src="${OVERLAYS_DIR}/home/.config/nipe/Status.pm"
	local dst_dir="/usr/share/nipe/lib/Nipe/Utils"
	local dst="${dst_dir}/Status.pm"

	if [[ ! -f "$src" ]]; then
		warn "No existe el overlay de Status.pm en ${src}; se omite"
		return 0
	fi

	if [[ ! -d "$dst_dir" ]]; then
		warn "No existe ${dst_dir}; nipe no quedo instalado donde se espera, se omite Status.pm"
		return 0
	fi

	cp -f --no-preserve=ownership "$src" "$dst"
	log "Status.pm de nipe colocado en ${dst}"
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

	# Instalacion en serie: un paquete por iteracion para que el fallo de uno
	# no aborte la instalacion de los demas (paru en una sola llamada corta
	# todo el batch ante el primer error).
	local pkg
	for pkg in "${aur_pkgs[@]}"; do
		if ! sudo -u "$TARGET_USER" AUR_PKG="$pkg" bash -lc '
			set -euo pipefail
			paru -S --noconfirm --needed --sudoloop "$AUR_PKG"
		'; then
			warn "Fallo instalando paquete AUR: ${pkg}"
		fi
	done
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
		# Copia HOME completo (incluye .config/hypr, que ahora vive en su ruta
		# estandar ~/.config/hypr en lugar de dentro de Caelestia).
		(
			cd "${OVERLAYS_DIR}/home"
			tar -cf - .
		) | (
			cd "$home_dst"
			tar -xf -
		)

		chown -R "${TARGET_USER}:${TARGET_USER}" "$home_dst"
	fi

	log "Aplicando overlays de share"
	if [[ -d "${OVERLAYS_DIR}/share" ]]; then
		ln -s "${OVERLAYS_DIR}/share/Documents" "$home_dst/Documents"
		ln -s "${OVERLAYS_DIR}/share/Pictures" "$home_dst/Pictures"
		chown -R "${TARGET_USER}:${TARGET_USER}" "$home_dst/Documents"
		chown -R "${TARGET_USER}:${TARGET_USER}" "$home_dst/Pictures"
	fi

	log "Aplicando overlays de SDDM"
	if [[ -f "${OVERLAYS_DIR}/etc/sddm/sddm.conf" ]]; then
		cp -f --no-preserve=ownership "${OVERLAYS_DIR}/etc/sddm/sddm.conf" /etc/sddm.conf
	fi
}

setup_quickshell() {
	log "Aplicando overlays de quickshell (Caelestia) via clst.sh"

	local clst="${REPO_DIR}/clst.sh"
	if [[ ! -f "$clst" ]]; then
		warn "No existe ${clst}; se omite quickshell"
		return 0
	fi

	bash "$clst" || warn "clst.sh fallo aplicando la config de quickshell"
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

setup_grub() {
	log "Configurando GRUB (theme yorha + desactivar 31_efi_bootnext)"

	if [[ -d "${OVERLAYS_DIR}/boot/grub/themes" ]]; then
		mkdir -p /boot/grub/themes
		cp -rf --no-preserve=ownership "${OVERLAYS_DIR}/boot/grub/themes/." /boot/grub/themes/
	fi

	local theme_path="/boot/grub/themes/yorha/theme.txt"
	if [[ -f "$theme_path" ]]; then
		if [[ ! -f /etc/default/grub ]]; then
			touch /etc/default/grub
		fi
		if grep -q '^GRUB_THEME=' /etc/default/grub; then
			sed -i -E "s|^GRUB_THEME=.*$|GRUB_THEME=\"${theme_path}\"|" /etc/default/grub
		else
			echo "GRUB_THEME=\"${theme_path}\"" >> /etc/default/grub
		fi
	else
		warn "No se encontro ${theme_path}; se omite GRUB_THEME"
	fi

	if [[ -f /etc/grub.d/31_efi_bootnext ]]; then
		chmod -x /etc/grub.d/31_efi_bootnext
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

setup_dns() {
	log "Configurando DNS estatico (NetworkManager dns=none + resolv.conf)"

	# NetworkManager no debe gestionar resolv.conf; usamos uno estatico.
	local nm_src_dir="${OVERLAYS_DIR}/etc/NetworkManager/conf.d"
	if [[ -d "$nm_src_dir" ]]; then
		mkdir -p /etc/NetworkManager/conf.d
		cp -rf --no-preserve=ownership "${nm_src_dir}/." /etc/NetworkManager/conf.d/
	fi

	# resolv.conf estatico (1.1.1.1 / 8.8.8.8). Si existe como symlink
	# (p. ej. hacia systemd-resolved), lo reemplazamos por el archivo real.
	if [[ -f "${OVERLAYS_DIR}/etc/resolv.conf" ]]; then
		[[ -L /etc/resolv.conf ]] && rm -f /etc/resolv.conf
		cp -f --no-preserve=ownership "${OVERLAYS_DIR}/etc/resolv.conf" /etc/resolv.conf
	fi
}

enable_services() {
	log "Habilitando servicios base"
	systemctl enable sddm >/dev/null 2>&1 || warn "No se pudo habilitar sddm"
	systemctl enable --now docker >/dev/null 2>&1 || warn "No se pudo habilitar/iniciar docker"
	systemctl enable bluetooth >/dev/null 2>&1 || true
	systemctl enable ufw >/dev/null 2>&1 || true

	# NetworkManager-wait-online queda enabled por preset al instalar networkmanager
	# y bloquea la critical-chain del arranque grafico: tras poner la contrasena en
	# SDDM, la sesion queda en negro hasta que vence su timeout. Lo deshabilitamos.
	systemctl disable NetworkManager-wait-online.service >/dev/null 2>&1 || true
}

setup_security_baseline() {
	log "Generando baselines de seguridad (rkhunter + clamav)"

	# --- rkhunter ---
	if command -v rkhunter >/dev/null 2>&1; then
		log "rkhunter: actualizando definiciones"
		# --update puede devolver codigos no-cero informativos; no abortar.
		rkhunter --update --nocolors >/dev/null 2>&1 || warn "rkhunter --update devolvio avisos"

		log "rkhunter: generando baseline (--propupd)"
		# Snapshot del estado bueno conocido de los binarios ya instalados.
		rkhunter --propupd --nocolors >/dev/null 2>&1 || warn "rkhunter --propupd fallo"

		# Instala el timer de escaneo diario (units versionados).
		local rk_svc="${OVERLAYS_DIR}/etc/systemd/system/rkhunter-scan.service"
		local rk_timer="${OVERLAYS_DIR}/etc/systemd/system/rkhunter-scan.timer"
		if [[ -f "$rk_svc" && -f "$rk_timer" ]]; then
			cp -f --no-preserve=ownership "$rk_svc" /etc/systemd/system/rkhunter-scan.service
			cp -f --no-preserve=ownership "$rk_timer" /etc/systemd/system/rkhunter-scan.timer
			systemctl daemon-reload
			systemctl enable --now rkhunter-scan.timer >/dev/null 2>&1 || warn "No se pudo habilitar rkhunter-scan.timer"
		else
			warn "No existen los units de rkhunter-scan en overlays; se omite el timer"
		fi

		# Instala el hook de pacman para escanear tras cada instalacion/upgrade/remove.
		local rk_hook="${OVERLAYS_DIR}/etc/pacman.d/hooks/rkhunter.hook"
		if [[ -f "$rk_hook" ]]; then
			mkdir -p /etc/pacman.d/hooks
			cp -f --no-preserve=ownership "$rk_hook" /etc/pacman.d/hooks/rkhunter.hook
			log "Hook de pacman para rkhunter instalado en /etc/pacman.d/hooks/rkhunter.hook"
		else
			warn "No existe el hook de rkhunter en overlays; se omite"
		fi
	else
		warn "rkhunter no instalado; se omite baseline"
	fi

	# --- clamav ---
	if command -v freshclam >/dev/null 2>&1; then
		log "clamav: descargando firmas iniciales (freshclam)"
		# El servicio freshclam toma un lock; detenerlo para la descarga manual.
		systemctl stop clamav-freshclam.service >/dev/null 2>&1 || true
		freshclam >/dev/null 2>&1 || warn "freshclam fallo descargando firmas"
		# Habilita la actualizacion automatica de firmas.
		systemctl enable --now clamav-freshclam.service >/dev/null 2>&1 || warn "No se pudo habilitar clamav-freshclam"
	else
		warn "clamav/freshclam no instalado; se omite"
	fi
}

setup_portainer() {
	log "Desplegando Portainer como servicio systemd (solo HTTP 9000)"
	command -v docker >/dev/null 2>&1 || die "Falta docker; agrega docker a paquetes oficiales"
	systemctl is-active --quiet docker || systemctl start docker || die "No se pudo iniciar docker para desplegar Portainer"

	# Volumen persistente para los datos de Portainer.
	docker volume inspect portainer_data >/dev/null 2>&1 || docker volume create portainer_data >/dev/null

	# Instala el unit versionado (contenedor manejado por systemd: start/stop).
	local unit_src="${OVERLAYS_DIR}/etc/systemd/system/portainer.service"
	if [[ -f "$unit_src" ]]; then
		cp -f --no-preserve=ownership "$unit_src" /etc/systemd/system/portainer.service
		systemctl daemon-reload
		# Si ya existe un contenedor suelto (p. ej. de un run manual), lo quitamos
		# para que el servicio lo cree limpio.
		if docker ps -a --format '{{.Names}}' | grep -qx portainer; then
			docker rm -f portainer >/dev/null 2>&1 || true
		fi
		systemctl enable --now portainer.service >/dev/null 2>&1 || warn "No se pudo habilitar/iniciar portainer.service"
	else
		warn "No existe ${unit_src}; se omite el servicio de Portainer"
	fi
}

main() {
	require_root
	require_files
	require_target_user
	setup_git_global
    setup_oh_my_bash
	setup_cachyos_repo
	install_cachyos_kernels
	setup_blackarch_repo
	setup_nipe
	install_official_packages
	install_aur_packages
	apply_overlays
	setup_quickshell
	setup_nvim_tmux
	setup_security_baseline
	setup_dns
	setup_grub
	configure_swap_hibernate
	enable_services
	setup_portainer

	setup_ssh_key
 
	log "Bootstrap completo para ${TARGET_USER} (${TARGET_HOME})"
	log "Reinicia para validar SDDM, GRUB theme y hibernacion"

	log "Portainer disponible en http://localhost:9000 (crea el usuario admin en el primer acceso)"

	printf '\n'
	printf '========================================================================\n'
	printf '  ACCIONES MANUALES PENDIENTES\n'
	printf '========================================================================\n'
	printf '\n'
	printf '  [1] Agrega esta clave SSH publica en https://github.com/settings/keys:\n'
	printf '\n'
	cat "${TARGET_HOME}/.ssh/id_ed25519.pub"
	printf '\n'
	printf '  [2] Instala el driver de huella manualmente (colisiona con libfprint\n'
	printf '      y hay que confirmar el reemplazo a mano):\n'
	printf '\n'
	printf '          paru -S libfprint-2-tod1-elan\n'
	printf '\n'
	printf '========================================================================\n'
}

main "$@"
