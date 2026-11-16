--[[
    MALEK  v1.2
    UNC-first single file. Xeno / Delta / Solara / Wave / Swift / Arceus / Codex.
    Camera-space aimbot with adaptive smoothing, velocity prediction,
    wall + team filtering, FOV ring, gated auto fire, AFK match farming,
    persisted keybinds, autostart and rejoin persistence.
]]

-- ===================== compat =====================
local function pick(...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v ~= nil then return v end
    end
end

local RAW = "https://raw.githubusercontent.com/malikofficialfahad-ai/malekrivalscript/main/malek.lua"
local LOGO_URL = "https://raw.githubusercontent.com/malikofficialfahad-ai/malekrivalscript/main/logo.png"

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
C.isfolder      = pick(isfolder, syn and syn.isfolder)
C.makefolder    = pick(makefolder, syn and syn.makefolder)
C.delfile       = pick(delfile, syn and syn.delfile)
C.mouse1press   = pick(mouse1press, syn and syn.mouse1press)
C.mouse1release = pick(mouse1release, syn and syn.mouse1release)
C.mouse1click   = pick(mouse1click, syn and syn.mouse1click)
C.setid         = pick(setthreadidentity, setidentity, syn and syn.set_thread_identity)
C.customasset   = pick(getcustomasset, getsynasset)
C.queue_teleport = pick(queue_on_teleport, queueonteleport)
if C.setid then pcall(C.setid, 7) end

local raw_http
if http_request then raw_http = http_request
elseif request then raw_http = request
elseif syn and syn.request then raw_http = syn.request
elseif fluxus and fluxus.request then raw_http = fluxus.request
end

function C.http(o)
    if raw_http then
        local ok, r = pcall(raw_http, o)
        if ok and type(r) == "table" then return r end
    end
    if game.HttpGet then
        local ok, b = pcall(function() return game:HttpGet(o.Url) end)
        if ok then return { Body = b, StatusCode = 200 } end
    end
    return { Body = "", StatusCode = 0 }
end

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
local conns, running = {}, true
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
    farm = false, farmdelay = 3, humanize = true, jitter = 40, persist = true,
}

local DIR = "Malek"
local CFG = DIR .. "/config.txt"
local LOGO = DIR .. "/logo.png"
if C.makefolder then pcall(C.makefolder, DIR) end

-- ===================== config io =====================
local keys = {
    "aimbot", "fov", "smooth", "fovring", "head", "teamcheck", "wallcheck",
    "prediction", "assist", "assiststrength", "autofire", "firedelay",
    "farm", "farmdelay", "humanize", "jitter", "persist",
}

local function save()
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = k .. "=" .. tostring(cfg[k]) end
    out[#out + 1] = "aimkey=" .. cfg.aimkey.Name
    if C.writefile then pcall(C.writefile, CFG, table.concat(out, "\n")) end
end

local function load()
    if not (C.readfile and C.isfile and C.isfile(CFG)) then return end
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

local save_timer
local function queue_save()
    if save_timer then return end
    save_timer = task.delay(0.4, function() save_timer = nil; save() end)
end

-- ===================== persistence =====================
local LOADER = ('loadstring(game:HttpGet("%s?v=2"))()'):format(RAW)
local AUTO_DIRS = { "autoexec", "AutoExec", "auto_exec", "Xeno/autoexec", "workspace/autoexec", "Malek/autoexec" }

local function arm()
    if cfg.persist and C.queue_teleport then
        pcall(C.queue_teleport, LOADER)
    end
end

local function install_autostart()
    if not (C.writefile and C.isfolder) then return "unsupported" end
    for _, d in ipairs(AUTO_DIRS) do
        local ok, exists = pcall(C.isfolder, d)
        if ok and exists then
            if pcall(C.writefile, d .. "/malek_autoload.lua", LOADER) then return d end
        end
    end
    return "none"
end
local autostart_dir = install_autostart()

arm()
task.spawn(function()
    while running do
        task.wait(4)
        arm()
    end
end)

-- ===================== logo =====================
local logo_asset
do
    if C.isfile and C.isfile(LOGO) and C.customasset then
        local ok, a = pcall(C.customasset, LOGO)
        if ok then logo_asset = a end
    end
    if not logo_asset and C.writefile then
        local r = C.http({ Url = LOGO_URL, Method = "GET" })
        if r.Body and #r.Body > 500 then
            pcall(C.writefile, LOGO, r.Body)
            if C.customasset then
                local ok, a = pcall(C.customasset, LOGO)
                if ok then logo_asset = a end
            end
        end
    end
end

-- ===================== palette =====================
local COL = {
    bg      = Color3.fromRGB(13, 13, 17),
    panel   = Color3.fromRGB(17, 16, 22),
    row     = Color3.fromRGB(27, 26, 34),
    rowhov  = Color3.fromRGB(36, 34, 45),
    stroke  = Color3.fromRGB(52, 46, 66),
    accent  = Color3.fromRGB(139, 92, 246),
    accent2 = Color3.fromRGB(34, 211, 238),
    text    = Color3.fromRGB(234, 232, 242),
    muted   = Color3.fromRGB(126, 122, 143),
    off     = Color3.fromRGB(52, 50, 64),
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
panel.Size = UDim2.fromOffset(300, 480)
panel.Position = UDim2.fromOffset(28, 28)
panel.BackgroundColor3 = COL.panel
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = gui
corner(panel, 12)
stroke(panel, COL.stroke, 1, 0.3)

local scale = Instance.new("UIScale")
scale.Scale = 0.94
scale.Parent = panel

local rail = Instance.new("Frame")
rail.Size = UDim2.new(1, 0, 0, 2)
rail.BackgroundColor3 = Color3.new(1, 1, 1)
rail.BorderSizePixel = 0
rail.Parent = panel
local rg = Instance.new("UIGradient")
rg.Color = ColorSequence.new(COL.accent, COL.accent2)
rg.Parent = rail

-- ===================== minimized restore chip =====================
local mini = Instance.new("ImageButton")
mini.Size = UDim2.fromOffset(42, 42)
mini.Position = panel.Position
mini.BackgroundColor3 = COL.panel
mini.BorderSizePixel = 0
mini.Visible = false
mini.AutoButtonColor = false
mini.Image = logo_asset or ""
mini.Parent = gui
corner(mini, 12)
stroke(mini, COL.accent, 1.5, 0.2)

if not logo_asset then
    local ph = Instance.new("TextLabel")
    ph.Size = UDim2.fromScale(1, 1)
    ph.BackgroundTransparency = 1
    ph.Font = FONT_B
    ph.TextSize = 16
    ph.Text = "M"
    ph.TextColor3 = COL.accent
    ph.Parent = mini
end

-- ===================== header =====================
local head = Instance.new("Frame")
head.Size = UDim2.new(1, 0, 0, 54)
head.BackgroundTransparency = 1
head.Parent = panel

local avatar = Instance.new("ImageLabel")
avatar.Size = UDim2.fromOffset(34, 34)
avatar.Position = UDim2.fromOffset(12, 10)
avatar.BackgroundColor3 = COL.row
avatar.BorderSizePixel = 0
avatar.Image = logo_asset or ""
avatar.ScaleType = Enum.ScaleType.Crop
avatar.Parent = head
corner(avatar, 9)
stroke(avatar, COL.accent, 1, 0.45)

if not logo_asset then
    local ph = Instance.new("TextLabel")
    ph.Size = UDim2.fromScale(1, 1)
    ph.BackgroundTransparency = 1
    ph.Font = FONT_B
    ph.TextSize = 15
    ph.Text = "M"
    ph.TextColor3 = COL.accent
    ph.Parent = avatar
end

local title = Instance.new("TextLabel")
title.Size = UDim2.fromOffset(150, 18)
title.Position = UDim2.fromOffset(54, 11)
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
sub.Size = UDim2.fromOffset(150, 13)
sub.Position = UDim2.fromOffset(54, 28)
sub.BackgroundTransparency = 1
sub.Font = FONT
sub.TextSize = 9
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.Text = "v1.2 · aim suite"
sub.TextColor3 = COL.muted
sub.Parent = head

local function iconBtn(glyph, x, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(20, 20)
    b.Position = UDim2.fromOffset(x, 14)
    b.BackgroundColor3 = COL.row
    b.BackgroundTransparency = 0.4
    b.AutoButtonColor = false
    b.Font = FONT_B
    b.TextSize = 12
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
local function set_minimized(v)
    minimized = v
    mini.Position = panel.Position
    panel.Visible = not v
    mini.Visible = v
end

iconBtn("–", 254, function() set_minimized(true) end)
mini.MouseButton1Click:Connect(function() set_minimized(false) end)

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
tabs.Position = UDim2.fromOffset(16, 60)
tabs.BackgroundTransparency = 1
tabs.Parent = panel

local pages, tabBtns = {}, {}
local order = { "AIM", "TGT", "FIRE", "FARM", "CFG" }

local body = Instance.new("Frame")
body.Size = UDim2.new(1, -32, 1, -142)
body.Position = UDim2.fromOffset(16, 94)
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
    b.Size = UDim2.new(0.2, -4, 1, 0)
    b.Position = UDim2.new((i - 1) * 0.2, (i - 1) * -3 + 2, 0, 0)
    b.BackgroundColor3 = COL.row
    b.AutoButtonColor = false
    b.Font = FONT_B
    b.TextSize = 9
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

local function label(page, txt)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 16)
    l.Position = UDim2.fromOffset(0, yget(page))
    l.BackgroundTransparency = 1
    l.Font = FONT_B
    l.TextSize = 9
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = string.upper(txt)
    l.TextColor3 = COL.muted
    l.Parent = page
    yadd(page, 20)
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

local function toggle(page, txt, key, cb)
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
    hit.Size = UDim2.fromScale(1,
