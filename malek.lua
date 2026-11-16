--[[
    MALEK  v1.0
    UNC-first single file. Xeno / Delta / Solara / Wave / Swift / Arceus / Codex.
    Camera-space aimbot with adaptive smoothing, velocity prediction,
    wall + team filtering, FOV ring, and gated auto fire.

    BindToRenderStep at Camera+1 so our CFrame write lands after the
    camera scripts and actually sticks.
]]

-- ===================== compat =====================
local function pick(...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v ~= nil then return v end
    end
end

local C = {}
C.executor, C.version = "unknown", ""
if identifyexecutor then
    local ok, a, b = pcall(identifyexecutor)
    if ok then C.executor, C.version = tostring(a), tostring(b) end
end
C.cloneref      = pick(cloneref, syn and syn.cloneref, function(x) return x end)
C.gethui        = pick(gethui, function() return nil end)
C.writefile     = pick(writefile, syn and syn.writefile)
C.readfile      = pick(readfile, syn and syn.readfile)
C.isfile        = pick(isfile, syn and syn.isfile)
C.makefolder    = pick(makefolder, syn and syn.makefolder)
C.mouse1press   = pick(mouse1press, syn and syn.mouse1press)
C.mouse1release = pick(mouse1release, syn and syn.mouse1release)
C.mouse1click   = pick(mouse1click, syn and syn.mouse1click)
C.setid         = pick(setthreadidentity, setidentity, syn and syn.set_thread_identity)
if C.setid then pcall(C.setid, 7) end

local Players = C.cloneref(game:GetService("Players"))
local Run     = C.cloneref(game:GetService("RunService"))
local UIS     = C.cloneref(game:GetService("UserInputService"))
local Tween   = C.cloneref(game:GetService("TweenService"))
local VIM     = C.cloneref(game:GetService("VirtualInputManager"))
local LP      = Players.LocalPlayer
local Camera  = workspace.CurrentCamera

local G = getgenv and getgenv() or _G
if type(G.__MALEK) == "table" and G.__MALEK.unload then pcall(G.__MALEK.unload) end

-- ===================== state =====================
local conns = {}
local function track(c) conns[#conns + 1] = c; return c end
local function untrack_all()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    table.clear(conns)
end

local cfg = {
    aimbot = true, aimkey = Enum.KeyCode.E, fov = 180, smooth = 9,
    fovring = true, head = true, teamcheck = true, wallcheck = true,
    prediction = 0.18, assist = false, assiststrength = 35,
    autofire = true, firedelay = 0.06,
}

local DIR = "Malek"
local CFG = DIR .. "/config.txt"
if C.makefolder then pcall(C.makefolder, DIR) end

-- ===================== palette =====================
local COL = {
    bg      = Color3.fromRGB(13, 13, 17),
    panel   = Color3.fromRGB(19, 19, 24),
    row     = Color3.fromRGB(27, 27, 34),
    rowhov  = Color3.fromRGB(35, 35, 44),
    stroke  = Color3.fromRGB(46, 46, 58),
    accent  = Color3.fromRGB(139, 92, 246),
    accent2 = Color3.fromRGB(34, 211, 238),
    text    = Color3.fromRGB(234, 234, 242),
    muted   = Color3.fromRGB(126, 126, 143),
    off     = Color3.fromRGB(52, 52, 64),
}
local FONT = Enum.Font.GothamMedium
local FONT_B = Enum.Font.GothamBold

local function corner(p, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r) c.Parent = p return c end
local function stroke(p, col, t, tr) local s = Instance.new("UIStroke") s.Color = col s.Thickness = t or 1 s.Transparency = tr or 0 s.Parent = p return s end

-- ===================== gui root =====================
local function root()
    local h = C.gethui()
    if h then return h end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return LP:WaitForChild("PlayerGui")
end

local gui = Instance.new("ScreenGui")
gui.Name = "Malek"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = root()

-- ===================== panel =====================
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(292, 436)
panel.Position = UDim2.fromOffset(28, 28)
panel.BackgroundColor3 = COL.panel
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = gui
corner(panel, 12)
stroke(panel, COL.stroke, 1, 0.25)

local scale = Instance.new("UIScale")
scale.Scale = 0.94
scale.Parent = panel

-- top gradient rail
local rail = Instance.new("Frame")
rail.Size = UDim2.new(1, 0, 0, 2)
rail.BackgroundColor3 = Color3.new(1, 1, 1)
rail.BorderSizePixel = 0
rail.Parent = panel
local rg = Instance.new("UIGradient")
rg.Color = ColorSequence.new(COL.accent, COL.accent2)
rg.Parent = rail

-- header
local head = Instance.new("Frame")
head.Size = UDim2.new(1, 0, 0, 46)
head.BackgroundTransparency = 1
head.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.fromOffset(200, 20)
title.Position = UDim2.fromOffset(16, 11)
title.BackgroundTransparency = 1
title.Font = FONT_B
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "MALEK"
title.TextColor3 = Color3.new(1, 1, 1)
title.Parent = head
local tg = Instance.new("UIGradient")
tg.Color = ColorSequence.new(COL.accent, COL.accent2)
tg.Parent = title

local sub = Instance.new("TextLabel")
sub.Size = UDim2.fromOffset(200, 14)
sub.Position = UDim2.fromOffset(16, 27)
sub.BackgroundTransparency = 1
sub.Font = FONT
sub.TextSize = 10
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.Text = "aim suite"
sub.TextColor3 = COL.muted
sub.Parent = head

local function iconBtn(glyph, x, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(22, 22)
    b.Position = UDim2.fromOffset(x, 13)
    b.BackgroundColor3 = COL.row
    b.BackgroundTransparency = 0.4
    b.AutoButtonColor = false
    b.Font = FONT_B
    b.TextSize = 13
    b.Text = glyph
    b.TextColor3 = COL.muted
    b.Parent = head
    corner(b, 6)
    b.MouseEnter:Connect(function() Tween:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0, TextColor3 = COL.text }):Play() end)
    b.MouseLeave:Connect(function() Tween:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0.4, TextColor3 = COL.muted }):Play() end)
    b.MouseButton1Click:Connect(cb)
    return b
end

local minimized = false
iconBtn("–", 220, function()
    minimized = not minimized
    Tween:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = minimized and UDim2.fromOffset(292, 46) or UDim2.fromOffset(292, 436),
    }):Play()
end)

-- drag
do
    local dragging, off
    head.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            off = Vector2.new(i.Position.X, i.Position.Y) - panel.AbsolutePosition
        end
    end)
    track(UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            panel.Position = UDim2.fromOffset(i.Position.X - off.X, i.Position.Y - off.Y)
        end
    end))
    track(UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

-- tabs
local tabs = Instance.new("Frame")
tabs.Size = UDim2.new(1, -32, 0, 26)
tabs.Position = UDim2.fromOffset(16, 52)
tabs.BackgroundTransparency = 1
tabs.Parent = panel

local pages, tabBtns = {}, {}
local order = { "AIM", "TARGET", "FIRE", "CONFIG" }

local body = Instance.new("Frame")
body.Size = UDim2.new(1, -32, 1, -130)
body.Position = UDim2.fromOffset(16, 86)
body.BackgroundTransparency = 1
body.Parent = panel

local function switch(name)
    for k, p in pairs(pages) do p.Visible = (k == name) end
    for k, b in pairs(tabBtns) do
        Tween:Create(b, TweenInfo.new(0.14), {
            BackgroundColor3 = k == name and COL.accent or COL.row,
            TextColor3 = k == name and Color3.new(1, 1, 1) or COL.muted,
        }):Play()
    end
end

for i, name in ipairs(order) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.25, -4, 1, 0)
    b.Position = UDim2.new((i - 1) * 0.25, (i - 1) * -3 + 2, 0, 0)
    b.BackgroundColor3 = COL.row
    b.AutoButtonColor = false
    b.Font = FONT_B
    b.TextSize = 10
    b.Text = name
    b.TextColor3 = COL.muted
    b.Parent = tabs
    corner(b, 6)
    b.MouseButton1Click:Connect(function() switch(name) end)
    tabBtns[name] = b

    local page = Instance.new("Frame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = body
    pages[name] = page
end

-- ===================== widgets =====================
local ycur = {}
local function yget(page) return ycur[page] or 0 end
local function yadd(page, n) ycur[page] = yget(page) + n end

local function label(page, txt, h)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, h or 18)
    l.Position = UDim2.fromOffset(0, yget(page))
    l.BackgroundTransparency = 1
    l.Font = FONT_B
    l.TextSize = 9
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = string.upper(txt)
    l.TextColor3 = COL.muted
    l.Parent = page
    yadd(page, (h or 18) + 4)
end

local function row(page, txt)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 30)
    f.Position = UDim2.fromOffset(0, yget(page))
    f.BackgroundColor3 = COL.row
    f.Parent = page
    corner(f, 7)
    yadd(page, 36)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -56, 1, 0)
    l.Position = UDim2.fromOffset(10, 0)
    l.BackgroundTransparency = 1
    l.Font = FONT
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = txt
    l.TextColor3 = COL.text
    l.Parent = f

    f.MouseEnter:Connect(function() Tween:Create(f, TweenInfo.new(0.12), { BackgroundColor3 = COL.rowhov }):Play() end)
    f.MouseLeave:Connect(function() Tween:Create(f, TweenInfo.new(0.12), { BackgroundColor3 = COL.row }):Play() end)
    return f
end

local function toggle(page, txt, key)
    local f = row(page, txt)
    local pill = Instance.new("Frame")
    pill.Size = UDim2.fromOffset(34, 18)
    pill.Position = UDim2.new(1, -44, 0.5, -9)
    pill.BackgroundColor3 = cfg[key] and COL.accent or COL.off
    pill.Parent = f
    corner(pill, 9)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(14, 14)
    knob.Position = UDim2.fromOffset(cfg[key] and 18 or 2, 2)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.Parent = pill
    corner(knob, 7)

    local hit = Instance.new("TextButton")
    hit.Size = UDim2.fromScale(1, 1)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.Parent = f

    hit.MouseButton1Click:Connect(function()
        cfg[key] = not cfg[key]
        Tween:Create(pill, TweenInfo.new(0.15, Enum.EasingStyle.Quart), { BackgroundColor3 = cfg[key] and COL.accent or COL.off }):Play()
        Tween:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quart), { Position = UDim2.fromOffset(cfg[key] and 18 or 2, 2) }):Play()
        if key == "fovring" then fovring.Visible = cfg.fovring end
    end)
end

local function slider(page, txt, key, min, max, suffix)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 42)
    f.Position = UDim2.fromOffset(0, yget(page))
    f.BackgroundColor3 = COL.row
    f.Parent = page
    corner(f, 7)
    yadd(page, 48)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -80, 0, 16)
    l.Position = UDim2.fromOffset(10, 5)
    l.BackgroundTransparency = 1
    l.Font = FONT
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = txt
    l.TextColor3 = COL.text
    l.Parent = f

    local val = Instance.new("TextLabel")
    val.Size = UDim2.fromOffset(60, 16)
    val.Position = UDim2.new(1, -70, 0, 5)
    val.BackgroundTransparency = 1
    val.Font = FONT_B
    val.TextSize = 12
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.Text = tostring(cfg[key]) .. (suffix or "")
    val.TextColor3 = COL.accent2
    val.Parent = f

    local trackf = Instance.new("Frame")
    trackf.Size = UDim2.new(1, -20, 0, 4)
    trackf.Position = UDim2.fromOffset(10, 28)
    trackf.BackgroundColor3 = COL.off
    trackf.Parent = f
    corner(trackf, 2)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale((cfg[key] - min) / (max - min), 1)
    fill.BackgroundColor3 = COL.accent
    fill.BorderSizePixel = 0
    fill.Parent = trackf
    corner(fill, 2)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(10, 10)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(fill.Size.X.Scale, 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.Parent = trackf
    corner(knob, 5)

    local function setFrom(x)
        local rel = math.clamp((x - trackf.AbsolutePosition.X) / math.max(trackf.AbsoluteSize.X, 1), 0, 1)
        local v = math.floor(min + (max - min) * rel + 0.5)
        cfg[key] = v
        val.Text = tostring(v) .. (suffix or "")
        fill.Size = UDim2.fromScale(rel, 1)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        if key == "fov" then fovring.Size = UDim2.fromOffset(v * 2 * scalei, v * 2 * scalei) end
    end

    local hit = Instance.new("TextButton")
    hit.Size = UDim2.fromScale(1, 1)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.Parent = f
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            setFrom(i.Position.X)
            local mv = UIS.InputChanged:Connect(function(m)
                if m.UserInputType == Enum.UserInputType.MouseMovement or m.UserInputType == Enum.UserInputType.Touch then
                    setFrom(m.Position.X)
                end
            end)
            local up
            up = UIS.InputEnded:Connect(function(m)
                if m.UserInputType == i.UserInputType then mv:Disconnect() up:Disconnect() end
            end)
        end
    end)
end

local function keybind(page, txt, key)
    local f = row(page, txt)
    local chip = Instance.new("TextButton")
    chip.Size = UDim2.fromOffset(56, 20)
    chip.Position = UDim2.new(1, -66, 0.5, -10)
    chip.BackgroundColor3 = COL.accent
    chip.BackgroundTransparency = 0.15
    chip.AutoButtonColor = false
    chip.Font = FONT_B
    chip.TextSize = 10
    chip.Text = cfg[key].Name
    chip.TextColor3 = Color3.new(1, 1, 1)
    chip.Parent = f
    corner(chip, 5)

    local waiting = false
    chip.MouseButton1Click:Connect(function()
        waiting = true
        chip.Text = "..."
    end)
    track(UIS.InputBegan:Connect(function(i, gp)
        if not waiting then return end
        if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
        cfg[key] = i.KeyCode
        chip.Text = i.KeyCode.Name
        waiting = false
    end))
end

local function action(page, txt, cb)
    local f = row(page, txt)
    local hit = Instance.new("TextButton")
    hit.Size = UDim2.fromScale(1, 1)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.Parent = f
    hit.MouseButton1Click:Connect(cb)
    local l = f:FindFirstChildOfClass("TextLabel")
    if l then l.TextColor3 = COL.accent2 end
end

-- ===================== pages =====================
label(pages.AIM, "aimbot")
toggle(pages.AIM, "Enabled", "aimbot")
keybind(pages.AIM, "Aim key", "aimkey")
slider(pages.AIM, "Field of view", "fov", 20, 600, "px")
slider(pages.AIM, "Smoothing speed", "smooth", 1, 20, "")
toggle(pages.AIM, "FOV ring", "fovring")

label(pages.TARGET, "filtering")
toggle(pages.TARGET, "Headshot priority", "head")
toggle(pages.TARGET, "Team check", "teamcheck")
toggle(pages.TARGET, "Wall check", "wallcheck")
slider(pages.TARGET, "Prediction", "prediction", 0, 100, "%")

label(pages.FIRE, "trigger")
toggle(pages.FIRE, "Auto fire", "autofire")
slider(pages.FIRE, "Fire interval", "firedelay", 1, 30, "0ms")

label(pages.CONFIG, "assist")
toggle(pages.CONFIG, "Aim assist (always on)", "assist")
slider(pages.CONFIG, "Assist strength", "assiststrength", 5, 100, "%")

label(pages.CONFIG, "preset")
action(pages.CONFIG, "Save config", function() save() end)
action(pages.CONFIG, "Load config", function() load() end)
action(pages.CONFIG, "Unload", function() G.__MALEK.unload() end)

-- footer
local foot = Instance.new("TextLabel")
foot.Size = UDim2.new(1, -32, 0, 14)
foot.Position = UDim2.new(0, 16, 1, -24)
foot.BackgroundTransparency = 1
foot.Font = FONT
foot.TextSize = 9
foot.TextXAlignment = Enum.TextXAlignment.Left
foot.Text = C.executor .. "  ·  " .. C.version
foot.TextColor3 = COL.muted
foot.Parent = panel

-- ===================== fov ring =====================
local scalei = 1
local fovring = Instance.new("Frame")
fovring.AnchorPoint = Vector2.new(0.5, 0.5)
fovring.Position = UDim2.fromScale(0.5, 0.5)
fovring.BackgroundTransparency = 1
fovring.Visible = cfg.fovring
fovring.Parent = gui
corner(fovring, 9999)
stroke(fovring, COL.accent2, 1, 0.55)

local dot = Instance.new("Frame")
dot.Size = UDim2.fromOffset(3, 3)
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.BackgroundColor3 = COL.accent2
dot.BackgroundTransparency = 0.2
dot.Parent = gui
corner(dot, 2)

local function sync_ring()
    scalei = Camera.ViewportSize.Y / 1080
    local d = cfg.fov * 2 * scalei
    fovring.Size = UDim2.fromOffset(d, d)
end
sync_ring()

-- ===================== aim engine =====================
local holding, current, firing, lastClick = false, nil, false, 0

local function part_of(char)
    if cfg.head then
        return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
end

local function valid(p)
    if p == LP then return false end
    local char = p.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if cfg.teamcheck and p.Team and LP.Team and p.Team == LP.Team then return false end
    return true
end

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.RespectCanCollide = false

local function select_target()
    local center = Camera.ViewportSize * 0.5
    local origin = Camera.CFrame.Position
    local radius = cfg.fov * (Camera.ViewportSize.Y / 1080)
    local best, bestscore = nil, math.huge

    for _, p in ipairs(Players:GetPlayers()) do
        if valid(p) then
            local part = part_of(p.Character)
            if part then
                local sp, on = Camera:WorldToViewportPoint(part.Position)
                if on then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d <= radius and d < bestscore then
                        local clear = true
                        if cfg.wallcheck then
                            rp.FilterDescendantsInstances = { p.Character, LP.Character, Camera }
                            clear = workspace:Raycast(origin, part.Position - origin, rp) == nil
                        end
                        if clear then
                            best, bestscore = p, d
                        end
                    end
                end
            end
        end
    end
    return best
end

local function fire(on)
    if on and not firing then
        firing = true
        if C.mouse1press then pcall(C.mouse1press)
        elseif C.mouse1click then pcall(C.mouse1click); lastClick = os.clock()
        else VIM:SendMouseButtonEvent(0, 0, 0, true, game, 1) end
    elseif not on and firing then
        firing = false
        if C.mouse1release then pcall(C.mouse1release)
        elseif not C.mouse1click then VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1) end
    end
end

local function step(dt)
    if not Camera then return end
    local t = select_target()
    current = t

    local engaged = t and (holding and cfg.aimbot or cfg.assist)
    if not engaged then
        if cfg.autofire then fire(false) end
        return
    end

    local char = t.Character
    local part = part_of(char)
    if not part then return end

    local origin = Camera.CFrame.Position
    local dest = part.Position
    if cfg.prediction > 0 then
        local travel = (dest - origin).Magnitude / 1200
        dest = dest + part.AssemblyLinearVelocity * travel * (cfg.prediction / 100)
    end

    local look = Camera.CFrame.LookVector
    local dir = (dest - origin).Unit
    local ang = math.deg(math.acos(math.clamp(look:Dot(dir), -1, 1)))

    local power = holding and cfg.aimbot and cfg.smooth or (cfg.smooth * cfg.assiststrength / 100)
    local base = math.clamp(power * dt * 9, 0, 1)
    local boost = math.clamp(ang / 22, 0, 1) * 0.4
    local alpha = math.clamp(base + boost, 0, 1)

    Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(origin, dest), alpha)

    if cfg.autofire then
        local sp = Camera:WorldToViewportPoint(dest)
        local gate = (Vector2.new(sp.X, sp.Y) - Camera.ViewportSize * 0.5).Magnitude
        local inrange = gate <= math.max(24, cfg.fov * (Camera.ViewportSize.Y / 1080) * 0.55)
        if inrange then
            if C.mouse1press then
                fire(true)
            elseif os.clock() - lastClick >= cfg.firedelay / 100 then
                fire(false); fire(true)
            end
        else
            fire(false)
        end
    end
end

Run:BindToRenderStep("Malek", Enum.RenderPriority.Camera.Value + 1, function(dt)
    local ok, err = pcall(step, dt)
    if not ok then warn("[malek] " .. tostring(err)) end
end)

-- ===================== input =====================
track(UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == cfg.aimkey then holding = true end
end))
track(UIS.InputEnded:Connect(function(i)
    if i.KeyCode == cfg.aimkey then holding = false end
end))
track(UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        panel.Visible = not panel.Visible
    end
end))

track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    if workspace.CurrentCamera then Camera = workspace.CurrentCamera; sync_ring() end
end))
track(Camera:GetPropertyChangedSignal("ViewportSize"):Connect(sync_ring))

-- ===================== config =====================
local keys = { "aimbot", "fov", "smooth", "fovring", "head", "teamcheck", "wallcheck", "prediction", "assist", "assiststrength", "autofire", "firedelay" }

function save()
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = k .. "=" .. tostring(cfg[k]) end
    out[#out + 1] = "aimkey=" .. cfg.aimkey.Name
    if C.writefile then pcall(C.writefile, CFG, table.concat(out, "\n")) end
end

function load()
    if not (C.readfile and C.isfile) then return end
    local ok, data = pcall(C.readfile, CFG)
    if not ok or not data then return end
    for line in data:gmatch("[^\r\n]+") do
        local k, v = line:match("^(%w+)=(.*)$")
        if k then
            if k == "aimkey" then
                local kc = Enum.KeyCode[v]
                if kc then cfg.aimkey = kc end
            elseif cfg[k] ~= nil then
                if type(cfg[k]) == "boolean" then cfg[k] = v == "true"
                else cfg[k] = tonumber(v) or cfg[k] end
            end
        end
    end
end
load()

-- ===================== unload =====================
G.__MALEK = {
    cfg = cfg,
    unload = function()
        pcall(function() Run:UnbindFromRenderStep("Malek") end)
        fire(false)
        untrack_all()
        pcall(function() gui:Destroy() end)
        G.__MALEK = nil
    end,
}

-- entrance
Tween:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1 }):Play()
switch("AIM")
