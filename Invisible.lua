-- Invisibility Cloak v4 by BrizNexuc + ChatGPT
-- Кладём в StarterPlayerScripts

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
local FakeCharacter

local renderConn, realDiedConn, fakeDiedConn

-- Файл позиции кнопки
local savedPosFile = "cloakBtnPos_" .. player.UserId .. ".json"
local savedPos
pcall(function()
	if isfile and isfile(savedPosFile) then
		savedPos = HttpService:JSONDecode(readfile(savedPosFile))
	end
end)

-- Функция поиска Humanoid
local function getHumanoid(char)
	if char then
		return char:FindFirstChildOfClass("Humanoid")
	end
end

-- Очистка фантома
local function cleanupFake()
	if fakeDiedConn then fakeDiedConn:Disconnect() fakeDiedConn = nil end
	if renderConn then renderConn:Disconnect() renderConn = nil end
	if FakeCharacter then FakeCharacter:Destroy() FakeCharacter = nil end
end

-- Создание фантома
local function createClone()
	RealCharacter.Archivable = true
	FakeCharacter = RealCharacter:Clone()

	-- Удаляем физические объекты
	for _, v in ipairs(FakeCharacter:GetDescendants()) do
		if v:IsA("BodyVelocity") or v:IsA("BodyGyro") or v:IsA("BodyPosition") then
			v:Destroy()
		end
	end

	-- Прозрачность фантома
	for _, v in ipairs(FakeCharacter:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Transparency = 0
		end
	end

	FakeCharacter.Parent = workspace
	FakeCharacter:SetPrimaryPartCFrame(RealCharacter.PrimaryPart.CFrame)

	-- Делаем настоящее тело невидимым
	for _, v in ipairs(RealCharacter:GetDescendants()) do
		if v:IsA("BasePart") then
			v.LocalTransparencyModifier = 1
			v.Transparency = 1
		elseif v:IsA("Decal") then
			v.Transparency = 1
		end
	end

	-- Переключаем камеру на фантома
	workspace.CurrentCamera.CameraSubject = getHumanoid(FakeCharacter)

	-- Синхронизация движений и анимаций
	renderConn = RunService.RenderStepped:Connect(function()
		if not IsInvisible or not FakeCharacter then return end
		local realHum = getHumanoid(RealCharacter)
		local fakeHum = getHumanoid(FakeCharacter)
		if realHum and fakeHum then
			fakeHum:Move(realHum.MoveDirection)
			fakeHum.Jump = realHum.Jump

			-- Копирование анимаций
			local realAnim = realHum:FindFirstChildOfClass("Animator")
			local fakeAnim = fakeHum:FindFirstChildOfClass("Animator")
			if realAnim and fakeAnim then
				for _, track in ipairs(fakeAnim:GetPlayingAnimationTracks()) do
					track:Stop()
				end
				for _, track in ipairs(realAnim:GetPlayingAnimationTracks()) do
					local newTrack = fakeAnim:LoadAnimation(track.Animation)
					newTrack.TimePosition = track.TimePosition
					newTrack:Play()
					newTrack.Speed = track.Speed
				end
			end
		end
	end)

	-- Пересоздаём фантом, если умер
	fakeDiedConn = getHumanoid(FakeCharacter).Died:Connect(function()
		if IsInvisible then
			cleanupFake()
			createClone()
		end
	end)
end

-- Отключение невидимости
local function disableInvisibility()
	IsInvisible = false
	cleanupFake()

	-- Возвращаем видимость
	for _, v in ipairs(RealCharacter:GetDescendants()) do
		if v:IsA("BasePart") then
			v.LocalTransparencyModifier = 0
			v.Transparency = 0
		elseif v:IsA("Decal") then
			v.Transparency = 0
		end
	end

	workspace.CurrentCamera.CameraSubject = getHumanoid(RealCharacter)
end

-- UI
local function createGui()
	local gui = player:WaitForChild("PlayerGui")
	local old = gui:FindFirstChild("InvisibilityCloakGUI")
	if old then old:Destroy() end

	local screen = Instance.new("ScreenGui")
	screen.Name = "InvisibilityCloakGUI"
	screen.ResetOnSpawn = false
	screen.Parent = gui

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.26, 0, 0.1, 0)
	btn.AnchorPoint = Vector2.new(1, 1)
	btn.Position = savedPos and UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset) or UDim2.new(0.98, 0, 0.95, 0)
	btn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	btn.Text = ""
	btn.Parent = screen
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)

	local grad = Instance.new("UIGradient", btn)
	grad.Color = ColorSequence.new(Color3.fromRGB(45, 45, 55), Color3.fromRGB(25, 25, 30))

	local stroke = Instance.new("UIStroke", btn)
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(100, 100, 140)

	local status = Instance.new("TextLabel", btn)
	status.Size = UDim2.new(1, 0, 0.5, 0)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBold
	status.TextSize = 20
	status.Text = "Status: OFF"
	status.TextColor3 = Color3.fromRGB(200, 70, 70)

	local author = Instance.new("TextLabel", btn)
	author.Size = UDim2.new(1, 0, 0.4, 0)
	author.Position = UDim2.new(0, 0, 0.6, 0)
	author.BackgroundTransparency = 1
	author.Font = Enum.Font.Gotham
	author.TextSize = 14
	author.TextColor3 = Color3.fromRGB(180, 180, 220)
	author.Text = "by BrizNexuc"

	-- Перетаскивание
	local dragging, dragStart, startPos
	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = btn.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					pcall(function()
						if writefile then
							writefile(savedPosFile, HttpService:JSONEncode({
								X = {Scale = btn.Position.X.Scale, Offset = btn.Position.X.Offset},
								Y = {Scale = btn.Position.Y.Scale, Offset = btn.Position.Y.Offset}
							}))
						end
					end)
				end
			end)
		end
	end)
	btn.InputChanged:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragging then
			local delta = input.Position - dragStart
			btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)

	return btn, status
end

local button, statusLabel = createGui()

-- Переключатель
local function toggleInvisibility()
	if not IsInvisible then
		IsInvisible = true
		createClone()
		statusLabel.Text = "Status: ON"
		statusLabel.TextColor3 = Color3.fromRGB(70, 200, 70)

		local sound = Instance.new("Sound", SoundService)
		sound.SoundId = "rbxassetid://232127604"
		sound:Play()
		game.Debris:AddItem(sound, 3)

		TweenService:Create(button, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(55, 75, 110)}):Play()

		StarterGui:SetCore("SendNotification", {
			Title = "Invisible Cloak",
			Text = "Mode enabled",
			Duration = 3
		})
	else
		disableInvisibility()
		statusLabel.Text = "Status: OFF"
		statusLabel.TextColor3 = Color3.fromRGB(200, 70, 70)

		TweenService:Create(button, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(35, 35, 40)}):Play()

		StarterGui:SetCore("SendNotification", {
			Title = "Invisible Cloak",
			Text = "Mode disabled",
			Duration = 3
		})
	end
end

button.MouseButton1Click:Connect(toggleInvisibility)

-- Перезапуск при респавне
player.CharacterAdded:Connect(function(char)
	RealCharacter = char
	if IsInvisible then
		disableInvisibility()
	end
end)
