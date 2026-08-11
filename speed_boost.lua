--[[
    Speed Boost Script for Roblox Executor
    WalkSpeed + Fly + Noclip + GUI

    Работает в играх БЕЗ серверного античита.
    В популярных играх скорость может сбрасываться или давать kick.
]]

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
}

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
        local coreGui = game:GetService("CoreGui")
        return coreGui
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

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

-- GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SpeedBoostGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = getParentGui()

local mainFrame = Instance.new("Frame")
mainFrame.Name = "Main"
mainFrame.Size = UDim2.new(0, 260, 0, 280)
mainFrame.Position = UDim2.new(0, 20, 0.5, -140)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 32)
title.Position = UDim2.new(0, 8, 0, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Speed Script"
title.Parent = mainFrame

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

local function makeButton(text, yPos, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -16, 0, 32)
    btn.Position = UDim2.new(0, 8, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = text
    btn.Parent = mainFrame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    btn.MouseButton1Click:Connect(callback)
    return btn
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

local sliderCorner = Instance.new("UICorner")
sliderCorner.CornerRadius = UDim.new(1, 0)
sliderCorner.Parent = speedSlider

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

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = sliderFill

local speedToggleBtn = makeButton("Speed: ВКЛ", 108, function() end)

local flyBtn = makeButton("Fly: ВЫКЛ  [F]", 148, function()
    setFly(not State.flyEnabled)
    flyBtn.Text = State.flyEnabled and "Fly: ВКЛ  [F]" or "Fly: ВЫКЛ  [F]"
end)

local noclipBtn = makeButton("Noclip: ВЫКЛ  [N]", 188, function()
    setNoclip(not State.noclipEnabled)
    noclipBtn.Text = State.noclipEnabled and "Noclip: ВКЛ  [N]" or "Noclip: ВЫКЛ  [N]"
end)

local hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.new(1, -16, 0, 40)
hintLabel.Position = UDim2.new(0, 8, 0, 232)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextSize = 11
hintLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.TextWrapped = true
hintLabel.Text = "RightShift — скрыть GUI\nРаботает не во всех играх"
hintLabel.Parent = mainFrame

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
    if gameProcessed then return end

    if input.KeyCode == Config.Hotkeys.ToggleGUI then
        State.guiVisible = not State.guiVisible
        mainFrame.Visible = State.guiVisible
    elseif input.KeyCode == Config.Hotkeys.Fly then
        setFly(not State.flyEnabled)
        flyBtn.Text = State.flyEnabled and "Fly: ВКЛ  [F]" or "Fly: ВЫКЛ  [F]"
    elseif input.KeyCode == Config.Hotkeys.Noclip then
        setNoclip(not State.noclipEnabled)
        noclipBtn.Text = State.noclipEnabled and "Noclip: ВКЛ  [N]" or "Noclip: ВЫКЛ  [N]"
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

print("[Speed Script] Загружен. RightShift — скрыть GUI.")
