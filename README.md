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

1. Configura clave SSH para el usuario.
2. Clona/actualiza oh-my-bash en `~/.config/oh-my-bash` y copia el tema lambda.
3. Configura el repo de CachyOS e instala sus kernels (`linux-cachyos` y
   `linux-cachyos-hardened` con sus headers).
4. Configura el repo de BlackArch, instala `nipe` y coloca el `Status.pm` propio
   en `/usr/share/nipe/lib/Nipe/Utils/Status.pm`.
5. Instala paquetes oficiales (`paquetes-oficiales.txt`).
6. Instala paquetes AUR (`paquetes-aur.txt`) **uno por uno** (un fallo no aborta
   el resto).
7. Copia overlays de home, binarios, quickshell (via `clst.sh`) y SDDM.
8. Clona nvim/tmux e instala TPM + plugins.
9. Crea/configura `/swapfile` (16GB) y ajusta resume para hibernacion.
10. Regenera `mkinitcpio` y `grub.cfg`.
11. Habilita servicios base (sddm, docker, bluetooth, ufw) y despliega Portainer.

## Scripts auxiliares

- `update-lists.sh` — regenera `paquetes-oficiales.txt` y `paquetes-aur.txt` desde
  el sistema actual. Correlo antes de commitear para refrescar las listas.
- `clst.sh` — reaplica la config de quickshell (Caelestia) tras cada actualizacion
  que la sobrescribe. Se ejecuta con `sudo`.

