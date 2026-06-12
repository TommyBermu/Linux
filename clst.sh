#!/usr/bin/env bash

if [[ $EUID -ne 0 ]]; then
		die "Ejecuta con sudo: sudo ${REPO_DIR}/clst.sh"
	fi

cp -f overlays/etc/quickshell/bongocat.gif /etc/xdg/quickshell/caelestia/assets/
cp -f overlays/etc/quickshell/Content.qml /etc/xdg/quickshell/caelestia/modules/session/
