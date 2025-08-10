-- LocalScript: Invisible + Animate + AntiFling + AntiVoid (проверено на синтаксис)
-- Положить в StarterPlayerScripts

-- Ждём загрузки игры
if not game:IsLoaded() then
    repeat task.wait() until game:IsLoaded()
end

-- Сервисы
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- Состояния
local IsInvisible = false
local RealCharacter = player.Character or player.CharacterAdded:Wait()
local FakeCharacter = nil

local FakeAnimData = {}

-- AntiFling cache и подключения
local affectedParts = {}
local antiFlingHB = nil
local antiFlingAddedConn = nil
local antiFlingRemovingConn = nil

-- Safe position (anti-void)
local lastSafeCFrame = nil
local voidY = Workspace.FallenPartsDestroyHeight or -500
local safeYOffset = 10
local safeYThreshold = voidY + safeYOffset

-- Сохранение позиции кнопки (если доступны writefile/readfile)
local savedPosFile = "InvisibleButtonPos_" .. tostring(player.UserId) .. ".json"
local savedPos = nil
pcall(function()
    if readfile and isfile and isfile(savedPosFile) then
        savedPos = HttpService:JSONDecode(readfile(savedPosFile))
    end
end)

-- Уведомление о старте
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "Invisibility script",
        Text = "Anti-Fling & Anti-Void active",
        Duration = 4
    })
end)

-- Утилиты
local function findHumanoid(char)
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function updateCharacter()
    RealCharacter = player.Character or player.CharacterAdded:Wait()
end

-- Secure part (для AntiFling)
local function securePart(part)
    if not part or not part.Parent then return end
    pcall(function()
        if part:IsA("BasePart") then
            part.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0, 0, 0)
            part.Velocity = Vector3.new(0, 0, 0)
            part.RotVelocity = Vector3.new(0, 0, 0)
            part.CanCollide = false
        end
    end)
end

-- ========== Anti-Fling (эффективно, с кешем) ==========
local function startAntiFling()
    if antiFlingHB then return end

    -- начальная выборка
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name == "HumanoidRootPart" and obj.Parent ~= player.Character then
            affectedParts[obj] = true
        end
    end

    antiFlingHB = RunService.Heartbeat:Connect(function()
        -- проходим только по кешу
        for part, _ in pairs(affectedParts) do
            if part and part.Parent and part:IsA("BasePart") then
                securePart(part)
            else
                affectedParts[part] = nil
            end
        end
    end)

    antiFlingAddedConn = Workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("BasePart") and obj.Name == "HumanoidRootPart" and obj.Parent ~= player.Character then
            affectedParts[obj] = true
            securePart(obj)
        end
    end)

    antiFlingRemovingConn = Workspace.DescendantRemoving:Connect(function(obj)
        affectedParts[obj] = nil
    end)
end

local function stopAntiFling()
    if antiFlingHB then antiFlingHB:Disconnect() antiFlingHB = nil end
    if antiFlingAddedConn then antiFlingAddedConn:Disconnect() antiFlingAddedConn = nil end
    if antiFlingRemovingConn then antiFlingRemovingConn:Disconnect() antiFlingRemovingConn = nil end
    affectedParts = {}
end

-- ========== АНИМАЦИОННАЯ СИСТЕМА (адаптировано из Animate.lua) ==========
local animNames = {
    idle = { { id = "http://www.roblox.com/asset/?id=507766388", weight = 9 }, { id = "http://www.roblox.com/asset/?id=507766666", weight = 1 }, { id = "http://www.roblox.com/asset/?id=507766951", weight = 1 } },
    walk = { { id = "http://www.roblox.com/asset/?id=507777826", weight = 10 } },
    run = { { id = "http://www.roblox.com/asset/?id=507767714", weight = 10 } },
    jump = { { id = "http://www.roblox.com/asset/?id=507765000", weight = 10 } },
    fall = { { id = "http://www.roblox.com/asset/?id=507767968", weight = 10 } },
    climb = { { id = "http://www.roblox.com/asset/?id=507765644", weight = 10 } },
    swim = { { id = "http://www.roblox.com/asset/?id=507784897", weight = 10 } },
    swimidle = { { id = "http://www.roblox.com/asset/?id=507785072", weight = 10 } },
    sit = { { id = "http://www.roblox.com/asset/?id=2506281703", weight = 10 } },
    toolnone = { { id = "http://www.roblox.com/asset/?id=507768375", weight = 10 } },
    toolslash = { { id = "http://www.roblox.com/asset/?id=522635514", weight = 10 } },
    toollunge = { { id = "http://www.roblox.com/asset/?id=522638767", weight = 10 } },
    wave = { { id = "http://www.roblox.com/asset/?id=507770239", weight = 10 } },
    point = { { id = "http://www.roblox.com/asset/?id=507770453", weight = 10 } },
    dance = { { id = "http://www.roblox.com/asset/?id=507771019", weight = 10 }, { id = "http://www.roblox.com/asset/?id=507771955", weight = 10 }, { id = "http://www.roblox.com/asset/?id=507772104", weight = 10 } },
    laugh = { { id = "http://www.roblox.com/asset/?id=507770818", weight = 10 } },
    cheer = { { id = "http://www.roblox.com/asset/?id=507770677", weight = 10 } },
}

local function rollAnimation(list)
    local total = 0
    for _, v in ipairs(list) do total = total + (v.weight or 1) end
    local r = Random.new():NextInteger(1, math.max(1, total))
    local idx = 1
    while idx <= #list do
        if r <= (list[idx].weight or 1) then
            return idx
        end
        r = r - (list[idx].weight or 1)
        idx = idx + 1
    end
    return 1
end

local function AttachAnimateToCharacter(char, storage)
    local humanoid = findHumanoid(char)
    if not humanoid then return end

    storage.connections = {}
    storage.animTable = {}
    storage.currentTrack = nil
    storage.runTrack = nil

    for name, list in pairs(animNames) do
        storage.animTable[name] = {}
        for _, data in ipairs(list) do
            local anim = Instance.new("Animation")
            anim.Name = name
            anim.AnimationId = data.id
            table.insert(storage.animTable[name], anim)
            pcall(function() humanoid:LoadAnimation(anim) end)
        end
    end

    local function stopAll()
        if storage.currentTrack then
            pcall(function() storage.currentTrack:Stop(); storage.currentTrack:Destroy() end)
            storage.currentTrack = nil
        end
        if storage.runTrack then
            pcall(function() storage.runTrack:Stop(); storage.runTrack:Destroy() end)
            storage.runTrack = nil
        end
        for _, c in ipairs(storage.connections) do
            pcall(function() c:Disconnect() end)
        end
        storage.connections = {}
    end

    local function play(animName, transition)
        transition = transition or 0.2
        local list = storage.animTable[animName]
        if not list or #list == 0 then return end
        local idx = rollAnimation(animNames[animName])
        local animObj = list[idx] or list[1]

        if storage.currentTrack then
            pcall(function() storage.currentTrack:Stop(transition); storage.currentTrack:Destroy() end)
            storage.currentTrack = nil
        end
        local ok, track = pcall(function() return humanoid:LoadAnimation(animObj) end)
        if ok and track then
            storage.currentTrack = track
            track.Priority = Enum.AnimationPriority.Core
            track:Play(transition)
        end

        if animName == "walk" then
            local runList = storage.animTable["run"]
            if runList and #runList > 0 then
                local idx2 = rollAnimation(animNames["run"])
                local runObj = runList[idx2]
                local ok2, runTrack = pcall(function() return humanoid:LoadAnimation(runObj) end)
                if ok2 and runTrack then
                    storage.runTrack = runTrack
                    runTrack.Priority = Enum.AnimationPriority.Core
                    runTrack:Play(transition)
                end
            end
        end
    end

    table.insert(storage.connections, humanoid.Running:Connect(function(speed)
        if speed > 0.75 then
            play("walk", 0.2)
            if storage.runTrack then pcall(function() storage.runTrack:AdjustSpeed(math.max(0.01, speed / 16)) end) end
        else
            play("idle", 0.2)
        end
    end))

    table.insert(storage.connections, humanoid.StateChanged:Connect(function(_, new)
        if new == Enum.HumanoidStateType.Jumping then
            play("jump", 0.1)
        elseif new == Enum.HumanoidStateType.Freefall then
            play("fall", 0.15)
        elseif new == Enum.HumanoidStateType.Seated then
            play("sit", 0.2)
        elseif new == Enum.HumanoidStateType.Dead then
            stopAll()
        end
    end))

    storage.stopAll = stopAll
    play("idle", 0.1)
end

local function CleanupAnimateStorage(storage)
    if storage and storage.stopAll then
        pcall(storage.stopAll)
    end
end

-- ========== Clone management & anti-void ==========
local renderConn = nil
local realDiedConn = nil
local fakeDiedConn = nil

local function cleanupFake()
    if fakeDiedConn then fakeDiedConn:Disconnect(); fakeDiedConn = nil end
    if renderConn then renderConn:Disconnect(); renderConn = nil end
    if FakeCharacter then
        CleanupAnimateStorage(FakeAnimData)
        pcall(function() FakeCharacter:Destroy() end)
        FakeCharacter = nil
    end
end

local function CreateClone()
    updateCharacter()
    if not RealCharacter or not RealCharacter:FindFirstChild("HumanoidRootPart") then return end

    cleanupFake()

    RealCharacter.Archivable = true
    FakeCharacter = RealCharacter:Clone()
    FakeCharacter.Parent = Workspace

    local realHRP = RealCharacter:FindFirstChild("HumanoidRootPart")
    local fakeHRP = FakeCharacter:FindFirstChild("HumanoidRootPart")
    if realHRP and fakeHRP then
        pcall(function() fakeHRP.CFrame = realHRP.CFrame end)
        fakeHRP.Anchored = false
    end

    -- очищаем физические силы и делаем фантом полупрозрачным
    for _, v in ipairs(FakeCharacter:GetDescendants()) do
        if v:IsA("BasePart") then
            v.Transparency = 0.85
            pcall(function() v.CanCollide = false end)
        elseif v:IsA("BodyVelocity") or v:IsA("BodyGyro") or v:IsA("BodyPosition") or v:IsA("VectorForce") then
            pcall(function() v:Destroy() end)
        end
    end

    Workspace.CurrentCamera.CameraSubject = findHumanoid(FakeCharacter)

    -- Перемещаем оригинал «в безопасное место», чтобы он не мешал физике
    if realHRP then
        pcall(function() realHRP.CFrame = CFrame.new(0, 10000, 0) end)
    end

    -- Подключаем анимации локально к фантому
    FakeAnimData = {}
    AttachAnimateToCharacter(FakeCharacter, FakeAnimData)

    -- Синхронизация движения и обновление lastSafeCFrame
    renderConn = RunService.RenderStepped:Connect(function()
        if not IsInvisible or not FakeCharacter then return end
        local realHum = findHumanoid(RealCharacter)
        local fakeHum = findHumanoid(FakeCharacter)
        if realHum and fakeHum then
            pcall(function()
                fakeHum:Move(realHum.MoveDirection)
                fakeHum.Jump = realHum.Jump
            end)
        end
        if fakeHRP and fakeHRP.Position and fakeHRP.Position.Y > safeYThreshold then
            lastSafeCFrame = fakeHRP.CFrame
        end
    end)

    -- При смерти фантома — пересоздаём
    local fakeHum = findHumanoid(FakeCharacter)
    if fakeHum then
        fakeDiedConn = fakeHum.Died:Connect(function()
            if IsInvisible then
                task.wait(0.12)
                cleanupFake()
                if IsInvisible then CreateClone() end
            end
        end)
    end
end

local function TeleportAndRemoveClone()
    if not IsInvisible then return end
    IsInvisible = false

    if renderConn then renderConn:Disconnect(); renderConn = nil end

    -- Выбираем безопасную позицию
    local safeCFrame = nil
    local fakeHRP = FakeCharacter and FakeCharacter:FindFirstChild("HumanoidRootPart")
    if fakeHRP and fakeHRP.Position and fakeHRP.Position.Y > safeYThreshold then
        safeCFrame = fakeHRP.CFrame + Vector3.new(0, 3, 0)
    elseif lastSafeCFrame then
        safeCFrame = lastSafeCFrame + Vector3.new(0, 3, 0)
    elseif player.RespawnLocation and player.RespawnLocation:IsA("BasePart") then
        safeCFrame = player.RespawnLocation.CFrame + Vector3.new(0, 3, 0)
    else
        local spawn = Workspace:FindFirstChildOfClass("SpawnLocation")
        safeCFrame = spawn and (spawn.CFrame + Vector3.new(0, 3, 0)) or Workspace.CurrentCamera.CFrame
    end

    -- Телепортируем реальный персонаж
    local realHRP = RealCharacter and RealCharacter:FindFirstChild("HumanoidRootPart")
    if realHRP and safeCFrame then
        pcall(function() realHRP.CFrame = safeCFrame end)
    end

    cleanupFake()
    Workspace.CurrentCamera.CameraSubject = findHumanoid(RealCharacter)
    stopAntiFling()
end

local function watchDeathForReal()
    if realDiedConn then realDiedConn:Disconnect(); realDiedConn = nil end
    local realHum = findHumanoid(RealCharacter)
    if realHum then
        realDiedConn = realHum.Died:Connect(function()
            if IsInvisible then TeleportAndRemoveClone() end
        end)
    end
end

-- ========== GUI: кнопка ==========
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

    local button = Instance.new("TextButton")
    button.Name = "ToggleButton"
    button.Size = UDim2.new(0.22, 0, 0.08, 0)
    button.AnchorPoint = Vector2.new(1, 1)
    button.Position = savedPos and UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset) or UDim2.new(0.98, 0, 0.95, 0)
    button.Text = "Invisible enable"
    button.Font = Enum.Font.GothamBold
    button.TextSize = 20
    button.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Parent = screen

    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", button)
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(100, 100, 140)

    local signature = Instance.new("TextLabel")
    signature.Size = UDim2.new(1, 0, 0.4, 0)
    signature.Position = UDim2.new(0, 0, 0.65, 0)
    signature.BackgroundTransparency = 1
    signature.Font = Enum.Font.Gotham
    signature.TextSize = 12
    signature.TextColor3 = Color3.fromRGB(180, 180, 180)
    signature.Text = "by BrizNexuc (fixed)"
    signature.Parent = button

    -- Drag + save
    local dragging, dragStart, startPos = false, nil, nil
    local function update(input)
        local delta = input.Position - dragStart
        button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end

    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = button.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    pcall(function()
                        if writefile then
                            writefile(savedPosFile, HttpService:JSONEncode({
                                X = { Scale = button.Position.X.Scale, Offset = button.Position.X.Offset },
                                Y = { Scale = button.Position.Y.Scale, Offset = button.Position.Y.Offset },
                            }))
                        end
                    end)
                end
            end)
        end
    end)

    button.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then update(input) end
        end
    end)

    return button
end

local button = createGui()

-- Переключатель невидимости
button.MouseButton1Click:Connect(function()
    if not IsInvisible then
        IsInvisible = true
        CreateClone()
        watchDeathForReal()
        startAntiFling()
        button.Text = "Invisible disable"
        pcall(function()
            local s = Instance.new("Sound")
            s.SoundId = "rbxassetid://232127604"
            s.Parent = SoundService
            s:Play()
            game.Debris:AddItem(s, 3)
        end)
        TweenService:Create(button, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(55, 75, 110) }):Play()
        StarterGui:SetCore("SendNotification", { Title = "Invisible Cloak", Text = "Mode enabled", Duration = 4 })
    else
        TeleportAndRemoveClone()
        IsInvisible = false
        button.Text = "Invisible enable"
        TweenService:Create(button, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(35, 35, 40) }):Play()
        StarterGui:SetCore("SendNotification", { Title = "Invisible Cloak", Text = "Mode disabled", Duration = 3 })
    end
end)

-- Reset при смене персонажа
player.CharacterAdded:Connect(function(char)
    RealCharacter = char
    if IsInvisible then
        -- безопасно вернём персонажа в игру
        TeleportAndRemoveClone()
    end
    watchDeathForReal()
end)

watchDeathForReal()
