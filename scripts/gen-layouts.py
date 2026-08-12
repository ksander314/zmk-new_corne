#!/usr/bin/env python3
"""Generate host layouts that put Cyrillic on the DVP key positions.

Background
----------
HID carries scancodes, not characters -- there is no usage code for a Cyrillic
letter, so one of the two alphabets always has to come from the host. What does
NOT have to come from the host is the *arrangement*. Today it does: switching to
Russian means falling back to the stock ``ru`` layout, which is laid out for
QWERTY positions, so the firmware has to hop to its QWERTY layer to match, and
both sides then have to be kept in sync by host-side code.

These layouts remove that. They are the stock Russian layout permuted so that
every Cyrillic letter lands on the same *physical* key it occupies today, while
the firmware stays on its DVP layer permanently. The firmware then holds no
language state at all and needs no macros; the host only supplies the alphabet.

How the permutation is derived
------------------------------
For a physical key P, today's Russian output is ``ru[qwerty(P)]``, where
``qwerty(P)`` is the scancode the QWERTY layer sends from that position.
With the firmware pinned to DVP the host instead receives ``dvp(P)``, so the
new layout must satisfy::

    layout[dvp(P)] = ru[qwerty(P)]

Both ``qwerty`` and ``dvp`` are read straight out of the keymap, so retuning the
DVP layer and re-running this script keeps the two in step. The mapping is
asserted to be a bijection over the 31 alphanumeric positions: if the keymap
grows or shrinks a row, generation fails loudly instead of emitting a layout
that silently drops a letter.

Usage
-----
    python3 scripts/gen-layouts.py         # writes layouts/
"""

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
KEYMAP = REPO / "config" / "eyelash_corne.keymap"
OUT = REPO / "layouts"

# Indices into a layer's `bindings` array that hold the alphanumeric block.
# The array is row-major and includes the joystick/encoder cluster in the middle
# of each row, hence the gaps. Verified against the combo definitions in the
# keymap, which reference the same numbering (e.g. `key-positions = <25 26>` is
# documented there as "N + S on DVP home row").
#
#   row 1: 0 = Tab,       6 = joystick up,     12 = outer right
#   row 2: 13 = L shift, 19..21 = joystick,    27 = R shift
#   row 3: 28 = L ctrl,  34..35 = encoder/joy, 41 = R ctrl
ALPHA_IDX = (
    [1, 2, 3, 4, 5] + [7, 8, 9, 10, 11, 12]
    + [14, 15, 16, 17, 18] + [22, 23, 24, 25, 26]
    + [29, 30, 31, 32, 33] + [36, 37, 38, 39, 40]
)

# ZMK keycode -> xkb key name. Only the alphanumeric block is needed; anything
# else in those positions is a bug in ALPHA_IDX and will raise.
ZMK_TO_XKB = {
    "Q": "AD01", "W": "AD02", "E": "AD03", "R": "AD04", "T": "AD05",
    "Y": "AD06", "U": "AD07", "I": "AD08", "O": "AD09", "P": "AD10",
    "A": "AC01", "S": "AC02", "D": "AC03", "F": "AC04", "G": "AC05",
    "H": "AC06", "J": "AC07", "K": "AC08", "L": "AC09",
    "SEMI": "AC10", "SEMICOLON": "AC10",
    "SQT": "AC11", "APOS": "AC11", "APOSTROPHE": "AC11", "SINGLE_QUOTE": "AC11",
    "Z": "AB01", "X": "AB02", "C": "AB03", "V": "AB04", "B": "AB05",
    "N": "AB06", "M": "AB07",
    "COMMA": "AB08", "DOT": "AB09", "PERIOD": "AB09",
    "FSLH": "AB10", "SLASH": "AB10",
}

# The 31 alphanumeric keys of stock `ru` (the default variant is "winkeys" --
# checked against /usr/share/X11/xkb/symbols/ru). Everything this table does not
# mention -- the digit row, <TLDE> (ё), <AD11> (х), <AD12> (ъ), <BKSL> -- is
# inherited unchanged, which is what keeps х/ъ/ё reachable from the symbol layer
# exactly as they are today.
RU = {
    "AD01": ("й", "Й"), "AD02": ("ц", "Ц"), "AD03": ("у", "У"),
    "AD04": ("к", "К"), "AD05": ("е", "Е"), "AD06": ("н", "Н"),
    "AD07": ("г", "Г"), "AD08": ("ш", "Ш"), "AD09": ("щ", "Щ"),
    "AD10": ("з", "З"),
    "AC01": ("ф", "Ф"), "AC02": ("ы", "Ы"), "AC03": ("в", "В"),
    "AC04": ("а", "А"), "AC05": ("п", "П"), "AC06": ("р", "Р"),
    "AC07": ("о", "О"), "AC08": ("л", "Л"), "AC09": ("д", "Д"),
    "AC10": ("ж", "Ж"), "AC11": ("э", "Э"),
    "AB01": ("я", "Я"), "AB02": ("ч", "Ч"), "AB03": ("с", "С"),
    "AB04": ("м", "М"), "AB05": ("и", "И"), "AB06": ("т", "Т"),
    "AB07": ("ь", "Ь"), "AB08": ("б", "Б"), "AB09": ("ю", "Ю"),
    "AB10": (".", ","),
}

CYRILLIC_KEYSYM = {
    "а": "a", "б": "be", "в": "ve", "г": "ghe", "д": "de", "е": "ie",
    "ё": "io", "ж": "zhe", "з": "ze", "и": "i", "й": "shorti", "к": "ka",
    "л": "el", "м": "em", "н": "en", "о": "o", "п": "pe", "р": "er",
    "с": "es", "т": "te", "у": "u", "ф": "ef", "х": "ha", "ц": "tse",
    "ч": "che", "ш": "sha", "щ": "shcha", "ъ": "hardsign", "ы": "yeru",
    "ь": "softsign", "э": "e", "ю": "yu", "я": "ya",
}

ASCII_KEYSYM = {".": "period", ",": "comma"}

# xkb key name -> macOS virtual keycode (ANSI).
XKB_TO_MAC = {
    "AD01": 12, "AD02": 13, "AD03": 14, "AD04": 15, "AD05": 17,
    "AD06": 16, "AD07": 32, "AD08": 34, "AD09": 31, "AD10": 35,
    "AD11": 33, "AD12": 30,
    "AC01": 0, "AC02": 1, "AC03": 2, "AC04": 3, "AC05": 5,
    "AC06": 4, "AC07": 38, "AC08": 40, "AC09": 37, "AC10": 41, "AC11": 39,
    "AB01": 6, "AB02": 7, "AB03": 8, "AB04": 9, "AB05": 11,
    "AB06": 45, "AB07": 46, "AB08": 43, "AB09": 47, "AB10": 44,
    "AE01": 18, "AE02": 19, "AE03": 20, "AE04": 21, "AE05": 23,
    "AE06": 22, "AE07": 26, "AE08": 28, "AE09": 25, "AE10": 29,
    "AE11": 27, "AE12": 24,
    "TLDE": 50, "BKSL": 42,
}

# Keys `ru(winkeys)` defines that this layout leaves alone. macOS has no include
# mechanism, so unlike the xkb file the .keylayout has to spell them out.
RU_FIXED = {
    "TLDE": ("ё", "Ё"), "AD11": ("х", "Х"), "AD12": ("ъ", "Ъ"),
    "BKSL": ("\\", "/"),
    "AE01": ("1", "!"), "AE02": ("2", '"'), "AE03": ("3", "№"),
    "AE04": ("4", ";"), "AE05": ("5", "%"), "AE06": ("6", ":"),
    "AE07": ("7", "?"), "AE08": ("8", "*"), "AE09": ("9", "("),
    "AE10": ("0", ")"), "AE11": ("-", "_"), "AE12": ("=", "+"),
}

# US mapping per macOS keycode, used for the ⌘/⌃ maps so that shortcuts stay on
# the same physical keys in both languages. The firmware has already applied the
# DVP permutation, so what belongs here is plain US -- identical to what the
# English input source sees.
US_BY_MAC = {
    0: ("a", "A"), 1: ("s", "S"), 2: ("d", "D"), 3: ("f", "F"),
    4: ("h", "H"), 5: ("g", "G"), 6: ("z", "Z"), 7: ("x", "X"),
    8: ("c", "C"), 9: ("v", "V"), 11: ("b", "B"), 12: ("q", "Q"),
    13: ("w", "W"), 14: ("e", "E"), 15: ("r", "R"), 16: ("y", "Y"),
    17: ("t", "T"), 18: ("1", "!"), 19: ("2", "@"), 20: ("3", "#"),
    21: ("4", "$"), 22: ("6", "^"), 23: ("5", "%"), 24: ("=", "+"),
    25: ("9", "("), 26: ("7", "&"), 27: ("-", "_"), 28: ("8", "*"),
    29: ("0", ")"), 30: ("]", "}"), 31: ("o", "O"), 32: ("u", "U"),
    33: ("[", "{"), 34: ("i", "I"), 35: ("p", "P"), 37: ("l", "L"),
    38: ("j", "J"), 39: ("'", '"'), 40: ("k", "K"), 41: (";", ":"),
    42: ("\\", "|"), 43: (",", "<"), 44: ("/", "?"), 45: ("n", "N"),
    46: ("m", "M"), 47: (".", ">"), 50: ("`", "~"),
}

# Non-printing keys, identical in every map. macOS layouts spell these out with
# the conventional control codes rather than leaving them undefined.
MAC_SPECIAL = {
    36: "\r", 48: "\t", 49: " ", 51: "\x08", 53: "\x1b",
    65: ".", 67: "*", 69: "+", 71: "\x1b", 75: "/", 76: "\x03",
    78: "-", 81: "=", 82: "0", 83: "1", 84: "2", 85: "3", 86: "4",
    87: "5", 88: "6", 89: "7", 91: "8", 92: "9",
    114: "\x05", 115: "\x01", 116: "\x0b", 117: "\x7f",
    119: "\x04", 121: "\x0c",
    123: "\x1c", 124: "\x1d", 125: "\x1f", 126: "\x1e",
}
# Function keys.
MAC_SPECIAL.update({code: "\x10" for code in
                    (96, 97, 98, 99, 100, 101, 103, 105, 106, 107,
                     109, 110, 111, 113, 118, 120, 122)})


def parse_layer(text, layer):
    """Return the `bindings` of a keymap layer as a list of behaviour tokens."""
    match = re.search(
        r"\b%s\s*\{.*?\bbindings\s*=\s*<(.*?)>\s*;" % re.escape(layer),
        text, re.S)
    if not match:
        sys.exit("cannot find layer %s in %s" % (layer, KEYMAP))
    body = re.sub(r"//[^\n]*", "", match.group(1))
    return [tok.strip() for tok in body.split("&") if tok.strip()]


def xkb_key(tokens, idx, layer):
    """xkb name of the plain `&kp` at binding index idx, or exit with why not."""
    token = tokens[idx]
    if not token.startswith("kp "):
        sys.exit("%s binding %d is %r, not a plain &kp -- ALPHA_IDX is stale"
                 % (layer, idx, "&" + token))
    code = token[3:].strip()
    if code not in ZMK_TO_XKB:
        sys.exit("%s binding %d sends %s, which is not an alphanumeric key"
                 % (layer, idx, code))
    return ZMK_TO_XKB[code]


def build_permutation():
    """Map each xkb key the DVP layer sends to the symbols it must produce."""
    text = KEYMAP.read_text(encoding="utf-8")
    qwerty = parse_layer(text, "layer_0")
    dvp = parse_layer(text, "layer_1")

    mapping = {}
    for idx in ALPHA_IDX:
        source = xkb_key(qwerty, idx, "layer_0")
        target = xkb_key(dvp, idx, "layer_1")
        if target in mapping:
            sys.exit("two positions both send <%s> on the DVP layer" % target)
        mapping[target] = RU[source]

    if set(mapping) != set(RU):
        missing = sorted(set(RU) - set(mapping))
        extra = sorted(set(mapping) - set(RU))
        sys.exit("permutation is not a bijection over the alphanumeric block; "
                 "unreachable: %s, unexpected: %s" % (missing, extra))
    return mapping


def keysym(char):
    if char.lower() in CYRILLIC_KEYSYM:
        suffix = CYRILLIC_KEYSYM[char.lower()]
        return "Cyrillic_" + (suffix if char.islower() else suffix.upper())
    if char in ASCII_KEYSYM:
        return ASCII_KEYSYM[char]
    sys.exit("no keysym known for %r" % char)


def emit_xkb(mapping):
    lines = [
        "// Russian on Dvorak-Programmer key positions.",
        "//",
        "// Generated by scripts/gen-layouts.py from config/eyelash_corne.keymap.",
        "// Do not edit by hand -- re-run the generator after changing layer 1.",
        "//",
        "// Pair this with the firmware pinned to its DVP layer: every Cyrillic",
        "// letter then sits on the same physical key as stock `ru` does with the",
        "// firmware on QWERTY, so the keyboard never has to change layers to",
        "// change language.",
        "//",
        "// The file is named `rudvp` rather than `ru` on purpose. xkb resolves",
        "// includes against the user directory first, so a user file called `ru`",
        "// would make `include \"ru(winkeys)\"` below recurse into itself.",
        "",
        "default partial alphanumeric_keys",
        'xkb_symbols "dvp" {',
        "",
        '    include "ru(winkeys)"',
        '    name[Group1] = "Russian (Dvorak Programmer)";',
        "",
    ]
    for key in sorted(mapping):
        lower, upper = mapping[key]
        lines.append("    key <%s> {[ %18s, %18s ]}; // %s %s"
                     % (key, keysym(lower), keysym(upper), lower, upper))
    lines += ["};", ""]
    return "\n".join(lines)


def xml_escape(char):
    # Character references below U+0020 are not legal XML 1.0, but .keylayout
    # is not quite XML: Apple's own bundled layouts and Ukelele both encode
    # Return, Tab and the arrow keys this way, and that is what macOS parses.
    # A strict parser will reject the result; macOS will not.
    if char in "<>&\"'" or ord(char) < 0x20 or ord(char) == 0x7F:
        return "&#x%04X;" % ord(char)
    return char


def mac_maps(mapping):
    """Six keyMaps: base, shift, caps, shift+caps, latin, latin+shift."""
    printable = {}
    for key, pair in list(mapping.items()) + list(RU_FIXED.items()):
        printable[XKB_TO_MAC[key]] = pair
    letters = {code for code, (lo, hi) in printable.items() if lo.isalpha()}

    maps = []
    for shift, caps in ((False, False), (True, False),
                        (False, True), (True, True)):
        out = {}
        for code, (lo, hi) in printable.items():
            upper = (shift != caps) if code in letters else shift
            out[code] = hi if upper else lo
        maps.append(out)
    for shift in (False, True):
        maps.append({code: pair[1] if shift else pair[0]
                     for code, pair in US_BY_MAC.items()})

    for out in maps:
        out.update(MAC_SPECIAL)
    return maps


def mac_selectors():
    """Assign every modifier combination to one of the six keyMaps."""
    groups = {index: [] for index in range(6)}
    for bits in range(32):
        shift, caps, option, control, command = (bool(bits & (1 << n))
                                                 for n in range(5))
        if command or control:
            index = 5 if shift else 4
        else:
            index = (1 if shift else 0) + (2 if caps else 0)
        keys = []
        if shift:
            keys.append("anyShift")
        if caps:
            keys.append("caps")
        if option:
            keys.append("anyOption")
        if control:
            keys.append("anyControl")
        if command:
            keys.append("command")
        groups[index].append(" ".join(keys))
    return groups


def emit_keylayout(mapping, name):
    maps = mac_maps(mapping)
    groups = mac_selectors()

    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<!DOCTYPE keyboard SYSTEM '
        '"file://localhost/System/Library/DTDs/KeyboardLayout.dtd">',
        # XML comments may not contain a double hyphen, so the prose here reads
        # a little differently from its counterpart in the xkb file.
        "<!--",
        "    Russian on Dvorak-Programmer key positions.",
        "",
        "    Generated by scripts/gen-layouts.py from config/eyelash_corne.keymap.",
        "    Do not edit by hand; re-run the generator after changing layer 1.",
        "",
        "    The ⌘ and ⌃ maps deliberately emit plain US characters: the firmware",
        "    has already applied the DVP permutation, so this puts every shortcut",
        "    on the same physical key it has in the English input source.",
        "-->",
        '<keyboard group="126" id="-2718" name="%s" maxout="1">' % name,
        "    <layouts>",
        '        <layout first="0" last="17" modifiers="commonModifiers" '
        'mapSet="ansi"/>',
        "    </layouts>",
        '    <modifierMap id="commonModifiers" defaultIndex="0">',
    ]
    for index in range(6):
        lines.append('        <keyMapSelect mapIndex="%d">' % index)
        for keys in groups[index]:
            lines.append('            <modifier keys="%s"/>' % keys)
        lines.append("        </keyMapSelect>")
    lines += ["    </modifierMap>", '    <keyMapSet id="ansi">']
    for index, table in enumerate(maps):
        lines.append('        <keyMap index="%d">' % index)
        for code in sorted(table):
            lines.append('            <key code="%d" output="%s"/>'
                         % (code, xml_escape(table[code])))
        lines.append("        </keyMap>")
    lines += ["    </keyMapSet>", "</keyboard>", ""]
    return "\n".join(lines)


def main():
    mapping = build_permutation()
    OUT.mkdir(exist_ok=True)

    (OUT / "rudvp").write_text(emit_xkb(mapping), encoding="utf-8")
    (OUT / "Russian DVP.keylayout").write_text(
        emit_keylayout(mapping, "Russian DVP"), encoding="utf-8")

    print("wrote %d permuted keys to:" % len(mapping))
    print("  layouts/rudvp")
    print("  layouts/Russian DVP.keylayout")


if __name__ == "__main__":
    main()
