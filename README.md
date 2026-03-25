# Linux Bootstrap

Script para dejar una instalacion nueva de Arch igual a mi setup (paquetes + configs + themes + hibernacion).

## Requisitos

- Arch ya instalado
- Usuario normal creado
- Repositorio clonado en la maquina destino

## Uso

```bash
cd ~/Linux
sudo bash bootstrap.sh
```

El script detecta automaticamente el usuario que ejecuto sudo (`SUDO_USER`).

## Que aplica

1. Clona/actualiza oh-my-bash en `~/.config/oh-my-bash`.
2. Copia `pacman.conf` y mirrorlists desde `overlays/etc`.
3. Instala paquetes oficiales (`paquetes-oficiales.txt`).
4. Instala paquetes AUR (`paquetes-aur.txt`).
5. Copia overlays de home, binarios, quickshell, SDDM y GRUB.
6. Crea/configura `/swapfile` (16GB) y ajusta resume para hibernacion.
7. Regenera `mkinitcpio` y `grub.cfg`.
8. Habilita servicios base (sddm, docker, bluetooth, ufw).
