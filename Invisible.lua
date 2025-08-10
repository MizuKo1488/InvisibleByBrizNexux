-- LocalScript: Invisibility Cloak GUI (строгий стиль, динамичный текст, сохранение позиции)
-- Поместить в StarterPlayerScripts или StarterGui

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

-- Удаление клона
local function cleanupFake()
	if fakeDiedConn then fakeDiedConn:Disconnect() fakeDiedConn = nil end
	if FakeCharacter then FakeCharacter:Destroy() FakeCharacter = nil end
	if renderConn then renderConn:Disconnect() renderConn = nil end
end

-- Создание клона
local function CreateClone()
	updateCharacter()
	if not RealCharacter:FindFirstChild("HumanoidRootPart") then return end

	cleanupFake()
	RealCharacter.Archivable = true
	FakeCharacter = RealCharacter:Clone()

	-- Убираем лишнее
	for _, v in ipairs(FakeCharacter:GetDescendants()) do
		if v:IsA("BodyVelocity") or v:IsA("BodyGyro") or v:IsA("BodyPosition") then
			v:Destroy()
		end
	end

	FakeCharacter.Parent = workspace
	FakeCharacter.HumanoidRootPart.CFrame = RealCharacter.HumanoidRootPart.CFrame
	FakeCharacter.HumanoidRootPart.Anchored = false

	-- Прозрачность
	for _, v in ipairs(FakeCharacter:GetDescendants()) do
		if v:IsA("BasePart") then v.Transparency = 0.85 end
	end

	-- Камера
	workspace.CurrentCamera.CameraSubject = findHumanoid(FakeCharacter)

	-- Перемещаем оригинал
	RealCharacter.HumanoidRootPart.CFrame += Vector3.new(0, 1e5, 0)

	-- Синхронизация
	renderConn = RunService.RenderStepped:Connect(function()
		if not IsInvisible or not FakeCharacter then return end
		workspace.CurrentCamera.CameraSubject = findHumanoid(FakeCharacter)
		local realHum = findHumanoid(RealCharacter)
		local fakeHum = findHumanoid(FakeCharacter)
		if realHum and fakeHum then
			fakeHum:Move(realHum.MoveDirection)
			fakeHum.Jump = realHum.Jump
		end
	end)

	-- Смерть клона
	fakeDiedConn = findHumanoid(FakeCharacter).Died:Connect(function()
		if IsInvisible then
			task.wait(0.1)
			cleanupFake()
			if IsInvisible then CreateClone() end
		end
	end)
end

-- Возврат персонажа
local function TeleportAndRemoveClone()
	if not IsInvisible then return end
	IsInvisible = false
	if renderConn then renderConn:Disconnect() renderConn = nil end

	if FakeCharacter and FakeCharacter:FindFirstChild("HumanoidRootPart") then
		RealCharacter.HumanoidRootPart.CFrame = FakeCharacter.HumanoidRootPart.CFrame
	end

	cleanupFake()
	workspace.CurrentCamera.CameraSubject = findHumanoid(RealCharacter)
end

-- Слежение за смертью персонажа
local function watchDeathForReal()
	if realDiedConn then realDiedConn:Disconnect() realDiedConn = nil end
	local realHum = findHumanoid(RealCharacter)
	if realHum then
		realDiedConn = realHum.Died:Connect(function()
			if IsInvisible then TeleportAndRemoveClone() end
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
					-- сохраняем позицию
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
			if dragging then
				update(input)
			end
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

		StarterGui:SetCore("SendNotification", {
			Title = "Invisible Cloak",
			Text = "Mode enabled",
			Duration = 4
		})
	else
		TeleportAndRemoveClone()
		IsInvisible = false
		button.Text = "Invisible enable"

		TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35,35,40)}):Play()

		StarterGui:SetCore("SendNotification", {
			Title = "Invisible Cloak",
			Text = "Mode disabled",
			Duration = 3
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
