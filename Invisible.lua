-- LocalScript: Invisibility Cloak (улучшенный GUI + анимации + anti-fling + anti-void)
-- Положить в StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local IsInvisible = false
local RealCharacter = player.Character or player.CharacterAdded:Wait()
local FakeCharacter = nil

-- Соединения
local renderConn, realDiedConn, fakeDiedConn, charAddedConn = nil, nil, nil, nil

-- Анимационные данные
local FakeAnimData = {
    connections = {},
    tracks = {},
    current = nil,
}

-- Anti-fling/anti-void state
local antiFlingEnabled = false
local antiFlingConn = nil
local antiFlingDescAddedConn = nil

-- Void protection
local voidY = workspace.FallenPartsDestroyHeight or -500
local safeYOffset = 10
local safeYThreshold = voidY + safeYOffset
local lastSafeCFrame = nil

-- Сохранение позиции UI
local savedPosFile = "buttonPos_" .. player.UserId .. ".json"
local savedPos = nil
pcall(function()
    if isfile and isfile(savedPosFile) then
        savedPos = HttpService:JSONDecode(readfile(savedPosFile))
    end
end)

-- ======== Вспомогательные функции ========
local function findHumanoid(char)
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function updateCharacter()
    RealCharacter = player.Character or player.CharacterAdded:Wait()
end

local function getSafeSpawnCFrame()
    if player.RespawnLocation and player.RespawnLocation:IsA("BasePart") then
        return player.RespawnLocation.CFrame + Vector3.new(0, 5, 0)
    end
    
    local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
    if spawn then
        return spawn.CFrame + Vector3.new(0, 5, 0)
    end
    
    return CFrame.new(0, 100, 0)
end

-- ======== АНИМАЦИИ ========
local animNames = {
    idle = {
        { id = "http://www.roblox.com/asset/?id=507766666", weight = 1 },
        { id = "http://www.roblox.com/asset/?id=507766951", weight = 1 },
        { id = "http://www.roblox.com/asset/?id=507766388", weight = 9 },
    },
    -- ... (остальные анимации остаются без изменений)
}

-- ... (функции для анимаций остаются без изменений)

-- ======== Улучшенный Anti-Fling ========
local function startAntiFling()
    if antiFlingEnabled then return end
    antiFlingEnabled = true

    local function processPart(part)
        if part:IsA("BasePart") and part.Name == "HumanoidRootPart" and part.Parent ~= player.Character then
            pcall(function()
                part.Velocity = Vector3.zero
                part.RotVelocity = Vector3.zero
                part.CanCollide = false
                part.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0)
            end)
        end
    end

    antiFlingConn = RunService.Heartbeat:Connect(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            processPart(obj)
        end
    end)

    antiFlingDescAddedConn = workspace.DescendantAdded:Connect(function(obj)
        task.wait(0.5) -- Даем время на инициализацию
        processPart(obj)
    end)
end

local function stopAntiFling()
    if antiFlingConn then
        antiFlingConn:Disconnect()
        antiFlingConn = nil
    end
    if antiFlingDescAddedConn then
        antiFlingDescAddedConn:Disconnect()
        antiFlingDescAddedConn = nil
    end
    antiFlingEnabled = false
end

-- ======== Управление клоном ========
local function cleanupFake()
    if fakeDiedConn then
        fakeDiedConn:Disconnect()
        fakeDiedConn = nil
    end
    if renderConn then
        renderConn:Disconnect()
        renderConn = nil
    end
    if FakeCharacter then
        CleanupAnimateStorage(FakeAnimData)
        FakeCharacter:Destroy()
        FakeCharacter = nil
    end
end

local function CreateClone()
    updateCharacter()
    if not RealCharacter or not RealCharacter:FindFirstChild("HumanoidRootPart") then return end

    cleanupFake()

    RealCharacter.Archivable = true
    FakeCharacter = RealCharacter:Clone()

    -- Очистка физических контроллеров
    for _, v in ipairs(FakeCharacter:GetDescendants()) do
        if v:IsA("BodyVelocity") or v:IsA("BodyGyro") or v:IsA("BodyPosition") or v:IsA("VectorForce") then
            v:Destroy()
        end
    end

    FakeCharacter.Parent = workspace

    local realHRP = RealCharacter:FindFirstChild("HumanoidRootPart")
    local fakeHRP = FakeCharacter:FindFirstChild("HumanoidRootPart")
    
    if realHRP and fakeHRP then
        fakeHRP.CFrame = realHRP.CFrame
        lastSafeCFrame = fakeHRP.CFrame
    end

    -- Настройка визуала фантома
    for _, v in ipairs(FakeCharacter:GetDescendants()) do
        if v:IsA("BasePart") then
            v.Transparency = 0.85
            v.Material = Enum.Material.Glass
            v.Color = Color3.fromRGB(170, 170, 255)
            pcall(function() v.CanCollide = false end)
        end
    end

    -- Синхронизация движений с защитой от пустоты
    renderConn = RunService.RenderStepped:Connect(function()
        if not IsInvisible or not FakeCharacter then return end
        
        -- Anti-void защита
        if fakeHRP and fakeHRP.Position.Y < safeYThreshold then
            fakeHRP.CFrame = lastSafeCFrame or getSafeSpawnCFrame()
        end
        
        -- Обновление безопасной позиции
        if fakeHRP and fakeHRP.Position.Y > safeYThreshold then
            lastSafeCFrame = fakeHRP.CFrame
        end
        
        -- Синхронизация движений
        local realHum = findHumanoid(RealCharacter)
        local fakeHum = findHumanoid(FakeCharacter)
        if realHum and fakeHum then
            pcall(function()
                fakeHum:Move(realHum.MoveDirection)
                fakeHum.Jump = realHum.Jump
            end)
        end
    end)

    -- Анимация фантома
    FakeAnimData = { connections = {}, tracks = {}, current = nil }
    AttachAnimateToCharacter(FakeCharacter, FakeAnimData)

    -- Обработка смерти фантома
    local fakeHum = findHumanoid(FakeCharacter)
    if fakeHum then
        fakeDiedConn = fakeHum.Died:Connect(function()
            if IsInvisible then
                task.wait(0.12)
                cleanupFake()
                if IsInvisible then
                    CreateClone()
                end
            end
        end)
    end

    -- Перемещение реального персонажа
    if realHRP then
        RealCharacter:SetPrimaryPartCFrame(CFrame.new(0, 1e4, 0))
    end

    workspace.CurrentCamera.CameraSubject = findHumanoid(FakeCharacter)
    startAntiFling()
end

local function TeleportAndRemoveClone()
    if not IsInvisible then return end
    IsInvisible = false

    -- Безопасный телепорт с защитой от пустоты
    local safeCFrame = lastSafeCFrame or getSafeSpawnCFrame()
    if FakeCharacter and FakeCharacter:FindFirstChild("HumanoidRootPart") then
        local fakeHRP = FakeCharacter:FindFirstChild("HumanoidRootPart")
        if fakeHRP.Position.Y > safeYThreshold then
            safeCFrame = fakeHRP.CFrame + Vector3.new(0, 3, 0)
        end
    end

    -- Дополнительная проверка на пустоту
    if safeCFrame.Position.Y < safeYThreshold then
        safeCFrame = getSafeSpawnCFrame()
    end

    -- Телепорт реального персонажа
    if RealCharacter and RealCharacter:FindFirstChild("HumanoidRootPart") then
        pcall(function()
            RealCharacter:SetPrimaryPartCFrame(safeCFrame)
        end)
    end

    cleanupFake()
    workspace.CurrentCamera.CameraSubject = findHumanoid(RealCharacter)
    stopAntiFling()
end

-- ======== GUI ========
local function createGui()
    local gui = player:WaitForChild("PlayerGui")
    local existing = gui:FindFirstChild("InvisibilityCloakGUI")
    if existing then existing:Destroy() end

    local screen = Instance.new("ScreenGui")
    screen.Name = "InvisibilityCloakGUI"
    screen.ResetOnSpawn = false
    screen.Parent = gui

    local uiScale = Instance.new("UIScale", screen)
    uiScale.Scale = UserInputService.TouchEnabled and 1.2 or 1

    local container = Instance.new("Frame")
    container.Name = "MainContainer"
    container.Size = UDim2.new(0.25, 0, 0.09, 0)
    container.AnchorPoint = Vector2.new(1, 1)
    container.Position = savedPos and UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset) or UDim2.new(0.98, 0, 0.95, 0)
    container.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    container.BackgroundTransparency = 0.2
    container.Parent = screen
    
    -- ... (остальной код GUI остается без изменений)

    return button, stateIcon, stateText
end

-- ======== Основные функции ========
local function watchDeathForReal()
    if realDiedConn then
        realDiedConn:Disconnect()
        realDiedConn = nil
    end
    local realHum = findHumanoid(RealCharacter)
    if realHum then
        realDiedConn = realHum.Died:Connect(function()
            if IsInvisible then
                TeleportAndRemoveClone()
            end
        end)
    end
end

local button, stateIcon, stateText = createGui()

local function ToggleInvisibility()
    if not IsInvisible then
        IsInvisible = true
        CreateClone()
        watchDeathForReal()

        -- UI обновления
        stateText.Text = "INVISIBLE: ON"
        stateIcon.ImageRectOffset = Vector2.new(844, 884)
        
        TweenService:Create(stateIcon, TweenInfo.new(0.3), {
            ImageColor3 = Color3.fromRGB(100, 200, 255)
        }):Play()
        
        -- ... (остальные UI эффекты)
    else
        TeleportAndRemoveClone()
        
        -- UI обновления
        stateText.Text = "INVISIBLE: OFF"
        stateIcon.ImageRectOffset = Vector2.new(124, 364)
        
        TweenService:Create(stateIcon, TweenInfo.new(0.3), {
            ImageColor3 = Color3.fromRGB(200, 200, 255)
        }):Play()
    end
end

button.MouseButton1Click:Connect(ToggleInvisibility)

charAddedConn = player.CharacterAdded:Connect(function(char)
    RealCharacter = char
    if IsInvisible then
        TeleportAndRemoveClone()
    end
    watchDeathForReal()
end)

watchDeathForReal()
