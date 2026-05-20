--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║  TENDANG BLOK KEBERUNTUNGAN - ALL-IN-ONE GUI                ║
    ║  Compatible: Delta Executor (Mobile/All Devices)            ║
    ║  Game ID: 89469502395769                                     ║
    ╚══════════════════════════════════════════════════════════════╝
    
    Cara pakai:
    1. Paste seluruh script ini ke Delta Executor
    2. Execute
    3. GUI muncul, tinggal tap tombol menu
    4. Drag header untuk pindah posisi GUI
]]

-- Cleanup old GUI if re-executed
if game.CoreGui:FindFirstChild("TBK_GUI") then
    game.CoreGui:FindFirstChild("TBK_GUI"):Destroy()
end

-- ═══════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ═══════════════════════════════════════
-- STATE VARIABLES
-- ═══════════════════════════════════════
local States = {
    AutoFarm = false,
    SpeedHack = false,
    AutoKick = false,
    AutoCollect = false,
    AutoTeleport = false,
    AutoUpgrade = false,
    AutoWheel = false,
    AutoWeight = false,
    Noclip = false,
    AntiAFK = false,
    MaxKick = false,
    LuckBoost = false,
    FriendBoost = false,
    InfiniteBoost = false,
    Fly = false,
}

local SETTINGS = {
    Speed = 100,
    KickDelay = 0.5,
    CollectWait = 1.5,
}

-- ═══════════════════════════════════════
-- GUI CREATION (Mobile-Friendly)
-- ═══════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TBK_GUI"
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

-- Protect GUI from game scripts
pcall(function()
    if syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
    end
end)

-- Parent to CoreGui (works on most executors)
pcall(function()
    ScreenGui.Parent = game:GetService("CoreGui")
end)
if not ScreenGui.Parent then
    ScreenGui.Parent = player:WaitForChild("PlayerGui")
end

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "Main"
MainFrame.Size = UDim2.new(0, 320, 0, 420)
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(100, 50, 255)
MainStroke.Thickness = 2
MainStroke.Parent = MainFrame

-- Header (Draggable)
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(40, 20, 80)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = Header

-- Fix bottom corners of header
local HeaderFix = Instance.new("Frame")
HeaderFix.Size = UDim2.new(1, 0, 0, 10)
HeaderFix.Position = UDim2.new(0, 0, 1, -10)
HeaderFix.BackgroundColor3 = Color3.fromRGB(40, 20, 80)
HeaderFix.BorderSizePixel = 0
HeaderFix.Parent = Header

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Text = "⚡ TBK AUTO FARM"
TitleLabel.Size = UDim2.new(0.75, 0, 1, 0)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 16
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

-- Minimize Button
local MinBtn = Instance.new("TextButton")
MinBtn.Text = "—"
MinBtn.Size = UDim2.new(0, 35, 0, 35)
MinBtn.Position = UDim2.new(1, -75, 0, 3)
MinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.TextSize = 18
MinBtn.Font = Enum.Font.GothamBold
MinBtn.BorderSizePixel = 0
MinBtn.Parent = Header
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

-- Close Button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Text = "✕"
CloseBtn.Size = UDim2.new(0, 35, 0, 35)
CloseBtn.Position = UDim2.new(1, -38, 0, 3)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 16
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

-- Tab Container
local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, -10, 0, 32)
TabBar.Position = UDim2.new(0, 5, 0, 43)
TabBar.BackgroundTransparency = 1
TabBar.Parent = MainFrame

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0, 4)
TabLayout.Parent = TabBar

-- Content ScrollFrame
local Content = Instance.new("ScrollingFrame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -10, 1, -82)
Content.Position = UDim2.new(0, 5, 0, 78)
Content.BackgroundTransparency = 1
Content.ScrollBarThickness = 4
Content.ScrollBarImageColor3 = Color3.fromRGB(100, 50, 255)
Content.CanvasSize = UDim2.new(0, 0, 0, 0)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.BorderSizePixel = 0
Content.Parent = MainFrame

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 5)
ContentLayout.Parent = Content

local ContentPadding = Instance.new("UIPadding")
ContentPadding.PaddingTop = UDim.new(0, 3)
ContentPadding.PaddingBottom = UDim.new(0, 3)
ContentPadding.Parent = Content

-- ═══════════════════════════════════════
-- GUI HELPERS
-- ═══════════════════════════════════════
local Pages = {}
local Tabs = {}
local currentPage = nil

local function createTab(name)
    local btn = Instance.new("TextButton")
    btn.Text = name
    btn.Size = UDim2.new(0, 70, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    btn.TextColor3 = Color3.fromRGB(180, 180, 200)
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamSemibold
    btn.BorderSizePixel = 0
    btn.Parent = TabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    Tabs[name] = btn
    return btn
end

local function createPage(name)
    local page = Instance.new("Frame")
    page.Name = name
    page.Size = UDim2.new(1, 0, 0, 0)
    page.AutomaticSize = Enum.AutomaticSize.Y
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = Content
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.Parent = page
    
    Pages[name] = page
    return page
end

local function switchPage(name)
    for n, page in pairs(Pages) do
        page.Visible = (n == name)
    end
    for n, tab in pairs(Tabs) do
        if n == name then
            tab.BackgroundColor3 = Color3.fromRGB(100, 50, 255)
            tab.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            tab.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
            tab.TextColor3 = Color3.fromRGB(180, 180, 200)
        end
    end
    currentPage = name
end

local function createToggle(parent, text, stateKey, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 36)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    
    local label = Instance.new("TextLabel")
    label.Text = "  " .. text
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(220, 220, 240)
    label.TextSize = 13
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 50, 0, 24)
    toggleBtn.Position = UDim2.new(1, -58, 0.5, -12)
    toggleBtn.BackgroundColor3 = States[stateKey] and Color3.fromRGB(80, 200, 80) or Color3.fromRGB(80, 80, 100)
    toggleBtn.Text = States[stateKey] and "ON" or "OFF"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.TextSize = 11
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Parent = frame
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 12)
    
    toggleBtn.MouseButton1Click:Connect(function()
        States[stateKey] = not States[stateKey]
        toggleBtn.Text = States[stateKey] and "ON" or "OFF"
        TweenService:Create(toggleBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = States[stateKey] and Color3.fromRGB(80, 200, 80) or Color3.fromRGB(80, 80, 100)
        }):Play()
        if callback then callback(States[stateKey]) end
    end)
    
    return frame
end

local function createButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Text = text
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(50, 30, 100)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamSemibold
    btn.BorderSizePixel = 0
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    
    btn.MouseButton1Click:Connect(function()
        -- Flash effect
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(100, 60, 200)}):Play()
        task.wait(0.1)
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50, 30, 100)}):Play()
        if callback then callback() end
    end)
    
    return btn
end

local function createSeparator(parent, text)
    local label = Instance.new("TextLabel")
    label.Text = "── " .. text .. " ──"
    label.Size = UDim2.new(1, 0, 0, 22)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(130, 100, 255)
    label.TextSize = 11
    label.Font = Enum.Font.GothamBold
    label.Parent = parent
    return label
end

-- ═══════════════════════════════════════
-- DRAGGABLE HEADER
-- ═══════════════════════════════════════
local dragging, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

Header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Minimize/Close
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    local targetSize = minimized and UDim2.new(0, 320, 0, 44) or UDim2.new(0, 320, 0, 420)
    TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Size = targetSize}):Play()
    MinBtn.Text = minimized and "+" or "—"
end)

CloseBtn.MouseButton1Click:Connect(function()
    -- Stop all loops
    for k, _ in pairs(States) do States[k] = false end
    ScreenGui:Destroy()
end)

-- ═══════════════════════════════════════
-- GAME UTILITY FUNCTIONS
-- ═══════════════════════════════════════
local function getChar()
    local c = player.Character
    if not c then return nil, nil, nil end
    return c, c:FindFirstChildOfClass("Humanoid"), c:FindFirstChild("HumanoidRootPart")
end

local function tp(pos)
    local _, _, hrp = getChar()
    if hrp then hrp.CFrame = CFrame.new(pos) end
end

local function notify(title, text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title, Text = text, Duration = 3
        })
    end)
end

-- ═══════════════════════════════════════
-- GAME MODULE ACCESS
-- ═══════════════════════════════════════
local Modules = RS:FindFirstChild("Modules")
local Shared = RS:FindFirstChild("Shared")

local function tryRequire(path)
    local ok, res = pcall(function()
        local obj = RS
        for _, name in ipairs(path) do
            obj = obj:WaitForChild(name, 3)
            if not obj then error("not found: " .. name) end
        end
        return require(obj)
    end)
    return ok and res or nil
end

local KickService = tryRequire({"Modules", "ServicesLoader", "KickServiceClient"})
local BalanceService = tryRequire({"Modules", "ServicesLoader", "ClientBalanceService"})
local WheelService = tryRequire({"Modules", "ServicesLoader", "WheelSpinServiceClient"})
local LuckService = tryRequire({"Modules", "ServicesLoader", "ServerLuckClient"})
local FriendBoostSvc = tryRequire({"Modules", "ServicesLoader", "FriendBoostServiceClient"})
local KickCtrl = tryRequire({"Modules", "ControllerLoader", "KickController"})
local TeleCtrl = tryRequire({"Modules", "ControllerLoader", "TeleportController"})
local Network = tryRequire({"Shared", "Packages", "Network"})

-- ═══════════════════════════════════════
-- NETWORK REMOTES (from capture analysis)
-- Path: ReplicatedStorage.Shared.Packages.Network
-- Server→Client (rev_ prefix): rev_KickEvent, rev_IndexUpdate, rev_Collected, rev_KickEventEnded
-- Client→Server: Look for RemoteEvents without rev_ prefix
-- ═══════════════════════════════════════
local NetworkFolder = RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("Packages") and RS.Shared.Packages:FindFirstChild("Network")
local Remotes = {}

-- Scan all remotes in Network folder
if NetworkFolder then
    for _, child in pairs(NetworkFolder:GetChildren()) do
        if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") or child:IsA("UnreliableRemoteEvent") then
            Remotes[child.Name] = child
        end
    end
end

-- Also scan other common locations
for _, folder in pairs({RS, RS:FindFirstChild("Remotes"), RS:FindFirstChild("Events")}) do
    if folder then
        for _, child in pairs(folder:GetChildren()) do
            if (child:IsA("RemoteEvent") or child:IsA("RemoteFunction")) and not Remotes[child.Name] then
                Remotes[child.Name] = child
            end
        end
    end
end

-- ═══════════════════════════════════════
-- CORE FUNCTIONS
-- ═══════════════════════════════════════

--[[
    NETWORK PROTOCOL (dari manual capture):
    Path: ReplicatedStorage.Shared.Packages.Network
    
    SERVER → CLIENT (prefix "rev_"):
    - rev_KickEvent: (distance: number, {Name: string, Mutation: string})
    - rev_IndexUpdate: (brainrotName: string, mutation: string)
    - rev_Collected: (brainrotName: string)
    - rev_KickEventEnded: (success: boolean)
    
    CLIENT → SERVER: RemoteEvents tanpa prefix "rev_" di folder Network
    
    FLOW:
    1. Client fires kick remote → server processes
    2. Server fires rev_KickEvent (brainrot spawns di dunia)
    3. Player harus "touch"/collect brainrot yg spawn
    4. Server fires rev_Collected (confirmed collected)
    5. Server fires rev_KickEventEnded (round done)
]]

-- Scan Network folder for client→server remotes
local kickRemote, collectRemote, placeRemote, upgradeRemote
if NetworkFolder then
    for _, child in pairs(NetworkFolder:GetChildren()) do
        if child:IsA("RemoteEvent") and not child.Name:find("^rev_") then
            local n = child.Name:lower()
            if n:find("kick") and not kickRemote then kickRemote = child end
            if (n:find("collect") or n:find("claim")) and not collectRemote then collectRemote = child end
            if n:find("place") and not placeRemote then placeRemote = child end
            if n:find("upgrade") and not upgradeRemote then upgradeRemote = child end
        end
    end
end

-- Auto Kick
local function doKick()
    -- Method 1: Direct kick remote from Network folder (BEST)
    if kickRemote then
        pcall(function() kickRemote:FireServer() end)
        return
    end
    -- Method 2: KickController
    if KickCtrl and KickCtrl.PerformKick then
        pcall(function()
            KickCtrl.TravelRatio = 1
            KickCtrl.Scale = 1
            KickCtrl:PerformKick()
        end)
        return
    end
    -- Method 3: Network module
    if Network and Network.FireServer then
        pcall(function() Network.FireServer("Kick") end)
        return
    end
    -- Method 4: Scan all remotes
    pcall(function()
        for _, r in pairs(RS:GetDescendants()) do
            if r:IsA("RemoteEvent") and r.Name:lower():find("kick") and not r.Name:find("rev_") then
                r:FireServer()
                break
            end
        end
    end)
end

-- Auto Collect
local function doCollect()
    local _, _, hrp = getChar()
    if not hrp then return end
    
    -- Method 1: Fire collect remote directly (BEST)
    if collectRemote then
        pcall(function() collectRemote:FireServer() end)
    end
    
    -- Method 2: Network module
    if Network and Network.FireServer then
        pcall(function() Network.FireServer("Collect") end)
        pcall(function() Network.FireServer("Claim") end)
    end
    
    -- Method 3: Touch entities via firetouchinterest
    pcall(function()
        for _, tag in pairs({"EntityTool", "LuckyBlockTool", "Entity", "Brainrot"}) do
            for _, obj in pairs(CollectionService:GetTagged(tag)) do
                local part = obj:IsA("BasePart") and obj or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")))
                if part and hrp and (part.Position - hrp.Position).Magnitude < 300 then
                    tp(part.Position + Vector3.new(0, 2, 0))
                    task.wait(0.05)
                    if firetouchinterest then
                        firetouchinterest(hrp, part, 0)
                        task.wait(0.02)
                        firetouchinterest(hrp, part, 1)
                    end
                end
            end
        end
    end)
    
    -- Method 4: Proximity prompts
    pcall(function()
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Enabled then
                local promPart = obj.Parent
                if promPart and promPart:IsA("BasePart") and hrp and (promPart.Position - hrp.Position).Magnitude < 100 then
                    if fireproximityprompt then fireproximityprompt(obj) end
                end
            end
        end
    end)
end

-- Teleport to Base
local function doTeleportBase()
    if TeleCtrl and TeleCtrl.TeleportToBase then
        pcall(function() TeleCtrl:TeleportToBase() end)
        return
    end
    -- Fallback: fire remote
    pcall(function()
        if Network then Network.FireServer("TeleportToBase") end
    end)
    -- Fallback: find plot
    pcall(function()
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj.Name:find("Plot") and obj:IsA("Model") then
                if obj:GetAttribute("Owner") == player.Name or obj:GetAttribute("UserId") == player.UserId then
                    local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if p then tp(p.Position + Vector3.new(0, 5, 0)) return end
                end
            end
        end
    end)
end

-- Place Brainrot
local function doPlace()
    -- Method 1: Direct place remote
    if placeRemote then
        pcall(function() placeRemote:FireServer() end)
        return
    end
    -- Method 2: Network module
    pcall(function()
        if Network and Network.FireServer then
            Network.FireServer("PlaceBrainrot")
            Network.FireServer("Place")
        end
    end)
    -- Method 3: Scan remotes
    pcall(function()
        if NetworkFolder then
            for _, child in pairs(NetworkFolder:GetChildren()) do
                if child:IsA("RemoteEvent") and not child.Name:find("^rev_") then
                    if child.Name:lower():find("place") or child.Name:lower():find("slot") then
                        child:FireServer()
                    end
                end
            end
        end
    end)
end

-- Upgrade Kick
local function doUpgradeKick()
    -- Method 1: Direct upgrade remote
    if upgradeRemote then
        pcall(function() upgradeRemote:FireServer() end)
        return
    end
    -- Method 2: Network module
    pcall(function()
        if Network and Network.FireServer then
            Network.FireServer("UpgradeKick")
            Network.FireServer("BuyKickUpgrade")
        end
    end)
    -- Method 3: Scan
    pcall(function()
        if NetworkFolder then
            for _, child in pairs(NetworkFolder:GetChildren()) do
                if child:IsA("RemoteEvent") and not child.Name:find("^rev_") then
                    if child.Name:lower():find("upgrade") then
                        child:FireServer()
                    end
                end
            end
        end
    end)
end

-- Wheel Spin
local function doWheelSpin()
    pcall(function()
        if WheelService then
            WheelService.LastFreeSpin = 0
            WheelService.Spins = 999
            WheelService.IsSpinning = false
            if WheelService.RequestSpin then WheelService:RequestSpin() end
        end
        if Network then
            Network.FireServer("SpinWheel")
            Network.FireServer("RequestSpin")
        end
    end)
end

-- Weight/Squat Machine
local function doWeight()
    local _, _, hrp = getChar()
    if not hrp then return end
    local machine = workspace:FindFirstChild("Machine")
    if not machine then return end
    local hitbox = machine:FindFirstChild("Hitbox")
    if not hitbox then return end
    
    tp(hitbox.Position + Vector3.new(0, 3, 0))
    task.wait(0.2)
    pcall(function()
        if firetouchinterest then
            firetouchinterest(hrp, hitbox, 0)
            task.wait(0.05)
            firetouchinterest(hrp, hitbox, 1)
        end
        local prompt = hitbox:FindFirstChildOfClass("ProximityPrompt")
        if prompt and fireproximityprompt then fireproximityprompt(prompt) end
    end)
end

-- Max Kick Power
local function applyMaxKick(enabled)
    if not enabled then return end
    pcall(function()
        if KickService then
            KickService.Level = 9999
            KickService.Percent = 1
            KickService.Multipliers = {Speed = 10, Power = 10}
        end
    end)
end

-- Luck Boost
local function applyLuckBoost(enabled)
    if not enabled then return end
    pcall(function()
        if LuckService then
            LuckService.Luck = 999
            LuckService.GlobalLuck = 999
        end
    end)
end

-- Friend Boost Spoof
local function applyFriendBoost(enabled)
    if not enabled then return end
    pcall(function()
        if FriendBoostSvc then
            FriendBoostSvc.Friends = {
                {UserId=1,Name="F1"},{UserId=2,Name="F2"},
                {UserId=3,Name="F3"},{UserId=4,Name="F4"},{UserId=5,Name="F5"}
            }
            if FriendBoostSvc.Changed then FriendBoostSvc.Changed:Fire() end
        end
    end)
end

-- Infinite Boost (timed upgrades never expire)
local function applyInfiniteBoost(enabled)
    if not enabled then return end
    pcall(function()
        if KickService and KickService.EndTimes then
            for k,_ in pairs(KickService.EndTimes) do
                KickService.EndTimes[k] = os.time() + 999999999
            end
        end
    end)
end

-- ═══════════════════════════════════════
-- CREATE PAGES & TABS
-- ═══════════════════════════════════════

-- TAB 1: FARM
local tabFarm = createTab("Farm")
local pageFarm = createPage("Farm")

createSeparator(pageFarm, "FULL AUTO")
createToggle(pageFarm, "Auto Farm (All-in-One)", "AutoFarm")
createSeparator(pageFarm, "INDIVIDUAL")
createToggle(pageFarm, "Auto Kick", "AutoKick")
createToggle(pageFarm, "Auto Collect", "AutoCollect")
createToggle(pageFarm, "Auto Teleport Base", "AutoTeleport")
createToggle(pageFarm, "Auto Upgrade Kick", "AutoUpgrade")
createToggle(pageFarm, "Auto Wheel Spin", "AutoWheel")
createToggle(pageFarm, "Auto Weight/Squat", "AutoWeight")
createSeparator(pageFarm, "ACTIONS")
createButton(pageFarm, "⚡ Kick Once", doKick)
createButton(pageFarm, "📦 Collect Now", doCollect)
createButton(pageFarm, "🏠 Teleport Base", doTeleportBase)
createButton(pageFarm, "⬆️ Upgrade Kick", doUpgradeKick)
createButton(pageFarm, "🎰 Spin Wheel", doWheelSpin)

-- TAB 2: BOOST
local tabBoost = createTab("Boost")
local pageBoost = createPage("Boost")

createSeparator(pageBoost, "POWER")
createToggle(pageBoost, "Max Kick Power (9999)", "MaxKick", applyMaxKick)
createToggle(pageBoost, "Luck x999", "LuckBoost", applyLuckBoost)
createToggle(pageBoost, "Friend Boost +25%", "FriendBoost", applyFriendBoost)
createToggle(pageBoost, "Infinite Timed Boosts", "InfiniteBoost", applyInfiniteBoost)
createSeparator(pageBoost, "ACTIONS")
createButton(pageBoost, "💰 Set Coins Visual (9.9e99)", function()
    pcall(function()
        if BalanceService then
            BalanceService.Balance = {first=9.999, second=99}
            BalanceService.Multiplier = 999
            if BalanceService.CoinsChanged then
                BalanceService.CoinsChanged:Fire(BalanceService.Balance)
            end
        end
    end)
    notify("TBK", "Coins visual set!")
end)
createButton(pageBoost, "🔄 Force Rebirth", function()
    pcall(function()
        local rb = tryRequire({"Modules","ServicesLoader","RebirthServiceClient"})
        if rb and rb.RequestRebirth then rb:RequestRebirth() end
        for _, r in pairs(RS:GetDescendants()) do
            if r:IsA("RemoteEvent") and r.Name:lower():find("rebirth") then r:FireServer() end
        end
    end)
    notify("TBK", "Rebirth requested!")
end)
createButton(pageBoost, "🎁 Try Sacrifice All", function()
    pcall(function()
        for _, r in pairs(RS:GetDescendants()) do
            if r:IsA("RemoteEvent") and r.Name:lower():find("sacrifice") then
                for _, recipe in pairs({"UFO","WITCH","BACON","FLOOD","Phantom"}) do
                    pcall(function() r:FireServer(recipe) end)
                end
            end
        end
    end)
    notify("TBK", "Sacrifice attempts sent!")
end)

-- TAB 3: PLAYER
local tabPlayer = createTab("Player")
local pagePlayer = createPage("Player")

createSeparator(pagePlayer, "MOVEMENT")
createToggle(pagePlayer, "Speed Hack (100)", "SpeedHack")
createToggle(pagePlayer, "Noclip", "Noclip")
createToggle(pagePlayer, "Fly", "Fly")
createToggle(pagePlayer, "Anti-AFK", "AntiAFK")
createSeparator(pagePlayer, "TELEPORT")
createButton(pagePlayer, "🏠 Teleport to Base", doTeleportBase)
createButton(pagePlayer, "🏪 Teleport to Seller", function()
    pcall(function()
        if TeleCtrl and TeleCtrl.TeleportToSeller then TeleCtrl:TeleportToSeller() end
    end)
end)
createButton(pagePlayer, "💪 Teleport to Machine", function()
    local machine = workspace:FindFirstChild("Machine")
    if machine then
        local hitbox = machine:FindFirstChild("Hitbox")
        if hitbox then tp(hitbox.Position + Vector3.new(0,3,0)) end
    end
end)
createButton(pagePlayer, "🔄 Respawn", function()
    local char, hum = getChar()
    if hum then hum.Health = 0 end
end)

-- TAB 4: INFO
local tabInfo = createTab("Info")
local pageInfo = createPage("Info")

createSeparator(pageInfo, "STATUS")
local statusLabel = Instance.new("TextLabel")
statusLabel.Text = "Loading..."
statusLabel.Size = UDim2.new(1, 0, 0, 80)
statusLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.Code
statusLabel.TextWrapped = true
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Parent = pageInfo
Instance.new("UICorner", statusLabel).CornerRadius = UDim.new(0, 8)
Instance.new("UIPadding", statusLabel).PaddingLeft = UDim.new(0, 8)

createSeparator(pageInfo, "DEBUG")
createButton(pageInfo, "📡 Scan All Remotes", function()
    local count = 0
    local list = ""
    -- Prioritize Network folder
    if NetworkFolder then
        list = list .. "=== Network Folder ===\n"
        for _, r in pairs(NetworkFolder:GetChildren()) do
            if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") or r:IsA("UnreliableRemoteEvent") then
                count = count + 1
                local prefix = r.Name:find("^rev_") and "[S→C]" or "[C→S]"
                list = list .. prefix .. " " .. r.Name .. "\n"
            end
        end
    end
    -- Then all others
    list = list .. "\n=== Other Remotes ===\n"
    for _, r in pairs(RS:GetDescendants()) do
        if (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) and r.Parent ~= NetworkFolder then
            count = count + 1
            if count <= 30 then
                list = list .. r.Name .. " (" .. r.Parent.Name .. ")\n"
            end
        end
    end
    statusLabel.Text = string.format("Found %d remotes:\n%s", count, list)
end)
createButton(pageInfo, "🔍 Show Game Modules", function()
    local info = ""
    info = info .. "=== Services ===\n"
    info = info .. "KickService: " .. (KickService and "OK" or "X") .. "\n"
    info = info .. "BalanceService: " .. (BalanceService and "OK" or "X") .. "\n"
    info = info .. "WheelService: " .. (WheelService and "OK" or "X") .. "\n"
    info = info .. "LuckService: " .. (LuckService and "OK" or "X") .. "\n"
    info = info .. "KickCtrl: " .. (KickCtrl and "OK" or "X") .. "\n"
    info = info .. "TeleCtrl: " .. (TeleCtrl and "OK" or "X") .. "\n"
    info = info .. "Network: " .. (Network and "OK" or "X") .. "\n"
    info = info .. "NetworkFolder: " .. (NetworkFolder and "OK" or "X") .. "\n"
    info = info .. "\n=== Detected Remotes ===\n"
    info = info .. "Kick: " .. (kickRemote and kickRemote.Name or "NOT FOUND") .. "\n"
    info = info .. "Collect: " .. (collectRemote and collectRemote.Name or "NOT FOUND") .. "\n"
    info = info .. "Place: " .. (placeRemote and placeRemote.Name or "NOT FOUND") .. "\n"
    info = info .. "Upgrade: " .. (upgradeRemote and upgradeRemote.Name or "NOT FOUND") .. "\n"
    if KickService then
        info = info .. "\n=== Stats ===\n"
        info = info .. "Kick Lvl: " .. tostring(KickService.Level) .. "\n"
        info = info .. "Kick %: " .. tostring(KickService.Percent) .. "\n"
    end
    if BalanceService and BalanceService.Balance then
        info = info .. "Coins: " .. tostring(BalanceService.Balance.first) .. "e" .. tostring(BalanceService.Balance.second) .. "\n"
    end
    statusLabel.Text = info
end)

-- Tab click handlers
tabFarm.MouseButton1Click:Connect(function() switchPage("Farm") end)
tabBoost.MouseButton1Click:Connect(function() switchPage("Boost") end)
tabPlayer.MouseButton1Click:Connect(function() switchPage("Player") end)
tabInfo.MouseButton1Click:Connect(function() switchPage("Info") end)

-- Default page
switchPage("Farm")

-- ═══════════════════════════════════════
-- MAIN LOOPS
-- ═══════════════════════════════════════

-- Auto Farm Loop
task.spawn(function()
    while ScreenGui.Parent do
        if States.AutoFarm then
            -- CORRECT FLOW: Kick → Brainrot spawns → Teleport to Base → Brainrot masuk kantong
            doKick()
            task.wait(SETTINGS.KickDelay)
            task.wait(SETTINGS.CollectWait) -- Tunggu brainrot spawn
            doTeleportBase()              -- Lari ke base = brainrot auto masuk kantong
            task.wait(0.8)                -- Tunggu collected
            doCollect()                   -- Backup: trigger collect jika perlu
            task.wait(0.3)
        elseif States.AutoKick then
            doKick()
            task.wait(SETTINGS.KickDelay)
        else
            task.wait(0.5)
        end
        task.wait(0.1)
    end
end)

-- Auto Collect Loop (standalone)
task.spawn(function()
    while ScreenGui.Parent do
        if States.AutoCollect and not States.AutoFarm then
            doCollect()
        end
        task.wait(1)
    end
end)

-- Auto Teleport Loop (standalone)
task.spawn(function()
    while ScreenGui.Parent do
        if States.AutoTeleport and not States.AutoFarm then
            doTeleportBase()
        end
        task.wait(3)
    end
end)

-- Auto Upgrade Loop
task.spawn(function()
    while ScreenGui.Parent do
        if States.AutoUpgrade then
            doUpgradeKick()
        end
        task.wait(5)
    end
end)

-- Auto Wheel Loop
task.spawn(function()
    while ScreenGui.Parent do
        if States.AutoWheel then
            doWheelSpin()
        end
        task.wait(10)
    end
end)

-- Auto Weight Loop
task.spawn(function()
    while ScreenGui.Parent do
        if States.AutoWeight then
            doWeight()
        end
        task.wait(3)
    end
end)

-- Speed / Noclip / Fly Loop
local flyBV, flyBG
task.spawn(function()
    while ScreenGui.Parent do
        local char, hum, hrp = getChar()
        
        -- Speed
        if States.SpeedHack and hum then
            hum.WalkSpeed = SETTINGS.Speed
        end
        
        -- Noclip
        if States.Noclip and char then
            for _, p in pairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
        
        -- Fly
        if States.Fly and hrp then
            if not flyBV or not flyBV.Parent then
                flyBV = Instance.new("BodyVelocity")
                flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                flyBV.Velocity = Vector3.new(0,0,0)
                flyBV.Parent = hrp
                flyBG = Instance.new("BodyGyro")
                flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
                flyBG.P = 9e4
                flyBG.Parent = hrp
            end
            local cam = camera
            local mv = Vector3.new(0,0,0)
            -- Mobile: use MoveDirection from humanoid
            if hum then
                mv = hum.MoveDirection * 80
                if UIS:IsKeyDown(Enum.KeyCode.Space) then mv = mv + Vector3.new(0,50,0) end
                if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then mv = mv + Vector3.new(0,-50,0) end
            end
            flyBV.Velocity = mv
            if flyBG then flyBG.CFrame = cam.CFrame end
        else
            if flyBV and flyBV.Parent then flyBV:Destroy() flyBV = nil end
            if flyBG and flyBG.Parent then flyBG:Destroy() flyBG = nil end
        end
        
        -- Boost re-apply
        if States.MaxKick then applyMaxKick(true) end
        if States.LuckBoost then applyLuckBoost(true) end
        if States.InfiniteBoost then applyInfiniteBoost(true) end
        
        task.wait(0.1)
    end
end)

-- Anti-AFK
task.spawn(function()
    local VU = game:GetService("VirtualUser")
    while ScreenGui.Parent do
        if States.AntiAFK then
            pcall(function()
                VU:CaptureController()
                VU:ClickButton2(Vector2.new())
            end)
        end
        task.wait(60)
    end
end)

-- Also connect to Idled
pcall(function()
    player.Idled:Connect(function()
        if States.AntiAFK then
            local VU = game:GetService("VirtualUser")
            VU:Button2Down(Vector2.new(0,0), camera.CFrame)
            task.wait(1)
            VU:Button2Up(Vector2.new(0,0), camera.CFrame)
        end
    end)
end)

-- Character respawn handler
player.CharacterAdded:Connect(function(char)
    task.wait(1)
    if States.SpeedHack then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = SETTINGS.Speed end
    end
end)

-- ═══════════════════════════════════════
-- OPEN BUTTON (jika GUI diminimize total)
-- ═══════════════════════════════════════
local OpenBtn = Instance.new("TextButton")
OpenBtn.Name = "TBK_Open"
OpenBtn.Text = "⚡"
OpenBtn.Size = UDim2.new(0, 40, 0, 40)
OpenBtn.Position = UDim2.new(0, 10, 0.5, -20)
OpenBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 160)
OpenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
OpenBtn.TextSize = 20
OpenBtn.Font = Enum.Font.GothamBold
OpenBtn.BorderSizePixel = 0
OpenBtn.Visible = false
OpenBtn.Parent = ScreenGui
Instance.new("UICorner", OpenBtn).CornerRadius = UDim.new(0, 20)

-- Make open button draggable too
local oDragging, oDragStart, oStartPos
OpenBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        oDragging = true
        oDragStart = input.Position
        oStartPos = OpenBtn.Position
    end
end)
OpenBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        if oDragging and (input.Position - oDragStart).Magnitude < 5 then
            -- Was a click, not a drag
            MainFrame.Visible = true
            OpenBtn.Visible = false
        end
        oDragging = false
    end
end)
UIS.InputChanged:Connect(function(input)
    if oDragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - oDragStart
        OpenBtn.Position = UDim2.new(oStartPos.X.Scale, oStartPos.X.Offset + delta.X, oStartPos.Y.Scale, oStartPos.Y.Offset + delta.Y)
    end
end)

-- Override close to hide instead of destroy
CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    OpenBtn.Visible = true
end)

-- ═══════════════════════════════════════
-- DONE
-- ═══════════════════════════════════════
notify("⚡ TBK Auto Farm", "GUI Loaded! Drag header to move.")
print("╔══════════════════════════════════╗")
print("║  TBK GUI LOADED SUCCESSFULLY    ║")
print("║  Compatible: Delta Executor     ║")
print("╚══════════════════════════════════╝")
