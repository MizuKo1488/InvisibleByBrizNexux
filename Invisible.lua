
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

local IsInvisible = false
local RealCharacter = player.Character or player.CharacterAdded:Wait()
local FakeCharacter = nil

-- Соединения
local renderConn, realDiedConn, fakeDiedConn, charAddedConn = nil, nil, nil, nil

-- Анимационные соединения/треки для клона (чтобы потом корректно очистить)
local FakeAnimData = {
connections = {},
tracks = {},
current = nil,
}

-- Хранилище позиции кнопки (локально)
local savedPosFile = "buttonPos_" .. player.UserId .. ".json"
local savedPos = nil
pcall(function()
if isfile and isfile(savedPosFile) then
savedPos = HttpService:JSONDecode(readfile(savedPosFile))
end
end)

-- Поиск Humanoid
local function findHumanoid(char)
if not char then return nil end
return char:FindFirstChildOfClass("Humanoid")
end

-- Обновление ссылки на персонажа
local function updateCharacter()
RealCharacter = player.Character or player.CharacterAdded:Wait()
end

-- ========== АНИМАЦИОННАЯ СИСТЕМА (упрощённая адаптация Animate.lua) ==========

-- Таблица стандартных анимаций (взято из Animate.lua gist)
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
-- простая рулетка по весам
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
-- storage: таблица для хранения connections и tracks (чтобы можно было очистить)
local humanoid = findHumanoid(char)
if not humanoid then return end

storage.connections = storage.connections or {}  
storage.tracks = storage.tracks or {}  
storage.currentAnim = nil  
storage.currentTrack = nil  
storage.runTrack = nil  
storage.animTable = {}  

-- подготовим animTable: для каждого имени создаём Animation объекты (по дефолту из animNames)  
for name, list in pairs(animNames) do  
    storage.animTable[name] = {}  
    for i = 1, #list do  
        local animInst = Instance.new("Animation")  
        animInst.Name = name  
        animInst.AnimationId = list[i].id  
        table.insert(storage.animTable[name], animInst)  
        -- preload (LoadAnimation кэширует/возвращает трек)  
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
    -- если тот же animation instance — не перегружаем  
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
    -- если walk — стартим run-layer  
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

-- сеттер скорости: упрощённо подменяем веса/скорости для walk/run  
local function setRunSpeed(speed)  
    -- scale approx: base 16  
    local base = 16  
    local s = speed / base  
    if storage.currentTrack then  
        pcall(function() storage.currentTrack:AdjustSpeed(math.max(0.01, s)) end)  
    end  
    if storage.runTrack then  
        pcall(function() storage.runTrack:AdjustSpeed(math.max(0.01, s)) end)  
    end  
end  

-- обработчики состояний  
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
        -- если не в свободном падении и не эмоте — возрврат к idle  
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

-- подписываемся на события humanoid и сохраняем ссылки в storage.connections  
table.insert(storage.connections, humanoid.StateChanged:Connect(onStateChanged))  
table.insert(storage.connections, humanoid.Running:Connect(onRunning))  
table.insert(storage.connections, humanoid.Climbing:Connect(onClimbing))  
table.insert(storage.connections, humanoid.Swimming:Connect(onSwimming))  

-- инициализация: стартуем idle  
play("idle", 0.1)  

-- сохраняем функцию остановки для внешней очистки  
storage._stopAll = function()  
    -- остановим треки  
    if storage.currentTrack then  
        pcall(function() storage.currentTrack:Stop() storage.currentTrack:Destroy() end)  
        storage.currentTrack = nil  
    end  
    if storage.runTrack then  
        pcall(function() storage.runTrack:Stop() storage.runTrack:Destroy() end)  
        storage.runTrack = nil  
    end  
    -- отключим подписки  
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

-- ========== ОКОНЧАНИЕ АНИМАЦИОННОЙ СИСТЕМЫ ==========

-- Удаление клона
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
-- очистим анимации, если прикручивали
CleanupAnimateStorage(FakeAnimData)
FakeCharacter:Destroy()
FakeCharacter = nil
end
end

-- Создание клона
local function CreateClone()
updateCharacter()
if not RealCharacter:FindFirstChild("HumanoidRootPart") then return end

cleanupFake()  

RealCharacter.Archivable = true  
FakeCharacter = RealCharacter:Clone()  

-- убираем лишнее у клона (физические силы и т.п.)  
for _, v in ipairs(FakeCharacter:GetDescendants()) do  
    if v:IsA("BodyVelocity") or v:IsA("BodyGyro") or v:IsA("BodyPosition") then  
        v:Destroy()  
    end  
end  

FakeCharacter.Parent = workspace  
-- синхронно поставить в то же место  
local realHRP = RealCharacter:FindFirstChild("HumanoidRootPart")  
local fakeHRP = FakeCharacter:FindFirstChild("HumanoidRootPart")  
if realHRP and fakeHRP then  
    fakeHRP.CFrame = realHRP.CFrame  
end  
if fakeHRP then  
    fakeHRP.Anchored = false  
end  

-- Подменяю прозрачность у частей клона (чтобы был полупрозрачный фантом)  
for _, v in ipairs(FakeCharacter:GetDescendants()) do  
    if v:IsA("BasePart") then  
        v.Transparency = 0.85  
    elseif v:IsA("Decal") or v:IsA("Texture") then  
        -- по желанию оставить видимые детали; можно менять  
        -- оставим как есть  
    end  
end  

-- Камера на фантом  
workspace.CurrentCamera.CameraSubject = findHumanoid(FakeCharacter)  

-- Перемещаем оригинал далеко (чтобы не мешал)  
if realHRP then  
    RealCharacter.HumanoidRootPart.CFrame = RealCharacter.HumanoidRootPart.CFrame + Vector3.new(0, 1e5, 0)  
end  

-- Синхронизация движения фантома с оригиналом (копируем направление и прыжки)  
renderConn = RunService.RenderStepped:Connect(function()  
    if not IsInvisible or not FakeCharacter then return end  
    workspace.CurrentCamera.CameraSubject = findHumanoid(FakeCharacter)  
    local realHum = findHumanoid(RealCharacter)  
    local fakeHum = findHumanoid(FakeCharacter)  
    if realHum and fakeHum then  
        -- MoveDirection нельзя напрямую присвоить, используем Move()  
        pcall(function()  
            fakeHum:Move(realHum.MoveDirection)  
            fakeHum.Jump = realHum.Jump  
        end)  
    end  
end)  

-- Прикручиваем анимационную систему к клону (локально)  
FakeAnimData = { connections = {}, tracks = {}, current = nil }  
AttachAnimateToCharacter(FakeCharacter, FakeAnimData)  

-- Смерть клона: пересоздаём (как в оригинале)  
local fakeHum = findHumanoid(FakeCharacter)  
if fakeHum then  
    fakeDiedConn = fakeHum.Died:Connect(function()  
        if IsInvisible then  
            task.wait(0.1)  
            cleanupFake()  
            if IsInvisible then  
                CreateClone()  
            end  
        end  
    end)  
end

end

-- Возврат персонажа
local function TeleportAndRemoveClone()
if not IsInvisible then return end
IsInvisible = false

if renderConn then  
    renderConn:Disconnect()  
    renderConn = nil  
end  

if FakeCharacter and FakeCharacter:FindFirstChild("HumanoidRootPart") and RealCharacter and RealCharacter:FindFirstChild("HumanoidRootPart") then  
    RealCharacter.HumanoidRootPart.CFrame = FakeCharacter.HumanoidRootPart.CFrame  
end  

cleanupFake()  
workspace.CurrentCamera.CameraSubject = findHumanoid(RealCharacter)

end

-- Слежение за смертью персонажа
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

-- UI
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
button.TextColor3 = Color3.fromRGB(255,255,255)  
button.Parent = screen  
Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)  
local btnStroke = Instance.new("UIStroke", button)  
btnStroke.Thickness = 2  
btnStroke.Color = Color3.fromRGB(100, 100, 140)  
local signature = Instance.new("TextLabel")  
signature.Size = UDim2.new(1, 0, 0.4, 0)  
signature.Position = UDim2.new(0, 0, 0.65, 0)  
signature.BackgroundTransparency = 1  
signature.Font = Enum.Font.Gotham  
signature.TextSize = 12  
signature.TextColor3 = Color3.fromRGB(180,180,180)  
signature.Text = "by BrizNexuc"  
signature.Parent = button  

-- Перетаскивание с сохранением  
local dragging, dragStart, startPos  
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
                            X = {Scale = button.Position.X.Scale, Offset = button.Position.X.Offset},  
                            Y = {Scale = button.Position.Y.Scale, Offset = button.Position.Y.Offset}  
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

-- Переключение режима
local function ToggleInvisibility()
if not IsInvisible then
IsInvisible = true
CreateClone()
watchDeathForReal()
button.Text = "Invisible disable"
local sound = Instance.new("Sound")
sound.SoundId = "rbxassetid://232127604"
sound.Parent = SoundService
sound:Play()
game.Debris:AddItem(sound, 3)
TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(55,75,110)}):Play()
StarterGui:SetCore("SendNotification", { Title = "Invisible Cloak", Text = "Mode enabled", Duration = 4 })
else
TeleportAndRemoveClone()
IsInvisible = false
button.Text = "Invisible enable"
TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35,35,40)}):Play()
StarterGui:SetCore("SendNotification", { Title = "Invisible Cloak", Text = "Mode disabled", Duration = 3 })
end
end

button.MouseButton1Click:Connect(ToggleInvisibility)

charAddedConn = player.CharacterAdded:Connect(function(char)
RealCharacter = char
if IsInvisible then TeleportAndRemoveClone() end
watchDeathForReal()
end)

watchDeathForReal()

