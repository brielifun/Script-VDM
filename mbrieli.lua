-- =====================================================
--  brieli vis — Violence District Edition (Mobile / Delta)
--  Правый Shift — открыть/закрыть (ПК)
--  Кнопка ≡ в углу — открыть/закрыть (мобилка)
-- =====================================================

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ContextActionSvc  = game:GetService("ContextActionService")
local Lighting          = game:GetService("Lighting")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local TweenService      = game:GetService("TweenService")
local HttpService       = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- ============== МОБИЛЬНЫЙ РЕЖИМ ==============
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
if UserInputService.TouchEnabled and UserInputService.KeyboardEnabled then
    IS_MOBILE = false -- планшет с клавой или ПК с тачскрином
end
local RENDER_INTERVAL = IS_MOBILE and 0.033 or 0  -- 30 FPS на мобиле
local ROLE_UPDATE     = IS_MOBILE and 1.0 or 0.5
local SCAN_CHUNK      = IS_MOBILE and 20 or 30

if _G.brieliVisUnload then pcall(_G.brieliVisUnload) end

-- ============== ФАЙЛОВЫЕ ОПЕРАЦИИ ==============
local CONFIG_FILE = "brieli_vis_config.json"

local function fsWrite(name, content)
    if writefile then pcall(writefile, name, content)
    elseif write_file then pcall(write_file, name, content) end
end

local function fsRead(name)
    if isfile then
        local ok, exists = pcall(isfile, name)
        if ok and exists then
            local ok2, data = pcall(readfile, name)
            if ok2 then return data end
        end
    elseif read_file then
        local ok, data = pcall(read_file, name)
        if ok and data then return data end
    end
    return nil
end

local function fsDelete(name)
    if delfile then pcall(delfile, name)
    elseif del_file then pcall(del_file, name) end
end

-- ============== ПРОВЕРКА DRAWING ==============
local drawingAvailable = false
do
    local ok = pcall(function()
        local t = Drawing.new("Line")
        t:Remove()
        return true
    end)
    drawingAvailable = ok
end

-- ============== СОСТОЯНИЕ ==============
local state = {
    espEnabled      = false,
    showName        = false,
    showDistance    = false,
    showHealthBar   = false,
    showKillerTag   = false,
    chams           = false,
    box2D           = false,
    skeleton        = false,
    espGenerators   = false,
    espHooks        = false,
    espPallets      = false,
    noclip          = false,
    fullbright      = false,
    noFog           = false,
    noShadows       = false,
    fovValue        = 90,
    killerAlert     = false,
    menuKey         = Enum.KeyCode.RightShift,
    checkpointBinds = false,

    aimbotEnabled   = false,
    aimbotShowFov   = false,
    aimbotFovSize   = IS_MOBILE and 90 or 120,

    avoidKiller          = false,
    avoidKillerDistance  = IS_MOBILE and 25 or 40,

    currentEffects  = {},
    effectTrail     = false,
    effectParticles = false,
    effectAura      = false,

    spinEnabled     = false,
    spinDirection   = "right",
    spinSpeed       = 40,
    spinConn        = nil,
    originalAutoRotate = true,

    autoEscape      = false,
    autoEscapeRef   = nil,
    autoEscapeConn  = nil,

    survivorColor   = Color3.fromRGB(0, 170, 255),
    killerColor     = Color3.fromRGB(255, 40, 40),
    generatorColor  = Color3.fromRGB(255, 200, 0),
    hookColor       = Color3.fromRGB(255, 0, 255),
    palletColor     = Color3.fromRGB(0, 255, 100),

    configAccent          = nil,
    configBgImage         = "",
    configBgImageEnabled  = false,
    configBgImageTransparency = 0.55,

    highlights      = {},
    billboards      = {},
    boxes2D         = {},
    skeletons       = {},
    connections     = {},
    renderConn      = nil,
    aimConn         = nil,
    avoidConn       = nil,
    noclipConn      = nil,
    savedCollide    = {},
    roleCache       = {},
    checkpoint      = nil,
    checkpointMarker = nil,
    unloaded        = false,
    currentTab      = "visuals",
    tabSwitching    = false,
    loadingConfig   = false,
    bindDialog      = nil,
}

local function bind(conn)
    table.insert(state.connections, conn)
    return conn
end

-- ============== ПАЛИТРА ==============
local C = {
    bg        = Color3.fromRGB(13, 16, 21),
    topbar    = Color3.fromRGB(17, 21, 27),
    sidebar   = Color3.fromRGB(17, 21, 27),
    panelBg   = Color3.fromRGB(20, 25, 31),
    panelHdr  = Color3.fromRGB(24, 29, 37),
    row       = Color3.fromRGB(21, 26, 33),
    rowHover  = Color3.fromRGB(28, 34, 43),
    tabActive = Color3.fromRGB(24, 40, 54),
    tabHover  = Color3.fromRGB(22, 28, 36),
    accent    = Color3.fromRGB(0, 200, 255),
    accentDim = Color3.fromRGB(0, 130, 170),
    text      = Color3.fromRGB(220, 228, 240),
    textDim   = Color3.fromRGB(115, 128, 145),
    textMute  = Color3.fromRGB(80, 92, 105),
    track     = Color3.fromRGB(38, 46, 58),
    border    = Color3.fromRGB(28, 34, 43),
}

local function colorToTable(c)
    return {
        R = math.floor(c.R * 255 + 0.5),
        G = math.floor(c.G * 255 + 0.5),
        B = math.floor(c.B * 255 + 0.5),
    }
end
local function colorFromTable(t)
    if not t or type(t) ~= "table" then return nil end
    return Color3.fromRGB(t.R or 255, t.G or 255, t.B or 255)
end

-- ============== КОНФИГ ==============
local keybindRegistry = {}

local function buildConfig()
    local kb = {}
    for label, data in pairs(keybindRegistry) do
        if data and data.key then kb[label] = data.key.Name end
    end
    return {
        espEnabled = state.espEnabled, showName = state.showName,
        showDistance = state.showDistance, showHealthBar = state.showHealthBar,
        showKillerTag = state.showKillerTag, chams = state.chams,
        box2D = state.box2D, skeleton = state.skeleton,
        espGenerators = state.espGenerators, espHooks = state.espHooks,
        espPallets = state.espPallets, fullbright = state.fullbright,
        noFog = state.noFog, noShadows = state.noShadows, fovValue = state.fovValue,
        killerAlert = state.killerAlert, checkpointBinds = state.checkpointBinds,
        spinSpeed = state.spinSpeed, spinDirection = state.spinDirection,
        autoEscape = state.autoEscape,
        menuKeyName = state.menuKey and state.menuKey.Name or "RightShift",
        aimbotEnabled = state.aimbotEnabled, aimbotShowFov = state.aimbotShowFov,
        aimbotFovSize = state.aimbotFovSize,
        avoidKiller = state.avoidKiller, avoidKillerDistance = state.avoidKillerDistance,
        survivorColor = colorToTable(state.survivorColor),
        killerColor = colorToTable(state.killerColor),
        generatorColor = colorToTable(state.generatorColor),
        hookColor = colorToTable(state.hookColor),
        palletColor = colorToTable(state.palletColor),
        configAccent = state.configAccent and colorToTable(state.configAccent) or nil,
        configBgImage = state.configBgImage,
        configBgImageEnabled = state.configBgImageEnabled,
        configBgImageTransparency = state.configBgImageTransparency,
        keybinds = kb,
    }
end

local function saveConfig()
    local ok, encoded = pcall(function() return HttpService:JSONEncode(buildConfig()) end)
    if ok and encoded then fsWrite(CONFIG_FILE, encoded) end
end

local function loadConfigTable()
    local data = fsRead(CONFIG_FILE)
    if not data or data == "" then return nil end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(data) end)
    if ok then return decoded end
    return nil
end

-- ============== GUI ==============
local parentGui
pcall(function() parentGui = (gethui and gethui()) or game:GetService("CoreGui") end)
if not parentGui then parentGui = LocalPlayer:WaitForChild("PlayerGui") end

local function round(obj, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = obj
    return c
end

local function attachHoverScale(btn, targetScale)
    targetScale = targetScale or 1.02
    local scale = Instance.new("UIScale")
    scale.Scale = 1
    scale.Parent = btn
    btn.MouseEnter:Connect(function()
        TweenService:Create(scale, TweenInfo.new(0.12), {Scale = targetScale}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(scale, TweenInfo.new(0.12), {Scale = 1}):Play()
    end)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "brieli_vis_vd"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 999
screenGui.Parent = parentGui

-- Адаптивный размер
local VIEWPORT = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
local WIN_W, WIN_H
if IS_MOBILE then
    WIN_W = math.min(VIEWPORT.X * 0.96, 540)
    WIN_H = math.min(VIEWPORT.Y * 0.9, 640)
else
    WIN_W = 820
    WIN_H = 540
end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, WIN_W, 0, WIN_H)
main.Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
main.BackgroundColor3 = C.bg
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = screenGui
round(main, 8)

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = C.border
mainStroke.Thickness = 1
mainStroke.Parent = main

local topbar = Instance.new("Frame")
topbar.Size = UDim2.new(1, 0, 0, 42)
topbar.BackgroundColor3 = C.topbar
topbar.BorderSizePixel = 0
topbar.Parent = main
round(topbar, 8)

local topbarCover = Instance.new("Frame")
topbarCover.Size = UDim2.new(1, 0, 0, 12)
topbarCover.Position = UDim2.new(0, 0, 1, -12)
topbarCover.BackgroundColor3 = C.topbar
topbarCover.BorderSizePixel = 0
topbarCover.Parent = topbar

local logoDot = Instance.new("Frame")
logoDot.Size = UDim2.new(0, 8, 0, 8)
logoDot.Position = UDim2.new(0, 18, 0.5, -4)
logoDot.BackgroundColor3 = C.accent
logoDot.BorderSizePixel = 0
logoDot.Parent = topbar
round(logoDot, 4)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 300, 1, 0)
titleLabel.Position = UDim2.new(0, 36, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "brieli vis"
titleLabel.TextColor3 = C.text
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 15
titleLabel.Parent = topbar

local titleSub = Instance.new("TextLabel")
titleSub.Size = UDim2.new(0, 300, 1, 0)
titleSub.Position = UDim2.new(0, 118, 0, 0)
titleSub.BackgroundTransparency = 1
titleSub.Text = "· Violence District"
titleSub.TextColor3 = C.textMute
titleSub.TextXAlignment = Enum.TextXAlignment.Left
titleSub.Font = Enum.Font.Gotham
titleSub.TextSize = 12
titleSub.Parent = topbar

-- Кнопка закрытия (X) — на мобилке
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -36, 0.5, -14)
closeBtn.BackgroundColor3 = C.row
closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = false
closeBtn.Text = "✕"
closeBtn.TextColor3 = C.textDim
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = topbar
round(closeBtn, 4)

closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false
    if state.mobileMenuBtn then state.mobileMenuBtn.Visible = true end
end)

local topbarSep = Instance.new("Frame")
topbarSep.Size = UDim2.new(1, 0, 0, 1)
topbarSep.Position = UDim2.new(0, 0, 0, 42)
topbarSep.BackgroundColor3 = C.border
topbarSep.BorderSizePixel = 0
topbarSep.Parent = main

-- ============== SIDEBAR ==============
local SIDEBAR_W = IS_MOBILE and 130 or 172

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, -43)
sidebar.Position = UDim2.new(0, 0, 0, 43)
sidebar.BackgroundColor3 = C.sidebar
sidebar.BorderSizePixel = 0
sidebar.Parent = main

local sidebarSep = Instance.new("Frame")
sidebarSep.Size = UDim2.new(0, 1, 1, 0)
sidebarSep.Position = UDim2.new(1, -1, 0, 0)
sidebarSep.BackgroundColor3 = C.border
sidebarSep.BorderSizePixel = 0
sidebarSep.Parent = sidebar

local sidebarList = Instance.new("Frame")
sidebarList.Size = UDim2.new(1, 0, 1, -60)
sidebarList.BackgroundTransparency = 1
sidebarList.Parent = sidebar

local sidebarLayout = Instance.new("UIListLayout")
sidebarLayout.Padding = UDim.new(0, 2)
sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
sidebarLayout.Parent = sidebarList

local sidebarPad = Instance.new("UIPadding")
sidebarPad.PaddingTop = UDim.new(0, 12)
sidebarPad.PaddingLeft = UDim.new(0, 8)
sidebarPad.PaddingRight = UDim.new(0, 8)
sidebarPad.Parent = sidebarList

local userPanel = Instance.new("Frame")
userPanel.Size = UDim2.new(1, -16, 0, 44)
userPanel.Position = UDim2.new(0, 8, 1, -52)
userPanel.BackgroundColor3 = C.panelBg
userPanel.BorderSizePixel = 0
userPanel.Parent = sidebar
round(userPanel, 6)

local userDot = Instance.new("Frame")
userDot.Size = UDim2.new(0, 26, 0, 26)
userDot.Position = UDim2.new(0, 9, 0.5, -13)
userDot.BackgroundColor3 = C.accentDim
userDot.BorderSizePixel = 0
userDot.Parent = userPanel
round(userDot, 13)

local userInitial = Instance.new("TextLabel")
userInitial.Size = UDim2.new(1, 0, 1, 0)
userInitial.BackgroundTransparency = 1
userInitial.Text = string.sub(LocalPlayer.Name, 1, 1):upper()
userInitial.TextColor3 = Color3.fromRGB(255, 255, 255)
userInitial.Font = Enum.Font.GothamBold
userInitial.TextSize = 13
userInitial.Parent = userDot

local userName = Instance.new("TextLabel")
userName.Size = UDim2.new(1, -48, 0, 16)
userName.Position = UDim2.new(0, 42, 0, 7)
userName.BackgroundTransparency = 1
userName.Text = LocalPlayer.Name
userName.TextColor3 = C.text
userName.TextXAlignment = Enum.TextXAlignment.Left
userName.Font = Enum.Font.GothamMedium
userName.TextSize = 12
userName.TextTruncate = Enum.TextTruncate.AtEnd
userName.Parent = userPanel

local userTime = Instance.new("TextLabel")
userTime.Size = UDim2.new(1, -48, 0, 14)
userTime.Position = UDim2.new(0, 42, 0, 23)
userTime.BackgroundTransparency = 1
userTime.Text = os.date("%H:%M:%S")
userTime.TextColor3 = C.textDim
userTime.TextXAlignment = Enum.TextXAlignment.Left
userTime.Font = Enum.Font.Gotham
userTime.TextSize = 10
userTime.Parent = userPanel

task.spawn(function()
    while not state.unloaded do
        userTime.Text = os.date("%H:%M:%S")
        task.wait(2)
    end
end)

-- ============== CONTENT ==============
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -(SIDEBAR_W + 1), 1, -43)
content.Position = UDim2.new(0, SIDEBAR_W + 1, 0, 43)
content.BackgroundColor3 = C.bg
content.BorderSizePixel = 0
content.Parent = main

local bgImage = Instance.new("ImageLabel")
bgImage.Name = "BackgroundImage"
bgImage.Size = UDim2.new(1, 0, 1, 0)
bgImage.BackgroundTransparency = 1
bgImage.Image = ""
bgImage.ImageTransparency = state.configBgImageTransparency
bgImage.ScaleType = Enum.ScaleType.Crop
bgImage.ZIndex = 0
bgImage.Visible = false
bgImage.Parent = content

local tabHeader = Instance.new("Frame")
tabHeader.Size = UDim2.new(1, 0, 0, 38)
tabHeader.BackgroundColor3 = C.bg
tabHeader.BorderSizePixel = 0
tabHeader.ZIndex = 2
tabHeader.Parent = content

local tabHeaderSep = Instance.new("Frame")
tabHeaderSep.Size = UDim2.new(1, 0, 0, 1)
tabHeaderSep.Position = UDim2.new(0, 0, 1, -1)
tabHeaderSep.BackgroundColor3 = C.border
tabHeaderSep.BorderSizePixel = 0
tabHeaderSep.Parent = tabHeader

local tabHeaderLabel = Instance.new("TextLabel")
tabHeaderLabel.Size = UDim2.new(1, -24, 1, 0)
tabHeaderLabel.Position = UDim2.new(0, 20, 0, 0)
tabHeaderLabel.BackgroundTransparency = 1
tabHeaderLabel.Text = "Визуальные"
tabHeaderLabel.TextColor3 = C.text
tabHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
tabHeaderLabel.Font = Enum.Font.GothamBold
tabHeaderLabel.TextSize = 13
tabHeaderLabel.Parent = tabHeader

local canvas = Instance.new("CanvasGroup")
canvas.Size = UDim2.new(1, 0, 1, -38)
canvas.Position = UDim2.new(0, 0, 0, 38)
canvas.BackgroundTransparency = 1
canvas.GroupTransparency = 0
canvas.ZIndex = 2
canvas.Parent = content

local contentScroll = Instance.new("ScrollingFrame")
contentScroll.Size = UDim2.new(1, 0, 1, 0)
contentScroll.BackgroundTransparency = 1
contentScroll.BorderSizePixel = 0
contentScroll.ScrollBarThickness = 4
contentScroll.ScrollBarImageColor3 = C.accentDim
contentScroll.ScrollBarImageTransparency = 0.4
contentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
contentScroll.Parent = canvas

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 6)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = contentScroll

local contentPad = Instance.new("UIPadding")
contentPad.PaddingTop = UDim.new(0, 12)
contentPad.PaddingLeft = UDim.new(0, 14)
contentPad.PaddingRight = UDim.new(0, 14)
contentPad.PaddingBottom = UDim.new(0, 12)
contentPad.Parent = contentScroll

contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    contentScroll.CanvasSize = UDim2.new(0, 0, 0, contentLayout.AbsoluteContentSize.Y + 24)
end)

-- ============== FOV CIRCLE ==============
local fovCircle = Instance.new("Frame")
fovCircle.Name = "AimFovCircle"
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
fovCircle.Size = UDim2.new(0, 0, 0, 0)
fovCircle.BackgroundTransparency = 1
fovCircle.BorderSizePixel = 0
fovCircle.Visible = false
fovCircle.ZIndex = 10
fovCircle.Parent = screenGui
round(fovCircle, 999)

local fovStroke = Instance.new("UIStroke")
fovStroke.Thickness = 1
fovStroke.Color = C.accent
fovStroke.Transparency = 0.3
fovStroke.Parent = fovCircle

-- ============== МОБИЛЬНАЯ КНОПКА МЕНЮ ==============
if IS_MOBILE then
    local mobileMenuBtn = Instance.new("TextButton")
    mobileMenuBtn.Name = "MobileMenuBtn"
    mobileMenuBtn.Size = UDim2.new(0, 46, 0, 46)
    mobileMenuBtn.Position = UDim2.new(0, 12, 0, 100)
    mobileMenuBtn.BackgroundColor3 = C.accent
    mobileMenuBtn.BorderSizePixel = 0
    mobileMenuBtn.AutoButtonColor = false
    mobileMenuBtn.Text = "≡"
    mobileMenuBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    mobileMenuBtn.Font = Enum.Font.GothamBold
    mobileMenuBtn.TextSize = 22
    mobileMenuBtn.Parent = screenGui
    round(mobileMenuBtn, 23)

    local mStroke = Instance.new("UIStroke")
    mStroke.Color = Color3.fromRGB(255, 255, 255)
    mStroke.Thickness = 1.5
    mStroke.Transparency = 0.6
    mStroke.Parent = mobileMenuBtn

    state.mobileMenuBtn = mobileMenuBtn

    mobileMenuBtn.MouseButton1Click:Connect(function()
        main.Visible = not main.Visible
        mobileMenuBtn.Visible = not main.Visible
    end)
end

-- ============== KEYBIND (ПК: MouseButton3 / Mobile: long press) ==============
local listeningRow = nil

local function openBindDialog(row, label)
    if state.bindDialog then
        state.bindDialog:Destroy()
        state.bindDialog = nil
    end

    local dlg = Instance.new("Frame")
    dlg.Size = UDim2.new(0, 260, 0, 130)
    dlg.Position = UDim2.new(0.5, -130, 0.5, -65)
    dlg.BackgroundColor3 = C.bg
    dlg.BorderSizePixel = 0
    dlg.ZIndex = 50
    dlg.Parent = screenGui
    round(dlg, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Color = C.border
    stroke.Thickness = 1.5
    stroke.Parent = dlg

    local ttl = Instance.new("TextLabel")
    ttl.Size = UDim2.new(1, 0, 0, 30)
    ttl.Position = UDim2.new(0, 0, 0, 0)
    ttl.BackgroundTransparency = 1
    ttl.Text = "Назначить бинд"
    ttl.TextColor3 = C.text
    ttl.Font = Enum.Font.GothamBold
    ttl.TextSize = 13
    ttl.Parent = dlg

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -20, 0, 20)
    sub.Position = UDim2.new(0, 10, 0, 30)
    sub.BackgroundTransparency = 1
    sub.Text = label
    sub.TextColor3 = C.textDim
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 11
    sub.TextTruncate = Enum.TextTruncate.AtEnd
    sub.Parent = dlg

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -40, 0, 32)
    box.Position = UDim2.new(0, 20, 0, 54)
    box.BackgroundColor3 = C.row
    box.BorderSizePixel = 0
    box.Text = ""
    box.PlaceholderText = "Введи клавишу (Z, X, F1...)"
    box.TextColor3 = C.text
    box.PlaceholderColor3 = C.textMute
    box.Font = Enum.Font.GothamMedium
    box.TextSize = 13
    box.ClearTextOnFocus = false
    box.Parent = dlg
    round(box, 5)

    local ok = Instance.new("TextButton")
    ok.Size = UDim2.new(0, 90, 0, 26)
    ok.Position = UDim2.new(0, 20, 0, 94)
    ok.BackgroundColor3 = C.accent
    ok.BorderSizePixel = 0
    ok.Text = "ОК"
    ok.TextColor3 = Color3.fromRGB(255, 255, 255)
    ok.Font = Enum.Font.GothamBold
    ok.TextSize = 12
    ok.Parent = dlg
    round(ok, 5)

    local no = Instance.new("TextButton")
    no.Size = UDim2.new(0, 90, 0, 26)
    no.Position = UDim2.new(1, -110, 0, 94)
    no.BackgroundColor3 = C.row
    no.BorderSizePixel = 0
    no.Text = "Снять / Отмена"
    no.TextColor3 = C.text
    no.Font = Enum.Font.GothamBold
    no.TextSize = 11
    no.Parent = dlg
    round(no, 5)

    state.bindDialog = dlg

    ok.MouseButton1Click:Connect(function()
        local text = box.Text:gsub("%s", ""):upper()
        if text == "" then
            dlg:Destroy()
            state.bindDialog = nil
            return
        end
        local success, key = pcall(function() return Enum.KeyCode[text] end)
        if success and key then
            -- снимаем старый бинд у другой функции
            for otherLabel, otherData in pairs(keybindRegistry) do
                if otherLabel ~= label and otherData.key == key then
                    otherData.key = nil
                    if otherData.indicator then otherData.indicator.Text = "" end
                end
            end
            local data = keybindRegistry[label]
            if data then
                data.key = key
                if data.indicator then data.indicator.Text = "[" .. key.Name .. "]" end
            end
        end
        dlg:Destroy()
        state.bindDialog = nil
    end)

    no.MouseButton1Click:Connect(function()
        local data = keybindRegistry[label]
        if data then
            data.key = nil
            if data.indicator then data.indicator.Text = "" end
        end
        dlg:Destroy()
        state.bindDialog = nil
    end)
end

local function registerKeybind(row, label, indicatorPos, action, allowLongPress)
    local indicator = Instance.new("TextLabel")
    indicator.Name = "BindIndicator"
    indicator.Size = UDim2.new(0, 60, 0, 14)
    indicator.Position = indicatorPos
    indicator.BackgroundTransparency = 1
    indicator.Text = ""
    indicator.TextColor3 = C.textMute
    indicator.TextXAlignment = Enum.TextXAlignment.Right
    indicator.Font = Enum.Font.GothamBold
    indicator.TextSize = 10
    indicator.Parent = row

    keybindRegistry[label] = {
        row = row, indicator = indicator, action = action, key = nil,
    }

    if not IS_MOBILE then
        row.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton3 then return end
            if listeningRow then return end
            listeningRow = label
            indicator.Text = "нажми..."
            indicator.TextColor3 = C.accent

            local conn
            conn = UserInputService.InputBegan:Connect(function(input2)
                if input2.UserInputType ~= Enum.UserInputType.Keyboard then return end
                conn:Disconnect()
                indicator.TextColor3 = C.textMute
                listeningRow = nil

                if input2.KeyCode == Enum.KeyCode.Escape then
                    local data = keybindRegistry[label]
                    if data.key then
                        indicator.Text = "[" .. data.key.Name .. "]"
                    else
                        indicator.Text = ""
                    end
                    return
                end

                for otherLabel, otherData in pairs(keybindRegistry) do
                    if otherLabel ~= label and otherData.key == input2.KeyCode then
                        otherData.key = nil
                        if otherData.indicator then otherData.indicator.Text = "" end
                    end
                end

                local data = keybindRegistry[label]
                data.key = input2.KeyCode
                indicator.Text = "[" .. input2.KeyCode.Name .. "]"
            end)
        end)
    elseif allowLongPress then
        -- long press 0.7s
        local pressStart = 0
        local pressConn = nil
        row.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.Touch then return end
            pressStart = tick()
            pressConn = RunService.Heartbeat:Connect(function()
                if tick() - pressStart >= 0.7 then
                    if pressConn then pressConn:Disconnect(); pressConn = nil end
                    openBindDialog(row, label)
                end
            end)
        end)
        row.InputEnded:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.Touch then return end
            if pressConn then pressConn:Disconnect(); pressConn = nil end
        end)
    end

    return indicator
end

-- Глобальный обработчик
bind(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    for _, data in pairs(keybindRegistry) do
        if data.key == input.KeyCode and data.action then
            data.action()
        end
    end
end))

-- ============== ВКЛАДКИ ==============
local tabButtons = {}
local tabNames = {
    visuals   = { label = "Визуальные", icon = "◉" },
    world     = { label = "Мир",        icon = "◐" },
    teleport  = { label = "Телепорт",   icon = "➤" },
    cosmetics = { label = "Косметика",  icon = "✦" },
    misc      = { label = "Разное",     icon = "⚙" },
    menu      = { label = "Меню",       icon = "☰" },
}

local function switchTab(tabId)
    if state.tabSwitching then return end
    state.tabSwitching = true
    TweenService:Create(canvas, TweenInfo.new(0.1), {GroupTransparency = 1}):Play()
    task.wait(0.1)

    state.currentTab = tabId
    for id, btn in pairs(tabButtons) do
        local isActive = (id == tabId)
        btn.BackgroundColor3 = isActive and C.tabActive or C.sidebar
        local nameL = btn:FindFirstChild("TabName")
        local iconL = btn:FindFirstChild("TabIcon")
        if nameL then nameL.TextColor3 = isActive and C.accent or C.textDim end
        if iconL then iconL.TextColor3 = isActive and C.accent or C.textMute end
    end
    if tabNames[tabId] then tabHeaderLabel.Text = tabNames[tabId].label end

    for _, child in ipairs(contentScroll:GetChildren()) do
        if child:IsA("GuiObject") then
            child.Visible = (child:GetAttribute("Tab") == tabId)
        end
    end

    TweenService:Create(canvas, TweenInfo.new(0.1), {GroupTransparency = 0}):Play()
    task.wait(0.1)
    state.tabSwitching = false
end

for id, info in pairs(tabNames) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, IS_MOBILE and 32 or 34)
    btn.BackgroundColor3 = C.sidebar
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Text = ""
    btn.Parent = sidebarList
    round(btn, 5)
    attachHoverScale(btn, 1.02)

    local icon = Instance.new("TextLabel")
    icon.Name = "TabIcon"
    icon.Size = UDim2.new(0, 22, 1, 0)
    icon.Position = UDim2.new(0, 8, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Text = info.icon
    icon.TextColor3 = C.textMute
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 13
    icon.TextXAlignment = Enum.TextXAlignment.Left
    icon.Parent = btn

    local nameL = Instance.new("TextLabel")
    nameL.Name = "TabName"
    nameL.Size = UDim2.new(1, -32, 1, 0)
    nameL.Position = UDim2.new(0, 30, 0, 0)
    nameL.BackgroundTransparency = 1
    nameL.Text = info.label
    nameL.TextColor3 = C.textDim
    nameL.TextXAlignment = Enum.TextXAlignment.Left
    nameL.Font = Enum.Font.GothamMedium
    nameL.TextSize = IS_MOBILE and 11 or 12
    nameL.Parent = btn

    btn.MouseEnter:Connect(function()
        if state.currentTab ~= id then
            btn.BackgroundColor3 = C.tabHover
            nameL.TextColor3 = C.text
        end
    end)
    btn.MouseLeave:Connect(function()
        if state.currentTab ~= id then
            btn.BackgroundColor3 = C.sidebar
            nameL.TextColor3 = C.textDim
        end
    end)
    btn.MouseButton1Click:Connect(function() switchTab(id) end)
    tabButtons[id] = btn
end

-- ============== UI ХЕЛПЕРЫ ==============
local function makeSectionLabel(text, tabId)
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, 24)
    wrap.BackgroundTransparency = 1
    wrap.Parent = contentScroll
    wrap:SetAttribute("Tab", tabId)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 0, 12)
    bar.Position = UDim2.new(0, 2, 0.5, -6)
    bar.BackgroundColor3 = C.accent
    bar.BorderSizePixel = 0
    bar.Parent = wrap
    round(bar, 2)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = C.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.Parent = wrap
    return wrap
end

local ROW_H = IS_MOBILE and 36 or 34

local function makeToggle(text, defaultOn, tabId, callback)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, ROW_H)
    row.BackgroundColor3 = C.row
    row.BorderSizePixel = 0
    row.AutoButtonColor = false
    row.Text = ""
    row.Parent = contentScroll
    row:SetAttribute("Tab", tabId)
    round(row, 5)
    if not IS_MOBILE then attachHoverScale(row, 1.02) end

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -130, 1, 0)
    label.Position = UDim2.new(0, 14, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = C.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.GothamMedium
    label.TextSize = IS_MOBILE and 11 or 12
    label.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 34, 0, 18)
    track.Position = UDim2.new(1, -46, 0.5, -9)
    track.BackgroundColor3 = defaultOn and C.accent or C.track
    track.BorderSizePixel = 0
    track.Parent = row
    round(track, 9)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = defaultOn and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = track
    round(knob, 6)

    local st = defaultOn
    local function setValue(newVal)
        st = newVal
        TweenService:Create(track, TweenInfo.new(0.15), {BackgroundColor3 = st and C.accent or C.track}):Play()
        if st then
            knob:TweenPosition(UDim2.new(1, -15, 0.5, -6), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
        else
            knob:TweenPosition(UDim2.new(0, 3, 0.5, -6), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
        end
        callback(st)
    end

    row.MouseButton1Click:Connect(function() setValue(not st) end)
    if not IS_MOBILE then
        row.MouseEnter:Connect(function() row.BackgroundColor3 = C.rowHover end)
        row.MouseLeave:Connect(function() row.BackgroundColor3 = C.row end)
    end

    registerKeybind(row, text, UDim2.new(1, -130, 0.5, -7), function() setValue(not st) end, true)
    return row
end

local function makeMasterToggle(text, defaultOn, tabId, callback)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, ROW_H + 6)
    row.BackgroundColor3 = C.panelBg
    row.BorderSizePixel = 0
    row.AutoButtonColor = false
    row.Text = ""
    row.Parent = contentScroll
    row:SetAttribute("Tab", tabId)
    round(row, 5)
    if not IS_MOBILE then attachHoverScale(row, 1.02) end

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -180, 1, 0)
    label.Position = UDim2.new(0, 16, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = C.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.GothamBold
    label.TextSize = IS_MOBILE and 12 or 13
    label.Parent = row

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(0, 40, 1, 0)
    status.Position = UDim2.new(1, -100, 0, 0)
    status.BackgroundTransparency = 1
    status.Text = defaultOn and "on" or "off"
    status.TextColor3 = defaultOn and C.accent or C.textMute
    status.TextXAlignment = Enum.TextXAlignment.Right
    status.Font = Enum.Font.GothamBold
    status.TextSize = 11
    status.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 38, 0, 20)
    track.Position = UDim2.new(1, -48, 0.5, -10)
    track.BackgroundColor3 = defaultOn and C.accent or C.track
    track.BorderSizePixel = 0
    track.Parent = row
    round(track, 10)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = defaultOn and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = track
    round(knob, 7)

    local st = defaultOn
    local function setValue(newVal)
        st = newVal
        TweenService:Create(track, TweenInfo.new(0.15), {BackgroundColor3 = st and C.accent or C.track}):Play()
        status.Text = st and "on" or "off"
        TweenService:Create(status, TweenInfo.new(0.15), {TextColor3 = st and C.accent or C.textMute}):Play()
        if st then
            knob:TweenPosition(UDim2.new(1, -17, 0.5, -7), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
        else
            knob:TweenPosition(UDim2.new(0, 3, 0.5, -7), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
        end
        callback(st)
    end

    row.MouseButton1Click:Connect(function() setValue(not st) end)
    if not IS_MOBILE then
        row.MouseEnter:Connect(function() row.BackgroundColor3 = C.rowHover end)
        row.MouseLeave:Connect(function() row.BackgroundColor3 = C.panelBg end)
    end

    registerKeybind(row, text, UDim2.new(1, -180, 0.5, -7), function() setValue(not st) end, true)
    return row
end

local function makeColorButton(text, initialColor, tabId, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, ROW_H)
    btn.BackgroundColor3 = C.row
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Text = ""
    btn.Parent = contentScroll
    btn:SetAttribute("Tab", tabId)
    round(btn, 5)
    if not IS_MOBILE then attachHoverScale(btn, 1.02) end

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -110, 1, 0)
    label.Position = UDim2.new(0, 14, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = C.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.GothamMedium
    label.TextSize = IS_MOBILE and 11 or 12
    label.Parent = btn

    local swatch = Instance.new("Frame")
    swatch.Size = UDim2.new(0, 22, 0, 22)
    swatch.Position = UDim2.new(1, -34, 0.5, -11)
    swatch.BackgroundColor3 = initialColor
    swatch.BorderSizePixel = 0
    swatch.Parent = btn
    round(swatch, 4)

    local swatchStroke = Instance.new("UIStroke")
    swatchStroke.Color = Color3.fromRGB(255, 255, 255)
    swatchStroke.Thickness = 1
    swatchStroke.Transparency = 0.8
    swatchStroke.Parent = swatch

    local presets = {
        Color3.fromRGB(0, 170, 255), Color3.fromRGB(255, 40, 40),
        Color3.fromRGB(255, 200, 0), Color3.fromRGB(0, 255, 100),
        Color3.fromRGB(255, 0, 255), Color3.fromRGB(255, 140, 0),
        Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 255, 255),
    }
    local idx = 1
    for i, col in ipairs(presets) do
        if col == initialColor then idx = i break end
    end

    if not IS_MOBILE then
        btn.MouseEnter:Connect(function() btn.BackgroundColor3 = C.rowHover end)
        btn.MouseLeave:Connect(function() btn.BackgroundColor3 = C.row end)
    end

    local function cycle()
        idx = idx % #presets + 1
        local col = presets[idx]
        swatch.BackgroundColor3 = col
        callback(col)
    end

    btn.MouseButton1Click:Connect(cycle)
    registerKeybind(btn, text, UDim2.new(1, -120, 0.5, -7), cycle, true)
    return btn
end

local function makeSlider(text, minVal, maxVal, defaultVal, tabId, callback, step)
    step = step or 1
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 52)
    frame.BackgroundColor3 = C.row
    frame.BorderSizePixel = 0
    frame.Parent = contentScroll
    frame:SetAttribute("Tab", tabId)
    round(frame, 5)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -90, 0, 20)
    label.Position = UDim2.new(0, 14, 0, 6)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = C.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.GothamMedium
    label.TextSize = IS_MOBILE and 11 or 12
    label.Parent = frame

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0, 60, 0, 20)
    valueLabel.Position = UDim2.new(1, -74, 0, 6)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(defaultVal)
    valueLabel.TextColor3 = C.accent
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = IS_MOBILE and 11 or 12
    valueLabel.Parent = frame

    local track = Instance.new("TextButton")
    track.Size = UDim2.new(1, -28, 0, IS_MOBILE and 10 or 6)
    track.Position = UDim2.new(0, 14, 0, 34)
    track.BackgroundColor3 = C.track
    track.BorderSizePixel = 0
    track.AutoButtonColor = false
    track.Text = ""
    track.Parent = frame
    round(track, 5)

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = C.accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    round(fill, 5)

    local handle = Instance.new("Frame")
    handle.Size = UDim2.new(0, 14, 0, 14)
    handle.Position = UDim2.new((defaultVal - minVal) / (maxVal - minVal), -7, 0.5, -7)
    handle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    handle.BorderSizePixel = 0
    handle.ZIndex = 2
    handle.Parent = track
    round(handle, 7)

    local dragging = false
    local function updateSlider(input)
        local relX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local val = minVal + (maxVal - minVal) * relX
        if step >= 1 then val = math.floor(val / step + 0.5) * step end
        fill.Size = UDim2.new(relX, 0, 1, 0)
        handle.Position = UDim2.new(relX, -7, 0.5, -7)
        if step >= 1 then valueLabel.Text = tostring(math.floor(val + 0.5))
        else valueLabel.Text = string.format("%.2f", val) end
        callback(val)
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            main.Active = false
            updateSlider(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then dragging = false main.Active = true end
        end
    end)
    return frame
end

local function makeActionButton(text, tabId, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, ROW_H)
    btn.BackgroundColor3 = color or C.row
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Text = "  " .. text
    btn.TextColor3 = color and Color3.fromRGB(255, 255, 255) or C.text
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = IS_MOBILE and 11 or 12
    btn.Parent = contentScroll
    btn:SetAttribute("Tab", tabId)
    round(btn, 5)
    if not IS_MOBILE then attachHoverScale(btn, 1.03) end

    if not IS_MOBILE then
        btn.MouseEnter:Connect(function()
            if not color then btn.BackgroundColor3 = C.rowHover end
        end)
        btn.MouseLeave:Connect(function()
            if not color then btn.BackgroundColor3 = C.row end
        end)
    end

    local function execute() callback(btn) end
    btn.MouseButton1Click:Connect(execute)
    registerKeybind(btn, text, UDim2.new(1, -80, 0.5, -7), execute, true)
    return btn
end

local function makeTextBox(placeholder, tabId, onApply)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, ROW_H)
    frame.BackgroundColor3 = C.row
    frame.BorderSizePixel = 0
    frame.Parent = contentScroll
    frame:SetAttribute("Tab", tabId)
    round(frame, 5)

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -100, 1, 0)
    box.Position = UDim2.new(0, 10, 0, 0)
    box.BackgroundTransparency = 1
    box.Text = ""
    box.PlaceholderText = placeholder
    box.TextColor3 = C.text
    box.PlaceholderColor3 = C.textMute
    box.Font = Enum.Font.GothamMedium
    box.TextSize = IS_MOBILE and 11 or 12
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.ClearTextOnFocus = false
    box.Parent = frame

    local apply = Instance.new("TextButton")
    apply.Size = UDim2.new(0, 80, 1, 0)
    apply.Position = UDim2.new(1, -85, 0, 0)
    apply.BackgroundColor3 = C.tabActive
    apply.BorderSizePixel = 0
    apply.Text = "ОК"
    apply.TextColor3 = C.accent
    apply.Font = Enum.Font.GothamBold
    apply.TextSize = 11
    apply.Parent = frame
    round(apply, 4)

    apply.MouseButton1Click:Connect(function() onApply(box.Text) end)
    return frame, box
end

-- ============== ПРИМЕНЕНИЕ АКЦЕНТА ==============
local function applyAccentColor(newColor)
    local old = C.accent
    if old == newColor then return end
    C.accent = newColor
    C.accentDim = Color3.new(newColor.R * 0.65, newColor.G * 0.65, newColor.B * 0.65)

    for _, d in ipairs(screenGui:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            if d.TextColor3 == old then d.TextColor3 = newColor end
        end
        if d:IsA("Frame") or d:IsA("TextButton") then
            if d.BackgroundColor3 == old then d.BackgroundColor3 = newColor end
        end
        if d:IsA("UIStroke") then
            if d.Color == old then d.Color = newColor end
        end
    end

    logoDot.BackgroundColor3 = newColor
    userDot.BackgroundColor3 = C.accentDim
    contentScroll.ScrollBarImageColor3 = C.accentDim
    fovStroke.Color = newColor
    if state.mobileMenuBtn then state.mobileMenuBtn.BackgroundColor3 = newColor end
    if state.currentTab and tabButtons[state.currentTab] then
        tabButtons[state.currentTab].BackgroundColor3 = C.tabActive
    end
end

local function applyBgImage()
    if state.configBgImageEnabled and state.configBgImage ~= "" then
        bgImage.Image = state.configBgImage
        bgImage.ImageTransparency = state.configBgImageTransparency
        bgImage.Visible = true
        content.BackgroundTransparency = 0.15
    else
        bgImage.Visible = false
        bgImage.Image = ""
        content.BackgroundTransparency = 0
    end
end

-- ============== РОЛИ ==============
local function getPlayerRole(player)
    if player.Team then
        local tn = player.Team.Name:lower()
        if tn:find("killer") or tn:find("murder") or tn:find("maniac") or tn:find("hunter") then
            return "killer"
        end
    end
    local ra = player:GetAttribute("Role") or player:GetAttribute("role")
    if ra then
        local r = tostring(ra):lower()
        if r:find("killer") or r:find("murder") or r:find("maniac") then return "killer" end
    end
    local char = player.Character
    if char then
        local cr = char:GetAttribute("Role") or char:GetAttribute("role")
        if cr then
            local r = tostring(cr):lower()
            if r:find("killer") or r:find("murder") or r:find("maniac") then return "killer" end
        end
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                local n = tool.Name:lower()
                if n:find("knife") or n:find("spear") or n:find("veil")
                   or n:find("weapon") or n:find("blade") then return "killer" end
            end
        end
    end
    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                local n = tool.Name:lower()
                if n:find("knife") or n:find("spear") or n:find("veil")
                   or n:find("weapon") or n:find("blade") then return "killer" end
            end
        end
    end
    return "survivor"
end

local function getPlayerColor(player)
    if state.roleCache[player] == "killer" then return state.killerColor end
    return state.survivorColor
end

-- ============== КЛАССИФИКАЦИЯ ==============
local function classifyObject(obj)
    local name = obj.Name:lower()
    local isBox = name:find("box") or name:find("crate") or name:find("container")
        or name:find("barrel") or name:find("chest") or name:find("locker")
        or name:find("coffin") or name:find("trash")

    local attrType = obj:GetAttribute("Type") or obj:GetAttribute("type")
    if attrType then
        local t = tostring(attrType):lower()
        if t:find("generator") then return "generator" end
        if t:find("hook") then return "hook" end
        if t:find("pallet") and not isBox then return "pallet" end
        if t:find("exit") or t:find("escape") then return "gate" end
    end

    for _, tag in ipairs(CollectionService:GetTags(obj)) do
        local t = tag:lower()
        if t:find("generator") then return "generator" end
        if t:find("hook") then return "hook" end
        if t:find("pallet") and not isBox then return "pallet" end
        if t:find("exit") or t:find("escape") then return "gate" end
    end

    if name:find("generator") or name == "gen" or name:find("fuse") then return "generator" end
    if name:find("hook") then return "hook" end
    if name:find("pallet") and not isBox then return "pallet" end
    if name:find("exit") or name:find("escape") then return "gate" end

    local pp = obj:FindFirstChildOfClass("ProximityPrompt")
    if pp then
        local t = (tostring(pp.ActionText) .. " " .. tostring(pp.ObjectText)):lower()
        if t:find("generator") or t:find("repair") or t:find("fix") then return "generator" end
        if t:find("hook") or t:find("hang") or t:find("sacrifice") then return "hook" end
        if not isBox then
            if t:find("pallet") or t:find("pull down") or t:find("drop pallet")
               or t:find("throw pallet") or t:find("use pallet") then
                return "pallet"
            end
        end
        if t:find("exit") or t:find("escape") or t:find("open gate") or t:find("побег") then return "gate" end
    end
    return nil
end

local function getWorldColor(cat)
    if cat == "generator" then return state.generatorColor end
    if cat == "hook" then return state.hookColor end
    if cat == "pallet" then return state.palletColor end
    return Color3.fromRGB(255,255,255)
end

local function getWorldEnabled(cat)
    if cat == "generator" then return state.espGenerators and state.espEnabled end
    if cat == "hook" then return state.espHooks and state.espEnabled end
    if cat == "pallet" then return state.espPallets and state.espEnabled end
    return false
end

-- ============== WORLD ESP ==============
local HIGHLIGHT_LIMIT = IS_MOBILE and 25 or 50
local highlightCount = 0

local function tryHighlightWorldObj(obj)
    if not obj or not obj.Parent then return end
    if not (obj:IsA("Model") or obj:IsA("BasePart")) then return end
    if state.highlights[obj] then return end
    if highlightCount >= HIGHLIGHT_LIMIT then return end

    local cat = classifyObject(obj)
    if not cat or cat == "gate" then return end

    local p = obj.Parent
    while p and p ~= Workspace do
        if state.highlights[p] then return end
        p = p.Parent
    end

    local hl = Instance.new("Highlight")
    hl.Name = "brieliVis_WorldESP"
    hl.Adornee = obj
    hl.FillColor = getWorldColor(cat)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.55
    hl.OutlineTransparency = 0.1
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Enabled = getWorldEnabled(cat)
    hl.Parent = obj
    state.highlights[obj] = hl
    highlightCount = highlightCount + 1
end

local function initialScan()
    local descendants = Workspace:GetDescendants()
    task.spawn(function()
        for i = 1, #descendants, SCAN_CHUNK do
            if state.unloaded then return end
            for j = i, math.min(i + SCAN_CHUNK - 1, #descendants) do
                pcall(tryHighlightWorldObj, descendants[j])
            end
            task.wait()
        end
    end)
end

local pendingQueue = {}
bind(Workspace.DescendantAdded:Connect(function(obj)
    if #pendingQueue < 200 then
        table.insert(pendingQueue, obj)
    end
end))

task.spawn(function()
    while not state.unloaded do
        task.wait(0.3)
        if #pendingQueue > 0 then
            local n = math.min(#pendingQueue, IS_MOBILE and 15 or 25)
            for i = 1, n do
                local obj = table.remove(pendingQueue, 1)
                pcall(tryHighlightWorldObj, obj)
            end
        end
    end
end)

-- ============== PLAYER ESP ==============
local function createBillboard(character)
    if state.billboards[character] then return end
    local head = character:FindFirstChild("Head")
    if not head then return end
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 180, 0, 58)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = head
    bb.Parent = head

    local nl = Instance.new("TextLabel")
    nl.Name = "NameLabel"
    nl.Size = UDim2.new(1, 0, 0, 18)
    nl.BackgroundTransparency = 1
    nl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nl.Font = Enum.Font.GothamBold
    nl.TextSize = 13
    nl.TextStrokeTransparency = 0
    nl.Parent = bb

    local dl = Instance.new("TextLabel")
    dl.Name = "DistLabel"
    dl.Size = UDim2.new(1, 0, 0, 14)
    dl.Position = UDim2.new(0, 0, 0, 18)
    dl.BackgroundTransparency = 1
    dl.TextColor3 = Color3.fromRGB(200, 200, 200)
    dl.Font = Enum.Font.Gotham
    dl.TextSize = 11
    dl.TextStrokeTransparency = 0
    dl.Parent = bb

    local hBg = Instance.new("Frame")
    hBg.Name = "HealthBg"
    hBg.Size = UDim2.new(0.85, 0, 0, 5)
    hBg.Position = UDim2.new(0.075, 0, 0, 38)
    hBg.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    hBg.BorderSizePixel = 0
    hBg.Parent = bb

    local hFill = Instance.new("Frame")
    hFill.Name = "HealthFill"
    hFill.Size = UDim2.new(1, 0, 1, 0)
    hFill.BackgroundColor3 = Color3.fromRGB(0, 220, 80)
    hFill.BorderSizePixel = 0
    hFill.Parent = hBg

    state.billboards[character] = bb
end

local function createBox2D(character)
    if state.boxes2D[character] then return end
    local box = Instance.new("Frame")
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Visible = false
    box.Parent = screenGui
    local s = Instance.new("UIStroke")
    s.Name = "BoxStroke"
    s.Color = Color3.fromRGB(255, 255, 255)
    s.Thickness = 1.5
    s.Parent = box
    state.boxes2D[character] = box
end

-- ============== SKELETON ==============
local R15_BONES = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"},
}
local R6_BONES = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}
local MAX_BONES = 14

local function createSkeleton(character)
    if state.skeletons[character] then return end
    if not drawingAvailable then return end
    local skel = {}
    for i = 1, MAX_BONES do
        local ok, line = pcall(Drawing.new, "Line")
        if ok and line then
            line.Thickness = 1.5
            line.Color = Color3.fromRGB(255, 255, 255)
            line.Transparency = 1
            line.Visible = false
            skel[i] = line
        else
            for _, l in ipairs(skel) do pcall(function() l:Remove() end) end
            return
        end
    end
    state.skeletons[character] = skel
end

local function destroySkeleton(char)
    local skel = state.skeletons[char]
    if not skel then return end
    for _, line in ipairs(skel) do pcall(function() line:Remove() end) end
    state.skeletons[char] = nil
end

-- ============== TELEPORT CORE ==============
local function teleportToCFrame(cf)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.CFrame = cf
    return true
end

local function teleportToPosition(pos)
    if not pos then return false end
    return teleportToCFrame(CFrame.new(pos + Vector3.new(0, 3, 0)))
end

local function getCharacterPosition(player)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position
end

local function findNearestObject(predicate)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local myPos = hrp.Position
    local best, bestPos, bestDist = nil, nil, math.huge

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("BasePart")) and predicate(obj) then
            local pos
            if obj:IsA("BasePart") then pos = obj.Position
            elseif obj:IsA("Model") then
                local ok, pivot = pcall(function() return obj:GetPivot().Position end)
                if ok then pos = pivot end
            end
            if pos then
                local d = (pos - myPos).Magnitude
                if d < bestDist then
                    bestDist = d
                    best = obj
                    bestPos = pos
                end
            end
        end
    end
    return best, bestPos, bestDist
end

local function scoreEscapeCandidate(obj)
    local score = 0
    local name = obj.Name:lower()
    if name:find("escape") then score = score + 100 end
    if name:find("exitzone") or name:find("exitgate") or name:find("exit_gate") then score = score + 90 end
    if name:find("^exit") then score = score + 60 end
    if name:find("gate") then score = score + 40 end
    if name:find("exit") then score = score + 30 end
    local pp = obj:FindFirstChildOfClass("ProximityPrompt")
    if pp then
        local t = (tostring(pp.ActionText) .. " " .. tostring(pp.ObjectText)):lower()
        if t:find("escape") or t:find("побег") then score = score + 80 end
        if t:find("exit") then score = score + 50 end
    end
    return score
end

local function findEscapeTrigger()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local myPos = hrp.Position
    local MIN_SCORE = 40
    local best, bestPos, bestScore, bestDist = nil, nil, 0, math.huge

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local s = scoreEscapeCandidate(obj)
            if s >= MIN_SCORE then
                local pos
                if obj:IsA("BasePart") then pos = obj.Position
                elseif obj:IsA("Model") then
                    local ok, pivot = pcall(function() return obj:GetPivot().Position end)
                    if ok then pos = pivot end
                end
                local pp = obj:FindFirstChildOfClass("ProximityPrompt")
                if pp and pp.Parent then
                    local par = pp.Parent
                    if par:IsA("BasePart") then pos = par.Position end
                end
                if pos then
                    local d = (pos - myPos).Magnitude
                    if s > bestScore or (s == bestScore and d < bestDist) then
                        bestScore = s; bestDist = d; best = obj; bestPos = pos
                    end
                end
            end
        end
    end
    return best, bestPos, bestScore, bestDist
end

-- ============== CHECKPOINT ==============
local function setCheckpointMarker(pos)
    if state.checkpointMarker then pcall(function() state.checkpointMarker:Destroy() end) end
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Size = Vector3.new(2, 2, 2)
    part.Position = pos
    part.Parent = Workspace

    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(0, 255, 100)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.4
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = part

    state.checkpointMarker = part
end

local function saveCheckpoint()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    state.checkpoint = hrp.CFrame
    setCheckpointMarker(hrp.Position)
end

local function goToCheckpoint()
    if state.checkpoint then teleportToCFrame(state.checkpoint) end
end

-- ============== АВТО-ПОБЕГ ==============
local function startAutoEscape()
    if state.autoEscapeConn then return end
    state.autoEscapeConn = RunService.Heartbeat:Connect(function()
        if state.unloaded or not state.autoEscape then return end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local inst, pos = findEscapeTrigger()
        if inst and pos and state.autoEscapeRef ~= inst then
            state.autoEscapeRef = inst
            teleportToPosition(pos)
        end
    end)
end

local function stopAutoEscape()
    if state.autoEscapeConn then
        state.autoEscapeConn:Disconnect()
        state.autoEscapeConn = nil
    end
end

-- ============== АИМБОТ ==============
local function findAimTarget()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local myRole = state.roleCache[LocalPlayer] or getPlayerRole(LocalPlayer)
    local targetRole = (myRole == "killer") and "survivor" or "killer"

    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local fovPixels = state.aimbotFovSize
    local closest, closestDist = nil, math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local pRole = state.roleCache[player] or "survivor"
        if pRole ~= targetRole then continue end
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local target = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        if not target then continue end
        local screenPos, onScreen = cam:WorldToViewportPoint(target.Position)
        if not onScreen then continue end
        local dist2d = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if dist2d <= fovPixels and dist2d < closestDist then
            closestDist = dist2d
            closest = target
        end
    end
    return closest
end

local function aimbotStep()
    if state.unloaded or not state.aimbotEnabled then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local target = findAimTarget()
    if target then
        local camPos = cam.CFrame.Position
        local lookCF = CFrame.lookAt(camPos, target.Position)
        cam.CFrame = cam.CFrame:Lerp(lookCF, IS_MOBILE and 0.45 or 0.35)
    end
end

-- ============== AVOID KILLER ==============
local function avoidKillerStep()
    if state.unloaded or not state.avoidKiller then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local killerRoot, closestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and state.roleCache[p] == "killer" then
            local c = p.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if r then
                local d = (r.Position - hrp.Position).Magnitude
                if d < closestDist then closestDist = d; killerRoot = r end
            end
        end
    end

    if killerRoot and closestDist < state.avoidKillerDistance then
        local offset = hrp.Position - killerRoot.Position
        local dir = offset.Magnitude > 0.01 and offset.Unit or Vector3.new(1, 0, 0)
        local strength = (1 - closestDist / state.avoidKillerDistance) * 120
        hrp.AssemblyLinearVelocity = Vector3.new(
            dir.X * strength,
            hrp.AssemblyLinearVelocity.Y,
            dir.Z * strength
        )
    end
end

-- ============== ЭФФЕКТЫ ==============
local function clearEffects()
    for _, e in ipairs(state.currentEffects) do pcall(function() e:Destroy() end) end
    state.currentEffects = {}
    state.effectTrail = false; state.effectParticles = false; state.effectAura = false
end

local function applyTrailEffect()
    local char = LocalPlayer.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not head or not hrp then return end
    local att0 = Instance.new("Attachment")
    att0.Position = Vector3.new(1.5, 0, 0); att0.Parent = head
    local att1 = Instance.new("Attachment")
    att1.Position = Vector3.new(-1.5, 0, 0); att1.Parent = hrp
    local trail = Instance.new("Trail")
    trail.Attachment0 = att0; trail.Attachment1 = att1
    trail.Lifetime = 0.5; trail.MinLength = 0.1
    trail.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, state.survivorColor),
        ColorSequenceKeypoint.new(1, state.killerColor),
    }
    trail.Parent = head
    table.insert(state.currentEffects, trail)
    table.insert(state.currentEffects, att0)
    table.insert(state.currentEffects, att1)
    state.effectTrail = true
end

local function applyParticlesEffect()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Rate = 25
    emitter.Lifetime = NumberRange.new(1, 2)
    emitter.Speed = NumberRange.new(2, 5)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Size = NumberSequence.new{NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)}
    emitter.Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)}
    emitter.Color = ColorSequence.new(state.survivorColor)
    emitter.LightEmission = 1
    emitter.Parent = hrp
    table.insert(state.currentEffects, emitter)
    state.effectParticles = true
end

local function applyAuraEffect()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local attachment = Instance.new("Attachment")
    attachment.Parent = hrp
    local beam = Instance.new("Beam")
    beam.Attachment0 = attachment; beam.Attachment1 = attachment
    beam.Width0 = 3; beam.Width1 = 0; beam.Lifetime = 1; beam.Segments = 10
    beam.FaceCamera = true
    beam.Color = ColorSequence.new(state.killerColor)
    beam.Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)}
    beam.Parent = hrp
    table.insert(state.currentEffects, beam)
    table.insert(state.currentEffects, attachment)
    state.effectAura = true
end

-- ============== КРУТИЛКА ==============
local function startSpin()
    if state.spinConn then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    state.originalAutoRotate = hum.AutoRotate
    hum.AutoRotate = false
    state.spinConn = RunService.RenderStepped:Connect(function(dt)
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not h or not hrp then return end
        local dir = (state.spinDirection == "left") and -1 or 1
        local step = math.rad(dt * state.spinSpeed * 9 * dir)
        hrp.CFrame = hrp.CFrame * CFrame.Angles(0, step, 0)
    end)
end

local function stopSpin()
    if state.spinConn then state.spinConn:Disconnect(); state.spinConn = nil end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.AutoRotate = state.originalAutoRotate end
end

-- ============== ТЕЛЕПОРТ UI ==============
local selectedPlayer = nil
local playerListRows = {}

local playerListFrame = Instance.new("Frame")
playerListFrame.Size = UDim2.new(1, 0, 0, 0)
playerListFrame.AutomaticSize = Enum.AutomaticSize.Y
playerListFrame.BackgroundTransparency = 1
playerListFrame.Parent = contentScroll
playerListFrame:SetAttribute("Tab", "teleport")

local plLayout = Instance.new("UIListLayout")
plLayout.Padding = UDim.new(0, 3)
plLayout.Parent = playerListFrame

local function refreshPlayerList()
    for _, row in ipairs(playerListRows) do pcall(function() row:Destroy() end) end
    playerListRows = {}
    selectedPlayer = nil
    local count = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        count = count + 1
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, 0, 0, 28)
        row.BackgroundColor3 = C.row
        row.BorderSizePixel = 0
        row.AutoButtonColor = false
        row.Text = "  " .. player.Name
        row.TextColor3 = C.text
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.Font = Enum.Font.GothamMedium
        row.TextSize = 12
        row.Parent = playerListFrame
        round(row, 4)
        row.MouseButton1Click:Connect(function()
            selectedPlayer = player
            for _, r in ipairs(playerListRows) do
                if r:IsA("TextButton") then
                    r.BackgroundColor3 = C.row
                    r.TextColor3 = C.text
                end
            end
            row.BackgroundColor3 = C.tabActive
            row.TextColor3 = C.accent
        end)
        table.insert(playerListRows, row)
    end
    if count == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 26)
        empty.BackgroundTransparency = 1
        empty.Text = "  Нет других игроков"
        empty.TextColor3 = C.textMute
        empty.TextXAlignment = Enum.TextXAlignment.Left
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 12
        empty.Parent = playerListFrame
        table.insert(playerListRows, empty)
    end
end

makeSectionLabel("К ИГРОКАМ", "teleport")
makeActionButton("Обновить список", "teleport", nil, function() refreshPlayerList() end)
makeActionButton("Телепорт к выбранному", "teleport", C.tabActive, function()
    if not selectedPlayer then return end
    local pos = getCharacterPosition(selectedPlayer)
    if pos then teleportToPosition(pos) end
end)
makeSectionLabel("ЧЕКПОИНТ", "teleport")
makeToggle("Бинды F1 / F2", state.checkpointBinds, "teleport", function(on) state.checkpointBinds = on end)
makeActionButton("Сохранить чекпоинт (F1)", "teleport", nil, function(btn)
    saveCheckpoint()
    btn.Text = "  Сохранено!"
    task.wait(1); btn.Text = "  Сохранить чекпоинт (F1)"
end)
makeActionButton("Телепорт к чекпоинту (F2)", "teleport", C.tabActive, function(btn)
    if state.checkpoint then
        goToCheckpoint()
        btn.Text = "  Готово!"; task.wait(1); btn.Text = "  Телепорт к чекпоинту (F2)"
    else
        btn.Text = "  Нет чекпоинта"; task.wait(1.5); btn.Text = "  Телепорт к чекпоинту (F2)"
    end
end)
makeActionButton("Удалить чекпоинт", "teleport", nil, function(btn)
    state.checkpoint = nil
    if state.checkpointMarker then pcall(function() state.checkpointMarker:Destroy() end); state.checkpointMarker = nil end
    btn.Text = "  Удалён"; task.wait(1); btn.Text = "  Удалить чекпоинт"
end)
makeSectionLabel("ОБЪЕКТЫ", "teleport")
makeActionButton("Телепорт к генератору", "teleport", nil, function(btn)
    local inst, pos, dist = findNearestObject(function(obj) return classifyObject(obj) == "generator" end)
    if pos then teleportToPosition(pos); btn.Text = string.format("  Готово (%.0f)", dist)
    else btn.Text = "  Не найден" end
    task.wait(1.5); btn.Text = "  Телепорт к генератору"
end)
makeActionButton("Телепорт к выходу", "teleport", nil, function(btn)
    local inst, pos = findEscapeTrigger()
    if pos then teleportToPosition(pos); btn.Text = "  Готово!"
    else btn.Text = "  Не найден" end
    task.wait(2); btn.Text = "  Телепорт к выходу"
end)
makeActionButton("СБЕЖАТЬ", "teleport", Color3.fromRGB(40, 120, 70), function(btn)
    local inst, pos = findEscapeTrigger()
    if pos then teleportToPosition(pos); btn.Text = "  СБЕЖАЛ!"
    else btn.Text = "  Не найден" end
    task.wait(2); btn.Text = "  СБЕЖАТЬ"
end)
makeToggle("Авто-побег", state.autoEscape, "teleport", function(on)
    state.autoEscape = on; state.autoEscapeRef = nil
    if on then startAutoEscape() else stopAutoEscape() end
end)
makeActionButton("Сбросить авто-побег", "teleport", nil, function(btn)
    state.autoEscapeRef = nil
    btn.Text = "  Сброшено"; task.wait(1); btn.Text = "  Сбросить авто-побег"
end)

bind(Players.PlayerAdded:Connect(function() task.wait(0.3) refreshPlayerList() end))
bind(Players.PlayerRemoving:Connect(function() task.wait(0.3) refreshPlayerList() end))
bind(LocalPlayer.CharacterAdded:Connect(function() state.autoEscapeRef = nil end))
refreshPlayerList()

-- ============== РЕНДЕР (с троттлингом) ==============
local renderAcc = 0

local renderConn = RunService.RenderStepped:Connect(function(dt)
    if state.unloaded then return end
    renderAcc = renderAcc + dt
    if renderAcc < RENDER_INTERVAL then return end
    renderAcc = 0

    local cam = Workspace.CurrentCamera
    if not cam then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end

        local role = state.roleCache[player] or "survivor"
        local col = getPlayerColor(player)
        local head = char:FindFirstChild("Head")
        local root = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local espOn = state.espEnabled

        local hl = state.highlights[char]
        if hl and hl.Parent and hl.Name == "brieliVis_PlayerESP" then
            hl.FillColor = col
            hl.Enabled = espOn and state.chams
            hl.FillTransparency = 0.2
            hl.OutlineTransparency = 0
        end

        if espOn and head and root then
            if not state.billboards[char] then createBillboard(char) end
            local bb = state.billboards[char]
            if bb then
                bb.Enabled = true
                local nl = bb:FindFirstChild("NameLabel")
                local dl = bb:FindFirstChild("DistLabel")
                local hBg = bb:FindFirstChild("HealthBg")
                local hFill = hBg and hBg:FindFirstChild("HealthFill")
                if nl then
                    if state.showName then
                        local prefix = state.showKillerTag and (role == "killer" and "[KILLER] " or "[SURV] ") or ""
                        nl.Text = prefix .. player.Name
                        nl.TextColor3 = col
                        nl.Visible = true
                    else nl.Visible = false end
                end
                if dl then
                    if state.showDistance then
                        local dist = (root.Position - cam.CFrame.Position).Magnitude
                        dl.Text = string.format("%.0f", dist)
                        dl.Visible = true
                    else dl.Visible = false end
                end
                if hBg and hFill and humanoid then
                    hBg.Visible = state.showHealthBar
                    if state.showHealthBar then
                        local hp = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                        hFill.Size = UDim2.new(hp, 0, 1, 0)
                        hFill.BackgroundColor3 = hp > 0.4 and Color3.fromRGB(0, 220, 80) or Color3.fromRGB(220, 60, 60)
                    end
                end
            end
        elseif state.billboards[char] then
            state.billboards[char].Enabled = false
        end

        if espOn and state.box2D and head and root then
            if not state.boxes2D[char] then createBox2D(char) end
            local box = state.boxes2D[char]
            if box then
                local tp, tOn = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 1, 0))
                local bp, bOn = cam:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                if tOn and bOn then
                    local h = math.abs(bp.Y - tp.Y)
                    local w = h * 0.55
                    box.Size = UDim2.new(0, w, 0, h)
                    box.Position = UDim2.new(0, tp.X - w/2, 0, tp.Y)
                    box.Visible = true
                    local s = box:FindFirstChild("BoxStroke")
                    if s then s.Color = col end
                else box.Visible = false end
            end
        elseif state.boxes2D[char] then
            state.boxes2D[char].Visible = false
        end

        if espOn and state.skeleton and drawingAvailable then
            if not state.skeletons[char] then createSkeleton(char) end
            local skel = state.skeletons[char]
            if skel then
                local bones
                if char:FindFirstChild("UpperTorso") then bones = R15_BONES
                elseif char:FindFirstChild("Torso") then bones = R6_BONES end
                if bones then
                    for i, bone in ipairs(bones) do
                        local line = skel[i]
                        if line then
                            local p1 = char:FindFirstChild(bone[1])
                            local p2 = char:FindFirstChild(bone[2])
                            if p1 and p2 then
                                local s1, o1 = cam:WorldToViewportPoint(p1.Position)
                                local s2, o2 = cam:WorldToViewportPoint(p2.Position)
                                if o1 and o2 then
                                    line.From = Vector2.new(s1.X, s1.Y)
                                    line.To = Vector2.new(s2.X, s2.Y)
                                    line.Color = col
                                    line.Visible = true
                                else line.Visible = false end
                            else line.Visible = false end
                        end
                    end
                    for i = #bones + 1, MAX_BONES do
                        if skel[i] then skel[i].Visible = false end
                    end
                else
                    for _, line in ipairs(skel) do line.Visible = false end
                end
            end
        elseif state.skeletons[char] then
            for _, line in ipairs(state.skeletons[char]) do line.Visible = false end
        end
    end
end)

-- Кэш ролей
task.spawn(function()
    while not state.unloaded do
        for _, p in ipairs(Players:GetPlayers()) do
            state.roleCache[p] = getPlayerRole(p)
        end
        task.wait(ROLE_UPDATE)
    end
end)

-- Аимбот + FOV circle
pcall(function()
    RunService:BindToRenderStep("brieliVis_Aimbot",
        Enum.RenderPriority.Camera.Value + 1,
        function()
            if state.unloaded then return end
            fovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
            fovCircle.Size = UDim2.new(0, state.aimbotFovSize * 2, 0, state.aimbotFovSize * 2)
            fovCircle.Visible = state.aimbotEnabled and state.aimbotShowFov
            aimbotStep()
        end)
end)

state.avoidConn = RunService.Heartbeat:Connect(avoidKillerStep)

-- ============== NOCLIP ==============
local floorRayParams = RaycastParams.new()
floorRayParams.FilterType = Enum.RaycastFilterType.Exclude

local function noclipStep()
    if state.unloaded then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            state.savedCollide[part] = true
            part.CanCollide = false
        end
    end

    floorRayParams.FilterDescendantsInstances = {char}
    local origin = hrp.Position + Vector3.new(0, 1, 0)
    local ray = Workspace:Raycast(origin, Vector3.new(0, -10, 0), floorRayParams)
    if ray then
        local floorY = ray.Position.Y + hum.HipHeight + hrp.Size.Y / 2
        if hrp.Position.Y < floorY + 0.3 and hrp.AssemblyLinearVelocity.Y < 0.1 then
            hrp.CFrame = CFrame.new(hrp.Position.X, floorY, hrp.Position.Z)
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
        end
    end
end

local function enableNoclip()
    if state.noclipConn then return end
    state.savedCollide = {}
    state.noclipConn = RunService.Stepped:Connect(noclipStep)
end

local function disableNoclip()
    if state.noclipConn then state.noclipConn:Disconnect(); state.noclipConn = nil end
    for part, _ in pairs(state.savedCollide) do
        if part and part.Parent then pcall(function() part.CanCollide = true end) end
    end
    state.savedCollide = {}
end

-- ============== LIGHTING ==============
local savedLighting = nil
local function saveLighting()
    if savedLighting then return end
    savedLighting = {
        Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
        GlobalShadows = Lighting.GlobalShadows,
        ExposureCompensation = Lighting.ExposureCompensation,
    }
end
local function setFullbright(on)
    if on then
        saveLighting()
        Lighting.Ambient = Color3.fromRGB(200, 200, 200)
        Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
        Lighting.Brightness = 2
        Lighting.ClockTime = 12
        Lighting.GlobalShadows = false
        Lighting.ExposureCompensation = 0.2
    elseif savedLighting then
        for k, v in pairs(savedLighting) do pcall(function() Lighting[k] = v end) end
    end
end
local function setNoFog(on)
    if on then
        saveLighting()
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
    elseif savedLighting then
        Lighting.FogEnd = savedLighting.FogEnd or 1000
        Lighting.FogStart = savedLighting.FogStart or 0
    end
end
local function setNoShadows(on)
    if on then saveLighting(); Lighting.GlobalShadows = false
    elseif savedLighting then Lighting.GlobalShadows = savedLighting.GlobalShadows end
end

-- ============== ИГРОКИ ==============
local function setupPlayer(player)
    if player == LocalPlayer then return end
    local function onChar(char)
        task.wait(0.3)
        if state.unloaded then return end
        local hl = Instance.new("Highlight")
        hl.Name = "brieliVis_PlayerESP"
        hl.Adornee = char
        hl.FillColor = getPlayerColor(player)
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.2
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Enabled = state.espEnabled and state.chams
        hl.Parent = char
        state.highlights[char] = hl
    end
    if player.Character then onChar(player.Character) end
    bind(player.CharacterAdded:Connect(onChar))
    bind(player.CharacterRemoving:Connect(function(char)
        if state.highlights[char] then state.highlights[char]:Destroy(); state.highlights[char] = nil end
        if state.billboards[char] then state.billboards[char]:Destroy(); state.billboards[char] = nil end
        if state.boxes2D[char] then state.boxes2D[char]:Destroy(); state.boxes2D[char] = nil end
        destroySkeleton(char)
    end))
end

for _, p in ipairs(Players:GetPlayers()) do setupPlayer(p) end
bind(Players.PlayerAdded:Connect(setupPlayer))

-- ============== ВКЛАДКА ВИЗУАЛЬНЫЕ ==============
makeSectionLabel("ESP", "visuals")
makeMasterToggle("ESP (раздел)", state.espEnabled, "visuals", function(on)
    state.espEnabled = on
    for _, hl in pairs(state.highlights) do
        if hl.Name == "brieliVis_PlayerESP" then hl.Enabled = on and state.chams end
        if hl.Name == "brieliVis_WorldESP" and hl.Adornee then
            local cat = classifyObject(hl.Adornee)
            if cat then hl.Enabled = on and getWorldEnabled(cat) end
        end
    end
    if not on then
        for _, bb in pairs(state.billboards) do bb.Enabled = false end
        for _, box in pairs(state.boxes2D) do box.Visible = false end
        for _, skel in pairs(state.skeletons) do
            for _, line in ipairs(skel) do line.Visible = false end
        end
    end
end)
makeSectionLabel("ИГРОКИ", "visuals")
makeToggle("Ник", state.showName, "visuals", function(on) state.showName = on end)
makeToggle("Дистанция", state.showDistance, "visuals", function(on) state.showDistance = on end)
makeToggle("Полоса HP", state.showHealthBar, "visuals", function(on) state.showHealthBar = on end)
makeToggle("Метка роли", state.showKillerTag, "visuals", function(on) state.showKillerTag = on end)
makeToggle("Chams (заливка)", state.chams, "visuals", function(on)
    state.chams = on
    for _, hl in pairs(state.highlights) do
        if hl.Name == "brieliVis_PlayerESP" then hl.Enabled = state.espEnabled and on end
    end
end)
makeToggle("2D Box", state.box2D, "visuals", function(on)
    state.box2D = on
    if not on then for _, box in pairs(state.boxes2D) do box.Visible = false end end
end)
makeToggle("Скелет", state.skeleton, "visuals", function(on)
    state.skeleton = on
    if not on then
        for _, skel in pairs(state.skeletons) do
            for _, line in ipairs(skel) do line.Visible = false end
        end
    end
end)
makeSectionLabel("ОБЪЕКТЫ МИРА", "visuals")
makeToggle("Генераторы", state.espGenerators, "visuals", function(on)
    state.espGenerators = on
    for inst, hl in pairs(state.highlights) do
        if hl.Name == "brieliVis_WorldESP" and classifyObject(inst) == "generator" then
            hl.Enabled = on and state.espEnabled
        end
    end
end)
makeToggle("Крюки", state.espHooks, "visuals", function(on)
    state.espHooks = on
    for inst, hl in pairs(state.highlights) do
        if hl.Name == "brieliVis_WorldESP" and classifyObject(inst) == "hook" then
            hl.Enabled = on and state.espEnabled
        end
    end
end)
makeToggle("Поддоны", state.espPallets, "visuals", function(on)
    state.espPallets = on
    for inst, hl in pairs(state.highlights) do
        if hl.Name == "brieliVis_WorldESP" and classifyObject(inst) == "pallet" then
            hl.Enabled = on and state.espEnabled
        end
    end
end)
makeSectionLabel("ЦВЕТА", "visuals")
makeColorButton("Цвет выживших", state.survivorColor, "visuals", function(col) state.survivorColor = col end)
makeColorButton("Цвет убийцы", state.killerColor, "visuals", function(col) state.killerColor = col end)
makeColorButton("Цвет генераторов", state.generatorColor, "visuals", function(col)
    state.generatorColor = col
    for inst, hl in pairs(state.highlights) do
        if hl.Name == "brieliVis_WorldESP" and classifyObject(inst) == "generator" then hl.FillColor = col end
    end
end)
makeColorButton("Цвет крюков", state.hookColor, "visuals", function(col)
    state.hookColor = col
    for inst, hl in pairs(state.highlights) do
        if hl.Name == "brieliVis_WorldESP" and classifyObject(inst) == "hook" then hl.FillColor = col end
    end
end)
makeColorButton("Цвет поддонов", state.palletColor, "visuals", function(col)
    state.palletColor = col
    for inst, hl in pairs(state.highlights) do
        if hl.Name == "brieliVis_WorldESP" and classifyObject(inst) == "pallet" then hl.FillColor = col end
    end
end)

-- ============== ВКЛАДКА МИР ==============
makeSectionLabel("ОСВЕЩЕНИЕ", "world")
makeToggle("Fullbright", state.fullbright, "world", function(on)
    state.fullbright = on; setFullbright(on)
end)
makeToggle("Убрать туман", state.noFog, "world", function(on)
    state.noFog = on; setNoFog(on)
end)
makeToggle("Убрать тени", state.noShadows, "world", function(on)
    state.noShadows = on; setNoShadows(on)
end)
makeSectionLabel("КАМЕРА", "world")
makeSlider("FOV", 60, 120, state.fovValue, "world", function(val)
    state.fovValue = val
    if Workspace.CurrentCamera then Workspace.CurrentCamera.FieldOfView = val end
end)
makeSectionLabel("HUD", "world")
makeToggle("Оповещение об убийце", state.killerAlert, "world", function(on)
    state.killerAlert = on
    if not on then alertGui.Visible = false end
end)

-- ============== ВКЛАДКА КОСМЕТИКА ==============
makeSectionLabel("ЭФФЕКТЫ", "cosmetics")
makeToggle("Трейл (шлейф)", state.effectTrail, "cosmetics", function(on)
    state.effectTrail = on
    if on then applyTrailEffect() else
        for _, e in ipairs(state.currentEffects) do
            if e.Name == "brieliVis_Trail" or e.Name:find("brieliVis_TrailAtt") then
                pcall(function() e:Destroy() end)
            end
        end
    end
end)
makeToggle("Частицы (искры)", state.effectParticles, "cosmetics", function(on)
    state.effectParticles = on
    if on then applyParticlesEffect() else
        for _, e in ipairs(state.currentEffects) do
            if e.Name == "brieliVis_Particles" then pcall(function() e:Destroy() end) end
        end
    end
end)
makeToggle("Аура (луч)", state.effectAura, "cosmetics", function(on)
    state.effectAura = on
    if on then applyAuraEffect() else
        for _, e in ipairs(state.currentEffects) do
            if e.Name == "brieliVis_Aura" or e.Name == "brieliVis_AuraAtt" then
                pcall(function() e:Destroy() end)
            end
        end
    end
end)
makeActionButton("Убрать все эффекты", "cosmetics", nil, function() clearEffects() end)

-- ============== ВКЛАДКА РАЗНОЕ ==============
makeSectionLabel("ДВИЖЕНИЕ", "misc")
makeToggle("Noclip (сквозь стены)", state.noclip, "misc", function(on)
    state.noclip = on
    if on then enableNoclip() else disableNoclip() end
end)

makeSectionLabel("ИЗБЕГАНИЕ МАНЬЯКА", "misc")
makeMasterToggle("Избегание маньяка", state.avoidKiller, "misc", function(on)
    state.avoidKiller = on
end)
makeSlider("Дистанция (studs)", 1, 100, state.avoidKillerDistance, "misc", function(val)
    state.avoidKillerDistance = val
end)

makeSectionLabel("АИМБОТ", "misc")
makeMasterToggle("Aimbot", state.aimbotEnabled, "misc", function(on)
    state.aimbotEnabled = on
    if not on then fovCircle.Visible = false end
end)
makeToggle("Показывать FOV", state.aimbotShowFov, "misc", function(on)
    state.aimbotShowFov = on
    if not on then fovCircle.Visible = false end
end)
makeSlider("Размер FOV", 20, 500, state.aimbotFovSize, "misc", function(val)
    state.aimbotFovSize = val
    fovCircle.Size = UDim2.new(0, val * 2, 0, val * 2)
end)

makeSectionLabel("КРУТИЛКА", "misc")
makeToggle("Включить вращение", state.spinEnabled, "misc", function(on)
    state.spinEnabled = on
    if on then startSpin() else stopSpin() end
end)

local spinDirFrame = Instance.new("Frame")
spinDirFrame.Size = UDim2.new(1, 0, 0, 50)
spinDirFrame.BackgroundColor3 = C.row
spinDirFrame.BorderSizePixel = 0
spinDirFrame.Parent = contentScroll
spinDirFrame:SetAttribute("Tab", "misc")
round(spinDirFrame, 5)

local spinDirLabel = Instance.new("TextLabel")
spinDirLabel.Size = UDim2.new(1, -14, 0, 20)
spinDirLabel.Position = UDim2.new(0, 14, 0, 4)
spinDirLabel.BackgroundTransparency = 1
spinDirLabel.Text = "Направление"
spinDirLabel.TextColor3 = C.text
spinDirLabel.TextXAlignment = Enum.TextXAlignment.Left
spinDirLabel.Font = Enum.Font.GothamMedium
spinDirLabel.TextSize = 12
spinDirLabel.Parent = spinDirFrame

local dirRightBtn = Instance.new("TextButton")
dirRightBtn.Size = UDim2.new(0, 100, 0, 22)
dirRightBtn.Position = UDim2.new(0, 14, 0, 26)
dirRightBtn.BackgroundColor3 = C.tabActive
dirRightBtn.BorderSizePixel = 0
dirRightBtn.Text = "Вправо"
dirRightBtn.TextColor3 = C.accent
dirRightBtn.Font = Enum.Font.GothamMedium
dirRightBtn.TextSize = 11
dirRightBtn.Parent = spinDirFrame
round(dirRightBtn, 4)

local dirLeftBtn = Instance.new("TextButton")
dirLeftBtn.Size = UDim2.new(0, 100, 0, 22)
dirLeftBtn.Position = UDim2.new(0, 120, 0, 26)
dirLeftBtn.BackgroundColor3 = C.rowHover
dirLeftBtn.BorderSizePixel = 0
dirLeftBtn.Text = "Влево"
dirLeftBtn.TextColor3 = C.textDim
dirLeftBtn.Font = Enum.Font.GothamMedium
dirLeftBtn.TextSize = 11
dirLeftBtn.Parent = spinDirFrame
round(dirLeftBtn, 4)

dirRightBtn.MouseButton1Click:Connect(function()
    state.spinDirection = "right"
    dirRightBtn.BackgroundColor3 = C.tabActive; dirRightBtn.TextColor3 = C.accent
    dirLeftBtn.BackgroundColor3 = C.rowHover; dirLeftBtn.TextColor3 = C.textDim
end)
dirLeftBtn.MouseButton1Click:Connect(function()
    state.spinDirection = "left"
    dirLeftBtn.BackgroundColor3 = C.tabActive; dirLeftBtn.TextColor3 = C.accent
    dirRightBtn.BackgroundColor3 = C.rowHover; dirRightBtn.TextColor3 = C.textDim
end)

makeSlider("Скорость вращения", 40, 240, state.spinSpeed, "misc", function(val)
    state.spinSpeed = val
end)

-- ============== ВКЛАДКА МЕНЮ ==============
makeSectionLabel("КЛАВИША МЕНЮ", "menu")

local keybindBtn = Instance.new("TextButton")
keybindBtn.Size = UDim2.new(1, 0, 0, ROW_H)
keybindBtn.BackgroundColor3 = C.row
keybindBtn.BorderSizePixel = 0
keybindBtn.AutoButtonColor = false
keybindBtn.Text = "  Изменить клавишу (" .. state.menuKey.Name .. ")"
keybindBtn.TextColor3 = C.text
keybindBtn.TextXAlignment = Enum.TextXAlignment.Left
keybindBtn.Font = Enum.Font.GothamMedium
keybindBtn.TextSize = IS_MOBILE and 11 or 12
keybindBtn.Parent = contentScroll
keybindBtn:SetAttribute("Tab", "menu")
round(keybindBtn, 5)

local listeningForKey = false
keybindBtn.MouseButton1Click:Connect(function()
    if listeningForKey then return end
    listeningForKey = true
    keybindBtn.Text = "  Нажмите клавишу..."
    local conn
    conn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            state.menuKey = input.KeyCode
            keybindBtn.Text = "  Изменить клавишу (" .. input.KeyCode.Name .. ")"
            listeningForKey = false
            conn:Disconnect()
        end
    end)
end)

makeSectionLabel("ЦВЕТ АКЦЕНТА", "menu")
local accentPresets = {
    { name = "Cyan",   color = Color3.fromRGB(0, 200, 255) },
    { name = "Purple", color = Color3.fromRGB(170, 110, 255) },
    { name = "Red",    color = Color3.fromRGB(255, 80, 80) },
    { name = "Green",  color = Color3.fromRGB(80, 230, 130) },
    { name = "Pink",   color = Color3.fromRGB(255, 110, 200) },
    { name = "Orange", color = Color3.fromRGB(255, 165, 30) },
}
for _, preset in ipairs(accentPresets) do
    local btn = makeActionButton(preset.name, "menu", nil, function()
        state.configAccent = preset.color
        applyAccentColor(preset.color)
    end)
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 14, 0, 14)
    dot.Position = UDim2.new(1, -24, 0.5, -7)
    dot.BackgroundColor3 = preset.color
    dot.BorderSizePixel = 0
    dot.Parent = btn
    round(dot, 7)
end

makeSectionLabel("ФОНОВОЕ ИЗОБРАЖЕНИЕ", "menu")
local bgBoxFrame, bgBox = makeTextBox("URL или rbxassetid://...", "menu", function(text)
    state.configBgImage = text
    applyBgImage()
end)
makeToggle("Показывать фон", state.configBgImageEnabled, "menu", function(on)
    state.configBgImageEnabled = on
    applyBgImage()
end)
makeSlider("Прозрачность фона", 0, 1, state.configBgImageTransparency, "menu", function(val)
    state.configBgImageTransparency = val
    bgImage.ImageTransparency = val
end, 0.05)
makeActionButton("Убрать фон", "menu", Color3.fromRGB(140, 35, 35), function()
    state.configBgImage = ""; state.configBgImageEnabled = false
    bgImage.Image = ""; bgImage.Visible = false
    content.BackgroundTransparency = 0
    if bgBox then bgBox.Text = "" end
end)

makeSectionLabel("ОБСЛУЖИВАНИЕ", "menu")
makeActionButton("Пересканировать мир", "menu", nil, function(btn)
    for inst, hl in pairs(state.highlights) do
        if hl.Name == "brieliVis_WorldESP" then
            hl:Destroy(); state.highlights[inst] = nil; highlightCount = math.max(0, highlightCount - 1)
        end
    end
    initialScan()
    btn.Text = "  Готово!"; task.wait(1.5); btn.Text = "  Пересканировать мир"
end)
makeActionButton("Сохранить конфиг", "menu", nil, function(btn)
    saveConfig(); btn.Text = "  Сохранено!"; task.wait(1); btn.Text = "  Сохранить конфиг"
end)
makeActionButton("Сбросить конфиг", "menu", Color3.fromRGB(140, 35, 35), function(btn)
    fsDelete(CONFIG_FILE); btn.Text = "  Удалён. Перезапусти"; task.wait(2); btn.Text = "  Сбросить конфиг"
end)

local unloadBtn = Instance.new("TextButton")
unloadBtn.Size = UDim2.new(0, 130, 0, 30)
unloadBtn.Position = UDim2.new(1, -14, 1, -14)
unloadBtn.AnchorPoint = Vector2.new(1, 1)
unloadBtn.BackgroundColor3 = Color3.fromRGB(140, 35, 35)
unloadBtn.BorderSizePixel = 0
unloadBtn.AutoButtonColor = false
unloadBtn.Text = "Выгрузить"
unloadBtn.TextColor3 = Color3.fromRGB(255, 220, 220)
unloadBtn.Font = Enum.Font.GothamMedium
unloadBtn.TextSize = 12
unloadBtn.Parent = main
round(unloadBtn, 5)

-- ============== ОПОВЕЩЕНИЕ ==============
local alertGui = Instance.new("TextLabel")
alertGui.Size = UDim2.new(0, 280, 0, 40)
alertGui.Position = UDim2.new(0.5, -140, 0, 60)
alertGui.BackgroundColor3 = Color3.fromRGB(180, 25, 25)
alertGui.BackgroundTransparency = 0.1
alertGui.Text = "РЯДОМ УБИЙЦА"
alertGui.TextColor3 = Color3.fromRGB(255, 255, 255)
alertGui.Font = Enum.Font.GothamBold
alertGui.TextSize = 15
alertGui.Visible = false
alertGui.Parent = screenGui
round(alertGui, 6)

-- ============== ПРИМЕНЕНИЕ КОНФИГА ==============
local function applyLoadedConfig(cfg)
    if not cfg then return end
    state.loadingConfig = true

    if cfg.espEnabled ~= nil then state.espEnabled = cfg.espEnabled end
    if cfg.showName ~= nil then state.showName = cfg.showName end
    if cfg.showDistance ~= nil then state.showDistance = cfg.showDistance end
    if cfg.showHealthBar ~= nil then state.showHealthBar = cfg.showHealthBar end
    if cfg.showKillerTag ~= nil then state.showKillerTag = cfg.showKillerTag end
    if cfg.chams ~= nil then state.chams = cfg.chams end
    if cfg.box2D ~= nil then state.box2D = cfg.box2D end
    if cfg.skeleton ~= nil then state.skeleton = cfg.skeleton end
    if cfg.espGenerators ~= nil then state.espGenerators = cfg.espGenerators end
    if cfg.espHooks ~= nil then state.espHooks = cfg.espHooks end
    if cfg.espPallets ~= nil then state.espPallets = cfg.espPallets end
    if cfg.fullbright ~= nil then state.fullbright = cfg.fullbright end
    if cfg.noFog ~= nil then state.noFog = cfg.noFog end
    if cfg.noShadows ~= nil then state.noShadows = cfg.noShadows end
    if cfg.fovValue ~= nil then state.fovValue = cfg.fovValue end
    if cfg.killerAlert ~= nil then state.killerAlert = cfg.killerAlert end
    if cfg.checkpointBinds ~= nil then state.checkpointBinds = cfg.checkpointBinds end
    if cfg.spinSpeed ~= nil then state.spinSpeed = cfg.spinSpeed end
    if cfg.spinDirection ~= nil then state.spinDirection = cfg.spinDirection end
    if cfg.autoEscape ~= nil then state.autoEscape = cfg.autoEscape end
    if cfg.aimbotEnabled ~= nil then state.aimbotEnabled = cfg.aimbotEnabled end
    if cfg.aimbotShowFov ~= nil then state.aimbotShowFov = cfg.aimbotShowFov end
    if cfg.aimbotFovSize ~= nil then state.aimbotFovSize = cfg.aimbotFovSize end
    if cfg.avoidKiller ~= nil then state.avoidKiller = cfg.avoidKiller end
    if cfg.avoidKillerDistance ~= nil then state.avoidKillerDistance = cfg.avoidKillerDistance end
    if cfg.menuKeyName then
        local ok, key = pcall(function() return Enum.KeyCode[cfg.menuKeyName] end)
        if ok and key then state.menuKey = key end
    end

    local sc = colorFromTable(cfg.survivorColor); if sc then state.survivorColor = sc end
    local kc = colorFromTable(cfg.killerColor); if kc then state.killerColor = kc end
    local gc = colorFromTable(cfg.generatorColor); if gc then state.generatorColor = gc end
    local hc = colorFromTable(cfg.hookColor); if hc then state.hookColor = hc end
    local pc = colorFromTable(cfg.palletColor); if pc then state.palletColor = pc end

    if cfg.configAccent then
        local ac = colorFromTable(cfg.configAccent)
        if ac then state.configAccent = ac; applyAccentColor(ac) end
    end
    if cfg.configBgImage then state.configBgImage = cfg.configBgImage end
    if cfg.configBgImageEnabled ~= nil then state.configBgImageEnabled = cfg.configBgImageEnabled end
    if cfg.configBgImageTransparency ~= nil then state.configBgImageTransparency = cfg.configBgImageTransparency end

    if state.fovValue ~= 90 and Workspace.CurrentCamera then
        Workspace.CurrentCamera.FieldOfView = state.fovValue
    end
    if state.fullbright then setFullbright(true) end
    if state.noFog then setNoFog(true) end
    if state.noShadows then setNoShadows(true) end
    if state.autoEscape then startAutoEscape() end

    fovCircle.Size = UDim2.new(0, state.aimbotFovSize * 2, 0, state.aimbotFovSize * 2)
    applyBgImage()

    if cfg.keybinds then
        for label, keyName in pairs(cfg.keybinds) do
            local data = keybindRegistry[label]
            if data then
                local ok, key = pcall(function() return Enum.KeyCode[keyName] end)
                if ok and key then
                    data.key = key
                    if data.indicator then data.indicator.Text = "[" .. keyName .. "]" end
                end
            end
        end
    end

    state.loadingConfig = false
end

-- ============== ВЫГРУЗКА ==============
local function unload()
    if state.unloaded then return end
    state.unloaded = true
    pcall(saveConfig)

    for _, c in ipairs(state.connections) do pcall(function() c:Disconnect() end) end
    state.connections = {}
    if renderConn then renderConn:Disconnect() end
    if state.avoidConn then state.avoidConn:Disconnect() end
    pcall(function() RunService:UnbindFromRenderStep("brieliVis_Aimbot") end)
    pcall(stopSpin); pcall(stopAutoEscape); pcall(disableNoclip); pcall(clearEffects)

    pcall(function()
        ContextActionSvc:UnbindAction("brieliVis_Checkpoint_Save")
        ContextActionSvc:UnbindAction("brieliVis_Checkpoint_Go")
    end)

    if state.checkpointMarker then pcall(function() state.checkpointMarker:Destroy() end) end
    for _, hl in pairs(state.highlights) do pcall(function() hl:Destroy() end) end
    state.highlights = {}
    for _, bb in pairs(state.billboards) do pcall(function() bb:Destroy() end) end
    state.billboards = {}
    for _, box in pairs(state.boxes2D) do pcall(function() box:Destroy() end) end
    state.boxes2D = {}
    for _, skel in pairs(state.skeletons) do
        for _, line in ipairs(skel) do pcall(function() line:Remove() end) end
    end
    state.skeletons = {}

    pcall(setFullbright, false); pcall(setNoFog, false); pcall(setNoShadows, false)
    if alertGui then pcall(function() alertGui:Destroy() end) end
    if screenGui then pcall(function() screenGui:Destroy() end) end

    _G.brieliVisUnload = nil
    print("[brieli vis] выгружен")
end

unloadBtn.MouseButton1Click:Connect(unload)
_G.brieliVisUnload = unload

-- ============== ПЕРЕКЛЮЧЕНИЕ МЕНЮ (ПК) ==============
bind(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == state.menuKey then
        main.Visible = not main.Visible
        if state.mobileMenuBtn then state.mobileMenuBtn.Visible = not main.Visible end
    end
end))

-- ============== F1 / F2 ==============
ContextActionSvc:BindActionAtPriority("brieliVis_Checkpoint_Save",
    function(_, inputState)
        if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
        if not state.checkpointBinds then return Enum.ContextActionResult.Pass end
        saveCheckpoint()
        return Enum.ContextActionResult.Sink
    end,
    false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.F1)

ContextActionSvc:BindActionAtPriority("brieliVis_Checkpoint_Go",
    function(_, inputState)
        if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
        if not state.checkpointBinds then return Enum.ContextActionResult.Pass end
        goToCheckpoint()
        return Enum.ContextActionResult.Sink
    end,
    false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.F2)

-- ============== СТАРТ ==============
local loadedCfg = loadConfigTable()
if loadedCfg then
    task.spawn(function()
        task.wait(0.3)
        applyLoadedConfig(loadedCfg)
    end)
end

initialScan()
switchTab("visuals")

-- Автосохранение (реже на мобилке)
task.spawn(function()
    while not state.unloaded do
        task.wait(IS_MOBILE and 6 or 3)
        if not state.unloaded and not state.loadingConfig then
            pcall(saveConfig)
        end
    end
end)

-- Оповещение
task.spawn(function()
    while not state.unloaded do
        task.wait(1)
        if not state.unloaded and state.killerAlert then
            local mc = LocalPlayer.Character
            local mr = mc and mc:FindFirstChild("HumanoidRootPart")
            if mr then
                local closest = math.huge
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and state.roleCache[p] == "killer" then
                        local c = p.Character
                        local r = c and c:FindFirstChild("HumanoidRootPart")
                        if r then
                            local d = (r.Position - mr.Position).Magnitude
                            if d < closest then closest = d end
                        end
                    end
                end
                alertGui.Visible = (closest < 70)
            else
                alertGui.Visible = false
            end
        else
            alertGui.Visible = false
        end
    end
end)

print("[brieli vis] загружен. " .. (IS_MOBILE and "Кнопка ≡ слева" or "Правый Shift — меню."))
