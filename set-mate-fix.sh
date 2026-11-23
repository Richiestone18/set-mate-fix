#!/usr/bin/env bash
#
# set-mate-fix.sh v2 — Corregir botón inicio (mate-menu) y reloj 12h del panel MATE.
#
# Uso:
#   bash set-mate-fix.sh                 aplicar fixes
#   bash set-mate-fix.sh --check         ver estado
#   bash set-mate-fix.sh --icon NOMBRE  fuerza icono (omite el SVG embebido)
#   bash set-mate-fix.sh --revert        revierte ambos fixes
#   bash set-mate-fix.sh --no-restart    no reiniciar mate-panel
#   bash set-mate-fix.sh --icon NOMBRE   forzar nombre del icono
#
# Integrado: set-mate-fix.sh también aplica el fix del reloj 12h (09:04 p. m. con cero a la izquierda)
#
set -euo pipefail

ROOT="${MATE_FIX_ROOT:-}"
PY_TARGET="${ROOT}/usr/lib/mate-menu/mate-menu.py"
SCHEMA="${ROOT}/usr/share/glib-2.0/schemas/org.mate.mate-menu.gschema.xml"
SCHEMA_DIR="${ROOT}/usr/share/glib-2.0/schemas"
CLK_BIN="${ROOT}/usr/libexec/mate-panel/clock-applet"
CLK_REAL="${ROOT}/usr/libexec/mate-panel/clock-applet.real"
LOCALE_ES="${ROOT}/usr/share/i18n/locales/es_MX"
FULL_ICON="$HOME/.local/share/icons/Yaru/scalable/places/start-here-full-symbolic.svg"
DEBIAN_ICON="$HOME/.local/share/icons/hicolor/scalable/places/distributor-logo-debian.svg"
DEBIAN_SRC="/usr/share/desktop-base/debian-logos/logo.svg"
BK=".set-mate-fix.orig"

MODE="apply"; RESTART=1; FORCE_ICON=""; RUN_CLOCK=1
for arg in "$@"; do
  case "$arg" in
    --check)      MODE="check" ;;
    --revert)     MODE="revert" ;;
    --icon-only)  RUN_CLOCK=0 ;;
    --no-restart) RESTART=0 ;;
    --icon)       FORCE_ICON="__needs_value__" ;;
    --icon=*)     FORCE_ICON="${arg#*=}" ;;
    -h|--help)    awk 'NR<3{next} !/^#/{exit} {sub(/^# ?/,""); print}' "$0"; exit 0 ;;
    *) echo "Opcion desconocida: $arg (--check --revert --icon-only --no-restart --icon NOMBRE)" >&2; exit 2 ;;
  esac
done
[[ "$FORCE_ICON" == "__needs_value__" ]] && { echo "Falta el valor para --icon" >&2; exit 2; }

command -v python3 >/dev/null || { echo "Falta python3" >&2; exit 1; }
if [[ -z "$ROOT" && ! -e "$PY_TARGET" ]]; then
  echo "No existe $PY_TARGET — mate-menu no está instalado" >&2
  exit 1
fi

# El trabajo fino (buscar/reemplazar bloques) vive en este parche embebido.
PATCHER="$(mktemp /tmp/set-mate-fix.XXXXXX.py)"
trap 'rm -f "$PATCHER"' EXIT
cat >"$PATCHER" <<'PYEOF'
import os, sys

mode, prefix = sys.argv[1], sys.argv[2]
PY = prefix + "/usr/lib/mate-menu/mate-menu.py"
SCHEMA = prefix + "/usr/share/glib-2.0/schemas/org.mate.mate-menu.gschema.xml"

# (marcador_que_indica_ya_aplicado, [bloque_original_pristine, variantes_previas], bloque_nuevo)
# v2: se aceptan varias variantes "old" para poder actualizar máquinas que ya
# tienen el parche v1 aplicado, sin importar el orden en que se parchearon.
PY_PATCHES = [
    (
        'self.icon = self.settings.get_string("custom-icon") or "start-here"',
        [
            '        self.icon = "start-here"',
            '        self.icon = self.settings.get_string("custom-icon")',
        ],
        '        self.icon = self.settings.get_string("custom-icon") or "start-here"',
    ),
    (
        'changed::custom-icon',
        [
            '        self.settings.connect( "changed::hide-applet-icon", self.reloadSettings )\n',
        ],
        '        self.settings.connect( "changed::hide-applet-icon", self.reloadSettings )\n'
        '        self.settings.connect( "changed::custom-icon", self.reloadSettings )\n',
    ),
    (
        "# set-mate-fix v2",
        [
            # pristine (paquete)
            '        icon_size = self.applet.get_size() - 8\n'
            '        scale_factor = self.button_icon.get_scale_factor()\n'
            '        surface = icon_theme.load_surface(icon_name, icon_size, scale_factor, None, Gtk.IconLookupFlags.FORCE_SIZE)\n',
            # v1 escrito por el script
            '        panel_size = self.applet.get_size()\n'
            '        # Same size ladder mate-panel uses for its own panel buttons\n'
            '        # (mate-panel/button-widget.c) so the icon scales with the panel\n'
            '        # just like every other panel icon.\n'
            '        if panel_size < 22:\n            icon_size = 16\n'
            '        elif panel_size < 24:\n            icon_size = 22\n'
            '        elif panel_size < 32:\n            icon_size = 24\n'
            '        elif panel_size < 48:\n            icon_size = 32\n'
            '        else:\n            icon_size = 48\n'
            '        scale_factor = self.button_icon.get_scale_factor()\n'
            '        # Symbolic icons are SVG: drop FORCE_SIZE so they scale cleanly\n'
            '        # instead of being raster-forced to a fixed pixel size.\n'
            '        is_symbolic = "-symbolic" in icon_name\n'
            '        flags = Gtk.IconLookupFlags.FORCE_SIZE if not is_symbolic else Gtk.IconLookupFlags(0)\n'
            '        surface = icon_theme.load_surface(icon_name, icon_size, scale_factor, None, flags)\n',
            # v1 con comentarios editados a mano (esta maquina)
            '        panel_size = self.applet.get_size()\n'
            '        # Same size ladder mate-panel uses for its own panel buttons\n'
            '        # (mate-panel/button-widget.c) so the icon scales with the panel\n'
            '        # just like every other panel icon.\n'
            '        if panel_size < 22:\n            icon_size = 16\n'
            '        elif panel_size < 24:\n            icon_size = 22\n'
            '        elif panel_size < 32:\n            icon_size = 24\n'
            '        elif panel_size < 48:\n            icon_size = 32\n'
            '        else:\n            icon_size = 48\n'
            '        scale_factor = self.button_icon.get_scale_factor()\n'
            '\n'
            '        # For symbolic icons (designed for 16px), don\'t use FORCE_SIZE\n'
            '        # to allow proper SVG scaling instead of raster forcing\n'
            '        is_symbolic = "-symbolic" in icon_name\n'
            '        flags = Gtk.IconLookupFlags.FORCE_SIZE if not is_symbolic else Gtk.IconLookupFlags(0)\n'
            '\n'
            '        surface = icon_theme.load_surface(icon_name, icon_size, scale_factor, None, flags)\n',
        ],
        '        panel_size = self.applet.get_size()\n'
        '        # set-mate-fix v2: same size ladder mate-panel uses for its own\n'
        '        # panel buttons (mate-panel/button-widget.c)\n'
        '        if panel_size < 22:\n            icon_size = 16\n'
        '        elif panel_size < 24:\n            icon_size = 22\n'
        '        elif panel_size < 32:\n            icon_size = 24\n'
        '        elif panel_size < 48:\n            icon_size = 32\n'
        '        else:\n            icon_size = 48\n'
        '        try:\n            scale_factor = self.button_icon.get_scale_factor()\n'
        '        except AttributeError:\n            scale_factor = 1\n'
        '        # set-mate-fix v2: fallback-safe icon load: si el icono\n'
        '        # configurado no existe o falla la carga, se prueban nombres\n'
        '        # known-good para que el boton NUNCA desaparezca del panel.\n'
        '        icon_name = icon_name or "start-here"\n'
        '        chain = [icon_name] + [n for n in ("start-here-symbolic", "start-here")\n'
        '                                if n != icon_name]\n'
        '        surface = None\n'
        '        for name in chain:\n'
        '            try:\n'
        '                if not icon_theme.has_icon(name):\n                    continue\n'
        '                # set-mate-fix v2.1: simbolicos a tamano completo\n'
        '                flags = Gtk.IconLookupFlags.FORCE_SIZE\n'
        '                surface = icon_theme.load_surface(name, icon_size,\n'
        '                                                  scale_factor, None, flags)\n'
        '            except Exception:\n                surface = None\n'
        '            if surface is not None:\n'
        '                icon_name = name\n                break\n',
    ),
    # v2.1: maquinas que quedaron con el bloque v2 (flags=0 en simbolicos):
    # los temas Yaru-no-MATE traen start-here-symbolic.svg de 16x16 y al no
    # forzar tamano el SVG se pinta a su tamano natural -> boton minusculo
    # en paneles de 32px. Se reconverge al bloque con FORCE_SIZE. Acepta las
    # dos variantes de chain que escribieron los scripts v2 anteriores.
    (
        "# set-mate-fix v2.1: simbolicos a tamano completo",
        [
            '        panel_size = self.applet.get_size()\n'
            '        # set-mate-fix v2: same size ladder mate-panel uses for its own\n'
            '        # panel buttons (mate-panel/button-widget.c)\n'
            '        if panel_size < 22:\n'
            '            icon_size = 16\n'
            '        elif panel_size < 24:\n'
            '            icon_size = 22\n'
            '        elif panel_size < 32:\n'
            '            icon_size = 24\n'
            '        elif panel_size < 48:\n'
            '            icon_size = 32\n'
            '        else:\n'
            '            icon_size = 48\n'
            '        try:\n'
            '            scale_factor = self.button_icon.get_scale_factor()\n'
            '        except AttributeError:\n'
            '            scale_factor = 1\n'
            '        # set-mate-fix v2: fallback-safe icon load: si el icono\n'
            '        # configurado no existe o falla la carga, se prueban nombres\n'
            '        # known-good para que el boton NUNCA desaparezca del panel.\n'
            '        icon_name = icon_name or "start-here"\n'
            '        chain = [icon_name] + [n for n in ("start-here-full-symbolic", "start-here")\n'
            '                                if n != icon_name]\n'
            '        surface = None\n'
            '        for name in chain:\n'
            '            try:\n'
            '                if not icon_theme.has_icon(name):\n'
            '                    continue\n'
            '                is_symbolic = "-symbolic" in name\n'
            '                flags = (Gtk.IconLookupFlags.FORCE_SIZE if not is_symbolic\n'
            '                         else Gtk.IconLookupFlags(0))\n'
            '                surface = icon_theme.load_surface(name, icon_size,\n'
            '                                                  scale_factor, None, flags)\n'
            '            except Exception:\n'
            '                surface = None\n'
            '            if surface is not None:\n'
            '                icon_name = name\n'
            '                break\n'
,
            '        panel_size = self.applet.get_size()\n'
            '        # set-mate-fix v2: same size ladder mate-panel uses for its own\n'
            '        # panel buttons (mate-panel/button-widget.c)\n'
            '        if panel_size < 22:\n'
            '            icon_size = 16\n'
            '        elif panel_size < 24:\n'
            '            icon_size = 22\n'
            '        elif panel_size < 32:\n'
            '            icon_size = 24\n'
            '        elif panel_size < 48:\n'
            '            icon_size = 32\n'
            '        else:\n'
            '            icon_size = 48\n'
            '        try:\n'
            '            scale_factor = self.button_icon.get_scale_factor()\n'
            '        except AttributeError:\n'
            '            scale_factor = 1\n'
            '        # set-mate-fix v2: fallback-safe icon load: si el icono\n'
            '        # configurado no existe o falla la carga, se prueban nombres\n'
            '        # known-good para que el boton NUNCA desaparezca del panel.\n'
            '        icon_name = icon_name or "start-here"\n'
            '        chain = [icon_name] + [n for n in ("start-here-symbolic", "start-here")\n'
            '                                if n != icon_name]\n'
            '        surface = None\n'
            '        for name in chain:\n'
            '            try:\n'
            '                if not icon_theme.has_icon(name):\n'
            '                    continue\n'
            '                is_symbolic = "-symbolic" in name\n'
            '                flags = (Gtk.IconLookupFlags.FORCE_SIZE if not is_symbolic\n'
            '                         else Gtk.IconLookupFlags(0))\n'
            '                surface = icon_theme.load_surface(name, icon_size,\n'
            '                                                  scale_factor, None, flags)\n'
            '            except Exception:\n'
            '                surface = None\n'
            '            if surface is not None:\n'
            '                icon_name = name\n'
            '                break\n'
        ],
        '        panel_size = self.applet.get_size()\n'
        '        # set-mate-fix v2: same size ladder mate-panel uses for its own\n'
        '        # panel buttons (mate-panel/button-widget.c)\n'
        '        if panel_size < 22:\n'
        '            icon_size = 16\n'
        '        elif panel_size < 24:\n'
        '            icon_size = 22\n'
        '        elif panel_size < 32:\n'
        '            icon_size = 24\n'
        '        elif panel_size < 48:\n'
        '            icon_size = 32\n'
        '        else:\n'
        '            icon_size = 48\n'
        '        try:\n'
        '            scale_factor = self.button_icon.get_scale_factor()\n'
        '        except AttributeError:\n'
        '            scale_factor = 1\n'
        '        # set-mate-fix v2: fallback-safe icon load: si el icono\n'
        '        # configurado no existe o falla la carga, se prueban nombres\n'
        '        # known-good para que el boton NUNCA desaparezca del panel.\n'
        '        icon_name = icon_name or "start-here"\n'
        '        chain = [icon_name] + [n for n in ("start-here-full-symbolic", "start-here")\n'
        '                                if n != icon_name]\n'
        '        surface = None\n'
        '        for name in chain:\n'
        '            try:\n'
        '                if not icon_theme.has_icon(name):\n'
        '                    continue\n'
        '                # set-mate-fix v2.1: simbolicos a tamano completo\n'
        '                flags = Gtk.IconLookupFlags.FORCE_SIZE\n'
        '                surface = icon_theme.load_surface(name, icon_size,\n'
        '                                                  scale_factor, None, flags)\n'
        '            except Exception:\n'
        '                surface = None\n'
        '            if surface is not None:\n'
        '                icon_name = name\n'
        '                break\n'
    ),
    # v2.2: el tamano real del panel se conoce EN la primera size-allocate,
    # no al crear el applet; sin esto el boton siempre usa el tamano minimo.
    (
        "# set-mate-fix v2.2",
        [
            '    def createPanelButton( self ):\n'
            '        self.button_icon = Gtk.Image()\n'
            '        self.do_load_icon(self.icon)\n'
        ],
        '    def createPanelButton( self ):\n'
        '        self.button_icon = Gtk.Image()\n'
        '        self.do_load_icon(self.icon)\n'
        '        # set-mate-fix v2.2: al crear el applet get_size() puede devolver 0\n'
        '        # (el panel aun no lo asigna) y el icono queda al tamano minimo del\n'
        '        # tema (16px). Recargar el icono cuando el panel asigne el tamano real.\n'
        '        self._icon_loaded_size = -1\n'
        '        def _reload_on_allocate(widget, allocation):\n'
        '            size = self.applet.get_size()\n'
        '            if size >= 16 and size != getattr(self, "_icon_loaded_size", -1):\n'
        '                self._icon_loaded_size = size\n'
        '                self.do_load_icon(self.icon)\n'
        '        self.applet.connect("size-allocate", _reload_on_allocate)\n'
    ),
    # v2.3: el tamano real solo existe en la asignacion del panel; get_size()
    # devuelve 0 tanto al crear como al recargar, asi que handler y ladder
    # deben leer allocation/orientation en vez de get_size().
    (
        "# set-mate-fix v2.3a",
        [
            '        self._icon_loaded_size = -1\n'
            '        def _reload_on_allocate(widget, allocation):\n'
            '            size = self.applet.get_size()\n'
            '            if size >= 16 and size != getattr(self, "_icon_loaded_size", -1):\n'
            '                self._icon_loaded_size = size\n'
            '                self.do_load_icon(self.icon)\n'
            '        self.applet.connect("size-allocate", _reload_on_allocate)\n'
        ],
        '        self._icon_loaded_size = -1\n'
        '        def _reload_on_allocate(widget, allocation):\n'
        '            # set-mate-fix v2.3a: get_size() vale 0 aqui; usar la asignacion\n'
        '            if self.applet.get_orientation() == Gtk.Orientation.HORIZONTAL:\n'
        '                size = allocation.height\n'
        '            else:\n'
        '                size = allocation.width\n'
        '            if size >= 16 and size != getattr(self, "_icon_loaded_size", -1):\n'
        '                self._icon_loaded_size = size\n'
        '                self.do_load_icon(self.icon)\n'
        '        self.applet.connect("size-allocate", _reload_on_allocate)\n'
    ),
    (
        "# set-mate-fix v2.3b",
        [
            '        panel_size = self.applet.get_size()\n'
            '        # set-mate-fix v2: same size ladder mate-panel uses for its own\n'
        ],
        '        panel_size = self.applet.get_size()\n'
        '        if panel_size < 16:\n'
        '            # set-mate-fix v2.3b: get_size() vale 0 antes de que el panel\n'
        '            # asigne; derivar el tamano de la asignacion real\n'
        '            _alloc = self.applet.get_allocation()\n'
        '            if self.applet.get_orientation() == Gtk.Orientation.HORIZONTAL:\n'
        '                panel_size = _alloc.height\n'
        '            else:\n'
        '                panel_size = _alloc.width\n'
        '        # set-mate-fix v2: same size ladder mate-panel uses for its own\n'
    ),
    # v2.4: preferencia del usuario: el icono a color un poco menor
    # (convencion MATE panel_size-8); el simbolico conserva el tamano.
    (
        "# set-mate-fix v2.4",
        [
            '                # set-mate-fix v2.1: simbolicos a tamano completo\n'
            '                flags = Gtk.IconLookupFlags.FORCE_SIZE\n'
            '                surface = icon_theme.load_surface(name, icon_size,\n'
            '                                                  scale_factor, None, flags)\n'
        ],
        '                # set-mate-fix v2.1: simbolicos a tamano completo\n'
        '                flags = Gtk.IconLookupFlags.FORCE_SIZE\n'
        '                # set-mate-fix v2.4: los iconos a color se ven enormes a\n'
        '                # tamano completo; cargarlos con panel-8 como el resto de\n'
        '                # los applets del panel (los simbolicos no cambian).\n'
        '                if "-symbolic" in name:\n'
        '                    load_size = icon_size\n'
        '                else:\n'
        '                    load_size = max(icon_size - 8, 16)\n'
        '                surface = icon_theme.load_surface(name, load_size,\n'
        '                                                  scale_factor, None, flags)\n'
    ),
    # v2.4b: el recorte v2.4 (panel-8) fue demasiado; el usuario pidio solo
    # "un minimo" -> panel-4. Se salta si ya existe el estado final (v2.4c) y
    # acepta como origen tanto el bloque de v2.4a como el de la propia v2.4b.
    (
        "# set-mate-fix v2.4c",
        [
            '                # set-mate-fix v2.4: los iconos a color se ven enormes a\n'
            '                # tamano completo; cargarlos con panel-8 como el resto de\n'
            '                # los applets del panel (los simbolicos no cambian).\n'
            '                if "-symbolic" in name:\n'
            '                    load_size = icon_size\n'
            '                else:\n'
            '                    load_size = max(icon_size - 8, 16)\n'
,
            '                # set-mate-fix v2.4b: los iconos a color, SOLO 4px menores\n'
            '                # que el tamano del panel (los simbolicos no cambian).\n'
            '                if "-symbolic" in name:\n'
            '                    load_size = icon_size\n'
            '                else:\n'
            '                    load_size = max(icon_size - 4, 16)\n'
        ],
        '                # set-mate-fix v2.4b: los iconos a color, SOLO 4px menores\n'
        '                # que el tamano del panel (los simbolicos no cambian).\n'
        '                if "-symbolic" in name:\n'
        '                    load_size = icon_size\n'
        '                else:\n'
        '                    load_size = max(icon_size - 4, 16)\n'
    ),
    # v2.4c: ajuste fino del usuario: subir al minimo -> panel-2.
    (
        "# set-mate-fix v2.4c",
        [
            '                # set-mate-fix v2.4b: los iconos a color, SOLO 4px menores\n'
            '                # que el tamano del panel (los simbolicos no cambian).\n'
            '                if "-symbolic" in name:\n'
            '                    load_size = icon_size\n'
            '                else:\n'
            '                    load_size = max(icon_size - 4, 16)\n'
        ],
        '                # set-mate-fix v2.4c: iconos a color 2px menores que el\n'
        '                # tamano del panel (los simbolicos no cambian).\n'
        '                if "-symbolic" in name:\n'
        '                    load_size = icon_size\n'
        '                else:\n'
        '                    load_size = max(icon_size - 2, 16)\n'
    ),
    (
        "# Auto-switch icon based on icon theme",
        [
            '        self.hotkeyText =  self.settings.get_string( "hot-key" )\n'
            '\n'
            '    def changeTheme(self, *args):\n'
            '        self.reloadSettings()\n'
            '        self.applyTheme()\n'
            '        self.mainwin.loadTheme()\n',
        ],
        '        self.hotkeyText =  self.settings.get_string( "hot-key" )\n'
        '        self.icon       =  self.settings.get_string( "custom-icon" )\n'
        '\n'
        '    def changeTheme(self, *args):\n'
        '        self.reloadSettings()\n'
        '        self.applyTheme()\n'
        '        self.mainwin.loadTheme()\n'
        '        # Auto-switch icon based on icon theme\n'
        "        icon_theme = self.mate_settings.get_string('icon-theme')\n"
        "        if icon_theme.startswith('Yaru-MATE'):\n"
        '            self.settings.set_string("custom-icon", "start-here")\n'
        '        else:\n'
        '            name = "start-here-full-symbolic"\n'
        '            if not Gtk.IconTheme.get_default().has_icon(name):\n'
        '                name = "start-here-symbolic"\n'
        '            self.settings.set_string("custom-icon", name)\n',
    ),
]

SCHEMA_PATCH = (
    'name="custom-icon"',
    ['    <key type="as" name="plugins-list">'],
    '    <key type="s" name="custom-icon">\n'
    '      <default>"start-here"</default>\n'
    '      <summary>Custom applet icon name</summary>\n'
    '      <description>Icon name for the menu button (start-here, start-here-symbolic, ...)</description>\n'
    '    </key>\n'
    '\n'
    '    <key type="as" name="plugins-list">',
)


def find_block(text, block):
    """Busca `block` ignorando espacios al final de linea -> (ini, fin) | None"""
    ends_with_nl = block.endswith("\n")
    needle = [ln.rstrip() for ln in block.split("\n")]
    while needle and needle[-1] == "":
        needle.pop()
    n = len(needle)
    lines = text.split("\n")
    starts, pos = [], 0
    for ln in lines:
        starts.append(pos)
        pos += len(ln) + 1
    starts.append(pos)
    for i in range(len(lines) - n + 1):
        if [lines[i + k].rstrip() for k in range(n)] == needle:
            if ends_with_nl:
                return starts[i], starts[i + n]
            return starts[i], starts[i + n - 1] + len(lines[i + n - 1])
    return None


def write(path, text):
    # v2.1: conserva el modo original del archivo. mate-menu.py se ejecuta
    # DIRECTO por activacion D-Bus (necesita +x); forzar 0644 quitaba el
    # permiso y el panel no podia lanzar el applet -> boton desaparecia.
    try:
        mode = os.stat(path).st_mode & 0o7777
    except OSError:
        mode = 0o644
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)
    os.chmod(path, mode)


def do_apply(path, patches):
    orig = open(path, encoding="utf-8").read()
    text, changed = orig, 0
    for marker, olds, new in patches:
        if marker in text:
            print("    ya aplicado : %s" % marker.strip()[:56])
            continue
        hit, hit_old = None, None
        for old in olds:
            hit = find_block(text, old)
            if hit:
                hit_old = old
                break
        if not hit:
            print("    ERROR: no se encontro el bloque esperado en %s:" % os.path.basename(path))
            print("           %s" % olds[0].strip().split("\n")[0][:72])
            print("           (el paquete se actualizo y cambio este archivo?)")
            return 3
        text = text[:hit[0]] + new + text[hit[1]:]
        changed += 1
        print("    aplicado    : %s" % marker.strip()[:56])
    if changed:
        b = path + ".set-mate-fix.orig"
        if not os.path.exists(b):
            with open(b, "w", encoding="utf-8") as fh:
                fh.write(orig)
            print("    backup      : %s" % os.path.basename(b))
        write(path, text)
    print("    total: %d bloque(s) nuevo(s)" % changed)
    return 0


def do_revert(path, patches):
    b = path + ".set-mate-fix.orig"
    if os.path.exists(b):
        write(path, open(b, encoding="utf-8").read())
        print("    restaurado desde %s" % os.path.basename(b))
        return 0
    text, changed = open(path, encoding="utf-8").read(), 0
    for marker, olds, new in reversed(patches):
        hit = find_block(text, new)
        if hit:
            text = text[:hit[0]] + olds[0] + text[hit[1]:]
            changed += 1
    if changed:
        write(path, text)
        print("    %d bloque(s) revertido(s) por patron (sin backup)" % changed)
        return 0
    print("    AVISO: no hay %s y el archivo no coincide con lo que escribe" % os.path.basename(b))
    print("           este script (parche a mano?). Recuperacion limpia:")
    print("             sudo apt-get install --reinstall mate-menu")
    return 6


def do_check(path, patches):
    text = open(path, encoding="utf-8").read()
    done = sum(1 for m, _o, _n in patches if m in text)
    print("    %d/%d aplicado(s)" % (done, len(patches)))
    for m, _o, _n in patches:
        print("      [%s] %s" % ("x" if m in text else " ", m.strip()[:60]))
    return 0


HANDLER = {"apply": do_apply, "revert": do_revert, "check": do_check}[mode]
rc = 0
for path, patches in ((PY, PY_PATCHES), (SCHEMA, [SCHEMA_PATCH])):
    print(path)
    if not os.path.isfile(path):
        print("    ERROR: no existe")
        rc = 2
        break
    rc = HANDLER(path, patches)
    if rc:
        print("    se interrumpe: %s no se pudo procesar" % os.path.basename(path))
        break
sys.exit(rc)
PYEOF

need_sudo() { [[ -n "$ROOT" ]] && return 1; [[ -w "$PY_TARGET" && -w "$SCHEMA_DIR" ]] && return 1; return 0; }
S() { if need_sudo; then sudo "$@"; else "$@"; fi; }
run_patcher() { S python3 "$PATCHER" "$1" "$ROOT"; }


# v2.5: el SVG start-here-full-symbolic (viewBox recortado, se ve a tamano
# completo en el panel) se empaqueta aqui para que el fix sea completo en
# maquinas nuevas; vive en ~/.local, sin root.
install_full_icon() {
  local want got; want="8e6ce7a6f0f9b8f69dbe0a4225e24228"
  if [[ -f "$FULL_ICON" ]]; then
    got=$(md5sum "$FULL_ICON" | awk '{print $1}')
    [[ "$got" == "$want" ]] && { echo "  full-symbolic SVG: OK"; return 0; }
  fi
  mkdir -p "$(dirname "$FULL_ICON")"
  base64 -d >"$FULL_ICON" <<'SVGEOF'
PHN2ZyB2ZXJzaW9uPSIxLjEiIHZpZXdCb3g9IjEuNTgxMyAyLjAxODggMTIuNCAxMi40IiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPgogPGcgZmlsbD0iIzgwODA4MCI+CiAgPHBhdGggZD0ibTEwLjE3NiAxMC41NTFhMS42NzUgMS42NzUgMCAwIDEgMS42NzM4IDEuNjczOCAxLjY3NSAxLjY3NSAwIDAgMS0xLjY3MzggMS42NzU4IDEuNjc1IDEuNjc1IDAgMCAxLTEuNjc1OC0xLjY3NTggMS42NzUgMS42NzUgMCAwIDEgMS42NzU4LTEuNjczOHoiLz4KICA8cGF0aCBkPSJtNC41ODk4IDEwLjA4NmE0LjA0IDQuMDQgMCAwIDAgMi43NzU0IDIuMTI1IDEuNDQ1IDEuNDQ1IDAgMCAwIDAuNDEwMTYgMC4wNjQ0NSAyLjM1NSAyLjM1NSAwIDAgMCAwLjUgMS40MDA0IDUuNSA1LjUgMCAwIDEtMS4xODU1LTAuMTI1IDUuNDM1IDUuNDM1IDAgMCAxLTMuOTI1OC0zLjI5MSAyLjQxNSAyLjQxNSAwIDAgMCAxLjQyNTgtMC4xNzM4M3oiLz4KICA8cGF0aCBkPSJtMy41ODk4IDYuMjM0NGExLjY3NSAxLjY3NSAwIDAgMSAxLjY3NTggMS42NzU4IDEuNjc1IDEuNjc1IDAgMCAxLTEuNjc1OCAxLjY3NTggMS42NzUgMS42NzUgMCAwIDEtMS42NzU4LTEuNjc1OCAxLjY3NSAxLjY3NSAwIDAgMSAxLjY3NTgtMS42NzU4eiIvPgogIDxwYXRoIGQ9Im0xMi43NzUgNS4xOTkyYTUuNSA1LjUgMCAwIDEtMC4yNzUzOSA2LjQxNiAyLjI5IDIuMjkgMCAwIDAtMC44MDA3OC0xLjI0MDIgNC4wNCA0LjA0IDAgMCAwIDAuNTI1MzktMS4zMDA4IDQuMTEgNC4xMSAwIDAgMC0wLjM4ODY3LTIuNzczNCAyLjQyNSAyLjQyNSAwIDAgMCAwLjkzOTQ1LTEuMTAxNnoiLz4KICA8cGF0aCBkPSJtOC4xMTkxIDIuNzQwMmE1LjUgNS41IDAgMCAxIDAuNTE1NjIgMC4wMTU2MjUgMi4zMTUgMi4zMTUgMCAwIDAtMC40NTg5OCAwLjk3NDYxIDMuMjEgMy4yMSAwIDAgMC0wLjA1MDc4MSAwLjM3NSA0LjA2IDQuMDYgMCAwIDAtMy4yODkxIDEuNzU5OCAyLjQyIDIuNDIgMCAwIDAtMC43NjE3Mi0wLjMxNDQ1IDIuMzI1IDIuMzI1IDAgMCAwLTAuNS0wLjA1MDc4MWgtMC4xMjVhNS41IDUuNSAwIDAgMSA0LjY2OTktMi43NTk4eiIvPgogIDxwYXRoIGQ9Im0xMC41NTEgMi41NjQ1YTEuNjc1IDEuNjc1IDAgMCAxIDEuNjczOCAxLjY3NTggMS42NzUgMS42NzUgMCAwIDEtMS42NzM4IDEuNjczOCAxLjY3NSAxLjY3NSAwIDAgMS0xLjY3NTgtMS42NzM4IDEuNjc1IDEuNjc1IDAgMCAxIDEuNjc1OC0xLjY3NTh6Ii8+CiA8L2c+Cjwvc3ZnPgo=
SVGEOF
  gtk-update-icon-cache -q "$(dirname "$(dirname "$(dirname "$FULL_ICON")")")" 2>/dev/null || true
  echo "  full-symbolic SVG instalado en ~/.local (sin root)"
}

remove_full_icon() {
  [[ -f "$FULL_ICON" ]] || return 0
  local want got; want="8e6ce7a6f0f9b8f69dbe0a4225e24228"
  got=$(md5sum "$FULL_ICON" | awk '{print $1}')
  if [[ "$got" == "$want" ]]; then rm -f "$FULL_ICON"; echo "  full-symbolic SVG quitado"; fi
}

install_debian_icon() {
  if [[ -f "$DEBIAN_ICON" ]]; then
    echo "  logo debian: ya esta instalado"; return 0
  fi
  if [[ ! -f "$DEBIAN_SRC" ]]; then
    echo "  AVISO: no existe $DEBIAN_SRC (paquete desktop-base); no se puede instalar el logo de debian" >&2
    return 1
  fi
  mkdir -p "$(dirname "$DEBIAN_ICON")"
  cp "$DEBIAN_SRC" "$DEBIAN_ICON"
  gtk-update-icon-cache -q "$(dirname "$(dirname "$(dirname "$DEBIAN_ICON")")")" 2>/dev/null || true
  echo "  logo debian instalado en ~/.local (sin root)"
}

remove_debian_icon() {
  [[ -f "$DEBIAN_ICON" ]] || return 0
  rm -f "$DEBIAN_ICON"
  gtk-update-icon-cache -q "$(dirname "$(dirname "$(dirname "$DEBIAN_ICON")")")" 2>/dev/null || true
  echo "  logo debian quitado"
}

have_icon() {
  python3 - "$1" <<'PY' 2>/dev/null || echo "no"
import sys, gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk
print("yes" if Gtk.IconTheme.get_default().has_icon(sys.argv[1]) else "no")
PY
}

pick_icon() {
  local theme
  theme=$(gsettings get org.mate.interface icon-theme 2>/dev/null | tr -d "'" || true)
  if [[ "$theme" == Yaru-MATE* ]]; then echo "start-here"; return; fi
  # v3: logo de Debian como icono del menu (preferido sobre start-here genericos)
  if [[ "$(have_icon distributor-logo-debian)" == "yes" ]]; then
    echo "distributor-logo-debian"
    return
  fi
  # v2: ultimo fallback "start-here" (existe en casi todos los temas) para
  # nunca dejar custom-icon apuntando a un icono inexistente.
  if [[ "$(have_icon start-here-full-symbolic)" == "yes" ]]; then
    echo "start-here-full-symbolic"
  elif [[ "$(have_icon start-here-symbolic)" == "yes" ]]; then
    echo "start-here-symbolic"
  else
    echo "start-here"
  fi
}

restart_panel() {
  if pgrep -x mate-panel >/dev/null 2>&1; then
    pkill -x mate-panel 2>/dev/null || true
    sleep 2
    nohup mate-panel >/tmp/mate-panel.log 2>&1 &
    sleep 2
    echo "  panel reiniciado"
  else
    echo "  (mate-panel no esta corriendo; se vera al iniciar sesion)"
  fi
}

# ---------- reloj 12h (integrado desde set-mate-clock-format.sh) ----------

clock_prefs_path() {
  local obj o iid
  obj=$(dconf list /org/mate/panel/objects/ 2>/dev/null | grep -ix 'clock' | head -1 || true)
  if [[ -z "$obj" ]]; then
    for o in $(dconf list /org/mate/panel/objects/ 2>/dev/null || true); do
      iid=$(dconf read "/org/mate/panel/objects/${o}applet-iid" 2>/dev/null || true)
      if [[ "$iid" == "'ClockAppletFactory::ClockApplet'" ]]; then obj="$o"; break; fi
    done
  fi
  [[ -z "$obj" ]] && return 1
  echo "/org/mate/panel/objects/${obj}prefs"
}

_locale_patched() {
  grep -q 'am_pm.*"a\. m\."' "$LOCALE_ES" 2>/dev/null &&
  locale -a 2>/dev/null | grep -qi '^es_MX\(\.UTF-8\)\?$'
}

apply_locale_fix() {
  if _locale_patched && locale -k am_pm 2>/dev/null | grep -q 'a\. m\.'; then
    echo "  locale am_pm: OK"; return 0
  fi
  [[ -f "$LOCALE_ES" ]] || { echo "  AVISO: no existe $LOCALE_ES; el reloj usara AM/PM"; return 1; }
  [[ -f "$LOCALE_ES$BK" ]] || S cp "$LOCALE_ES" "$LOCALE_ES$BK"
  # v2: sed anclado al patron (el viejo '123s/.../' dependia del numero de
  # linea y podia romper otra linea en maquinas con el archivo distinto)
  S sed -i -e 's/^[[:space:]]*#\{0,1\}[[:space:]]*am_pm.*/am_pm   "a. m.";"p. m."/' "$LOCALE_ES"
  if grep -qE '^[[:space:]]*#?[[:space:]]*t_fmt_ampm' "$LOCALE_ES"; then
    S sed -i -e 's/^[[:space:]]*#\{0,1\}[[:space:]]*t_fmt_ampm.*/t_fmt_ampm "%I:%M:%S %p"/' "$LOCALE_ES"
  else
    S bash -c "printf 't_fmt_ampm \"%%I:%%M:%%S %%p\"\n' >> '$LOCALE_ES'"
  fi
  if command -v locale-gen >/dev/null; then S locale-gen es_MX.UTF-8 >/dev/null
  elif command -v localedef >/dev/null; then S localedef -i es_MX -f UTF-8 es_MX.UTF-8 >/dev/null
  else echo "  AVISO: no hay locale-gen ni localedef; regenera tu locale manualmente"; fi
  echo "  locale es_MX: am_pm / t_fmt_ampm parcheados"
}

apply_clock_wrapper() {
  if [[ ! -e "$CLK_REAL" ]]; then
    [[ -f "$CLK_BIN" ]] || { echo "  AVISO: no existe $CLK_BIN; omito reloj"; return 1; }
    S mv "$CLK_BIN" "$CLK_REAL"
    echo "  binario movido a clock-applet.real"
  fi
  local so="${ROOT}/usr/local/lib/fake_nl.so" w
  if [[ ! -f "$so" ]]; then
    if command -v gcc >/dev/null; then
      local c so_b; c=$(mktemp /tmp/fake_nl.XXXXXX.c); so_b="${c%.c}.so"
      cat >"$c" <<'EOF'
#define _GNU_SOURCE
#include <langinfo.h>
#include <dlfcn.h>
char *nl_langinfo(nl_item item){static char *am="a. m.";static char *pm="p. m.";if(item==AM_STR) return am;if(item==PM_STR) return pm;char*(*o)(nl_item)=dlsym(RTLD_NEXT,"nl_langinfo");return o?o(item):"";}
EOF
      gcc -shared -fPIC -o "$so_b" "$c" -ldl
      S mkdir -p "$(dirname "$so")"
      S install -m 0644 "$so_b" "$so"
      rm -f "$c" "$so_b"
      echo "  fake_nl.so instalado"
    else
      echo "  AVISO: falta gcc (apt install gcc); el reloj mostrara AM/PM en vez de a. m./p. m."
    fi
  fi
  w=$(mktemp)
  {
    echo '#!/bin/bash'
    [[ -f "$so" ]] && echo "export LD_PRELOAD=$so"
    echo 'export LC_MESSAGES=C'
    echo 'export LANGUAGE=C'
    echo 'exec /usr/libexec/mate-panel/clock-applet.real "$@"'
  } >"$w"
  S install -m 0755 "$w" "$CLK_BIN"
  rm -f "$w"
  echo "  wrapper clock-applet escrito"
}

patch_clock_binary() {
  [[ -f "$CLK_REAL" ]] || return 0
  if grep -a -q '%l:%M %p' "$CLK_REAL" 2>/dev/null; then
    command -v perl >/dev/null || { echo "  AVISO: falta perl; el reloj no tendra cero a la izquierda"; return 0; }
    S perl -i -pe 's/%l:%M %p/%I:%M %p/g' "$CLK_REAL"
    echo "  parche binario %l -> %I aplicado"
  else
    echo "  parche binario %l -> %I: ya esta o no aplica"
  fi
}

apply_clock_settings() {
  local prefix
  prefix=$(clock_prefs_path) || { echo "  AVISO: no encontre el applet del reloj en el panel" >&2; return 1; }
  dconf write "${prefix}/format" "'12-hour'" || return 1
  dconf write "${prefix}/show-date" "false"
  dconf write "${prefix}/show-seconds" "false"
  dconf reset "${prefix}/custom-format" 2>/dev/null || true
  dconf reset -f /org/mate/panel/applet/clock/prefs/ 2>/dev/null || true
  export LANG=es_MX.UTF-8 LC_TIME=es_MX.UTF-8 LANGUAGE=es_MX:es
  systemctl --user import-environment LANG LC_TIME LANGUAGE 2>/dev/null || true
  dbus-update-activation-environment --systemd LANG LC_TIME LANGUAGE 2>/dev/null || true
  echo "  dconf: 12-hour, sin segundos, sin fecha"
}

apply_clock() {
  echo "-- reloj (12h con cero: 09:04 p. m.)"
  # limpieza de residuos de versiones antiguas del fix
  pkill -f clock-format-monitor.sh 2>/dev/null || true
  rm -f "$HOME/.config/autostart/mate-clock-fix.desktop" 2>/dev/null || true
  apply_locale_fix || true
  apply_clock_wrapper || return 1
  patch_clock_binary || true
  apply_clock_settings || return 1
}

revert_clock() {
  local did=0 prefix k
  if [[ -f "$CLK_REAL" ]]; then
    S mv -f "$CLK_REAL" "$CLK_BIN"
    echo "  clock-applet restaurado"; did=1
  fi
  if [[ -f "${ROOT}/usr/local/lib/fake_nl.so" ]]; then
    S rm -f "${ROOT}/usr/local/lib/fake_nl.so"
    echo "  fake_nl.so borrado"; did=1
  fi
  if [[ -f "$LOCALE_ES$BK" ]]; then
    S cp "$LOCALE_ES$BK" "$LOCALE_ES" && S rm -f "$LOCALE_ES$BK"
    if command -v locale-gen >/dev/null; then S locale-gen es_MX.UTF-8 >/dev/null
    elif command -v localedef >/dev/null; then S localedef -i es_MX -f UTF-8 es_MX.UTF-8 >/dev/null
    fi
    echo "  locale es_MX restaurada"; did=1
  fi
  if prefix=$(clock_prefs_path); then
    for k in format show-date show-seconds custom-format; do
      dconf reset "${prefix}/${k}" 2>/dev/null || true
    done
    did=1
  fi
  [[ "$did" == 1 ]] || echo "  (nada que revertir en el reloj)"
  return 0
}

clock_status() {
  echo "-- reloj"
  if [[ -e "${ROOT}/usr/libexec/mate-panel/clock-applet.real" ]]; then
    echo "  wrapper: ACTIVO"
  else
    echo "  wrapper: no aplicado"
  fi
  if [[ -f "${ROOT}/usr/local/lib/fake_nl.so" ]]; then
    echo "  fake_nl.so: instalado"
  else
    echo "  fake_nl.so: no"
  fi
  if [[ -f "$CLK_REAL" ]] && grep -a -q '%l:%M %p' "$CLK_REAL" 2>/dev/null; then
    echo "  parche %l: PENDIENTE (vuelve a ejecutar el script)"
  else
    echo "  parche %l: OK / no aplica"
  fi
  if locale -k am_pm 2>/dev/null | grep -q 'a\. m\.'; then
    echo "  locale am_pm: OK"
  else
    echo "  locale am_pm: sin corregir"
  fi
  local p
  p=$(clock_prefs_path 2>/dev/null || true)
  if [[ -n "$p" ]] && command -v dconf >/dev/null; then
    dconf dump "$p/" 2>/dev/null || true
  fi
  return 0
}

echo "== set-mate-fix v2: icono Menu + reloj 12h =="

if [[ "$MODE" == "check" ]]; then
  python3 "$PATCHER" check "$ROOT"
  echo "  custom-icon = $(gsettings get org.mate.mate-menu custom-icon 2>/dev/null || echo '(clave no disponible)')"
  [[ -z "$ROOT" ]] && clock_status
  exit 0
fi

if [[ "$MODE" == "revert" ]]; then
  echo "-- revirtiendo al paquete original"
  RCREV=0
  run_patcher revert || RCREV=$?
  if [[ -z "$ROOT" ]]; then
    gsettings reset org.mate.mate-menu custom-icon 2>/dev/null || true
    remove_full_icon
    remove_debian_icon || true
    S glib-compile-schemas "$SCHEMA_DIR" 2>/dev/null || true
    S rm -f "$PY_TARGET$BK" "$SCHEMA$BK" /usr/lib/mate-menu/__pycache__/mate-menu.*.pyc 2>/dev/null || true
    revert_clock || true
    [[ "$RESTART" == 1 ]] && restart_panel
  fi
  if [[ "$RCREV" != "0" ]]; then
    echo "El icono no se pudo revertir por completo (vease AVISO arriba)." >&2
    exit "$RCREV"
  fi
  echo "Listo: archivos restaurados."
  exit 0
fi

echo "-- aplicando parche del icono (mate-menu)"
run_patcher apply || { echo "No se pudo parchear; nada que reiniciar." >&2; exit 4; }

python3 -c "import ast; ast.parse(open('$PY_TARGET').read())" \
  || { echo "ERROR: $PY_TARGET quedo con sintaxis invalida" >&2; exit 5; }

if [[ -n "$ROOT" ]]; then
  echo "(prueba con MATE_FIX_ROOT=$ROOT: no se tocan schemas, gsettings ni reloj)"
  exit 0
fi

S glib-compile-schemas "$SCHEMA_DIR"
S rm -f /usr/lib/mate-menu/__pycache__/mate-menu.*.pyc 2>/dev/null || true

ICON="${FORCE_ICON:-$(pick_icon)}"
gsettings set org.mate.mate-menu custom-icon "$ICON"
echo "  custom-icon  = $ICON"
echo "  tema iconos  = $(gsettings get org.mate.interface icon-theme | tr -d "'")"
if [[ -z "$FORCE_ICON" ]]; then
  install_full_icon
  install_debian_icon || true
fi

CLOCK_OK=1
if [[ "$RUN_CLOCK" == "1" ]]; then
  apply_clock || CLOCK_OK=0
  [[ "$CLOCK_OK" == 1 ]] || echo "  AVISO: el fix del reloj no se completo; revisa los mensajes de arriba."
fi

[[ "$RESTART" == 1 ]] && restart_panel

echo "-- verificacion"
python3 "$PATCHER" check "$ROOT"
echo "  custom-icon = $(gsettings get org.mate.mate-menu custom-icon)"
clock_status
echo
echo "Si el boton sigue sin verse o algo se ve mal:  bash set-mate-fix.sh --revert"