Este repositorio contiene mi configuración personal de tmux pensada para productividad en la terminal: atajos (prefijo C-s), navegación estilo vim entre paneles, redimensionado cómodo, una barra de estado con el tema Catppuccin y varios plugins gestionados por TPM (tmux plugin manager). El archivo principal de configuración es `.tmux.conf` y el final del archivo ejecuta TPM desde `~/.tmux/plugins/tpm/tpm`.

Dependencias
------------
Requisitos mínimos:
- tmux (recomendado >= 3.0; algunas funcionalidades de plugins funcionan mejor en tmux >= 3.1+)
- git
- curl o wget (para clonar/instalar TPM y otros recursos)
- Una terminal compatible con emojis y ligaduras (por ejemplo: Kitty, Alacritty, iTerm2 en macOS, Windows Terminal, GNOME Terminal con fuente adecuada)
- Fuente con símbolos/nerd fonts / powerline (por ejemplo: Nerd Fonts o JetBrains Mono Nerd Font) — necesaria para los separadores y glifos usados por el tema Catppuccin (, , etc.)

Clipboard / copiar-pegar (según sistema):
- Linux X11: xclip o xsel
- Linux Wayland: wl-clipboard (wl-copy / wl-paste) o soporte por compositor
- macOS: pbcopy / pbpaste (incluidos en el sistema)
- WSL: configurar integración con Windows (por ejemplo clip.exe) o usar xclip con servidor X

Plugins usados (tal como aparecen en `.tmux.conf` — TPM los gestiona):
- tmux-plugins/tpm
- tmux-plugins/tmux-sensible
- christoomey/vim-tmux-navigator
- tmux-plugins/tmux-resurrect
- tmux-plugins/tmux-continuum
- tmux-plugins/tmux-yank
- catppuccin/tmux

Dependencias opcionales / recomendadas según uso:
- tmux Plugin Manager (TPM) — imprescindible para instalar y gestionar los plugins anteriores
- Fuentes Nerd Fonts / Powerline (para iconos y separadores)
- fzf (si integras búsquedas rápidas en scripts o plugins)
- python (si usas scripts de status que requieran Python)
- xclip / xsel / wl-clipboard / pbcopy (ver sección Clipboard)
- Herramienta de gestión de sesiones/shells (zsh, bash) — no obligatoria, pero común en personalizaciones

Instalación
-----------
1. Clona el repositorio en tu home (se asume que la configuración espera `~/.tmux/.tmux.conf`):
   ```
   git clone https://github.com/TommyBermu/tmux.git ~/.tmux
   ```

2. Enlaza (o copia) el archivo de configuración principal a `~/.tmux.conf` para que tmux lo cargue automáticamente:
   ```
   ln -s ~/.tmux/.tmux.conf ~/.tmux.conf
   # o, si prefieres copiar:
   # cp ~/.tmux/.tmux.conf ~/.tmux.conf
   ```

3. Instala TPM (tmux plugin manager) en la ruta esperada por la configuración:
   ```
   git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
   ```

4. Abre (o reinicia) tmux y presiona el prefijo seguido de I para instalar los plugins listados:
   - Prefijo por defecto en esta configuración: Ctrl+s
   - Entonces: Ctrl+s luego I (mayúscula i)

   Alternativamente, desde tu shell puedes forzar la instalación de plugins ejecutando:
   ```
   ~/.tmux/plugins/tpm/bin/install_plugins
   ```

5. Asegura las dependencias del sistema (ejemplos):
   - Debian/Ubuntu:
     ```
     sudo apt update
     sudo apt install -y tmux git curl xclip
     ```
   - Arch Linux:
     ```
     sudo pacman -Syu tmux git curl xclip
     ```
   - macOS (Homebrew):
     ```
     brew install tmux git curl
     ```
   - Instala wl-clipboard en Wayland si lo necesitas:
     ```
     sudo apt install wl-clipboard    # Debian/Ubuntu
     sudo pacman -S wl-clipboard      # Arch
     ```

6. Fuentes y terminal:
   - Instala una Nerd Font o una fuente que incluya los glifos necesarios (por ejemplo JetBrainsMono Nerd Font).
   - Usa un emulador de terminal que soporte ligaduras y emojis (Kitty, Alacritty, iTerm2, Windows Terminal, etc.) y configura la fuente instalada.

7. Recarga la configuración sin reiniciar sesiones:
   ```
   tmux source-file ~/.tmux/.tmux.conf
   ```

Notas finales
--------------
- La configuración incluye el tema Catppuccin y usa glifos especiales en la barra de estado: asegúrate de tener una fuente con dichos símbolos para que la apariencia sea correcta.
- Para que `tmux-yank` copie al portapapeles del sistema debes tener instalado y configurado el binario de copia adecuado para tu plataforma (xclip/xsel/wl-copy/pbcopy).

