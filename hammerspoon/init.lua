-- Idempotent input source switching for ZMK split keyboard
-- Hyper+1 → ABC (used with DVP layer)
-- Hyper+2 → Russian (used with QWERTY layer)

require("hs.ipc")

local log = io.open("/tmp/hammerspoon.log", "a")
local function logMsg(msg)
    log:write(os.date("%H:%M:%S") .. " " .. msg .. "\n")
    log:flush()
end

logMsg("=== Hammerspoon config loaded ===")

local hyper = {"cmd", "alt", "ctrl", "shift"}

hs.hotkey.bind(hyper, "1", function()
    logMsg("Hyper+1 triggered → switching to ABC")
    hs.keycodes.setLayout("ABC")
end)

hs.hotkey.bind(hyper, "2", function()
    logMsg("Hyper+2 triggered → switching to Russian – PC")
    hs.keycodes.setLayout("Russian – PC")
end)

-- Push every input source switch to the Emacs keystroke log
-- (~/.emacs.d/lisp/init-keystroke-log.el, my/klog-set-layout).
-- Value matches what the log used before: "ABC", "RussianWin".
local function pushLayoutToEmacs()
    local id = hs.keycodes.currentSourceID():gsub("^com%.apple%.keylayout%.", "")
    hs.task.new("/opt/homebrew/bin/emacsclient", nil,
        {"-e", string.format('(when (fboundp \'my/klog-set-layout) (my/klog-set-layout "%s"))', id)}):start()
end
hs.keycodes.inputSourceChanged(pushLayoutToEmacs)
pushLayoutToEmacs()

-- Windows between Desktops (Spaces) and monitors: ctrl-alt-shift + arrows.
-- On eyelash_corne: Spc + Alt under the left thumb, Shift, then the 5-way.

-- macOS has had no API to move a window to another Space since 15
-- (hs.spaces.moveWindowToSpace is a no-op, Hammerspoon issue #3698),
-- so do what a hand does: hold the title bar and press ctrl-arrow.
-- The arrow must carry fn: a real arrow key does, and the Mission Control
-- shortcuts "Move left/right a space" are stored with it.
local ev = hs.eventtap.event

-- A press on a control or on content would click it instead of dragging the window.
local notTitleBar = {
    AXButton = true, AXRadioButton = true, AXTab = true, AXCheckBox = true,
    AXPopUpButton = true, AXMenuButton = true, AXComboBox = true, AXLink = true,
    AXTextField = true, AXTextArea = true, AXScrollArea = true, AXWebArea = true,
}

local function titleBarPoint(win)
    local f = win:frame()
    for _, fx in ipairs({0.5, 0.35, 0.65, 0.8, 0.2}) do
        local p = hs.geometry.point(f.x + f.w * fx, f.y + 5)
        local el = hs.axuielement.systemElementAtPosition(p)
        local role = el and el:attributeValue("AXRole")
        if role and not notTitleBar[role] then return p end
    end
end

local function modifiersUp()
    local m = hs.eventtap.checkKeyboardModifiers()
    return not (m.ctrl or m.alt or m.shift or m.cmd)
end

local pendingCarry -- waits for the keys to be released; a new press replaces it

local function carryWindowToSpace(dir)
    local win = hs.window.focusedWindow()
    if not win then return end
    logMsg("carry " .. dir .. ": " .. win:application():name())
    if pendingCarry then pendingCarry:stop() end
    -- Start once the hotkey's modifiers are up: a held ctrl turns the press into a right click.
    local started = hs.timer.secondsSinceEpoch()
    local hinted = false
    pendingCarry = hs.timer.waitUntil(function()
        if modifiersUp() then return true end
        local waited = hs.timer.secondsSinceEpoch() - started
        if waited > 0.5 and not hinted then
            hinted = true
            hs.alert.show("Release the keys to carry the window")
        end
        return waited > 5
    end, function()
        pendingCarry = nil
        if not modifiersUp() then
            logMsg("carry " .. dir .. ": keys still held after 5 s")
            return
        end
        local grab = titleBarPoint(win)
        if not grab then
            logMsg("carry " .. dir .. ": no title bar to hold")
            return
        end
        local held = hs.geometry.point(grab.x + 6, grab.y)
        local back = hs.mouse.absolutePosition()
        hs.mouse.absolutePosition(grab)
        ev.newMouseEvent(ev.types.leftMouseDown, grab):post()
        hs.timer.doAfter(0.08, function()
            ev.newMouseEvent(ev.types.leftMouseDragged, held):post()
            hs.timer.doAfter(0.08, function()
                hs.eventtap.keyStroke({"ctrl", "fn"}, dir, 20000)
                hs.timer.doAfter(0.7, function()
                    ev.newMouseEvent(ev.types.leftMouseUp, held):post()
                    hs.mouse.absolutePosition(back)
                end)
            end)
        end)
    end, 0.02)
end

local windowMods = {"ctrl", "alt", "shift"}
hs.hotkey.bind(windowMods, "left", function() carryWindowToSpace("left") end)
hs.hotkey.bind(windowMods, "right", function() carryWindowToSpace("right") end)

-- The HP monitor stands above the laptop.
hs.hotkey.bind(windowMods, "up", function()
    local win = hs.window.focusedWindow()
    if win then win:moveOneScreenNorth(false, true) end
end)
hs.hotkey.bind(windowMods, "down", function()
    local win = hs.window.focusedWindow()
    if win then win:moveOneScreenSouth(false, true) end
end)
