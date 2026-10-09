# Notas y problemas conocidos

## quickshell-git vs noctalia-qs (Caelestia no inicia)

### Síntoma
`caelestia-shell` no arranca después de instalar o actualizar. La shell de
Caelestia queda muerta tras un `paru -Syu`.

### Causa
`caelestia-shell` depende literalmente de **`quickshell-git`**. Candidatos que
pueden satisfacer esa dependencia:

- `aur/quickshell-git`   → es el paquete REAL con ese nombre (el correcto).
- `cachyos/noctalia-qs`  → `Provides: quickshell quickshell-git` (alternativa).
- `extra/quickshell`     → `Provides: None` (no sirve, se llama distinto).

Clave: cuando el paquete real `quickshell-git` NO está instalado, paru puede
satisfacer la dependencia vía el `provides` de `noctalia-qs`, y lo prefiere
porque es binario de repo (no hay que compilar). Pero `noctalia-qs` está
compilado para **Qt < 6.12**, mientras el sistema corre **Qt 6.12**
(`qt6-base 6.12.x`), así que Caelestia revienta.

Si en cambio `aur/quickshell-git` ya está instalado, satisface la dependencia
por **nombre real** (que tiene prioridad sobre cualquier `provides`), y paru
deja de considerar a noctalia-qs.

### Reinstalación en cada update
Si `quickshell-git` (AUR) falla al recompilar (es paquete `-git`) o se
desinstala, paru vuelve a resolver el provides con `noctalia-qs` y lo reinstala.
De ahí que "cada vez que actualizo me vuelve a aparecer noctalia-qs".

### Solución aplicada en el bootstrap
En `bootstrap.sh`, la función `install_quickshell_first()` (llamada al inicio de
`install_aur_packages`):

1. Si hay un `noctalia-qs` previo, lo elimina con `-Rdd`.
2. Instala `aur/quickshell-git` explícitamente con `paru -S --aur quickshell-git`
   **antes** que `caelestia-shell`.

Con `aur/quickshell-git` instalado, satisface el `Depends: quickshell-git` de
caelestia-shell por nombre real y paru ya no cae en noctalia-qs. También se
corrigió `paquetes-aur.txt`: antes decía `quickshell` (suelto, que no satisface
a caelestia-shell) y ahora dice `quickshell-git`.

### Workaround manual (si vuelve a pasar tras un update)
```bash
sudo pacman -Rdd noctalia-qs
paru -S --needed --aur quickshell-git
```

### Idea pendiente de blindaje (NO aplicada todavía)
Para evitarlo de raíz en los updates se podría añadir `noctalia-qs` a
`IgnorePkg` en `pacman.conf`, o usar pinning/assume-installed para que paru
nunca lo considere como proveedor. Decidido dejarlo fuera por ahora; esta nota
queda como recordatorio.
