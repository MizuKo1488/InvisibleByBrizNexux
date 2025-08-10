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
local affectedParts = {}

-- last safe position (CFrame) to teleport back if phantom is in void
local lastSafeCFrame = nil
-- порог пустоты: используем FallenPartsDestroyHeight если доступен, иначе -500
local voidY = workspace.FallenPartsDestroyHeight or -500
local safeYOffset = 10 -- margin above voidY to consider "safe"
local safeYThreshold = voidY + safeYOffset

-- Сохранение позиции UI (опционально для exploit сред)
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

-- ======== АНИМАЦИИ (адаптация Animate.lua) ========
local animNames = {
    idle = {
        { id = "http://www.roblox.com/asset/?id=507766666", weight = 1 },
        { id = "http://www.roblox.com/asset/?id=507766951", weight = 1 },
        { id = "http://www.roblox.com/asset/?id=507766388", weight = 9 },
    },
    walk = {
        { id = "http://www.roblox.com/asset/?id=507777826", weight = 10 },
    },
    run = {
        { id = "http://www.roblox.com/asset/?id=507767714", weight = 10 },
    },
    swim = {
        { id = "http://www.roblox.com/asset/?id=507784897", weight = 10 },
    },
    swimidle = {
        { id = "http://www.roblox.com/asset/?id=507785072", weight = 10 },
    },
    jump = {
        { id = "http://www.roblox.com/asset/?id=507765000", weight = 10 },
    },
    fall = {
        { id = "http://www.roblox.com/asset/?id=507767968", weight = 10 },
    },
    climb = {
        { id = "http://www.roblox.com/asset/?id=507765644", weight = 10 },
    },
    sit = {
        { id = "http://www.roblox.com/asset/?id=2506281703", weight = 10 },
    },
    toolnone = {
        { id = "http://www.roblox.com/asset/?id=507768375", weight = 10 },
    },
    toolslash = {
        { id = "http://www.roblox.com/asset/?id=522635514", weight = 10 },
    },
    toollunge = {
        { id = "http://www.roblox.com/asset/?id=522638767", weight = 10 },
    },
    wave = {
        { id = "http://www.roblox.com/asset/?id=507770239", weight = 10 },
    },
    point = {
        { id = "http://www.roblox.com/asset/?id=507770453", weight = 10 },
    },
    dance = {
        { id = "http://www.roblox.com/asset/?id=507771019", weight = 10 },
        { id = "http://www.roblox.com/asset/?id=507771955", weight = 10 },
        { id = "http://www.roblox.com/asset/?id=507772104", weight = 10 },
    },
    dance2 = {
        { id = "http://www.roblox.com/asset/?id=507776043", weight = 10 },
        { id = "http://www.roblox.com/asset/?id=507776720", weight = 10 },
        { id = "http://www.roblox.com/asset/?id=507776879", weight = 10 },
    },
    dance3 = {
        { id = "http://www.roblox.com/asset/?id=507777268", weight = 10 },
        { id = "http://www.roblox.com/asset/?id=507777451", weight = 10 },
        { id = "http://www.roblox.com/asset/?id=507777623", weight = 10 },
    },
    laugh = {
        { id = "http://www.roblox.com/asset/?id=507770818", weight = 10 },
    },
    cheer = {
        { id = "http://www.roblox.com/asset/?id=507770677", weight = 10 },
    },
}

local function rollAnimation(animList)
    if not animList then return 1 end
    local total = 0
    for i = 1, #animList do total = total + (animList[i].weight or 1) end
    local r = Random.new():NextInteger(1, math.max(1, total))
    local idx = 1
    while idx <= #animList do
        if r <= (animList[idx].weight or 1) then
            return idx
        end
        r = r - (animList[idx].weight or 1)
        idx = idx + 1
    end
    return 1
end

local function AttachAnimateToCharacter(char, storage)
    local humanoid = findHumanoid(char)
    if not humanoid then return end

    storage.connections = storage.connections or {}
    storage.tracks = storage.tracks or {}
    storage.currentAnim = nil
    storage.currentTrack = nil
    storage.runTrack = nil
    storage.animTable = {}

    for name, list in pairs(animNames) do
        storage.animTable[name] = {}
        for i = 1, #list do
            local animInst = Instance.new("Animation")
            animInst.Name = name
            animInst.AnimationId = list[i].id
            table.insert(storage.animTable[name], animInst)
            pcall(function()
                humanoid:LoadAnimation(animInst)
            end)
        end
    end

    local function stopCurrent()
        if storage.currentTrack then
            pcall(function()
                storage.currentTrack:Stop(0.1)
                storage.currentTrack:Destroy()
            end)
            storage.currentTrack = nil
            storage.currentAnim = nil
        end
        if storage.runTrack then
            pcall(function()
                storage.runTrack:Stop(0.1)
                storage.runTrack:Destroy()
            end)
            storage.runTrack = nil
        end
    end

    local function play(animName, transition)
        transition = transition or 0.2
        local list = storage.animTable[animName]
        if not list or #list == 0 then return end
        local idx = rollAnimation(animNames[animName]) or 1
        local animObj = list[idx] or list[1]
        if storage.currentTrack then
            pcall(function()
                storage.currentTrack:Stop(transition)
                storage.currentTrack:Destroy()
            end)
            storage.currentTrack = nil
        end
        local ok, track = pcall(function() return humanoid:LoadAnimation(animObj) end)
        if ok and track then
            storage.currentTrack = track
            track.Priority = Enum.AnimationPriority.Core
            track:Play(transition)
            storage.currentAnim = animName
        end
        if animName == "walk" then
            local runList = storage.animTable["run"]
            if runList and #runList > 0 then
                local idx2 = rollAnimation(animNames["run"]) or 1
                local runAnimObj = runList[idx2]
                local ok2, runTrack = pcall(function() return humanoid:LoadAnimation(runAnimObj) end)
                if ok2 and runTrack then
                    storage.runTrack = runTrack
                    runTrack.Priority = Enum.AnimationPriority.Core
                    runTrack:Play(transition)
                end
            end
        end
    end

    local function setRunSpeed(speed)
        local base = 16
        local s = speed / base
        if storage.currentTrack then
            pcall(function() storage.currentTrack:AdjustSpeed(math.max(0.01, s)) end)
        end
        if storage.runTrack then
            pcall(function() storage.runTrack:AdjustSpeed(math.max(0.01, s)) end)
        end
    end

    local function onStateChanged(old, new)
        if new == Enum.HumanoidStateType.Jumping then
            play("jump", 0.1)
        elseif new == Enum.HumanoidStateType.Freefall then
            play("fall", 0.15)
        elseif new == Enum.HumanoidStateType.Seated then
            play("sit", 0.2)
        elseif new == Enum.HumanoidStateType.Dead then
            stopCurrent()
        end
    end

    local function onRunning(speed)
        if speed > 0.75 then
            play("walk", 0.2)
            setRunSpeed(speed)
        else
            if storage.currentAnim ~= "idle" then
                play("idle", 0.2)
            end
        end
    end

    local function onClimbing(speed)
        play("climb", 0.1)
        setRunSpeed(speed)
    end

    local function onSwimming(speed)
        if speed > 1.0 then
            play("swim", 0.2)
            setRunSpeed(speed)
        else
            play("swimidle", 0.2)
        end
    end

    table.insert(storage.connections, humanoid.StateChanged:Connect(onStateChanged))
    table.insert(storage.connections, humanoid.Running:Connect(onRunning))
    table.insert(storage.connections, humanoid.Climbing:Connect(onClimbing))
    table.insert(storage.connections, humanoid.Swimming:Connect(onSwimming))

    play("idle", 0.1)

    storage._stopAll = function()
        if storage.currentTrack then
            pcall(function() storage.currentTrack:Stop() storage.currentTrack:Destroy() end)
            storage.currentTrack = nil
        end
        if storage.runTrack then
            pcall(function() storage.runTrack:Stop() storage.runTrack:Destroy() end)
            storage.runTrack = nil
        end
        if storage.connections then
            for _,c in ipairs(storage.connections) do
                pcall(function() c:Disconnect() end)
            end
            storage.connections = {}
        end
    end
end

local function CleanupAnimateStorage(storage)
    if not storage then return end
    if storage._stopAll then
        pcall(storage._stopAll)
    end
    storage._stopAll = nil
    storage.animTable = nil
    storage.tracks = nil
    storage.currentAnim = nil
    storage.currentTrack = nil
    storage.runTrack = nil
    storage.connections = nil
end

-- ======== Anti-Fling ========
local function startAntiFling()
    if antiFlingEnabled then return end
    antiFlingEnabled = true
    affectedParts = {}

    antiFlingConn = RunService.Heartbeat:Connect(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name == "HumanoidRootPart" and obj.Parent and obj.Parent ~= player.Character then
                affectedParts[obj] = true
                pcall(function()
                    obj.CustomPhysicalProperties = PhysicalProperties.new(0,0,0,0,0)
                    obj.Velocity = Vector3.new(0,0,0)
                    obj.RotVelocity = Vector3.new(0,0,0)
                    obj.CanCollide = false
                end)
            end
        end
    end)

    antiFlingDescAddedConn = workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("BasePart") and obj.Name == "HumanoidRootPart" and obj.Parent and obj.Parent ~= player.Character then
            affectedParts[obj] = true
            pcall(function()
                obj.CustomPhysicalProperties = PhysicalProperties.new(0,0,0,0,0)
                obj.Velocity = Vector3.new(0,0,0)
                obj.RotVelocity = Vector3.new(0,0,0)
                obj.CanCollide = false
            end)
        end
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
    affectedParts = {}
    antiFlingEnabled = false
end

-- ======== Управление клоном / safe-teleport ========
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
    end
    if fakeHRP then
        fakeHRP.Anchored = false
    end

    -- Делаем фантом полупрозрачным с эффектами
    for _, v in ipairs(FakeCharacter:GetDescendants()) do
        if v:IsA("BasePart") then
            v.Transparency = 0.85
            v.Material = Enum.Material.Glass
            v.Color = Color3.fromRGB(170, 170, 255)
            pcall(function() v.CanCollide = false end)
        end
    end

    workspace.CurrentCamera.CameraSubject = findHumanoid(FakeCharacter)

    -- Перемещаем оригинал
    if realHRP then
        RealCharacter:SetPrimaryPartCFrame(CFrame.new(0, 1e4, 0))
    end

    -- Синхронизируем движения
    renderConn = RunService.RenderStepped:Connect(function()
        if not IsInvisible or not FakeCharacter then return end
        workspace.CurrentCamera.CameraSubject = findHumanoid(FakeCharacter)
        local realHum = findHumanoid(RealCharacter)
        local fakeHum = findHumanoid(FakeCharacter)
        if realHum and fakeHum then
            pcall(function()
                fakeHum:Move(realHum.MoveDirection)
                fakeHum.Jump = realHum.Jump
            end)
        end

        -- Обновляем lastSafeCFrame
        if fakeHRP and fakeHRP.Parent and fakeHRP.Position and fakeHRP.Position.Y and fakeHRP.Position.Y > safeYThreshold then
            lastSafeCFrame = fakeHRP.CFrame
        end
    end)

    -- Анимируем фантом
    FakeAnimData = { connections = {}, tracks = {}, current = nil }
    AttachAnimateToCharacter(FakeCharacter, FakeAnimData)

    -- При смерти фантома
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
end

local function TeleportAndRemoveClone()
    if not IsInvisible then return end
    IsInvisible = false

    if renderConn then
        renderConn:Disconnect()
        renderConn = nil
    end

    -- Безопасный телепорт с защитой от пустоты
    local fakeHRP = FakeCharacter and FakeCharacter:FindFirstChild("HumanoidRootPart")
    local safeCFrameToUse = nil

    if fakeHRP then
        local fy = fakeHRP.Position.Y
        if fy and fy > safeYThreshold then
            safeCFrameToUse = fakeHRP.CFrame + Vector3.new(0, 3, 0)
        elseif lastSafeCFrame then
            safeCFrameToUse = lastSafeCFrame + Vector3.new(0, 3, 0)
        else
            if player.RespawnLocation and player.RespawnLocation:IsA("BasePart") then
                safeCFrameToUse = player.RespawnLocation.CFrame + Vector3.new(0, 3, 0)
            else
                local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
                if spawn then
                    safeCFrameToUse = spawn.CFrame + Vector3.new(0, 3, 0)
                else
                    safeCFrameToUse = workspace.CurrentCamera.CFrame
                end
            end
        end
    elseif lastSafeCFrame then
        safeCFrameToUse = lastSafeCFrame + Vector3.new(0, 3, 0)
    else
        if player.RespawnLocation and player.RespawnLocation:IsA("BasePart") then
            safeCFrameToUse = player.RespawnLocation.CFrame + Vector3.new(0, 3, 0)
        else
            local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
            if spawn then
                safeCFrameToUse = spawn.CFrame + Vector3.new(0, 3, 0)
            else
                safeCFrameToUse = workspace.CurrentCamera.CFrame
            end
        end
    end

    -- Телепорт реального персонажа
    if RealCharacter and RealCharacter:FindFirstChild("HumanoidRootPart") and safeCFrameToUse then
        pcall(function()
            RealCharacter:SetPrimaryPartCFrame(safeCFrameToUse)
        end)
    end

    cleanupFake()
    workspace.CurrentCamera.CameraSubject = findHumanoid(RealCharacter)
    stopAntiFling()
end

-- Следим за смертью реального персонажа
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

-- ======== УЛУЧШЕННЫЙ GUI ========
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
    
    local corner = Instance.new("UICorner", container)
    corner.CornerRadius = UDim.new(0, 12)
    
    local stroke = Instance.new("UIStroke", container)
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(80, 100, 180)
    stroke.Transparency = 0.3

    -- Эффект свечения
    local glow = Instance.new("ImageLabel")
    glow.Name = "GlowEffect"
    glow.Size = UDim2.new(1.1, 0, 1.1, 0)
    glow.Position = UDim2.new(-0.05, 0, -0.05, 0)
    glow.BackgroundTransparency = 1
    glow.Image = "rbxassetid://8992231221" -- ID текстуры свечения
    glow.ImageColor3 = Color3.fromRGB(60, 90, 160)
    glow.ScaleType = Enum.ScaleType.Slice
    glow.SliceCenter = Rect.new(100, 100, 100, 100)
    glow.Parent = container

    -- Основная кнопка
    local button = Instance.new("TextButton")
    button.Name = "ToggleButton"
    button.Size = UDim2.new(1, 0, 1, 0)
    button.BackgroundTransparency = 1
    button.Text = ""
    button.ZIndex = 2
    button.Parent = container

    -- Контент
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -20, 1, -10)
    content.Position = UDim2.new(0, 10, 0, 5)
    content.BackgroundTransparency = 1
    content.Parent = container

    -- Иконка состояния
    local stateIcon = Instance.new("ImageLabel")
    stateIcon.Name = "StateIcon"
    stateIcon.Size = UDim2.new(0.15, 0, 0.8, 0)
    stateIcon.Position = UDim2.new(0, 0, 0.1, 0)
    stateIcon.BackgroundTransparency = 1
    stateIcon.Image = "rbxassetid://3926305904" -- ID иконки глаза
    stateIcon.ImageRectOffset = Vector2.new(124, 364)
    stateIcon.ImageRectSize = Vector2.new(36, 36)
    stateIcon.ImageColor3 = Color3.fromRGB(200, 200, 
    stateIcon.Parent = content

    -- Текст состояния
    local stateText = Instance.new("TextLabel")
    stateText.Name = "StateText"
    stateText.Size = UDim2.new(0.7, 0, 0.8, 0)
    stateText.Position = UDim2.new(0.17, 0, 0.1, 0)
    stateText.BackgroundTransparency = 1
    stateText.Font = Enum.Font.GothamBold
    stateText.Text = "INVISIBLE: OFF"
    stateText.TextColor3 = Color3.fromRGB(200, 220, 255)
    stateText.TextSize = 18
    stateText.TextXAlignment = Enum.TextXAlignment.Left
    stateText.Parent = content

    -- Подпись создателя
    local signature = Instance.new("TextLabel")
    signature.Name = "Signature"
    signature.Size = UDim2.new(1, 0, 0.3, 0)
    signature.Position = UDim2.new(0, 0, 0.7, 0)
    signature.BackgroundTransparency = 1
    signature.Font = Enum.Font.Gotham
    signature.TextSize = 12
    signature.TextColor3 = Color3.fromRGB(160, 180, 220)
    signature.Text = "by BrizNexuc"
    signature.TextXAlignment = Enum.TextXAlignment.Right
    signature.Parent = content

    -- Эффект при наведении
    button.MouseEnter:Connect(function()
        TweenService:Create(container, TweenInfo.new(0.2), {
            BackgroundTransparency = 0.1,
            Size = UDim2.new(0.26, 0, 0.095, 0)
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), {
            Thickness = 3,
            Transparency = 0
        }):Play()
    end)

    button.MouseLeave:Connect(function()
        TweenService:Create(container, TweenInfo.new(0.3), {
            BackgroundTransparency = 0.2,
            Size = UDim2.new(0.25, 0, 0.09, 0)
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.3), {
            Thickness = 2,
            Transparency = 0.3
        }):Play()
    end)

    -- Перетаскивание с сохранением
    local dragging, dragStart, startPos
    local function update(input)
        local delta = input.Position - dragStart
        container.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = container.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    -- Сохраняем позицию
                    pcall(function()
                        if writefile then
                            writefile(savedPosFile, HttpService:JSONEncode({
                                X = {Scale = container.Position.X.Scale, Offset = container.Position.X.Offset},
                                Y = {Scale = container.Position.Y.Scale, Offset = container.Position.Y.Offset}
                            }))
                        end
                    end)
                end
            end)
        end
    end)
    
    button.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                update(input)
            end
        end
    end)

    return button, stateIcon, stateText
end

local button, stateIcon, stateText = createGui()

-- Переключение режима
local function ToggleInvisibility()
    if not IsInvisible then
        IsInvisible = true
        CreateClone()
        watchDeathForReal()
        startAntiFling() -- Включаем защиту от флинга

        -- Обновление UI
        stateText.Text = "INVISIBLE: ON"
        stateIcon.ImageRectOffset = Vector2.new(844, 884) -- Иконка перечеркнутого глаза
        
        TweenService:Create(stateIcon, TweenInfo.new(0.3), {
            ImageColor3 = Color3.fromRGB(100, 200, 255)
        }):Play()
        
        TweenService:Create(stateText, TweenInfo.new(0.3), {
            TextColor3 = Color3.fromRGB(100, 200, 255)
        }):Play()

        -- Звуковой эффект
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://232127604" -- Звук активации
        sound.Parent = SoundService
        sound:Play()
        game.Debris:AddItem(sound, 3)

        StarterGui:SetCore("SendNotification", {
            Title = "🕶 INVISIBILITY CLOAK",
            Text = "Mode enabled | by BrizNexuc",
            Duration = 4,
            Icon = "rbxassetid://3926305904"
        })
    else
        TeleportAndRemoveClone()
        IsInvisible = false
        
        -- Обновление UI
        stateText.Text = "INVISIBLE: OFF"
        stateIcon.ImageRectOffset = Vector2.new(124, 364) -- Иконка глаза
        
        TweenService:Create(stateIcon, TweenInfo.new(0.3), {
            ImageColor3 = Color3.fromRGB(200, 200, 255)
        }):Play()
        
        TweenService:Create(stateText, TweenInfo.new(0.3), {
            TextColor3 = Color3.fromRGB(200, 220, 255)
        }):Play()

        StarterGui:SetCore("SendNotification", {
            Title = "🕶 INVISIBILITY CLOAK",
            Text = "Mode disabled | by BrizNexuc",
            Duration = 3,
            Icon = "rbxassetid://3926305904"
        })
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
