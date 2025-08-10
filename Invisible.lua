
local _B="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function _b64(d)
    d=string.gsub(d,"[^".._B.."=]","")
    d=string.gsub(d,".",function(x)
        if x=="=" then return "" end
        local s=string.find(_B,x)-1
        local out=""
        for i=6,1,-1 do
            out=out..(s%2)
            s=math.floor(s/2)
        end
        return out
    end)
    d=string.gsub(d,"%d%d%d%d%d%d%d%d",function(bin)
        local n=0
        for i=1,8 do n=n*2 + tonumber(bin:sub(i,i)) end
        return string.char(n)
    end)
    return d
end

local g=game
local P=g:GetService(_b64("UGxheWVycy==")) -- Players
local R=g:GetService(_b64("UnVuU2VydmljZQ==")) -- RunService
local SG=g:GetService(_b64("U3RhcnRlckd1aQ==")) -- StarterGui
local SS=g:GetService(_b64("U291bmRTZXJ2aWNl")) -- SoundService
local TS=g:GetService(_b64("VHdlZW5TZXJ2aWNl")) -- TweenService
local UI=g:GetService(_b64("VXNlcklucHV0U2VydmljZQ==")) -- UserInputService
local HTTP=g:GetService(_b64("SHR0cFNlcnZpY2U=")) -- HttpService

local pl=P.LocalPlayer

local INV=false
local RC=pl.Character or pl.CharacterAdded:Wait()
local FC=nil

local rcConn,rdConn,fdConn,caConn = nil,nil,nil,nil

local FAD={connections={},tracks={},current=nil}

local spf = "buttonPos_"..pl.UserId..".json"
local savedPos=nil
pcall(function()
    if isfile and isfile(spf) then
        savedPos = HTTP:JSONDecode(readfile(spf))
    end
end)

local function fH(c)
    if not c then return nil end
    return c:FindFirstChildOfClass(_b64("SHVtYW5vaWQ=")) -- "Humanoid"
end

local function updC() RC = pl.Character or pl.CharacterAdded:Wait() end

local anims={
idle={{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3NjY2NjY="),w=1},{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3NjY2OTU="),w=1},{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3NjY2Mzg4"),w=9}},
walk={{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3Nzc4MjY="),w=10}},
run={{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3Njc3MTQ="),w=10}},
swim={{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3ODQ4OTc="),w=10}},
swimidle={{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3ODUwNzI="),w=10}},
jump={{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3NjUwMDA="),w=10}},
fall={{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3Njc5Njg="),w=10}},
climb={{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3NjU0NDQ="),w=10}},
sit={{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD0yNTA2MjgxNzAz"),w=10}},
toolnone={{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3NjgzNzU="),w=10}},
toolslash={{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MjI2MzU1MTQ="),w=10}},
toollunge={{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MjI2Mzg3Njc="),w=10}},
wave={{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3NzYwMjM5"),w=10}},
point={{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3NzcwNDUz"),w=10}},
dance={{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3NzEwMTk="),w=10},{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3NzcwOTU="),w=10},{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3NzcyMTA0"),w=10}},
dance2={{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3NzYwNDM="),w=10},{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3NzY3MjA="),w=10},{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3NzY4Nzk="),w=10}},
dance3={{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3NzcyNjg="),w=10},{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3NzcyNTE="),w=10},{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3NzcyNjIz"),w=10}},
laugh={{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3NzYwODE4"),w=10}},
cheer={{id=_b64("aHR0cDovL3d3dy5yb2Jsb3guY29tL2Fzc2V0Lz9pZD01MDc3NzYwNjc3"),w=10}},
}

local function roll(list)
    if not list then return 1 end
    local t=0
    for i=1,#list do t=t + (list[i].w or 1) end
    local r=Random.new():NextInteger(1, math.max(1,t))
    local idx=1
    while idx<=#list do
        if r <= (list[idx].w or 1) then return idx end
        r = r - (list[idx].w or 1)
        idx = idx + 1
    end
    return 1
end

local function AttachA(c,s)
    local h=fH(c)
    if not h then return end
    s.connections = s.connections or {}
    s.tracks = s.tracks or {}
    s.currentAnim=nil s.currentTrack=nil s.runTrack=nil s.animTable={}
    for name,lis in pairs(anims) do
        s.animTable[name]={}
        for i=1,#lis do
            local ai=Instance.new("Animation")
            ai.Name=name
            ai.AnimationId = lis[i].id
            table.insert(s.animTable[name],ai)
            pcall(function() h:LoadAnimation(ai) end)
        end
    end
    local function stop()
        if s.currentTrack then pcall(function() s.currentTrack:Stop(0.1) s.currentTrack:Destroy() end) s.currentTrack=nil s.currentAnim=nil end
        if s.runTrack then pcall(function() s.runTrack:Stop(0.1) s.runTrack:Destroy() end) s.runTrack=nil end
    end
    local function play(n,trans)
        trans = trans or 0.2
        local lst = s.animTable[n]
        if not lst or #lst==0 then return end
        local idx = roll(anims[n]) or 1
        local ao = lst[idx] or lst[1]
        if s.currentTrack then pcall(function() s.currentTrack:Stop(trans) s.currentTrack:Destroy() end) s.currentTrack=nil end
        local ok, tr = pcall(function() return h:LoadAnimation(ao) end)
        if ok and tr then
            s.currentTrack = tr
            tr.Priority = Enum.AnimationPriority.Core
            tr:Play(trans)
            s.currentAnim = n
        end
        if n=="walk" then
            local runList = s.animTable["run"]
            if runList and #runList>0 then
                local idx2 = roll(anims["run"]) or 1
                local runObj = runList[idx2]
                local ok2, rt = pcall(function() return h:LoadAnimation(runObj) end)
                if ok2 and rt then rt.Priority = Enum.AnimationPriority.Core rt:Play(trans) s.runTrack = rt end
            end
        end
    end
    local function setRun(sp)
        local b = 16
        local s2 = sp / b
        if s.currentTrack then pcall(function() s.currentTrack:AdjustSpeed(math.max(0.01,s2)) end) end
        if s.runTrack then pcall(function() s.runTrack:AdjustSpeed(math.max(0.01,s2)) end) end
    end
    local function onState(old,new)
        if new==Enum.HumanoidStateType.Jumping then play("jump",0.1)
        elseif new==Enum.HumanoidStateType.Freefall then play("fall",0.15)
        elseif new==Enum.HumanoidStateType.Seated then play("sit",0.2)
        elseif new==Enum.HumanoidStateType.Dead then stop() end
    end
    local function onRun(sp)
        if sp>0.75 then play("walk",0.2) setRun(sp) else if s.currentAnim~="idle" then play("idle",0.2) end end
    end
    local function onCl(sp) play("climb",0.1) setRun(sp) end
    local function onSw(sp) if sp>1.0 then play("swim",0.2) setRun(sp) else play("swimidle",0.2) end end
    table.insert(s.connections, h.StateChanged:Connect(onState))
    table.insert(s.connections, h.Running:Connect(onRun))
    table.insert(s.connections, h.Climbing:Connect(onCl))
    table.insert(s.connections, h.Swimming:Connect(onSw))
    play("idle",0.1)
    s._stopAll = function()
        if s.currentTrack then pcall(function() s.currentTrack:Stop() s.currentTrack:Destroy() end) s.currentTrack=nil end
        if s.runTrack then pcall(function() s.runTrack:Stop() s.runTrack:Destroy() end) s.runTrack=nil end
        if s.connections then for _,c in ipairs(s.connections) do pcall(function() c:Disconnect() end) end s.connections = {} end
    end
end

local function CleanupS(s)
    if not s then return end
    if s._stopAll then pcall(s._stopAll) end
    s._stopAll=nil s.animTable=nil s.tracks=nil s.currentAnim=nil s.currentTrack=nil s.runTrack=nil s.connections=nil
end

local function cleanupFake()
    if fdConn then fdConn:Disconnect() fdConn=nil end
    if rcConn then rcConn:Disconnect() rcConn=nil end
    if FC then
        CleanupS(FAD)
        FC:Destroy()
        FC=nil
    end
end

local function CreateClone()
    updC()
    if not RC:FindFirstChild(_b64("SHVtYW5vaWRSb290UGFydA==")) then return end
    cleanupFake()
    RC.Archivable = true
    FC = RC:Clone()
    for _,v in ipairs(FC:GetDescendants()) do
        if v:IsA("BodyVelocity") or v:IsA("BodyGyro") or v:IsA("BodyPosition") then pcall(function() v:Destroy() end) end
    end
    FC.Parent = workspace
    local realHRP = RC:FindFirstChild(_b64("SHVtYW5vaWRSb290UGFydA=="))
    local fakeHRP = FC:FindFirstChild(_b64("SHVtYW5vaWRSb290UGFydA=="))
    if realHRP and fakeHRP then fakeHRP.CFrame = realHRP.CFrame end
    if fakeHRP then fakeHRP.Anchored = false end
    for _,v in ipairs(FC:GetDescendants()) do
        if v:IsA("BasePart") then pcall(function() v.Transparency = 0.85 end)
        elseif v:IsA("Decal") or v:IsA("Texture") then end
    end
    workspace.CurrentCamera.CameraSubject = fH(FC)
    if realHRP then
        RC.HumanoidRootPart.CFrame = RC.HumanoidRootPart.CFrame + Vector3.new(0,1e5,0)
    end
    rcConn = R.RenderStepped:Connect(function()
        if not INV or not FC then return end
        workspace.CurrentCamera.CameraSubject = fH(FC)
        local rh = fH(RC)
        local fh = fH(FC)
        if rh and fh then
            pcall(function() fh:Move(rh.MoveDirection) fh.Jump = rh.Jump end)
        end
    end)
    FAD = {connections={},tracks={},current=nil}
    AttachA(FC,FAD)
    local fh = fH(FC)
    if fh then
        fdConn = fh.Died:Connect(function()
            if INV then
                task.wait(0.1)
                cleanupFake()
                if INV then CreateClone() end
            end
        end)
    end
end

local function TeleAndRm()
    if not INV then return end
    INV=false
    if rcConn then rcConn:Disconnect() rcConn=nil end
    if FC and FC:FindFirstChild(_b64("SHVtYW5vaWRSb290UGFydA==")) and RC and RC:FindFirstChild(_b64("SHVtYW5vaWRSb290UGFydA==")) then
        RC.HumanoidRootPart.CFrame = FC.HumanoidRootPart.CFrame
    end
    cleanupFake()
    workspace.CurrentCamera.CameraSubject = fH(RC)
end

local function watchDeath()
    if rdConn then rdConn:Disconnect() rdConn=nil end
    local rh = fH(RC)
    if rh then
        rdConn = rh.Died:Connect(function()
            if INV then TeleAndRm() end
        end)
    end
end

local function createGui()
    local gui = pl:WaitForChild(_b64("UGxheWVyR3Vp")) -- PlayerGui
    local existing = gui:FindFirstChild(_b64("SW52aXNpYmlsaXR5Q2xvYWtHVUl=")) -- InvisibilityCloakGUI
    if existing then existing:Destroy() end
    local screen = Instance.new("ScreenGui")
    screen.Name = _b64("SW52aXNpYmlsaXR5Q2xvYWtHVUl=")
    screen.ResetOnSpawn = false
    screen.Parent = gui
    local uiScale = Instance.new("UIScale", screen)
    uiScale.Scale = UI.TouchEnabled and 1.2 or 1
    local button = Instance.new("TextButton")
    button.Name = _b64("VG9nZ2xlQnV0dG9u") -- ToggleButton
    button.Size = UDim2.new(0.22,0,0.08,0)
    button.AnchorPoint = Vector2.new(1,1)
    button.Position = savedPos and UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset) or UDim2.new(0.98,0,0.95,0)
    button.Text = _b64("SW52aXNpYmxlIGVuYWJsZQ==") -- "Invisible enable"
    button.Font = Enum.Font.GothamBold
    button.TextSize = 20
    button.BackgroundColor3 = Color3.fromRGB(35,35,40)
    button.TextColor3 = Color3.fromRGB(255,255,255)
    button.Parent = screen
    Instance.new("UICorner", button).CornerRadius = UDim.new(0,10)
    local btnStroke = Instance.new("UIStroke", button)
    btnStroke.Thickness = 2
    btnStroke.Color = Color3.fromRGB(100,100,140)
    local signature = Instance.new("TextLabel")
    signature.Size = UDim2.new(1,0,0.4,0)
    signature.Position = UDim2.new(0,0,0.65,0)
    signature.BackgroundTransparency = 1
    signature.Font = Enum.Font.Gotham
    signature.TextSize = 12
    signature.TextColor3 = Color3.fromRGB(180,180,180)
    signature.Text = _b64("YnkgQnJpelNleHVj") -- "by BrizNexuc"
    signature.Parent = button
    local dragging,dragStart,startPos=false,nil,nil
    local function upd(i)
        local delta = i.Position - dragStart
        button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    button.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true
            dragStart=input.Position
            startPos=button.Position
            input.Changed:Connect(function()
                if input.UserInputState==Enum.UserInputState.End then
                    dragging=false
                    pcall(function()
                        if writefile then
                            writefile(spf, HTTP:JSONEncode({
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
        if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then
            if dragging then upd(input) end
        end
    end)
    return button
end

local BTN = createGui()

local function Toggle()
    if not INV then
        INV=true
        CreateClone()
        watchDeath()
        BTN.Text = _b64("SW52aXNpYmxlIGRpc2FibGU=") -- "Invisible disable"
        local s=Instance.new("Sound") s.SoundId = _b64("cmJ4YXNzZXRpZDpSLzIzMjEyNzYwNA==") -- rbxassetid://232127604
        s.Parent = SS
        s:Play()
        game.Debris:AddItem(s,3)
        TS:Create(BTN, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(55,75,110)}):Play()
        SG:SetCore("SendNotification", { Title = _b64("SW52aXNpYml0eSBDbG9haw=="), Text = _b64("TW9kZSBlbmFibGVk"), Duration = 4 })
    else
        TeleAndRm()
        INV=false
        BTN.Text = _b64("SW52aXNpYmxlIGVuYWJsZQ==")
        TS:Create(BTN, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35,35,40)}):Play()
        SG:SetCore("SendNotification", { Title = _b64("SW52aXNpYml0eSBDbG9haw=="), Text = _b64("TW9kZSBkaXNhYmxlZA=="), Duration = 3 })
    end
end

BTN.MouseButton1Click:Connect(Toggle)

caConn = pl.CharacterAdded:Connect(function(c)
    RC = c
    if INV then TeleAndRm() end
    watchDeath()
end)

watchDeath()
