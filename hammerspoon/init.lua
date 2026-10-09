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
    -- Right of the window buttons first: there both Emacs and Chrome drag the window.
    for _, x in ipairs({f.x + 120, f.x + f.w * 0.5, f.x + f.w * 0.35, f.x + f.w * 0.65, f.x + f.w * 0.8}) do
        local p = hs.geometry.point(x, f.y + 12)
        local el = hs.axuielement.systemElementAtPosition(p)
        local role = el and el:attributeValue("AXRole")
        if role and not notTitleBar[role] then return p end
    end
end

-- Emacs moves only under a drag that looks like a real one: the same event number
-- on press, moves and release, pressure, and the delta of every move.
local mouseEventNumber = 1000
local function mouseEvent(kind, p, dx)
    local e = ev.newMouseEvent(kind, p)
    e:setProperty(ev.properties.mouseEventClickState, 1)
    e:setProperty(ev.properties.mouseEventNumber, mouseEventNumber)
    e:setProperty(ev.properties.mouseEventPressure, kind == ev.types.leftMouseUp and 0 or 1)
    if dx then
        e:setProperty(ev.properties.mouseEventDeltaX, dx)
        e:setProperty(ev.properties.mouseEventDeltaY, 0)
    end
    return e
end

local carryTimer -- the step of a carry in flight, kept here so the GC does not stop it

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
        local frame = win:frame()
        local back = hs.mouse.absolutePosition()
        mouseEventNumber = mouseEventNumber + 1
        hs.mouse.absolutePosition(grab)
        mouseEvent(ev.types.leftMouseDown, grab):post()
        -- Drag 30 px in steps, switch the Desktop, let go, put the window back where it was.
        local step = 0
        carryTimer = hs.timer.doEvery(0.03, function()
            step = step + 1
            mouseEvent(ev.types.leftMouseDragged, hs.geometry.point(grab.x + 5 * step, grab.y), 5):post()
            if step < 6 then return end
            carryTimer:stop()
            carryTimer = hs.timer.doAfter(0.15, function()
                hs.eventtap.keyStroke({"ctrl", "fn"}, dir, 20000)
                carryTimer = hs.timer.doAfter(0.7, function()
                    mouseEvent(ev.types.leftMouseUp, hs.geometry.point(grab.x + 30, grab.y)):post()
                    hs.mouse.absolutePosition(back)
                    win:setFrame(frame)
                    carryTimer = nil
                end)
            end)
        end)
    end, 0.02)
end

local windowMods = {"ctrl", "alt", "shift"}
hs.hotkey.bind(windowMods, "left", function() carryWindowToSpace("left") end)
hs.hotkey.bind(windowMods, "right", function() carryWindowToSpace("right") end)
-- The keyboard sends F18 / F19 for the same (SPEC + 5-way ← / →): no modifiers
-- to wait for, so the window goes at once. F14 / F15 are screen brightness on macOS.
hs.hotkey.bind({}, "f18", function() carryWindowToSpace("left") end)
hs.hotkey.bind({}, "f19", function() carryWindowToSpace("right") end)

-- The HP monitor stands above the laptop.
local function moveWindowUp()
    local win = hs.window.focusedWindow()
    if win then win:moveOneScreenNorth(false, true) end
end
local function moveWindowDown()
    local win = hs.window.focusedWindow()
    if win then win:moveOneScreenSouth(false, true) end
end
hs.hotkey.bind(windowMods, "up", moveWindowUp)
hs.hotkey.bind(windowMods, "down", moveWindowDown)
-- And F16 / F17 from the keyboard (SPEC + 5-way ↑ / ↓).
hs.hotkey.bind({}, "f16", moveWindowUp)
hs.hotkey.bind({}, "f17", moveWindowDown)

-- Focus: the same keys without Shift.

local function currentScreen()
    local win = hs.window.focusedWindow()
    return win and win:screen() or hs.mouse.getCurrentScreen()
end

-- Hammerspoon's window lists miss Emacs (its app shows up there with pid -1),
-- but the focused window is always known: remember every window that had the focus,
-- and the last one of every monitor.
local lastFocused = {} -- screen id -> hs.window
local seen = {}        -- window id -> hs.window

-- The Desktops a window lies on; none once it is closed.
local function spacesOf(w)
    local ok, spaces = pcall(hs.spaces.windowSpaces, w)
    return ok and spaces or {}
end

-- The window still exists and lies on the Desktop now shown on its monitor.
local function onShownDesktop(w)
    local ok, shown = pcall(function()
        local active = hs.spaces.activeSpaceOnScreen(w:screen())
        for _, space in ipairs(hs.spaces.windowSpaces(w) or {}) do
            if space == active then return true end
        end
        return false
    end)
    return ok and shown
end

-- Global, or the garbage collector stops the timer.
focusTracker = hs.timer.doEvery(0.5, function()
    local w = hs.window.focusedWindow()
    if w and w:isStandard() then
        lastFocused[w:screen():id()] = w
        seen[w:id()] = w
    end
end)

-- focus() from a hotkey sometimes leaves the old app in front (seen leaving Claude),
-- so check it took, and if not, activate the app the way the Dock does.
local function focusWindow(w)
    w:focus()
    hs.timer.doAfter(0.15, function()
        local now = hs.window.focusedWindow()
        if now and now:id() == w:id() then return end
        hs.application.launchOrFocusByBundleID(w:application():bundleID())
        w:focus()
        hs.timer.doAfter(0.15, function()
            local after = hs.window.focusedWindow()
            logMsg("focus retry " .. w:application():name() .. ": "
                .. ((after and after:id() == w:id()) and "ok" or "still " .. (after and after:application():name() or "nothing")))
        end)
    end)
end

-- Windows of a screen in a fixed order (left to right, top to bottom, then by id),
-- so the cycle does not depend on which window was focused last.
-- A cycle, not "the window to the left": maximized windows lie on top of each other.
local function windowsOn(screen)
    local wins, frames = {}, {}
    for _, w in ipairs(hs.window.visibleWindows()) do
        if w:isStandard() and w:screen():id() == screen:id() then
            table.insert(wins, w)
            frames[w:id()] = w:frame()
        end
    end
    -- Plus the windows the lists miss (Emacs) that had the focus; forget closed ones.
    for id, w in pairs(seen) do
        if #spacesOf(w) == 0 then
            seen[id] = nil
        elseif not frames[id] and not w:isMinimized() and onShownDesktop(w)
            and w:screen():id() == screen:id() then
            table.insert(wins, w)
            frames[id] = w:frame()
        end
    end
    table.sort(wins, function(a, b)
        local fa, fb = frames[a:id()], frames[b:id()]
        if fa.x ~= fb.x then return fa.x < fb.x end
        if fa.y ~= fb.y then return fa.y < fb.y end
        return a:id() < b:id()
    end)
    return wins
end

local function focusNextWindow(step)
    local wins = windowsOn(currentScreen())
    if #wins == 0 then return end
    local win = hs.window.focusedWindow()
    for i, w in ipairs(wins) do
        if win and w:id() == win:id() then
            focusWindow(wins[(i - 1 + step) % #wins + 1])
            return
        end
    end
    focusWindow(wins[1])
end

-- The monitors are stacked, so up is the top one (the HP) and down the bottom one
-- (the laptop), wherever the focus is now.
local function screenAtEdge(top)
    local best
    for _, s in ipairs(hs.screen.allScreens()) do
        local y, bestY = s:frame().y, best and best:frame().y
        if not best or (top and y < bestY) or (not top and y > bestY) then best = s end
    end
    return best
end

local function focusScreen(screen)
    local from = hs.window.focusedWindow()
    -- Back to where you were on that monitor, else its topmost window.
    local target = lastFocused[screen:id()]
    if not (target and onShownDesktop(target) and target:screen():id() == screen:id()) then
        target = nil
        for _, w in ipairs(hs.window.orderedWindows()) do
            if w:isStandard() and w:screen():id() == screen:id() then
                target = w
                break
            end
        end
    end
    logMsg("focus screen " .. screen:name() .. " from "
        .. (from and (from:application():name() .. " on " .. from:screen():name()) or "nothing")
        .. " to " .. (target and target:application():name() or "nothing"))
    if target then focusWindow(target) end
    -- The pointer goes too, so that ctrl-left / ctrl-right turn the Desktops of this monitor.
    if hs.mouse.getCurrentScreen():id() ~= screen:id() then
        hs.mouse.absolutePosition(screen:frame().center)
    end
end

local focusMods = {"ctrl", "alt"}
hs.hotkey.bind(focusMods, "right", function() focusNextWindow(1) end)
hs.hotkey.bind(focusMods, "left", function() focusNextWindow(-1) end)
hs.hotkey.bind(focusMods, "up", function() focusScreen(screenAtEdge(true)) end)
hs.hotkey.bind(focusMods, "down", function() focusScreen(screenAtEdge(false)) end)

-- A monitor that comes back (after its sleep, for one) gets its Desktops rebuilt,
-- and the Dock then stops switching to some of them: ctrl-4 did nothing on the HP
-- until `killall Dock`. So restart the Dock once a monitor is back.
local screenCount = #hs.screen.allScreens()
local dockRestart
-- Global, or the garbage collector stops the watcher.
screenWatcher = hs.screen.watcher.new(function()
    local n = #hs.screen.allScreens()
    if n > screenCount then
        if dockRestart then dockRestart:stop() end
        -- Let macOS finish rebuilding the Desktops first.
        dockRestart = hs.timer.doAfter(5, function()
            logMsg("monitor back: restarting the Dock")
            hs.task.new("/usr/bin/killall", nil, {"Dock"}):start()
        end)
    end
    screenCount = n
end):start()
