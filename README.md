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

# 3b. Solo el fix del reloj 12h (no toca mate-menu ni el ícono)
curl -fsSL https://raw.githubusercontent.com/Richiestone18/set-mate-fix/main/set-mate-fix.sh | bash -s -- --clock-only

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
| `--clock-only` | Solo el fix del reloj; no toca `mate-menu` ni el ícono |
| `--icon-only` | Solo aplica el ícono, omite el reloj |
| `--no-restart` | No reinicia `mate-panel` |
| `--icon NOMBRE` | Fuerza un nombre de ícono concreto |
| `--check` | Muestra qué parches están aplicados, sin cambiar nada |
| `--revert` | Restaura todo al estado original del paquete |

Códigos de salida: `0` todo bien · `2` opción inválida · `3` parcial (el parche del ícono no
aplicó pero el reloj sí, o al revés) · `5` `mate-menu.py` quedó con sintaxis inválida ·
`6` `--revert` no pudo restaurar el ícono.

## El parche del ícono no es fatal (v2.6)

En máquinas donde `/usr/lib/mate-menu/mate-menu.py` ya estaba editado a mano (o el paquete
cambió y el bloque esperado ya no está), el parche del ícono **avisa y se salta**, pero el
fix del reloj se aplica igual. Antes el script abortaba ahí y el reloj nunca se arreglaba.

Para regularizar el archivo antes de reintentar:

```bash
apt-get download mate-menu && dpkg-deb -x mate-menu_*.deb /tmp/mm
sudo cp /tmp/mm/usr/lib/mate-menu/mate-menu.py /usr/lib/mate-menu/mate-menu.py
```

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

### El reloj 12h (por qué hacen falta tantos pasos)

El locale `es_MX` de glibc trae `am_pm "";""`, así que `%p` se expande a **nada**: el panel
mostraba `04:09` sin `a. m.`/`p. m.` aunque el formato ya fuera de 12 h. El script:

1. Parchea `/usr/share/i18n/locales/es_MX` (`am_pm "a. m.";"p. m."`) y regenera el locale.
2. Deja un wrapper en `/usr/libexec/mate-panel/clock-applet` que carga
   `/usr/local/lib/fake_nl.so` vía `LD_PRELOAD` (fuerza `a. m.`/`p. m.` sin depender del locale)
   y ejecuta el binario real, movido a `clock-applet.real`.
3. Parchea el binario: `%l:%M %p` → `%I:%M %p` para el cero a la izquierda (`09:04`, no `9:04`).
4. Guarda una copia prístina del binario en `/usr/local/lib/set-mate-fix/clock-applet.orig`
   para que `--revert` deshaga también el parche del binario.
5. Pone el reloj en `format='12-hour'`, sin fecha ni segundos.

## Revertir

```bash
bash set-mate-fix.sh --revert
```

`--revert` restaura el locale, el binario del reloj (desde la copia prístina), borra
`fake_nl.so` y resetea las claves de dconf del reloj. Si el parche del ícono no se había
aplicado, avisa y sale con código 6, pero el reloj sí se revierte.

O desde el repo:

```bash
curl -fsSL https://raw.githubusercontent.com/Richiestone18/set-mate-fix/main/set-mate-fix.sh | bash -s -- --revert
```

## Seguridad

Revisa el script antes de hacer `curl | bash`. El script modifica archivos del sistema (`/usr/lib/mate-menu/mate-menu.py`, schemas de glib, binario del reloj) y reinicia el panel.
