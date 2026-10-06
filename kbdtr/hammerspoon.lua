-- Cheat sheet for the eyelash_corne keymap: Cmd+Alt+A opens a search over every
-- character the keymap can type, for the current input source; Enter copies the
-- character. Rows come from out/index.json (`./kb index`), re-read on every open.
--
-- Loaded from ~/.hammerspoon/init.lua:
--   dofile(os.getenv("HOME") .. "/src/kbdtr/hammerspoon.lua")
-- Global so it can be opened from a shell: hs -c 'kbCheatSheet.show()'
kbCheatSheet = {
    path = os.getenv("HOME") .. "/src/kbdtr/out/index.json",
    chooser = hs.chooser.new(function(choice)
        if choice then hs.pasteboard.setContents(choice.char) end
    end),
}
kbCheatSheet.chooser:placeholderText("символ или его имя: &, brace, э")
kbCheatSheet.chooser:width(60)   -- % of the screen; narrower cuts the ways off

function kbCheatSheet.show()
    local f = io.open(kbCheatSheet.path)
    if not f then
        hs.alert.show("Нет " .. kbCheatSheet.path .. " — запусти ~/src/kbdtr/kb index")
        return 0
    end
    local index = hs.json.decode(f:read("a"))
    f:close()
    local source = hs.keycodes.currentSourceID():gsub("^com%.apple%.keylayout%.", "")
    local rows = index[source] or index.ABC
    kbCheatSheet.chooser:choices(rows)
    kbCheatSheet.chooser:show()
    return #rows
end

-- 0 is the A key (kVK_ANSI_A); a raw keycode does not depend on the input source.
hs.hotkey.bind({"cmd", "alt"}, 0, kbCheatSheet.show)
