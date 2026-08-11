--[[
    Speed Boost Script for Roblox Executor
    WalkSpeed + Fly + Noclip + GUI
    Version: 2.5
]]

local SCRIPT_VERSION = "2.5"
local MENU_ICON_URL = "https://raw.githubusercontent.com/Patr1k66/roblox-speed-script/main/assets/menu_icon.png"

local Config = {
    DefaultWalkSpeed = 50,
    MinWalkSpeed = 16,
    MaxWalkSpeed = 200,
    FlySpeed = 50,
    DefaultCPS = 10,
    MinCPS = 1,
    MaxCPS = 30,
    Hotkeys = {
        Fly = Enum.KeyCode.F,
        Noclip = Enum.KeyCode.N,
        ToggleGUI = Enum.KeyCode.RightShift,
        AutoClick = Enum.KeyCode.C,
        PickClickPos = Enum.KeyCode.P,
    },
}

local Hotkeys = {
    Fly = Config.Hotkeys.Fly,
    Noclip = Config.Hotkeys.Noclip,
    ToggleGUI = Config.Hotkeys.ToggleGUI,
    AutoClick = Config.Hotkeys.AutoClick,
    PickClickPos = Config.Hotkeys.PickClickPos,
}

local bindNames = { "ToggleGUI", "Fly", "Noclip", "AutoClick", "PickClickPos" }
local bindLabels = {
    ToggleGUI = "Меню",
    Fly = "Fly",
    Noclip = "Noclip",
    AutoClick = "AutoClick",
    PickClickPos = "Pick spot",
}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local viewportSize = Camera and Camera.ViewportSize or Vector2.new(1280, 720)

-- State
local State = {
    speedEnabled = true,
    targetWalkSpeed = Config.DefaultWalkSpeed,
    flyEnabled = false,
    noclipEnabled = false,
    guiVisible = true,
    settingsOpen = false,
    autoClickEnabled = false,
    autoClickCPS = Config.DefaultCPS,
    clickPosition = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2),
    pickingClickPosition = false,
}

local rebindTarget = nil
local rebindButton = nil

local character = LocalPlayer.Character
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
local rootPart = character and character:FindFirstChild("HumanoidRootPart")

local connections = {}
local flyBodyVelocity = nil
local flyBodyGyro = nil
local lastAutoClickTime = 0
local clickMarker, pickOverlay, autoClickBtn, clickPosLabel, cpsLabel, cpsSlider, cpsFill, cpsKnob

-- Executor compatibility: parent GUI to hidden UI
local function getParentGui()
    if gethui then
        return gethui()
    end
    if syn and syn.protect_gui then
        return game:GetService("CoreGui")
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function cleanupPrevious()
    if getgenv and getgenv().SpeedBoostCleanup then
        pcall(getgenv().SpeedBoostCleanup)
    end

    local parent = getParentGui()
    local oldGui = parent:FindFirstChild("SpeedBoostGUI")
    if oldGui then
        oldGui:Destroy()
    end
end

cleanupPrevious()

local function disconnectAll()
    for _, conn in connections do
        conn:Disconnect()
    end
    table.clear(connections)
end

local function track(conn)
    table.insert(connections, conn)
    return conn
end

local function cleanupFly()
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    if flyBodyGyro then
        flyBodyGyro:Destroy()
        flyBodyGyro = nil
    end
end

local function setupCharacter(newChar)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid", 10)
    rootPart = newChar:WaitForChild("HumanoidRootPart", 10)

    cleanupFly()
    State.flyEnabled = false
    State.noclipEnabled = false

    if humanoid then
        humanoid.WalkSpeed = State.speedEnabled and State.targetWalkSpeed or Config.MinWalkSpeed
    end
end

if character then
    setupCharacter(character)
else
    character = LocalPlayer.CharacterAdded:Wait()
    setupCharacter(character)
end

track(LocalPlayer.CharacterAdded:Connect(setupCharacter))

-- WalkSpeed loop
track(RunService.RenderStepped:Connect(function()
    if not humanoid then return end

    if State.speedEnabled then
        if humanoid.WalkSpeed ~= State.targetWalkSpeed then
            humanoid.WalkSpeed = State.targetWalkSpeed
        end
    end
end))

-- Noclip loop
track(RunService.Stepped:Connect(function()
    if not State.noclipEnabled or not character then return end

    for _, part in character:GetDescendants() do
        if part:IsA("BasePart") and part.CanCollide then
            part.CanCollide = false
        end
    end
end))

-- Fly
local function setFly(enabled)
    State.flyEnabled = enabled

    if not rootPart or not humanoid then return end

    cleanupFly()

    if enabled then
        flyBodyVelocity = Instance.new("BodyVelocity")
        flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        flyBodyVelocity.Velocity = Vector3.zero
        flyBodyVelocity.Parent = rootPart

        flyBodyGyro = Instance.new("BodyGyro")
        flyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        flyBodyGyro.P = 9000
        flyBodyGyro.CFrame = rootPart.CFrame
        flyBodyGyro.Parent = rootPart

        humanoid.PlatformStand = true
    else
        humanoid.PlatformStand = false
    end
end

track(RunService.RenderStepped:Connect(function()
    if not State.flyEnabled or not flyBodyVelocity or not rootPart then return end

    local moveDirection = Vector3.zero

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        moveDirection += Camera.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        moveDirection -= Camera.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        moveDirection -= Camera.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        moveDirection += Camera.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        moveDirection += Vector3.yAxis
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        moveDirection -= Vector3.yAxis
    end

    if moveDirection.Magnitude > 0 then
        moveDirection = moveDirection.Unit * Config.FlySpeed
    end

    flyBodyVelocity.Velocity = moveDirection
    if flyBodyGyro then
        flyBodyGyro.CFrame = Camera.CFrame
    end
end))

-- Noclip toggle
local function setNoclip(enabled)
    State.noclipEnabled = enabled

    if not enabled and character then
        for _, part in character:GetDescendants() do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
    end
end

-- Auto Clicker
local function updateClickMarker()
    if not clickMarker then return end
    clickMarker.Position = UDim2.fromOffset(State.clickPosition.X, State.clickPosition.Y)
    clickMarker.Visible = not State.pickingClickPosition
end

local function updateClickPosLabel()
    if not clickPosLabel then return end
    clickPosLabel.Text = string.format(
        "Click pos: %d, %d",
        math.floor(State.clickPosition.X),
        math.floor(State.clickPosition.Y)
    )
end

local function performVirtualClick(x, y)
    local ok = pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)

    if not ok and mouse1click then
        pcall(mouse1click)
    end
end

local function setAutoClick(enabled)
    State.autoClickEnabled = enabled
    if clickMarker then
        clickMarker.BackgroundColor3 = enabled
            and Color3.fromRGB(255, 60, 60)
            or Color3.fromRGB(255, 120, 120)
    end
end

local function toggleAutoClick()
    setAutoClick(not State.autoClickEnabled)
    updateActionButtons()
end

local function cancelPickClickPosition()
    State.pickingClickPosition = false
    if pickOverlay then
        pickOverlay.Visible = false
    end
    updateClickMarker()
end

local function setClickPosition(position)
    State.clickPosition = Vector2.new(
        math.floor(position.X),
        math.floor(position.Y)
    )
    updateClickMarker()
    updateClickPosLabel()
end

local function startPickClickPosition()
    cancelPickClickPosition()
    State.pickingClickPosition = true
    if pickOverlay then
        pickOverlay.Visible = true
    end
    if clickMarker then
        clickMarker.Visible = false
    end
end

track(RunService.Heartbeat:Connect(function()
    if not State.autoClickEnabled or State.pickingClickPosition then
        return
    end

    local interval = 1 / math.max(State.autoClickCPS, 1)
    local now = tick()
    if now - lastAutoClickTime >= interval then
        lastAutoClickTime = now
        performVirtualClick(State.clickPosition.X, State.clickPosition.Y)
    end
end))

-- GUI helpers
local function keyLabel(keyCode)
    if not keyCode or keyCode == Enum.KeyCode.Unknown then
        return "?"
    end
    return keyCode.Name
end

local function loadMenuIcon(url)
    if getcustomasset then
        local ok, asset = pcall(getcustomasset, url)
        if ok and asset and asset ~= "" then
            return asset
        end
    end

    local fileName = "patr1k_cheats_icon.png"
    local imageData = game:HttpGet(url)

    if syn and syn.writefile then
        pcall(syn.writefile, fileName, imageData)
    elseif writefile then
        pcall(writefile, fileName, imageData)
    end

    if getcustomasset then
        local ok, asset = pcall(getcustomasset, fileName)
        if ok and asset and asset ~= "" then
            return asset
        end
    end

    return ""
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SpeedBoostGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 999999
screenGui.Parent = getParentGui()

if syn and syn.protect_gui then
    syn.protect_gui(screenGui)
end

local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = parent
    return c
end

-- Floating icon — always visible, opens/closes menu, draggable
local menuToggleBtn = Instance.new("ImageButton")
menuToggleBtn.Name = "MenuToggle"
menuToggleBtn.Size = UDim2.new(0, 56, 0, 56)
menuToggleBtn.Position = UDim2.new(0, 12, 0.5, -28)
menuToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
menuToggleBtn.BackgroundTransparency = 0.2
menuToggleBtn.BorderSizePixel = 0
menuToggleBtn.Image = loadMenuIcon(MENU_ICON_URL)
menuToggleBtn.ScaleType = Enum.ScaleType.Crop
menuToggleBtn.ZIndex = 100
menuToggleBtn.Parent = screenGui
addCorner(menuToggleBtn, 28)

clickMarker = Instance.new("Frame")
clickMarker.Name = "ClickMarker"
clickMarker.Size = UDim2.new(0, 14, 0, 14)
clickMarker.AnchorPoint = Vector2.new(0.5, 0.5)
clickMarker.BackgroundColor3 = Color3.fromRGB(255, 120, 120)
clickMarker.BorderSizePixel = 0
clickMarker.ZIndex = 50
clickMarker.Parent = screenGui
addCorner(clickMarker, 7)

local markerStroke = Instance.new("UIStroke")
markerStroke.Color = Color3.fromRGB(255, 255, 255)
markerStroke.Thickness = 2
markerStroke.Parent = clickMarker

pickOverlay = Instance.new("TextButton")
pickOverlay.Name = "PickOverlay"
pickOverlay.Size = UDim2.new(1, 0, 1, 0)
pickOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
pickOverlay.BackgroundTransparency = 0.45
pickOverlay.BorderSizePixel = 0
pickOverlay.Font = Enum.Font.GothamBold
pickOverlay.TextSize = 18
pickOverlay.TextColor3 = Color3.fromRGB(255, 255, 255)
pickOverlay.Text = "Click anywhere to set autoclick spot\nEsc - cancel"
pickOverlay.TextWrapped = true
pickOverlay.Visible = false
pickOverlay.ZIndex = 2000
pickOverlay.AutoButtonColor = false
pickOverlay.Parent = screenGui

pickOverlay.MouseButton1Click:Connect(function()
    local mousePos = UserInputService:GetMouseLocation()
    setClickPosition(mousePos)
    cancelPickClickPosition()
end)

updateClickMarker()

local menuIconStroke = Instance.new("UIStroke")
menuIconStroke.Color = Color3.fromRGB(80, 160, 255)
menuIconStroke.Thickness = 2
menuIconStroke.Parent = menuToggleBtn

local mainFrame = Instance.new("Frame")
mainFrame.Name = "Main"
mainFrame.Size = UDim2.new(0, 260, 0, 400)
mainFrame.Position = UDim2.new(0, 68, 0.5, -200)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui
addCorner(mainFrame, 8)

local settingsFrame = Instance.new("Frame")
settingsFrame.Name = "Settings"
settingsFrame.Size = UDim2.new(0, 260, 0, 400)
settingsFrame.Position = mainFrame.Position
settingsFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
settingsFrame.BorderSizePixel = 0
settingsFrame.Visible = false
settingsFrame.Active = true
settingsFrame.Parent = screenGui
addCorner(settingsFrame, 8)

local title = Instance.new("TextButton")
title.Size = UDim2.new(1, -80, 0, 32)
title.Position = UDim2.new(0, 8, 0, 8)
title.BackgroundTransparency = 1
title.BorderSizePixel = 0
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "patr1k cheats"
title.AutoButtonColor = false
title.Parent = mainFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -36, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Text = "X"
closeBtn.Parent = mainFrame
addCorner(closeBtn, 6)

local settingsOpenBtn = Instance.new("TextButton")
settingsOpenBtn.Size = UDim2.new(0, 28, 0, 28)
settingsOpenBtn.Position = UDim2.new(1, -68, 0, 10)
settingsOpenBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
settingsOpenBtn.BorderSizePixel = 0
settingsOpenBtn.Font = Enum.Font.GothamBold
settingsOpenBtn.TextSize = 14
settingsOpenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
settingsOpenBtn.Text = "CFG"
settingsOpenBtn.Parent = mainFrame
addCorner(settingsOpenBtn, 6)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -16, 0, 20)
statusLabel.Position = UDim2.new(0, 8, 0, 36)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "Статус: ..."
statusLabel.Parent = mainFrame

local flyBtn, noclipBtn, speedToggleBtn, hintLabel, settingsHint
local bindButtons = {}

local function makeButton(parent, text, yPos, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -16, 0, 32)
    btn.Position = UDim2.new(0, 8, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = text
    btn.Parent = parent
    addCorner(btn, 6)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function updateActionButtons()
    flyBtn.Text = string.format("Fly: %s  [%s]", State.flyEnabled and "ВКЛ" or "ВЫКЛ", keyLabel(Hotkeys.Fly))
    noclipBtn.Text = string.format("Noclip: %s  [%s]", State.noclipEnabled and "ВКЛ" or "ВЫКЛ", keyLabel(Hotkeys.Noclip))
    autoClickBtn.Text = string.format("AutoClick: %s  [%s]", State.autoClickEnabled and "ВКЛ" or "ВЫКЛ", keyLabel(Hotkeys.AutoClick))
    hintLabel.Text = string.format("%s menu | %s pick spot | CFG binds", keyLabel(Hotkeys.ToggleGUI), keyLabel(Hotkeys.PickClickPos))
end

local function updateBindButtons()
    for name, btn in pairs(bindButtons) do
        local label = bindLabels[name] or name
        local hotkey = Hotkeys[name] or Config.Hotkeys[name]
        btn.Text = string.format("%s: [%s]", label, keyLabel(hotkey))
        btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    end
end

local function setMenuPosition(position)
    mainFrame.Position = position
    settingsFrame.Position = position
end

local function setMenuVisible(visible)
    State.guiVisible = visible
    mainFrame.Visible = visible
    if not visible then
        settingsFrame.Visible = false
        State.settingsOpen = false
    end
    menuIconStroke.Color = visible
        and Color3.fromRGB(255, 90, 90)
        or Color3.fromRGB(80, 160, 255)
end

local function openSettings()
    State.settingsOpen = true
    mainFrame.Visible = false
    settingsFrame.Visible = true
    updateBindButtons()
end

local function closeSettings()
    State.settingsOpen = false
    settingsFrame.Visible = false
    mainFrame.Visible = State.guiVisible
end

local bindNames = { "ToggleGUI", "Fly", "Noclip", "AutoClick", "PickClickPos" }
local bindLabels = {
    ToggleGUI = "Меню",
    Fly = "Fly",
    Noclip = "Noclip",
    AutoClick = "AutoClick",
    PickClickPos = "Pick spot",
}

local REBIND_ACTION = "Patr1kCheatsRebind"

local function stopRebindCapture()
    pcall(function()
        ContextActionService:UnbindAction(REBIND_ACTION)
    end)
end

local function cancelRebind()
    rebindTarget = nil
    rebindButton = nil
    stopRebindCapture()
    updateBindButtons()
    if settingsHint then
        settingsHint.Text = "Нажмите на бинд и нажмите новую клавишу"
        settingsHint.TextColor3 = Color3.fromRGB(160, 160, 160)
    end
end

local function applyRebindKey(keyCode)
    if not rebindTarget or not keyCode or keyCode == Enum.KeyCode.Unknown then
        return false
    end

    local blocked = {
        Enum.KeyCode.Return,
        Enum.KeyCode.Space,
        Enum.KeyCode.Tab,
    }
    for _, code in blocked do
        if keyCode == code then
            return false
        end
    end

    Hotkeys[rebindTarget] = keyCode
    local savedName = rebindTarget
    local savedLabel = bindLabels[savedName]
    cancelRebind()
    updateBindButtons()
    updateActionButtons()

    if settingsHint then
        settingsHint.Text = string.format("Сохранено: %s = %s", savedLabel, keyLabel(keyCode))
        settingsHint.TextColor3 = Color3.fromRGB(100, 220, 130)
    end

    return true
end

local function startRebindCapture(bindName, btn)
    cancelRebind()

    rebindTarget = bindName
    rebindButton = btn
    btn.Text = "Нажмите клавишу..."
    btn.BackgroundColor3 = Color3.fromRGB(80, 120, 200)

    if settingsHint then
        settingsHint.Text = "Жду клавишу... Esc — отмена"
        settingsHint.TextColor3 = Color3.fromRGB(255, 210, 100)
    end

    local function onRebindInput(_, state, input)
        if state ~= Enum.UserInputState.Begin then
            return Enum.ContextActionResult.Pass
        end

        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Escape then
                cancelRebind()
                return Enum.ContextActionResult.Sink
            end

            if applyRebindKey(input.KeyCode) then
                return Enum.ContextActionResult.Sink
            end
        end

        return Enum.ContextActionResult.Pass
    end

    task.defer(function()
        if not rebindTarget then
            return
        end

        stopRebindCapture()

        local bound = pcall(function()
            ContextActionService:BindActionAtPriority(
                REBIND_ACTION,
                onRebindInput,
                false,
                3000,
                Enum.UserInputType.Keyboard
            )
        end)

        if not bound then
            pcall(function()
                ContextActionService:BindAction(
                    REBIND_ACTION,
                    onRebindInput,
                    false,
                    Enum.UserInputType.Keyboard
                )
            end)
        end
    end)
end

local function startRebind(bindName, btn)
    startRebindCapture(bindName, btn)
end

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, -16, 0, 20)
speedLabel.Position = UDim2.new(0, 8, 0, 68)
speedLabel.BackgroundTransparency = 1
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextSize = 13
speedLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Text = "WalkSpeed: " .. Config.DefaultWalkSpeed
speedLabel.Parent = mainFrame

local speedSlider = Instance.new("TextButton")
speedSlider.Name = "SpeedSlider"
speedSlider.Size = UDim2.new(1, -16, 0, 22)
speedSlider.Position = UDim2.new(0, 8, 0, 88)
speedSlider.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
speedSlider.BorderSizePixel = 0
speedSlider.Text = ""
speedSlider.AutoButtonColor = false
speedSlider.ClipsDescendants = true
speedSlider.Parent = mainFrame
addCorner(speedSlider, 11)

local sliderFill = Instance.new("Frame")
sliderFill.Name = "Fill"
sliderFill.Size = UDim2.new(
    (Config.DefaultWalkSpeed - Config.MinWalkSpeed) / (Config.MaxWalkSpeed - Config.MinWalkSpeed),
    0,
    1,
    0
)
sliderFill.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
sliderFill.BorderSizePixel = 0
sliderFill.Active = false
sliderFill.Parent = speedSlider
addCorner(sliderFill, 11)

local sliderKnob = Instance.new("Frame")
sliderKnob.Name = "Knob"
sliderKnob.Size = UDim2.new(0, 14, 0, 14)
sliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
sliderKnob.Position = UDim2.new(sliderFill.Size.X.Scale, 0, 0.5, 0)
sliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sliderKnob.BorderSizePixel = 0
sliderKnob.Active = false
sliderKnob.ZIndex = 2
sliderKnob.Parent = speedSlider
addCorner(sliderKnob, 7)

speedSlider.ZIndex = 5

speedToggleBtn = makeButton(mainFrame, "Speed: ВКЛ", 118, function() end)

flyBtn = makeButton(mainFrame, "Fly: ВЫКЛ", 158, function()
    setFly(not State.flyEnabled)
    updateActionButtons()
end)

noclipBtn = makeButton(mainFrame, "Noclip: ВЫКЛ", 198, function()
    setNoclip(not State.noclipEnabled)
    updateActionButtons()
end)

clickPosLabel = Instance.new("TextLabel")
clickPosLabel.Size = UDim2.new(1, -16, 0, 18)
clickPosLabel.Position = UDim2.new(0, 8, 0, 228)
clickPosLabel.BackgroundTransparency = 1
clickPosLabel.Font = Enum.Font.Gotham
clickPosLabel.TextSize = 12
clickPosLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
clickPosLabel.TextXAlignment = Enum.TextXAlignment.Left
clickPosLabel.Text = "Click pos: ..."
clickPosLabel.Parent = mainFrame

autoClickBtn = makeButton(mainFrame, "AutoClick: ВЫКЛ", 248, function()
    toggleAutoClick()
end)

makeButton(mainFrame, "Pick click spot", 288, function()
    startPickClickPosition()
end)

cpsLabel = Instance.new("TextLabel")
cpsLabel.Size = UDim2.new(1, -16, 0, 18)
cpsLabel.Position = UDim2.new(0, 8, 0, 328)
cpsLabel.BackgroundTransparency = 1
cpsLabel.Font = Enum.Font.Gotham
cpsLabel.TextSize = 12
cpsLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
cpsLabel.TextXAlignment = Enum.TextXAlignment.Left
cpsLabel.Text = "CPS: " .. Config.DefaultCPS
cpsLabel.Parent = mainFrame

cpsSlider = Instance.new("TextButton")
cpsSlider.Name = "CpsSlider"
cpsSlider.Size = UDim2.new(1, -16, 0, 18)
cpsSlider.Position = UDim2.new(0, 8, 0, 348)
cpsSlider.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
cpsSlider.BorderSizePixel = 0
cpsSlider.Text = ""
cpsSlider.AutoButtonColor = false
cpsSlider.ClipsDescendants = true
cpsSlider.Parent = mainFrame
addCorner(cpsSlider, 9)

cpsFill = Instance.new("Frame")
cpsFill.BackgroundColor3 = Color3.fromRGB(255, 120, 80)
cpsFill.BorderSizePixel = 0
cpsFill.Active = false
cpsFill.Parent = cpsSlider
addCorner(cpsFill, 9)

cpsKnob = Instance.new("Frame")
cpsKnob.Size = UDim2.new(0, 12, 0, 12)
cpsKnob.AnchorPoint = Vector2.new(0.5, 0.5)
cpsKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
cpsKnob.BorderSizePixel = 0
cpsKnob.Active = false
cpsKnob.ZIndex = 2
cpsKnob.Parent = cpsSlider
addCorner(cpsKnob, 6)

cpsSlider.ZIndex = 5

hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.new(1, -16, 0, 36)
hintLabel.Position = UDim2.new(0, 8, 0, 372)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextSize = 11
hintLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.TextWrapped = true
hintLabel.Parent = mainFrame

-- Settings panel
local settingsTitle = Instance.new("TextButton")
settingsTitle.Size = UDim2.new(1, -16, 0, 32)
settingsTitle.Position = UDim2.new(0, 8, 0, 8)
settingsTitle.BackgroundTransparency = 1
settingsTitle.BorderSizePixel = 0
settingsTitle.Font = Enum.Font.GothamBold
settingsTitle.TextSize = 16
settingsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
settingsTitle.TextXAlignment = Enum.TextXAlignment.Left
settingsTitle.Text = "Настройки биндов"
settingsTitle.AutoButtonColor = false
settingsTitle.Parent = settingsFrame

local settingsHint = Instance.new("TextLabel")
settingsHint.Size = UDim2.new(1, -16, 0, 36)
settingsHint.Position = UDim2.new(0, 8, 0, 40)
settingsHint.BackgroundTransparency = 1
settingsHint.Font = Enum.Font.Gotham
settingsHint.TextSize = 12
settingsHint.TextColor3 = Color3.fromRGB(160, 160, 160)
settingsHint.TextXAlignment = Enum.TextXAlignment.Left
settingsHint.TextWrapped = true
settingsHint.Text = "Нажмите на бинд и нажмите новую клавишу"
settingsHint.Parent = settingsFrame

for i, bindName in ipairs(bindNames) do
    local btn = makeButton(settingsFrame, bindLabels[bindName] .. ": [...]", 88 + (i - 1) * 40, function()
        startRebind(bindName, btn)
    end)
    bindButtons[bindName] = btn
end

makeButton(settingsFrame, "Сбросить бинды", 288, function()
    Hotkeys.Fly = Config.Hotkeys.Fly
    Hotkeys.Noclip = Config.Hotkeys.Noclip
    Hotkeys.ToggleGUI = Config.Hotkeys.ToggleGUI
    Hotkeys.AutoClick = Config.Hotkeys.AutoClick
    Hotkeys.PickClickPos = Config.Hotkeys.PickClickPos
    cancelRebind()
    updateBindButtons()
    updateActionButtons()
end)

makeButton(settingsFrame, "← Назад", 328, function()
    cancelRebind()
    closeSettings()
end)

closeBtn.MouseButton1Click:Connect(function()
    setMenuVisible(false)
end)

settingsOpenBtn.MouseButton1Click:Connect(function()
    openSettings()
end)

updateActionButtons()
updateBindButtons()
updateClickPosLabel()

local pointer = {
    menuDrag = false,
    iconDrag = false,
    speedDrag = false,
    cpsDrag = false,
    dragStart = nil,
    menuStartPos = nil,
    iconStartPos = nil,
    iconMoved = false,
}

local function getMouseLocation()
    return UserInputService:GetMouseLocation()
end

local function updateCpsSlider(value)
    State.autoClickCPS = math.clamp(math.floor(value), Config.MinCPS, Config.MaxCPS)
    cpsLabel.Text = "CPS: " .. State.autoClickCPS
    local ratio = (State.autoClickCPS - Config.MinCPS) / (Config.MaxCPS - Config.MinCPS)
    cpsFill.Size = UDim2.new(ratio, 0, 1, 0)
    cpsKnob.Position = UDim2.new(ratio, 0, 0.5, 0)
end

local function updateSpeedSlider(value)
    State.targetWalkSpeed = math.clamp(math.floor(value), Config.MinWalkSpeed, Config.MaxWalkSpeed)
    speedLabel.Text = "WalkSpeed: " .. State.targetWalkSpeed
    local ratio = (State.targetWalkSpeed - Config.MinWalkSpeed) / (Config.MaxWalkSpeed - Config.MinWalkSpeed)
    sliderFill.Size = UDim2.new(ratio, 0, 1, 0)
    sliderKnob.Position = UDim2.new(ratio, 0, 0.5, 0)
end

local function setSliderFromScreenX(slider, minValue, maxValue, updater, screenX)
    if not slider or slider.AbsoluteSize.X <= 0 then
        return
    end

    local relative = math.clamp(
        (screenX - slider.AbsolutePosition.X) / slider.AbsoluteSize.X,
        0,
        1
    )
    updater(minValue + relative * (maxValue - minValue))
end

local function startMenuDrag()
    pointer.menuDrag = true
    pointer.dragStart = getMouseLocation()
    pointer.menuStartPos = mainFrame.Position
end

local function beginMenuDrag(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    startMenuDrag()
end

local function beginIconDrag(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    pointer.iconDrag = true
    pointer.iconMoved = false
    pointer.dragStart = getMouseLocation()
    pointer.iconStartPos = menuToggleBtn.Position
end

speedSlider.MouseButton1Down:Connect(function()
    pointer.speedDrag = true
    setSliderFromScreenX(speedSlider, Config.MinWalkSpeed, Config.MaxWalkSpeed, updateSpeedSlider, getMouseLocation().X)
end)

cpsSlider.MouseButton1Down:Connect(function()
    pointer.cpsDrag = true
    setSliderFromScreenX(cpsSlider, Config.MinCPS, Config.MaxCPS, updateCpsSlider, getMouseLocation().X)
end)

menuToggleBtn.MouseButton1Click:Connect(function()
    if pointer.iconMoved then
        pointer.iconMoved = false
        return
    end
    setMenuVisible(not State.guiVisible)
end)

updateCpsSlider(Config.DefaultCPS)
updateSpeedSlider(Config.DefaultWalkSpeed)

speedToggleBtn.MouseButton1Click:Connect(function()
    State.speedEnabled = not State.speedEnabled
    speedToggleBtn.Text = State.speedEnabled and "Speed: ВКЛ" or "Speed: ВЫКЛ"

    if humanoid then
        humanoid.WalkSpeed = State.speedEnabled and State.targetWalkSpeed or Config.MinWalkSpeed
    end
end)

-- Status indicator: shows if game is resetting speed
track(RunService.Heartbeat:Connect(function()
    if not humanoid then
        statusLabel.Text = "Статус: нет персонажа"
        statusLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
        return
    end

    if not State.speedEnabled then
        statusLabel.Text = "Статус: speed выключен"
        statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        return
    end

    if math.abs(humanoid.WalkSpeed - State.targetWalkSpeed) < 1 then
        statusLabel.Text = "Статус: скорость применена ✓"
        statusLabel.TextColor3 = Color3.fromRGB(100, 220, 130)
    else
        statusLabel.Text = "Статус: игра сбрасывает скорость ✗"
        statusLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
    end
end))

-- Hotkeys
track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if rebindTarget then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Escape then
                cancelRebind()
            else
                applyRebindKey(input.KeyCode)
            end
        end
        return
    end

    if State.pickingClickPosition and input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.Escape then
            cancelPickClickPosition()
        end
        return
    end

    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end

    if gameProcessed then
        return
    end

    if input.KeyCode == Hotkeys.ToggleGUI then
        setMenuVisible(not State.guiVisible)
    elseif input.KeyCode == Hotkeys.Fly then
        setFly(not State.flyEnabled)
        updateActionButtons()
    elseif input.KeyCode == Hotkeys.Noclip then
        setNoclip(not State.noclipEnabled)
        updateActionButtons()
    elseif input.KeyCode == Hotkeys.AutoClick then
        toggleAutoClick()
    elseif input.KeyCode == Hotkeys.PickClickPos then
        startPickClickPosition()
    end
end))

-- Drag GUI (menu + settings + icon)
local dragBar = Instance.new("Frame")
dragBar.Name = "DragBar"
dragBar.Size = UDim2.new(1, -76, 0, 44)
dragBar.Position = UDim2.new(0, 0, 0, 0)
dragBar.BackgroundTransparency = 1
dragBar.Active = true
dragBar.ZIndex = 20
dragBar.Parent = mainFrame

local settingsDragBar = Instance.new("Frame")
settingsDragBar.Name = "DragBar"
settingsDragBar.Size = UDim2.new(1, -16, 0, 44)
settingsDragBar.Position = UDim2.new(0, 0, 0, 0)
settingsDragBar.BackgroundTransparency = 1
settingsDragBar.Active = true
settingsDragBar.ZIndex = 20
settingsDragBar.Parent = settingsFrame

title.ZIndex = 21
settingsTitle.ZIndex = 21
closeBtn.ZIndex = 30
settingsOpenBtn.ZIndex = 30

dragBar.InputBegan:Connect(beginMenuDrag)
title.MouseButton1Down:Connect(startMenuDrag)
settingsDragBar.InputBegan:Connect(beginMenuDrag)
settingsTitle.MouseButton1Down:Connect(startMenuDrag)

menuToggleBtn.InputBegan:Connect(beginIconDrag)

track(UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local mouse = getMouseLocation()

    if pointer.speedDrag then
        setSliderFromScreenX(speedSlider, Config.MinWalkSpeed, Config.MaxWalkSpeed, updateSpeedSlider, mouse.X)
    elseif pointer.cpsDrag then
        setSliderFromScreenX(cpsSlider, Config.MinCPS, Config.MaxCPS, updateCpsSlider, mouse.X)
    elseif pointer.menuDrag and pointer.dragStart and pointer.menuStartPos then
        local delta = mouse - pointer.dragStart
        setMenuPosition(UDim2.new(
            pointer.menuStartPos.X.Scale,
            pointer.menuStartPos.X.Offset + delta.X,
            pointer.menuStartPos.Y.Scale,
            pointer.menuStartPos.Y.Offset + delta.Y
        ))
    elseif pointer.iconDrag and pointer.dragStart and pointer.iconStartPos then
        local delta = mouse - pointer.dragStart
        if delta.Magnitude > 6 then
            pointer.iconMoved = true
        end
        menuToggleBtn.Position = UDim2.new(
            pointer.iconStartPos.X.Scale,
            pointer.iconStartPos.X.Offset + delta.X,
            pointer.iconStartPos.Y.Scale,
            pointer.iconStartPos.Y.Offset + delta.Y
        )
    end
end))

track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    pointer.menuDrag = false
    pointer.iconDrag = false
    pointer.speedDrag = false
    pointer.cpsDrag = false
    pointer.dragStart = nil
    pointer.menuStartPos = nil
    pointer.iconStartPos = nil
end))

print("[patr1k cheats v" .. SCRIPT_VERSION .. "] Loaded. Drag Patrick icon or menu title.")

if getgenv then
    getgenv().SpeedBoostCleanup = function()
        cancelRebind()
        disconnectAll()
        cleanupFly()
        cancelPickClickPosition()
        setAutoClick(false)
        if screenGui and screenGui.Parent then
            screenGui:Destroy()
        end
    end
end
