#!/bin/bash
# Setup layout switching for GNOME (Wayland & X11).
# ZMK sends Hyper+1 (Ctrl+Shift+Alt+Super+1) and Hyper+2 (...+2) when switching
# layers (to_dvp / to_qwerty).
#
# NOTE: On GNOME (esp. Wayland + IBus) external writes to the active layout do
# NOT work — `gsettings set org.gnome.desktop.input-sources current N` and
# `ibus engine <name>` are silently ignored for actual input, and GNOME Shell
# exposes no D-Bus method to select a source (Eval is disabled). The only thing
# that changes what you type is GNOME Shell's own `switch-input-source` action.
# So we bind the ZMK chords directly to that native action.
#
# CAVEAT: the native action is a TOGGLE (cycle), not idempotent. With exactly
# two sources it works as long as the keyboard drives the switches; if they ever
# desync (e.g. after login, or after switching with Super+Space / the indicator),
# one extra switch re-syncs. For fully idempotent switching you need a small
# GNOME Shell extension exposing a "select source N" D-Bus method.
set -euo pipefail

EN='<Ctrl><Shift><Alt><Super>1'   # to_dvp     -> English
RU='<Ctrl><Shift><Alt><Super>2'   # to_qwerty  -> Russian

python3 - "$EN" "$RU" <<'PY'
import sys
from gi.repository import Gio

EN, RU = sys.argv[1], sys.argv[2]

# 1) Remove any old broken script-based custom keybindings from earlier versions
mk = Gio.Settings.new('org.gnome.settings-daemon.plugins.media-keys')
base = '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings'
mk.set_strv('custom-keybindings',
            [p for p in mk.get_strv('custom-keybindings')
             if not p.rstrip('/').endswith(('zmk-en', 'zmk-ru'))])

# 2) Bind the Hyper chords to GNOME Shell's native input-source switch
wm = Gio.Settings.new('org.gnome.desktop.wm.keybindings')
for key, chord in (('switch-input-source', EN), ('switch-input-source-backward', RU)):
    vals = [b for b in wm.get_strv(key) if b not in (EN, RU)]
    wm.set_strv(key, vals + [chord])

Gio.Settings.sync()
print('switch-input-source     :', wm.get_strv('switch-input-source'))
print('switch-input-source-back:', wm.get_strv('switch-input-source-backward'))
PY

echo
echo "Done. Ensure exactly the two layouts are enabled (order doesn't matter):"
echo "  gsettings get org.gnome.desktop.input-sources sources"
echo "  gsettings set org.gnome.desktop.input-sources sources \"[('xkb', 'us'), ('xkb', 'ru')]\""
