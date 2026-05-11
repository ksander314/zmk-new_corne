#!/bin/bash
# Setup idempotent layout switching for GNOME (X11 & Wayland)
# ZMK sends Hyper+1 (Ctrl+Shift+Alt+Super+1) → English
# ZMK sends Hyper+2 (Ctrl+Shift+Alt+Super+2) → Russian
set -euo pipefail

SCRIPTS_DIR="$HOME/.local/bin"
mkdir -p "$SCRIPTS_DIR"

# Create switching scripts. Look up the input-source index by xkb-id at
# runtime, so reordering or adding sources in GNOME Settings doesn't
# silently switch you to the wrong layout.
cat > "$SCRIPTS_DIR/kb-layout-en.sh" << 'EOF'
#!/bin/bash
candidates='us en'
idx=$(gsettings get org.gnome.desktop.input-sources sources \
  | python3 -c 'import ast, sys; srcs = ast.literal_eval(sys.stdin.read().strip()); cands = set(sys.argv[1].split()); print(next(i for i, (_, n) in enumerate(srcs) if n in cands))' "$candidates") || {
    echo "no input source matching {$candidates} in GNOME input-sources" >&2
    exit 1
}
gsettings set org.gnome.desktop.input-sources current "$idx"
EOF

cat > "$SCRIPTS_DIR/kb-layout-ru.sh" << 'EOF'
#!/bin/bash
candidates='ru'
idx=$(gsettings get org.gnome.desktop.input-sources sources \
  | python3 -c 'import ast, sys; srcs = ast.literal_eval(sys.stdin.read().strip()); cands = set(sys.argv[1].split()); print(next(i for i, (_, n) in enumerate(srcs) if n in cands))' "$candidates") || {
    echo "no input source matching {$candidates} in GNOME input-sources" >&2
    exit 1
}
gsettings set org.gnome.desktop.input-sources current "$idx"
EOF

chmod +x "$SCRIPTS_DIR/kb-layout-en.sh" "$SCRIPTS_DIR/kb-layout-ru.sh"

# Register custom keybindings in GNOME
SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
CUSTOM_SCHEMA="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"
KEY_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"

# Read existing custom keybindings and append ours
EXISTING=$(gsettings get "$SCHEMA" custom-keybindings)
if [ "$EXISTING" = "@as []" ]; then
    EXISTING="[]"
fi

# Remove our slots if they already exist, then re-add
CLEAN=$(echo "$EXISTING" | sed "s|'${KEY_PATH}/zmk-en/'||g; s|'${KEY_PATH}/zmk-ru/'||g; s|, ,|,|g; s|\[,|[|g; s|,]|]|g")

# Build new list
if [ "$CLEAN" = "[]" ]; then
    NEW="['${KEY_PATH}/zmk-en/', '${KEY_PATH}/zmk-ru/']"
else
    # Strip trailing ] and append
    INNER=$(echo "$CLEAN" | sed 's/\]$//')
    NEW="${INNER}, '${KEY_PATH}/zmk-en/', '${KEY_PATH}/zmk-ru/']"
fi

gsettings set "$SCHEMA" custom-keybindings "$NEW"

# Set English keybinding: Hyper+1
gsettings set "${CUSTOM_SCHEMA}:${KEY_PATH}/zmk-en/" name "ZMK: Switch to English"
gsettings set "${CUSTOM_SCHEMA}:${KEY_PATH}/zmk-en/" command "$SCRIPTS_DIR/kb-layout-en.sh"
gsettings set "${CUSTOM_SCHEMA}:${KEY_PATH}/zmk-en/" binding "<Ctrl><Shift><Alt><Super>1"

# Set Russian keybinding: Hyper+2
gsettings set "${CUSTOM_SCHEMA}:${KEY_PATH}/zmk-ru/" name "ZMK: Switch to Russian"
gsettings set "${CUSTOM_SCHEMA}:${KEY_PATH}/zmk-ru/" command "$SCRIPTS_DIR/kb-layout-ru.sh"
gsettings set "${CUSTOM_SCHEMA}:${KEY_PATH}/zmk-ru/" binding "<Ctrl><Shift><Alt><Super>2"

echo "Done. Layout switching looks up xkb-ids by name (English: 'us' or 'en'; Russian: 'ru')."
echo "Order in input-sources no longer matters, but matching sources must be enabled:"
echo "  gsettings get org.gnome.desktop.input-sources sources"
echo "  To enable: gsettings set org.gnome.desktop.input-sources sources \"[('xkb', 'us'), ('xkb', 'ru')]\""
