#!/bin/bash
# Setup idempotent layout switching for GNOME (X11 & Wayland)
# ZMK sends Hyper+1 (Ctrl+Shift+Alt+Super+1) → English
# ZMK sends Hyper+2 (Ctrl+Shift+Alt+Super+2) → Russian
#
# GNOME Shell exposes no supported way to select an input source from outside
# the Shell process:
#
#   * `gsettings set org.gnome.desktop.input-sources current N` does nothing --
#     Shell only *writes* that key to record its own state and never reacts to
#     external writes, so the call succeeds and changes no layout.
#   * `ibus engine xkb:...` moves the mutter keymap, but Shell keeps its own
#     idea of the current source, so the panel indicator and the per-app input
#     context go stale and get snapped back.
#
# So we ship a tiny Shell extension that exports one D-Bus method and lets
# Shell perform the switch itself.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$HOME/.local/bin"
UUID="zmk-input-source@ksander314"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"

mkdir -p "$SCRIPTS_DIR" "$EXT_DIR"
cp "$HERE/gnome-extension/metadata.json" "$HERE/gnome-extension/extension.js" "$EXT_DIR/"

# Enable it via gsettings rather than `gnome-extensions enable`: on Wayland a
# freshly installed extension is unknown to the running Shell, so the D-Bus
# call that command makes would fail. Writing the setting means it comes up
# enabled on the next login.
python3 - "$UUID" << 'PYEOF'
import ast, subprocess, sys

uuid = sys.argv[1]
SCHEMA = "org.gnome.shell"


def read(key):
    raw = subprocess.run(["gsettings", "get", SCHEMA, key],
                         capture_output=True, text=True, check=True).stdout.strip()
    if raw.startswith("@as "):
        raw = raw[len("@as "):].strip()
    return ast.literal_eval(raw)  # gsettings prints a python-shaped list


def write(key, value):
    subprocess.run(["gsettings", "set", SCHEMA, key, repr(value)], check=True)


enabled = read("enabled-extensions")
if uuid not in enabled:
    write("enabled-extensions", enabled + [uuid])

disabled = read("disabled-extensions")
if uuid in disabled:
    write("disabled-extensions", [e for e in disabled if e != uuid])
PYEOF

# Create the switching scripts. They resolve the input source by xkb-id at
# runtime, so reordering or adding sources in GNOME Settings doesn't silently
# switch you to the wrong layout.
gen_script() {
    cat << EOF
#!/bin/bash
candidates='$1'
EOF
    cat << 'EOF'
xkbid=$(gsettings get org.gnome.desktop.input-sources sources \
  | python3 -c 'import ast, sys; srcs = ast.literal_eval(sys.stdin.read().strip()); cands = set(sys.argv[1].split()); print(next(n for t, n in srcs if t == "xkb" and n.split("+")[0] in cands))' "$candidates") || {
    echo "no input source matching {$candidates} in GNOME input-sources" >&2
    exit 1
}

res=$(gdbus call --session --dest org.gnome.Shell \
    --object-path /org/gnome/Shell/Extensions/ZmkInputSource \
    --method org.gnome.Shell.Extensions.ZmkInputSource.Activate "$xkbid" 2>&1) || {
    echo "cannot reach the zmk-input-source extension: $res" >&2
    echo "run scripts/linux-setup.sh, then log out and back in" >&2
    exit 1
}

case "$res" in
    "(true,)"*) ;;
    *) echo "GNOME has no input source with xkb id '$xkbid'" >&2; exit 1 ;;
esac
EOF
}

gen_script 'us en' > "$SCRIPTS_DIR/kb-layout-en.sh"
gen_script 'ru'    > "$SCRIPTS_DIR/kb-layout-ru.sh"

chmod +x "$SCRIPTS_DIR/kb-layout-en.sh" "$SCRIPTS_DIR/kb-layout-ru.sh"

# Register custom keybindings in GNOME
SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
CUSTOM_SCHEMA="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"
KEY_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"

# Read the existing custom keybindings, drop our own slots if a previous run
# already added them, then re-append. Done in python rather than sed so that
# re-running stays idempotent: textual deletion leaves stray separators behind
# and produces a list gsettings refuses to parse.
NEW=$(gsettings get "$SCHEMA" custom-keybindings \
  | python3 -c 'import ast, sys
raw = sys.stdin.read().strip()
raw = raw[len("@as "):].strip() if raw.startswith("@as ") else raw
key_path = sys.argv[1]
ours = ["%s/zmk-en/" % key_path, "%s/zmk-ru/" % key_path]
print(repr([p for p in ast.literal_eval(raw) if p not in ours] + ours))' "$KEY_PATH")

gsettings set "$SCHEMA" custom-keybindings "$NEW"

# Set English keybinding: Hyper+1
gsettings set "${CUSTOM_SCHEMA}:${KEY_PATH}/zmk-en/" name "ZMK: Switch to English"
gsettings set "${CUSTOM_SCHEMA}:${KEY_PATH}/zmk-en/" command "$SCRIPTS_DIR/kb-layout-en.sh"
gsettings set "${CUSTOM_SCHEMA}:${KEY_PATH}/zmk-en/" binding "<Ctrl><Shift><Alt><Super>1"

# Set Russian keybinding: Hyper+2
gsettings set "${CUSTOM_SCHEMA}:${KEY_PATH}/zmk-ru/" name "ZMK: Switch to Russian"
gsettings set "${CUSTOM_SCHEMA}:${KEY_PATH}/zmk-ru/" command "$SCRIPTS_DIR/kb-layout-ru.sh"
gsettings set "${CUSTOM_SCHEMA}:${KEY_PATH}/zmk-ru/" binding "<Ctrl><Shift><Alt><Super>2"

echo "Done. Installed $UUID and registered Hyper+1 / Hyper+2."
echo
echo "Log out and back in to load the extension (Wayland cannot restart the"
echo "Shell in place), then check it came up:"
echo "  gnome-extensions info $UUID"
echo
echo "Matching input sources must be enabled (English: 'us' or 'en'; Russian: 'ru');"
echo "their order does not matter:"
echo "  gsettings get org.gnome.desktop.input-sources sources"
echo "  To enable: gsettings set org.gnome.desktop.input-sources sources \"[('xkb', 'us'), ('xkb', 'ru')]\""
