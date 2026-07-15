# ✨ Pixie SDDM

A clean, modern, and minimal SDDM theme inspired by Google Pixel UI and Material Design 3. Supports both the latest **Qt6** engine and legacy **Qt5** systems.

<div align="center">
  <img src="screenshots/lock_screen.png" width="45%" alt="Lock Screen" />
  <img src="screenshots/login_screen.png" width="45%" alt="Login Screen" />
</div>

<div align="center">
  <img src="screenshots/lock_screen_2.png" width="22%" />
  <img src="screenshots/login_screen_2.png" width="22%" />
  <img src="screenshots/lock_screen_3.png" width="22%" />
  <img src="screenshots/login_screen_3.png" width="22%" />
</div>

<div align="center">
  <img src="screenshots/lock_screen_4.png" width="22%" />
  <img src="screenshots/login_screen_4.png" width="22%" />
  <img src="screenshots/lock_screen_5.png" width="22%" />
  <img src="screenshots/login_screen_5.png" width="22%" />
</div>

## 🌟 Features

- **Pixel Aesthetic:** Clean typography and a unique two-tone stacked clock.
- **Material You Dynamic Colors:** Intelligent color extraction that samples your wallpaper for UI accents.
- **Next-Gen Blur:** High-performance Gaussian blur (Qt6) and custom shader blur (Qt5).
- **Universal Circle Avatar:** A bulletproof, anti-aliased circular profile mask that works on all systems.
- **Material Design 3:** Dark card UI with smooth interactions and responsive dropdowns.
- **Keyboard Navigation:** Full support for navigating menus with arrows and `Enter`.

---

## 🛠 1. Prerequisites (Essential)

Before installing, ensure you have the required modules for your system version to avoid a black screen:

<details open>
<summary><b>Qt6 (Default / Modern Distros)</b></summary>
Recommended for Fedora 40+, Arch Linux, CachyOS, NixOS.

```bash
# Arch: sudo pacman -S qt6-declarative qt6-svg qt6-quickcontrols2
# Fedora: sudo dnf install qt6-qtdeclarative qt6-qtsvg qt6-qtquickcontrols2
```
</details>

<details>
<summary><b>Qt5 (Legacy / Stable Distros)</b></summary>
Required for Ubuntu 22.04/24.04, Debian 12, Linux Mint.

```bash
# Ubuntu: sudo apt install qml-module-qtgraphicaleffects qml-module-qtquick-controls2
# Arch: sudo pacman -S qt5-graphicaleffects qt5-quickcontrols2
```
</details>

---

## 📦 2. Installation

Pixie SDDM automatically detects your system and installs the correct version.

| System Type | Engine | Recommended Branch |
| :--- | :--- | :--- |
| **Bleeding Edge** (Fedora, Arch, Nix) | **Qt6** | `main` (Default) |
| **Stable/LTS** (Ubuntu, Debian) | **Qt5** | `qt5` |

### Method A: Automatic Script (Recommended)
This script intelligently detects your Qt version and handles everything:
```bash
git clone https://github.com/xCaptaiN09/pixie-sddm.git
cd pixie-sddm
sudo ./install.sh
```

### Method B: Arch Linux (AUR)
The AUR package automatically tracks the latest modern version:
```bash
yay -S pixie-sddm-git
```

### Method C: NixOS (Declarative)
Add the following to your `configuration.nix`. (Change `rev = "main"` to `rev = "qt5"` for legacy systems).

```nix
{ pkgs, ... }: {
  services.displayManager.sddm = {
    enable = true;
    theme = "pixie";
  };

  environment.systemPackages = [
    (pkgs.stdenv.mkDerivation {
      name = "pixie-sddm";
      src = pkgs.fetchFromGitHub {
        owner = "xCaptaiN09";
        repo = "pixie-sddm";
        rev = "main";
        sha256 = "sha256-0000000000000000000000000000000000000000000=";
      };
      installPhase = ''
        mkdir -p $out/share/sddm/themes/pixie
        cp -r * $out/share/sddm/themes/pixie/
      '';
    })
    pkgs.kdePackages.qtdeclarative
    pkgs.kdePackages.qtquickcontrols2
    pkgs.kdePackages.qtsvg
    pkgs.kdePackages.qteffects
  ];
}
```

### Method D: Manual
1. Copy the folder to SDDM themes directory:
   `sudo cp -r pixie-sddm /usr/share/sddm/themes/pixie`
2. Set the theme in `/etc/sddm.conf`:
   ```ini
   [Theme]
   Current=pixie
   ```

---

## 🛠 Configuration & Testing

### Preview Without Logging Out
Run this command to preview the theme safely:
```bash
# For Qt6 (Modern):
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/pixie

# For Qt5 (Legacy):
sddm-greeter --test-mode --theme /usr/share/sddm/themes/pixie
```

### Customization
Edit `theme.conf` or replace assets in `assets/`:
- **Wallpaper:** Replace `assets/background.jpg`.
- **Avatar:** Replace `assets/avatar.jpg`.

## 🤝 Credits

- **Author:** [xCaptaiN09](https://github.com/xCaptaiN09)
- **Design:** Inspired by Google Pixel and MD3.
- **Font:** Google Sans Flex (included).

---
*Made with ❤️ for the Linux community.*
