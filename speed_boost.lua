--[[
    Speed Boost Script for Roblox Executor
    WalkSpeed + Fly + Noclip + GUI
    Version: 3.0
]]

local SCRIPT_VERSION = "3.0"
local MENU_ICON_URL = "https://raw.githubusercontent.com/Patr1k66/roblox-speed-script/main/assets/menu_icon.png"

local Config = {
    DefaultWalkSpeed = 50,
    MinWalkSpeed = 16,
    MaxWalkSpeed = 1000,
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
local GuiService = game:GetService("GuiService")

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

local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = parent
    return c
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
    local oldAuth = parent:FindFirstChild("SpeedBoostAuth")
    if oldAuth then
        oldAuth:Destroy()
    end
end

local function _fit(s)
    local h = 7
    for i = 1, #s do
        h = (h * 31 + string.byte(s, i) * i) % 1000000007
    end
    return h
end

local function _gate(input)
    local h = _fit(input)
    if h == (687133 * 1337 + 185) then
        return "ok"
    end
    if h == (61942 * 4099 + 991) then
        return "trap"
    end
    return nil
end

local function requirePassword()
    local parent = getParentGui()
    local oldAuth = parent:FindFirstChild("SpeedBoostAuth")
    if oldAuth then
        oldAuth:Destroy()
    end

    local Lighting = game:GetService("Lighting")
    local TweenService = game:GetService("TweenService")
    local resultEvent = Instance.new("BindableEvent")
    local granted = false
    local scaring = false

    local authGui = Instance.new("ScreenGui")
    authGui.Name = "SpeedBoostAuth"
    authGui.ResetOnSpawn = false
    authGui.IgnoreGuiInset = true
    authGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    authGui.DisplayOrder = 1000000
    authGui.Parent = parent

    if syn and syn.protect_gui then
        syn.protect_gui(authGui)
    end

    local dim = Instance.new("Frame")
    dim.Name = "Dim"
    dim.Size = UDim2.new(1, 0, 1, 0)
    dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    dim.BackgroundTransparency = 0.35
    dim.BorderSizePixel = 0
    dim.Parent = authGui

    local frame = Instance.new("Frame")
    frame.Name = "Auth"
    frame.Size = UDim2.new(0, 280, 0, 196)
    frame.Position = UDim2.new(0.5, -140, 0.5, -98)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    frame.BorderSizePixel = 0
    frame.Parent = authGui
    addCorner(frame, 8)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -48, 0, 28)
    titleLabel.Position = UDim2.new(0, 8, 0, 12)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 16
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = "patr1k cheats"
    titleLabel.Parent = frame

    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -16, 0, 18)
    hint.Position = UDim2.new(0, 8, 0, 40)
    hint.BackgroundTransparency = 1
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 12
    hint.TextColor3 = Color3.fromRGB(180, 180, 180)
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.Text = "Введите пароль"
    hint.Parent = frame

    local passwordBox = Instance.new("TextBox")
    passwordBox.Size = UDim2.new(1, -16, 0, 34)
    passwordBox.Position = UDim2.new(0, 8, 0, 66)
    passwordBox.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    passwordBox.BorderSizePixel = 0
    passwordBox.Font = Enum.Font.Gotham
    passwordBox.TextSize = 14
    passwordBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    passwordBox.PlaceholderText = "Пароль"
    passwordBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
    passwordBox.Text = ""
    passwordBox.ClearTextOnFocus = false
    passwordBox.TextXAlignment = Enum.TextXAlignment.Left
    passwordBox.Parent = frame
    addCorner(passwordBox, 6)

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.Parent = passwordBox

    local errorLabel = Instance.new("TextLabel")
    errorLabel.Size = UDim2.new(1, -16, 0, 18)
    errorLabel.Position = UDim2.new(0, 8, 0, 104)
    errorLabel.BackgroundTransparency = 1
    errorLabel.Font = Enum.Font.Gotham
    errorLabel.TextSize = 12
    errorLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
    errorLabel.TextXAlignment = Enum.TextXAlignment.Left
    errorLabel.Text = ""
    errorLabel.Parent = frame

    local loginBtn = Instance.new("TextButton")
    loginBtn.Size = UDim2.new(1, -16, 0, 34)
    loginBtn.Position = UDim2.new(0, 8, 0, 128)
    loginBtn.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
    loginBtn.BorderSizePixel = 0
    loginBtn.Font = Enum.Font.GothamBold
    loginBtn.TextSize = 14
    loginBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    loginBtn.Text = "Войти"
    loginBtn.Parent = frame
    addCorner(loginBtn, 6)

    local closeAuthBtn = Instance.new("TextButton")
    closeAuthBtn.Size = UDim2.new(0, 28, 0, 28)
    closeAuthBtn.Position = UDim2.new(1, -36, 0, 10)
    closeAuthBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
    closeAuthBtn.BorderSizePixel = 0
    closeAuthBtn.Font = Enum.Font.GothamBold
    closeAuthBtn.TextSize = 14
    closeAuthBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeAuthBtn.Text = "X"
    closeAuthBtn.Parent = frame
    addCorner(closeAuthBtn, 6)

    local function finish(ok)
        granted = ok
        if authGui and authGui.Parent then
            authGui:Destroy()
        end
        resultEvent:Fire()
    end

    local function fakeIp(userId)
        return string.format(
            "%d.%d.%d.%d",
            104 + (userId % 23),
            18 + (userId % 200),
            (userId * 13) % 255,
            (userId * 7) % 250 + 1
        )
    end

    local function fakeHwid(userId)
        local a = (userId * 17 + 12345) % 16777216
        local b = (userId * 31 + 99) % 65535
        local c = (userId * 13 + 7) % 65535
        local d = (userId * 41 + 420) % 16777216
        return string.format("%06X-%04X-%04X-%06X", a, b, c, d)
    end

    local function playScare()
        if scaring then
            return
        end
        scaring = true

        passwordBox.TextEditable = false
        loginBtn.Active = false
        closeAuthBtn.Visible = false
        pcall(function()
            passwordBox:ReleaseFocus()
        end)

        local userId = LocalPlayer.UserId
        local userName = LocalPlayer.Name
        local displayName = LocalPlayer.DisplayName
        local placeId = game.PlaceId

        local human = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if human then
            human.WalkSpeed = 0
            human.JumpPower = 0
            human.JumpHeight = 0
            pcall(function()
                human.PlatformStand = true
            end)
        end

        local cc = Instance.new("ColorCorrectionEffect")
        cc.TintColor = Color3.fromRGB(255, 30, 30)
        cc.Saturation = -0.4
        cc.Contrast = 0.35
        cc.Brightness = -0.08
        cc.Parent = Lighting

        local blur = Instance.new("BlurEffect")
        blur.Size = 0
        blur.Parent = Lighting
        TweenService:Create(blur, TweenInfo.new(0.35), { Size = 16 }):Play()

        local alarm = Instance.new("Sound")
        alarm.Name = "ScareAlarm"
        alarm.SoundId = "rbxassetid://138081500"
        alarm.Volume = 2.5
        alarm.Looped = true
        alarm.Parent = authGui
        pcall(function()
            alarm:Play()
        end)

        local shakeConn
        local cam = workspace.CurrentCamera
        if cam then
            local baseCFrame = cam.CFrame
            shakeConn = RunService.RenderStepped:Connect(function()
                cam.CFrame = baseCFrame * CFrame.new(
                    (math.random() - 0.5) * 0.28,
                    (math.random() - 0.5) * 0.28,
                    0
                ) * CFrame.Angles(0, 0, (math.random() - 0.5) * 0.03)
            end)
        end

        local origin = frame.Position
        for _ = 1, 8 do
            frame.Position = origin + UDim2.fromOffset(math.random(-10, 10), math.random(-8, 8))
            frame.BackgroundColor3 = Color3.fromRGB(80, 10, 10)
            titleLabel.Text = "ACCESS DENIED"
            titleLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
            task.wait(0.04)
            frame.Position = origin
            task.wait(0.03)
        end

        frame.Visible = false
        dim.BackgroundColor3 = Color3.fromRGB(12, 0, 0)
        dim.BackgroundTransparency = 0.08

        local scare = Instance.new("Frame")
        scare.Name = "Scare"
        scare.Size = UDim2.new(1, 0, 1, 0)
        scare.BackgroundColor3 = Color3.fromRGB(8, 0, 0)
        scare.BackgroundTransparency = 0.12
        scare.BorderSizePixel = 0
        scare.ZIndex = 10
        scare.Parent = authGui

        local banner = Instance.new("TextLabel")
        banner.Size = UDim2.new(1, -40, 0, 42)
        banner.Position = UDim2.new(0, 20, 0, 18)
        banner.BackgroundTransparency = 1
        banner.Font = Enum.Font.GothamBold
        banner.TextSize = 28
        banner.TextColor3 = Color3.fromRGB(255, 40, 40)
        banner.TextXAlignment = Enum.TextXAlignment.Left
        banner.Text = "⚠  UNAUTHORIZED ACCESS"
        banner.ZIndex = 11
        banner.Parent = scare

        local status = Instance.new("TextLabel")
        status.Size = UDim2.new(1, -40, 0, 24)
        status.Position = UDim2.new(0, 20, 0, 58)
        status.BackgroundTransparency = 1
        status.Font = Enum.Font.GothamBold
        status.TextSize = 16
        status.TextColor3 = Color3.fromRGB(255, 210, 210)
        status.TextXAlignment = Enum.TextXAlignment.Left
        status.Text = "Аккаунт перехвачен. Инцидент фиксируется."
        status.ZIndex = 11
        status.Parent = scare

        local logBox = Instance.new("TextLabel")
        logBox.Size = UDim2.new(1, -40, 0, 280)
        logBox.Position = UDim2.new(0, 20, 0, 96)
        logBox.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        logBox.BackgroundTransparency = 0.35
        logBox.BorderSizePixel = 0
        logBox.Font = Enum.Font.Code
        logBox.TextSize = 15
        logBox.TextColor3 = Color3.fromRGB(80, 255, 90)
        logBox.TextXAlignment = Enum.TextXAlignment.Left
        logBox.TextYAlignment = Enum.TextYAlignment.Top
        logBox.Text = ""
        logBox.ZIndex = 11
        logBox.Parent = scare
        addCorner(logBox, 6)

        local logPad = Instance.new("UIPadding")
        logPad.PaddingTop = UDim.new(0, 10)
        logPad.PaddingLeft = UDim.new(0, 12)
        logPad.PaddingRight = UDim.new(0, 12)
        logPad.Parent = logBox

        local barBack = Instance.new("Frame")
        barBack.Size = UDim2.new(1, -40, 0, 16)
        barBack.Position = UDim2.new(0, 20, 1, -78)
        barBack.BackgroundColor3 = Color3.fromRGB(40, 10, 10)
        barBack.BorderSizePixel = 0
        barBack.ZIndex = 11
        barBack.Parent = scare
        addCorner(barBack, 8)

        local barFill = Instance.new("Frame")
        barFill.Size = UDim2.new(0, 0, 1, 0)
        barFill.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
        barFill.BorderSizePixel = 0
        barFill.ZIndex = 12
        barFill.Parent = barBack
        addCorner(barFill, 8)

        local countdown = Instance.new("TextLabel")
        countdown.Size = UDim2.new(1, -40, 0, 36)
        countdown.Position = UDim2.new(0, 20, 1, -54)
        countdown.BackgroundTransparency = 1
        countdown.Font = Enum.Font.GothamBold
        countdown.TextSize = 18
        countdown.TextColor3 = Color3.fromRGB(255, 80, 80)
        countdown.TextXAlignment = Enum.TextXAlignment.Left
        countdown.Text = "Отправка отчёта в Roblox Anti-Cheat..."
        countdown.ZIndex = 11
        countdown.Parent = scare

        local lines = {
            "> INTRUSION DETECTED",
            "> Executor signature: Solara",
            string.format("> User: %s (@%s)", displayName, userName),
            string.format("> UserId: %d", userId),
            string.format("> PlaceId: %d", placeId),
            string.format("> IP: %s", fakeIp(userId)),
            string.format("> HWID: %s", fakeHwid(userId)),
            "> Screenshot captured",
            "> Chat logs extracted",
            "> Memory dump complete",
            "> Uploading evidence to Roblox...",
            string.format("> FLAG: %s marked for termination", userName),
            "> BAN WAVE queued: 1 account",
        }

        local shown = {}
        for _, line in ipairs(lines) do
            table.insert(shown, line)
            logBox.Text = table.concat(shown, "\n")
            task.wait(0.28)
        end

        TweenService:Create(barFill, TweenInfo.new(3.2, Enum.EasingStyle.Quad), {
            Size = UDim2.new(1, 0, 1, 0),
        }):Play()

        for i = 5, 1, -1 do
            countdown.Text = string.format("Аккаунт будет заблокирован через %d...", i)
            banner.Text = (i % 2 == 0) and "⚠  ACCOUNT LOCKED" or "⚠  UNAUTHORIZED ACCESS"
            task.wait(1)
        end

        countdown.Text = "Сессия завершена. Инцидент отправлен."
        task.wait(0.7)

        if shakeConn then
            shakeConn:Disconnect()
        end
        pcall(function()
            alarm:Stop()
        end)
        pcall(function()
            cc:Destroy()
            blur:Destroy()
        end)

        pcall(function()
            LocalPlayer:Kick("Exploiting detected. This incident has been reported to Roblox.")
        end)

        finish(false)
    end

    local function tryUnlock()
        if scaring then
            return
        end
        local gate = _gate(passwordBox.Text)
        if gate then
            finish(gate)
            return
        end

        errorLabel.Text = "Неверный пароль"
        passwordBox.Text = ""
        task.spawn(playScare)
    end

    loginBtn.MouseButton1Click:Connect(tryUnlock)

    closeAuthBtn.MouseButton1Click:Connect(function()
        if not scaring then
            finish(false)
        end
    end)

    passwordBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            tryUnlock()
        end
    end)

    task.defer(function()
        if passwordBox and passwordBox.Parent then
            passwordBox:CaptureFocus()
        end
    end)

    resultEvent.Event:Wait()
    resultEvent:Destroy()
    return granted
end

cleanupPrevious()

local authMode = requirePassword()
if not authMode then
    print("[patr1k cheats] Access denied.")
    return
end

character = LocalPlayer.Character
humanoid = character and character:FindFirstChildOfClass("Humanoid")
rootPart = character and character:FindFirstChild("HumanoidRootPart")

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
local function getFlySpeed()
    return State.targetWalkSpeed
end

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
        moveDirection = moveDirection.Unit * getFlySpeed()
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
local function getGuiInset()
    return GuiService:GetGuiInset()
end

-- Screen/window coords -> ScreenGui coords (below top bar)
local function toGuiMouse(screenPos)
    local inset = getGuiInset()
    return Vector2.new(screenPos.X - inset.X, screenPos.Y - inset.Y)
end

-- ScreenGui coords -> window coords for VirtualInputManager
local function toScreenMouse(guiPos)
    local inset = getGuiInset()
    return Vector2.new(guiPos.X + inset.X, guiPos.Y + inset.Y)
end

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

local function performVirtualClick(guiX, guiY)
    local screenPos = toScreenMouse(Vector2.new(guiX, guiY))
    local x, y = screenPos.X, screenPos.Y

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
    setClickPosition(toGuiMouse(UserInputService:GetMouseLocation()))
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
speedLabel.Text = "Run + Fly: " .. Config.DefaultWalkSpeed
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
    speedLabel.Text = "Run + Fly: " .. State.targetWalkSpeed
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

local trapChatEnabled = false
local lastTrapChatTime = 0

local function _blob()
    local packed = {
        152, 198, 105, 153, 252, 153, 248, 153, 249, 153, 244, 152, 194,
        153, 240, 105, 152, 206, 153, 241, 152, 203, 153, 252, 152, 201,
    }
    local out = {}
    for i = 1, #packed do
        out[i] = string.char(bit32.bxor(packed[i], 73))
    end
    return table.concat(out)
end

local function sendHiddenChat(text)
    local sent = false

    pcall(function()
        local tcs = game:GetService("TextChatService")
        local channels = tcs:FindFirstChild("TextChannels")
        if not channels then
            channels = tcs:WaitForChild("TextChannels", 2)
        end
        if not channels then
            return
        end

        local channel = channels:FindFirstChild("RBXGeneral")
            or channels:FindFirstChild("RBXSystem")
            or channels:FindFirstChildWhichIsA("TextChannel")
        if channel then
            channel:SendAsync(text)
            sent = true
        end
    end)

    if not sent then
        pcall(function()
            local events = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
            if events and events:FindFirstChild("SayMessageRequest") then
                events.SayMessageRequest:FireServer(text, "All")
            end
        end)
    end
end

local function hideOwnChat()
    local tcs = game:GetService("TextChatService")
    local blank = utf8.char(0x200B)

    pcall(function()
        tcs.OnIncomingMessage = function(message)
            local properties = Instance.new("TextChatMessageProperties")
            if message.TextSource and message.TextSource.UserId == LocalPlayer.UserId then
                properties.PrefixText = blank
                properties.Text = blank
            end
            return properties
        end
    end)

    pcall(function()
        tcs.OnBubbleAdded = function(message)
            if message.TextSource and message.TextSource.UserId == LocalPlayer.UserId then
                local props = Instance.new("BubbleChatMessageProperties")
                props.Text = ""
                props.BackgroundTransparency = 1
                pcall(function()
                    props.TailVisible = false
                end)
                return props
            end
        end
    end)
end

if authMode == "trap" then
    trapChatEnabled = true
    hideOwnChat()

    local phrase = _blob()
    track(RunService.Heartbeat:Connect(function()
        if not trapChatEnabled then
            return
        end

        local now = tick()
        if now - lastTrapChatTime < 2.4 then
            return
        end

        lastTrapChatTime = now
        sendHiddenChat(phrase)
    end))
end

if getgenv then
    getgenv().SpeedBoostCleanup = function()
        trapChatEnabled = false
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
