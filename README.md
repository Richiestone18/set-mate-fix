# set-mate-fix

Script para poner el **logo de Debian** como ícono del menú (`mate-menu`) en el panel de MATE, y opcionalmente ajustar el reloj a formato 12h.

## Uso rápido con curl

```bash
# 1. Ver el script antes de ejecutarlo (recomendado)
curl -fsSL https://raw.githubusercontent.com/Richiestone18/set-mate-fix/main/set-mate-fix.sh

# 2. Descargar y ejecutar
curl -fsSL https://raw.githubusercontent.com/Richiestone18/set-mate-fix/main/set-mate-fix.sh | bash

# 3. Solo poner el ícono (omitir el fix del reloj)
curl -fsSL https://raw.githubusercontent.com/Richiestone18/set-mate-fix/main/set-mate-fix.sh | bash -s -- --icon-only

# 4. Revertir todo al estado original del paquete
curl -fsSL https://raw.githubusercontent.com/Richiestone18/set-mate-fix/main/set-mate-fix.sh | bash -s -- --revert

# 5. Ver estado sin cambiar nada
curl -fsSL https://raw.githubusercontent.com/Richiestone18/set-mate-fix/main/set-mate-fix.sh | bash -s -- --check
```

## Uso descargando primero

```bash
curl -fsSL -o set-mate-fix.sh https://raw.githubusercontent.com/Richiestone18/set-mate-fix/main/set-mate-fix.sh
bash set-mate-fix.sh
```

## Opciones

| Opción | Qué hace |
|--------|----------|
| (ninguna) | Aplica el ícono de Debian + fix del reloj 12h, reinicia el panel |
| `--icon-only` | Solo aplica el ícono, omite el reloj |
| `--no-restart` | No reinicia `mate-panel` |
| `--icon NOMBRE` | Fuerza un nombre de ícono concreto |
| `--check` | Muestra qué parches están aplicados, sin cambiar nada |
| `--revert` | Restaura todo al estado original del paquete |

## Requisitos

- Debian 13 (o similar) con entorno de escritorio MATE
- Paquete `desktop-base` (trae el logo oficial de Debian)
- `mate-menu` instalado
- `gsettings`, `gtk-update-icon-cache`, `python3`

## Qué hace exactamente

1. Copia `/usr/share/desktop-base/debian-logos/logo.svg` a  
   `~/.local/share/icons/hicolor/scalable/places/distributor-logo-debian.svg` (sin root).
2. Actualiza el caché de íconos.
3. Setea `gsettings set org.mate.mate-menu custom-icon distributor-logo-debian`.
4. (Opcional) Aplica el fix del reloj 12h (`09:04 p. m.` con cero a la izquierda).
5. Reinicia `mate-panel` para que se vea el cambio.

## Revertir

```bash
bash set-mate-fix.sh --revert
```

O desde el repo:

```bash
curl -fsSL https://raw.githubusercontent.com/Richiestone18/set-mate-fix/main/set-mate-fix.sh | bash -s -- --revert
```

## Seguridad

Revisa el script antes de hacer `curl | bash`. El script modifica archivos del sistema (`/usr/lib/mate-menu/mate-menu.py`, schemas de glib, binario del reloj) y reinicia el panel.
