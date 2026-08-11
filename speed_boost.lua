--[[
    Speed Boost Script for Roblox Executor
    WalkSpeed + Fly + Noclip + GUI
    Version: 2.1
]]

local SCRIPT_VERSION = "2.1"

local Config = {
    DefaultWalkSpeed = 50,
    MinWalkSpeed = 16,
    MaxWalkSpeed = 200,
    FlySpeed = 50,
    Hotkeys = {
        Fly = Enum.KeyCode.F,
        Noclip = Enum.KeyCode.N,
        ToggleGUI = Enum.KeyCode.RightShift,
    },
}

local Hotkeys = {
    Fly = Config.Hotkeys.Fly,
    Noclip = Config.Hotkeys.Noclip,
    ToggleGUI = Config.Hotkeys.ToggleGUI,
}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- State
local State = {
    speedEnabled = true,
    targetWalkSpeed = Config.DefaultWalkSpeed,
    flyEnabled = false,
    noclipEnabled = false,
    guiVisible = true,
    settingsOpen = false,
}

local rebindTarget = nil
local rebindButton = nil

local character = LocalPlayer.Character
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
local rootPart = character and character:FindFirstChild("HumanoidRootPart")

local connections = {}
local flyBodyVelocity = nil
local flyBodyGyro = nil

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

-- GUI helpers
local function keyLabel(keyCode)
    if not keyCode or keyCode == Enum.KeyCode.Unknown then
        return "?"
    end
    return keyCode.Name
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

-- Floating button — always visible, opens/closes menu
local menuToggleBtn = Instance.new("TextButton")
menuToggleBtn.Name = "MenuToggle"
menuToggleBtn.Size = UDim2.new(0, 48, 0, 48)
menuToggleBtn.Position = UDim2.new(0, 12, 0.5, -24)
menuToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 110, 220)
menuToggleBtn.BorderSizePixel = 0
menuToggleBtn.Font = Enum.Font.GothamBold
menuToggleBtn.TextSize = 20
menuToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
menuToggleBtn.Text = "MENU"
menuToggleBtn.ZIndex = 100
menuToggleBtn.Parent = screenGui
addCorner(menuToggleBtn, 22)

local mainFrame = Instance.new("Frame")
mainFrame.Name = "Main"
mainFrame.Size = UDim2.new(0, 260, 0, 318)
mainFrame.Position = UDim2.new(0, 68, 0.5, -159)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui
addCorner(mainFrame, 8)

local settingsFrame = Instance.new("Frame")
settingsFrame.Name = "Settings"
settingsFrame.Size = UDim2.new(0, 260, 0, 318)
settingsFrame.Position = mainFrame.Position
settingsFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
settingsFrame.BorderSizePixel = 0
settingsFrame.Visible = false
settingsFrame.Active = true
settingsFrame.Parent = screenGui
addCorner(settingsFrame, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 0, 32)
title.Position = UDim2.new(0, 8, 0, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Speed Script v" .. SCRIPT_VERSION
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

local flyBtn, noclipBtn, speedToggleBtn, hintLabel
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
    hintLabel.Text = string.format("%s - menu | CFG - keybinds", keyLabel(Hotkeys.ToggleGUI))
end

local function updateBindButtons()
    for name, btn in pairs(bindButtons) do
        btn.Text = string.format("%s: [%s]", bindLabels[name], keyLabel(Hotkeys[name]))
        btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    end
end

local function setMenuVisible(visible)
    State.guiVisible = visible
    mainFrame.Visible = visible
    if not visible then
        settingsFrame.Visible = false
        State.settingsOpen = false
    end
    menuToggleBtn.Text = visible and "CLOSE" or "MENU"
    menuToggleBtn.BackgroundColor3 = visible
        and Color3.fromRGB(180, 60, 60)
        or Color3.fromRGB(50, 110, 220)
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

local function cancelRebind()
    rebindTarget = nil
    rebindButton = nil
    updateBindButtons()
end

local function startRebind(bindName, btn)
    if rebindTarget then
        cancelRebind()
    end
    rebindTarget = bindName
    rebindButton = btn
    btn.Text = "Нажмите клавишу..."
    btn.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
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
speedSlider.Size = UDim2.new(1, -16, 0, 8)
speedSlider.Position = UDim2.new(0, 8, 0, 92)
speedSlider.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
speedSlider.BorderSizePixel = 0
speedSlider.Text = ""
speedSlider.AutoButtonColor = false
speedSlider.Parent = mainFrame
addCorner(speedSlider, 4)

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(
    (Config.DefaultWalkSpeed - Config.MinWalkSpeed) / (Config.MaxWalkSpeed - Config.MinWalkSpeed),
    0,
    1,
    0
)
sliderFill.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
sliderFill.BorderSizePixel = 0
sliderFill.Parent = speedSlider
addCorner(sliderFill, 4)

speedToggleBtn = makeButton(mainFrame, "Speed: ВКЛ", 108, function() end)

flyBtn = makeButton(mainFrame, "Fly: ВЫКЛ", 148, function()
    setFly(not State.flyEnabled)
    updateActionButtons()
end)

noclipBtn = makeButton(mainFrame, "Noclip: ВЫКЛ", 188, function()
    setNoclip(not State.noclipEnabled)
    updateActionButtons()
end)

hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.new(1, -16, 0, 48)
hintLabel.Position = UDim2.new(0, 8, 0, 232)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextSize = 11
hintLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.TextWrapped = true
hintLabel.Parent = mainFrame

-- Settings panel
local settingsTitle = Instance.new("TextLabel")
settingsTitle.Size = UDim2.new(1, -16, 0, 32)
settingsTitle.Position = UDim2.new(0, 8, 0, 8)
settingsTitle.BackgroundTransparency = 1
settingsTitle.Font = Enum.Font.GothamBold
settingsTitle.TextSize = 16
settingsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
settingsTitle.TextXAlignment = Enum.TextXAlignment.Left
settingsTitle.Text = "Настройки биндов"
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

local bindNames = { "ToggleGUI", "Fly", "Noclip" }
local bindLabels = {
    ToggleGUI = "Меню",
    Fly = "Fly",
    Noclip = "Noclip",
}

for i, bindName in ipairs(bindNames) do
    local btn = makeButton(settingsFrame, bindLabels[bindName] .. ": [...]", 88 + (i - 1) * 40, function()
        startRebind(bindName, btn)
    end)
    bindButtons[bindName] = btn
end

makeButton(settingsFrame, "Сбросить бинды", 208, function()
    Hotkeys.Fly = Config.Hotkeys.Fly
    Hotkeys.Noclip = Config.Hotkeys.Noclip
    Hotkeys.ToggleGUI = Config.Hotkeys.ToggleGUI
    cancelRebind()
    updateBindButtons()
    updateActionButtons()
end)

makeButton(settingsFrame, "← Назад", 248, function()
    cancelRebind()
    closeSettings()
end)

menuToggleBtn.MouseButton1Click:Connect(function()
    setMenuVisible(not State.guiVisible)
end)

closeBtn.MouseButton1Click:Connect(function()
    setMenuVisible(false)
end)

settingsOpenBtn.MouseButton1Click:Connect(function()
    openSettings()
end)

updateActionButtons()
updateBindButtons()

local function updateSpeedSlider(value)
    State.targetWalkSpeed = math.clamp(math.floor(value), Config.MinWalkSpeed, Config.MaxWalkSpeed)
    speedLabel.Text = "WalkSpeed: " .. State.targetWalkSpeed
    sliderFill.Size = UDim2.new(
        (State.targetWalkSpeed - Config.MinWalkSpeed) / (Config.MaxWalkSpeed - Config.MinWalkSpeed),
        0,
        1,
        0
    )
end

local draggingSlider = false

speedSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingSlider = true
    end
end)

speedSlider.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingSlider = false
    end
end)

track(UserInputService.InputChanged:Connect(function(input)
    if not draggingSlider or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

    local relative = math.clamp(
        (input.Position.X - speedSlider.AbsolutePosition.X) / speedSlider.AbsoluteSize.X,
        0,
        1
    )
    local value = Config.MinWalkSpeed + relative * (Config.MaxWalkSpeed - Config.MinWalkSpeed)
    updateSpeedSlider(value)
end))

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
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
            Hotkeys[rebindTarget] = input.KeyCode
            rebindTarget = nil
            rebindButton = nil
            updateBindButtons()
            updateActionButtons()
        end
        return
    end

    if gameProcessed then return end

    if input.KeyCode == Hotkeys.ToggleGUI then
        setMenuVisible(not State.guiVisible)
    elseif input.KeyCode == Hotkeys.Fly then
        setFly(not State.flyEnabled)
        updateActionButtons()
    elseif input.KeyCode == Hotkeys.Noclip then
        setNoclip(not State.noclipEnabled)
        updateActionButtons()
    end
end))

-- Drag GUI
local draggingGui = false
local dragStart = nil
local startPos = nil

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingGui = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)

title.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingGui = false
    end
end)

track(UserInputService.InputChanged:Connect(function(input)
    if not draggingGui or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end))

print("[Speed Script v" .. SCRIPT_VERSION .. "] Loaded. Blue MENU button on the left.")

if getgenv then
    getgenv().SpeedBoostCleanup = function()
        disconnectAll()
        cleanupFly()
        if screenGui and screenGui.Parent then
            screenGui:Destroy()
        end
    end
end
