#!/bin/bash
# Setup idempotent layout switching for GNOME (X11 & Wayland)
# ZMK sends Hyper+1 (Ctrl+Shift+Alt+Super+1) → English
# ZMK sends Hyper+2 (Ctrl+Shift+Alt+Super+2) → Russian
set -euo pipefail

SCRIPTS_DIR="$HOME/.local/bin"
mkdir -p "$SCRIPTS_DIR"

# Create switching scripts
cat > "$SCRIPTS_DIR/kb-layout-en.sh" << 'EOF'
#!/bin/bash
gsettings set org.gnome.desktop.input-sources current 0
EOF

cat > "$SCRIPTS_DIR/kb-layout-ru.sh" << 'EOF'
#!/bin/bash
gsettings set org.gnome.desktop.input-sources current 1
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

echo "Done. Make sure GNOME input sources are configured:"
echo "  gsettings get org.gnome.desktop.input-sources sources"
echo "  Expected: [('xkb', 'us'), ('xkb', 'ru')]"
echo "  To set:   gsettings set org.gnome.desktop.input-sources sources \"[('xkb', 'us'), ('xkb', 'ru')]\""
