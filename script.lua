--[[
    Ultimate Invisibility System
    Created by BrizNexuc
    Features:
    - Clone-based invisibility
    - Walk through players
    - Flight toggle
    - Death/respawn fixes
    - Enhanced welcome message
    - Improved collision handling
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Enhanced welcome message function
local function ShowEnhancedWelcomeMessage()
    local welcomeGui = Instance.new("ScreenGui")
    welcomeGui.Name = "BrizNexucWelcome"
    welcomeGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    welcomeGui.ResetOnSpawn = false
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 80)
    frame.Position = UDim2.new(0.5, -150, 0.5, -40)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BackgroundTransparency = 0.5
    frame.BorderSizePixel = 0
    frame.Parent = welcomeGui
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(0.9, 0, 0.7, 0)
    textLabel.Position = UDim2.new(0.05, 0, 0.15, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = "Ultimate Invisibility System\nCreated by BrizNexuc"
    textLabel.TextColor3 = Color3.fromRGB(0, 162, 255)
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.TextSize = 20
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = frame
    
    welcomeGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    -- Fade animation
    local fadeTime = 1.5
    local startTime = tick()
    
    local connection
    connection = RunService.RenderStepped:Connect(function()
        local elapsed = tick() - startTime
        if elapsed > 3 then
            local alpha = 1 - ((elapsed - 3) / fadeTime)
            if alpha <= 0 then
                welcomeGui:Destroy()
                connection:Disconnect()
            else
                frame.BackgroundTransparency = 0.5 + (0.5 * (1 - alpha))
                textLabel.TextTransparency = 1 - alpha
            end
        end
    end)
end

-- Original welcome message (kept for compatibility)
local function ShowWelcomeMessage()
    game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
        Text = "Thanks for using my invisibility script! - BrizNexuc",
        Color = Color3.fromRGB(0, 162, 255),
        Font = Enum.Font.SourceSansBold,
        FontSize = 24
    })
    
    task.wait(2)
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Invisibility System",
        Text = "Press F to toggle flight\nPress G to toggle collision\nMade by BrizNexuc",
        Duration = 8,
        Icon = "rbxassetid://6726578260"
    })
end

-- Configuration
local TRANSPARENCY_AMOUNT = 0.85
local CLONE_SPEED_MULTIPLIER = 1.5
local HIDE_POSITION = Vector3.new(0, 1e8, 0)
local NO_COLLIDE = true
local FLIGHT_ENABLED = true

-- Create RemoteEvent
local remoteEvent = Instance.new("RemoteEvent")
remoteEvent.Name = "BrizNexuc_UltimateInvisSystem"
remoteEvent.Parent = ReplicatedStorage

-- State variables
local IsInvisible = false
local RealCharacter = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local FakeCharacter = nil
local BodyVelocity = nil
local FlightBodyVelocity = nil
local OriginalCollisionGroups = {}

-- Make character archivable
RealCharacter.Archivable = true

-- Create GUI
local ScreenGui = Instance.new("ScreenGui")
local Frame = Instance.new("Frame")
local ToggleButton = Instance.new("TextButton")
local StatusLabel = Instance.new("TextLabel")
local CollisionButton = Instance.new("TextButton")
local FlightButton = Instance.new("TextButton")
local CreditLabel = Instance.new("TextLabel")

ScreenGui.Name = "BrizNexuc_InvisGUI"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

Frame.Parent = ScreenGui
Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Frame.BorderSizePixel = 0
Frame.Position = UDim2.new(0.8, 0, 0.5, -110)
Frame.Size = UDim2.new(0, 200, 0, 220)
Frame.Active = true
Frame.Draggable = true

-- Credit label
CreditLabel.Name = "CreditLabel"
CreditLabel.Parent = Frame
CreditLabel.BackgroundTransparency = 1
CreditLabel.Position = UDim2.new(0.1, 0, 0.02, 0)
CreditLabel.Size = UDim2.new(0.8, 0, 0.1, 0)
CreditLabel.Font = Enum.Font.SourceSansBold
CreditLabel.Text = "by BrizNexuc"
CreditLabel.TextColor3 = Color3.fromRGB(0, 162, 255)
CreditLabel.TextSize = 14

ToggleButton.Name = "ToggleButton"
ToggleButton.Parent = Frame
ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
ToggleButton.Position = UDim2.new(0.1, 0, 0.15, 0)
ToggleButton.Size = UDim2.new(0.8, 0, 0.2, 0)
ToggleButton.Font = Enum.Font.SourceSansBold
ToggleButton.Text = "Enable Invisibility"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 18

StatusLabel.Name = "StatusLabel"
StatusLabel.Parent = Frame
StatusLabel.BackgroundTransparency = 1
StatusLabel.Position = UDim2.new(0.1, 0, 0.35, 0)
StatusLabel.Size = UDim2.new(0.8, 0, 0.1, 0)
StatusLabel.Font = Enum.Font.SourceSansBold
StatusLabel.Text = "Status: Visible"
StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
StatusLabel.TextSize = 16

CollisionButton.Name = "CollisionButton"
CollisionButton.Parent = Frame
CollisionButton.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
CollisionButton.Position = UDim2.new(0.1, 0, 0.45, 0)
CollisionButton.Size = UDim2.new(0.8, 0, 0.2, 0)
CollisionButton.Font = Enum.Font.SourceSansBold
CollisionButton.Text = "Collision: OFF"
CollisionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CollisionButton.TextSize = 18

FlightButton.Name = "FlightButton"
FlightButton.Parent = Frame
FlightButton.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
FlightButton.Position = UDim2.new(0.1, 0, 0.65, 0)
FlightButton.Size = UDim2.new(0.8, 0, 0.2, 0)
FlightButton.Font = Enum.Font.SourceSansBold
FlightButton.Text = "Flight: ON"
FlightButton.TextColor3 = Color3.fromRGB(0, 0, 0)
FlightButton.TextSize = 18

-- Improved collision toggle function
local function TogglePlayerCollision(enable)
    if not RealCharacter then return end
    
    local humanoidRootPart = RealCharacter:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    if enable then
        -- Restore original collision
        for part, group in pairs(OriginalCollisionGroups) do
            if part and part.Parent then
                part.CollisionGroup = group
                part.CanCollide = true
            end
        end
        OriginalCollisionGroups = {}
        CollisionButton.Text = "Collision: OFF"
        CollisionButton.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
    else
        -- Enhanced collision disable
        for _, part in ipairs(RealCharacter:GetDescendants()) do
            if part:IsA("BasePart") then
                OriginalCollisionGroups[part] = part.CollisionGroup
                part.CollisionGroup = "NoCollision"
                part.CanCollide = false
                
                -- Disable constraints for better no-clip
                for _, constraint in ipairs(part:GetChildren()) do
                    if constraint:IsA("Constraint") then
                        constraint.Enabled = false
                    end
                end
            end
        end
        CollisionButton.Text = "Collision: ON"
        CollisionButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    end
    
    -- Apply same to clone if exists
    if FakeCharacter then
        for _, part in ipairs(FakeCharacter:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = enable
                part.CollisionGroup = enable and "Default" or "NoCollision"
            end
        end
    end
end

-- Toggle flight
local function ToggleFlight(enable)
    FLIGHT_ENABLED = enable
    
    if enable then
        FlightButton.Text = "Flight: ON"
        FlightButton.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
    else
        FlightButton.Text = "Flight: OFF"
        FlightButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        
        -- Reset velocity if flight is disabled
        if FakeCharacter and FakeCharacter:FindFirstChild("HumanoidRootPart") then
            FakeCharacter.HumanoidRootPart.Velocity = Vector3.new(0, 0, 0)
        end
    end
end

-- Enhanced clone creation with improved collision handling
local function CreateClone()
    -- Clean up real character physics
    local realRoot = RealCharacter:FindFirstChild("HumanoidRootPart")
    if realRoot then
        local bv = realRoot:FindFirstChild("BodyVelocity")
        if bv then
            bv.P = 0
            bv.MaxForce = Vector3.new(0, 0, 0)
        end
    end

    -- Create clone
    FakeCharacter = RealCharacter:Clone()

    -- Enhanced collision and physics handling for clone
    for _, v in pairs(FakeCharacter:GetDescendants()) do
        if v:IsA("BasePart") then
            -- Completely disable collisions for clone parts
            v.CanCollide = false
            v.CollisionGroup = "NoCollision"
            
            -- Make parts invisible to other players
            if v:IsA("MeshPart") or v:IsA("Part") then
                v.LocalTransparencyModifier = 1
            end
            
            -- Remove all physics constraints
            for _, constraint in ipairs(v:GetChildren()) do
                if constraint:IsA("Constraint") then
                    constraint:Destroy()
                end
            end
        elseif v:IsA("BodyVelocity") or v:IsA("BodyGyro") or v:IsA("BodyPosition") then
            v:Destroy()
        end
    end

    -- Add movement control
    BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.MaxForce = Vector3.new(500000, 500000, 500000)
    BodyVelocity.Velocity = Vector3.new(0, 0, 0)
    BodyVelocity.Parent = FakeCharacter.HumanoidRootPart

    -- Position clone
    FakeCharacter.Parent = workspace
    FakeCharacter.HumanoidRootPart.CFrame = RealCharacter.HumanoidRootPart.CFrame
    FakeCharacter.HumanoidRootPart.Anchored = false

    -- Increase clone speed
    FakeCharacter.Humanoid.WalkSpeed = RealCharacter.Humanoid.WalkSpeed * CLONE_SPEED_MULTIPLIER

    -- Apply transparency
    for _, v in pairs(FakeCharacter:GetDescendants()) do
        if v:IsA("BasePart") and v.Transparency < 1 then
            v.Transparency = TRANSPARENCY_AMOUNT
        end
    end

    -- Set collision based on current setting
    if NO_COLLIDE then
        for _, part in ipairs(FakeCharacter:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CollisionGroup = "NoCollision"
                part.CanCollide = false
            end
        end
    end

    -- Copy animator
    local RealAnimator = RealCharacter:FindFirstChildOfClass("Animator")
    if RealAnimator then
        local CloneAnimator = RealAnimator:Clone()
        CloneAnimator.Parent = FakeCharacter
    end

    -- Disable local scripts in clone
    for _, v in pairs(RealCharacter:GetChildren()) do
        if v:IsA("LocalScript") then
            local clone = v:Clone()
            clone.Disabled = true
            clone.Parent = FakeCharacter
        end
    end

    -- Switch camera to clone
    workspace.CurrentCamera.CameraSubject = FakeCharacter.Humanoid

    -- Hide real character (fixed death position bug)
    local hidePosition = CFrame.new(HIDE_POSITION)
    IsInvisible = true
    ToggleButton.Text = "Disable Invisibility"
    ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
    StatusLabel.Text = "Status: Invisible"

    -- Keep real character hidden (fixed death position bug)
    coroutine.wrap(function()
        while IsInvisible and RealCharacter and RealCharacter.Parent do
            RealCharacter.HumanoidRootPart.CFrame = hidePosition
            RealCharacter.HumanoidRootPart.Anchored = true
            task.wait(0.1)
        end
        if RealCharacter and RealCharacter:FindFirstChild("HumanoidRootPart") then
            RealCharacter.HumanoidRootPart.Anchored = false
        end
    end)()

    -- Notify server
    remoteEvent:FireServer(true, not NO_COLLIDE)

    -- Show enhanced welcome message
    ShowEnhancedWelcomeMessage()

    -- Movement handling with flight toggle
    RunService.RenderStepped:Connect(function()
        if not IsInvisible or not FakeCharacter or not RealCharacter then return end
        
        local moveDirection = RealCharacter.Humanoid.MoveDirection
        local camera = workspace.CurrentCamera

        if moveDirection.Magnitude > 0 then
            BodyVelocity.Parent = nil
            
            local cameraVector = camera.CFrame.LookVector
            local isMovingBackward = cameraVector:Dot(moveDirection) < 0
            
            -- Flight movement when enabled
            if FLIGHT_ENABLED then
                local adjustedY = isMovingBackward and (cameraVector.Y * -1.4) or (cameraVector.Y * 1.8)
                local speedMultiplier = isMovingBackward and 1.4 or 1.6
                
                FakeCharacter.HumanoidRootPart.Velocity = Vector3.new(
                    moveDirection.X, 
                    adjustedY + 0.35, 
                    moveDirection.Z
                ).Unit * (FakeCharacter.Humanoid.WalkSpeed * speedMultiplier)
            else
                -- Normal walking movement
                FakeCharacter.HumanoidRootPart.Velocity = Vector3.new(
                    moveDirection.X * FakeCharacter.Humanoid.WalkSpeed,
                    0,
                    moveDirection.Z * FakeCharacter.Humanoid.WalkSpeed
                )
            end
        else
            BodyVelocity.Parent = FakeCharacter.HumanoidRootPart
        end
    end)
end

-- Remove clone and restore visibility
local function RemoveClone()
    if not IsInvisible then return end

    -- Reset real character
    if RealCharacter and RealCharacter:FindFirstChild("HumanoidRootPart") then
        RealCharacter.HumanoidRootPart.Velocity = Vector3.new(0, 0, 0)
        RealCharacter.HumanoidRootPart.Anchored = false
    end

    -- Fade out clone
    if FakeCharacter then
        for _, v in pairs(FakeCharacter:GetDescendants()) do
            if v:IsA("BasePart") and v.Transparency < 1 then
                v.Transparency = 1
            end
        end
    end

    IsInvisible = false
    ToggleButton.Text = "Enable Invisibility"
    ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    StatusLabel.Text = "Status: Visible"

    -- Teleport real character back
    if FakeCharacter and RealCharacter then
        for i = 1, 5 do
            if not IsInvisible and FakeCharacter:FindFirstChild("HumanoidRootPart") then
                RealCharacter.HumanoidRootPart.CFrame = FakeCharacter.HumanoidRootPart.CFrame
                task.wait()
            end
        end
    end

    -- Clean up
    if FakeCharacter then
        FakeCharacter:Destroy()
        FakeCharacter = nil
    end

    -- Restore camera
    if RealCharacter then
        workspace.CurrentCamera.CameraSubject = RealCharacter.Humanoid
    end

    -- Notify server
    remoteEvent:FireServer(false, false)
end

-- Handle character added/respawn (fixed death position bug)
LocalPlayer.CharacterAdded:Connect(function(character)
    RealCharacter = character
    RealCharacter.Archivable = true
    
    -- Handle death properly
    local humanoid = character:WaitForChild("Humanoid")
    humanoid.Died:Connect(function()
        if IsInvisible then
            RemoveClone()
            
            -- Ensure character is properly positioned
            task.wait(0.5)
            if character and character:FindFirstChild("HumanoidRootPart") then
                character.HumanoidRootPart.Anchored = false
            end
        end
    end)
    
    -- Re-enable if was invisible before respawn
    if IsInvisible then
        task.wait(1) -- Wait for character to load
        CreateClone()
    end
end)

-- Toggle visibility
ToggleButton.MouseButton1Click:Connect(function()
    if IsInvisible then
        RemoveClone()
    else
        CreateClone()
        ShowWelcomeMessage()
    end
end)

-- Toggle collision
CollisionButton.MouseButton1Click:Connect(function()
    NO_COLLIDE = not NO_COLLIDE
    TogglePlayerCollision(NO_COLLIDE)
    
    if IsInvisible then
        remoteEvent:FireServer(true, not NO_COLLIDE)
    end
end)

-- Toggle flight
FlightButton.MouseButton1Click:Connect(function()
    ToggleFlight(not FLIGHT_ENABLED)
end)

-- Keyboard shortcuts
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed then
        if input.KeyCode == Enum.KeyCode.F then
            ToggleFlight(not FLIGHT_ENABLED)
        elseif input.KeyCode == Enum.KeyCode.G then
            NO_COLLIDE = not NO_COLLIDE
            TogglePlayerCollision(NO_COLLIDE)
            if IsInvisible then
                remoteEvent:FireServer(true, not NO_COLLIDE)
            end
        end
    end
end)

-- Server-side handling
remoteEvent.OnServerEvent:Connect(function(player, shouldBeInvisible, noCollide)
    if player ~= LocalPlayer then return end
    
    local character = player.Character
    if not character then return end
    
    -- Enhanced server-side invisibility handling
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = shouldBeInvisible and 1 or 0
            part.CanCollide = not (shouldBeInvisible and noCollide)
            
            if shouldBeInvisible and noCollide then
                part.CollisionGroup = "NoCollision"
            else
                part.CollisionGroup = "Default"
            end
            
            -- Handle constraints
            if shouldBeInvisible then
                for _, constraint in ipairs(part:GetChildren()) do
                    if constraint:IsA("Constraint") then
                        constraint.Enabled = false
                    end
                end
            else
                for _, constraint in ipairs(part:GetChildren()) do
                    if constraint:IsA("Constraint") then
                        constraint.Enabled = true
                    end
                end
            end
        elseif part:IsA("Decal") or part:IsA("Texture") then
            part.Transparency = shouldBeInvisible and 1 or 0
        end
    end
end)

-- Initialize
if LocalPlayer.Character then
    RealCharacter = LocalPlayer.Character
    RealCharacter.Archivable = true
end

-- Set initial states
TogglePlayerCollision(NO_COLLIDE)
ToggleFlight(FLIGHT_ENABLED)

-- Show welcome message when script starts
ShowWelcomeMessage()
