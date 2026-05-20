--[[
    ╔══════════════════════════════════════════════════════════╗
    ║  AUTO KICK + AUTO WALK TO BASE                          ║
    ║  Game: Tendang Blok Keberuntungan                       ║
    ║  Executor: Delta (Android)                              ║
    ║  Compatible: All Android devices                        ║
    ╚══════════════════════════════════════════════════════════╝
    
    FITUR:
    - Auto Kick Lucky Block (dengan random delay anti-detect)
    - Auto Walk ke tempat kick (Lucky Block spawn)
    - Auto Walk balik ke Base setelah dapat brainrot
    - GUI mobile-friendly (draggable, minimize)
    
    FLOW:
    1. Karakter jalan ke Lucky Block (tempat kick)
    2. Kick Lucky Block
    3. Tunggu hasil (brainrot)
    4. Jalan balik ke Base
    5. Ulangi
]]

-- ═══════════════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════════════
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HRP = Character:WaitForChild("HumanoidRootPart")

-- ═══════════════════════════════════════════════════
-- MODULE ACCESS (Knit Framework)
-- ═══════════════════════════════════════════════════
local Modules = ReplicatedStorage:WaitForChild("Modules")
local ControllerLoader = require(Modules:WaitForChild("ControllerLoader"))
local HandlerLoader = require(Modules:WaitForChild("HandlerLoader"))
local ServicesLoader = require(Modules:WaitForChild("ServicesLoader"))

-- Controllers & Handlers
local KickController = ControllerLoader.KickController or require(Modules.ControllerLoader:WaitForChild("KickController"))
local TeleportController = ControllerLoader.TeleportController or require(Modules.ControllerLoader:WaitForChild("TeleportController"))

local GameHandler = HandlerLoader.GameHandler or require(Modules.HandlerLoader:WaitForChild("GameHandler"))

-- ═══════════════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════════════
local Config = {
    -- Timing (dengan jitter anti-detect)
    KickDelayMin = 4.0,        -- minimum delay antar kick (detik)
    KickDelayMax = 6.5,        -- maximum delay antar kick (detik)
    WalkSpeed = 32,            -- speed saat auto-walk (jangan terlalu tinggi)
    
    -- Auto Walk
    AutoWalkToKick = true,     -- auto jalan ke tempat kick
    AutoWalkToBase = true,     -- auto jalan balik ke base
    

    
    -- Safety
    MaxKicksPerSession = 999,  -- max kick per session (safety limit)
    AntiAFK = true,            -- anti-AFK (agar tidak di-kick server)
    
    -- Lokasi (akan di-detect otomatis)
    KickPosition = nil,        -- posisi lucky block (auto-detect)
    BasePosition = nil,        -- posisi base/plot (auto-detect)
}

-- ═══════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════
local State = {
    Running = false,
    TotalKicks = 0,
    TotalBrainrots = 0,
    CurrentPhase = "Idle",     -- Idle, Walking_ToKick, Kicking, Walking_ToBase
    LastKickTime = 0,
    GotBrainrot = false,
    LastBrainrotName = "None",
    LastMutation = "None",
}

-- ═══════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════
local function RandomDelay(min, max)
    return min + math.random() * (max - min)
end

local function GetCharacter()
    Character = Player.Character
    if Character then
        Humanoid = Character:FindFirstChildOfClass("Humanoid")
        HRP = Character:FindFirstChild("HumanoidRootPart")
    end
    return Character and Humanoid and HRP
end

local function FindLuckyBlockPosition()
    -- Cari Lucky Block di workspace
    -- Lucky Block biasanya ada di area kick (dekat spawn)
    local luckyBlocks = {}
    
    -- Method 1: Cari by tag "LuckyBlockTool"
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "LuckyBlock" or obj.Name == "Lucky Block" or 
           (obj:IsA("Model") and obj.Name:find("Lucky")) or
           (obj:IsA("BasePart") and obj:GetAttribute("LuckyBlock")) then
            table.insert(luckyBlocks, obj)
        end
    end
    
    -- Method 2: Cari area kick platform
    if #luckyBlocks == 0 then
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj.Name == "KickPlatform" or obj.Name == "KickArea" or 
               obj.Name == "KickZone" or obj.Name == "KickPad" then
                table.insert(luckyBlocks, obj)
            end
        end
    end
    
    -- Pilih yang terdekat dari player
    if #luckyBlocks > 0 then
        local closest = nil
        local closestDist = math.huge
        for _, block in pairs(luckyBlocks) do
            local pos = block:IsA("Model") and block:GetPivot().Position or block.Position
            local dist = (pos - HRP.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                closest = pos
            end
        end
        return closest
    end
    
    return nil
end

local function FindBasePosition()
    -- Cari base/plot player
    -- Method 1: Dari ClientPlotService
    local plotService = ServicesLoader and ServicesLoader.ClientPlotService
    if plotService and plotService.Model then
        local model = plotService.Model
        if typeof(model) == "Instance" and model:IsA("Model") then
            return model:GetPivot().Position
        end
    end
    
    -- Method 2: Cari Plot di workspace
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and (obj.Name:find("Plot") or obj.Name:find("Base")) then
            -- Cek apakah milik player ini
            local owner = obj:GetAttribute("Owner") or obj:GetAttribute("Player")
            if owner == Player.Name or owner == Player.UserId then
                return obj:GetPivot().Position
            end
        end
    end
    
    -- Method 3: Gunakan TeleportController.TeleportToBase sebagai referensi
    -- (kita bisa panggil langsung function-nya)
    return nil
end

local function WalkTo(targetPosition, timeout)
    if not GetCharacter() then return false end
    timeout = timeout or 15
    
    -- Gunakan Humanoid:MoveTo untuk jalan ke target
    local startTime = tick()
    local reached = false
    
    -- Coba pathfinding dulu
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = false,
    })
    
    local success, err = pcall(function()
        path:ComputeAsync(HRP.Position, targetPosition)
    end)
    
    if success and path.Status == Enum.PathStatus.Success then
        -- Ikuti waypoints
        local waypoints = path:GetWaypoints()
        for i, waypoint in ipairs(waypoints) do
            if not State.Running then return false end
            
            Humanoid:MoveTo(waypoint.Position)
            
            if waypoint.Action == Enum.PathWaypointAction.Jump then
                Humanoid.Jump = true
            end
            
            -- Tunggu sampai sampai waypoint atau timeout
            local moveStart = tick()
            repeat
                task.wait(0.1)
            until (HRP.Position - waypoint.Position).Magnitude < 4 
                  or (tick() - moveStart) > 5
                  or not State.Running
        end
        reached = true
    else
        -- Fallback: MoveTo langsung
        Humanoid:MoveTo(targetPosition)
        
        repeat
            task.wait(0.1)
        until (HRP.Position - targetPosition).Magnitude < 6 
              or (tick() - startTime) > timeout
              or not State.Running
        
        reached = (HRP.Position - targetPosition).Magnitude < 6
    end
    
    -- Stop movement
    Humanoid:MoveTo(HRP.Position)
    
    return reached
end

local function TeleportToBase()
    -- Coba gunakan TeleportController bawaan game
    local success = pcall(function()
        if TeleportController and TeleportController.TeleportToBase then
            TeleportController:TeleportToBase()
        end
    end)
    
    if success then
        task.wait(0.5)
        return true
    end
    
    -- Fallback: walk manual
    local basePos = Config.BasePosition or FindBasePosition()
    if basePos then
        return WalkTo(basePos, 20)
    end
    
    return false
end

-- ═══════════════════════════════════════════════════
-- CORE AUTOMATION
-- ═══════════════════════════════════════════════════
local function DoKick()
    if not GetCharacter() then return false end
    
    -- Cek apakah sedang dalam minigame
    if KickController.InMinigame then
        return false
    end
    
    -- Panggil kick function
    local success = pcall(function()
        KickController:Kick()
    end)
    
    return success
end

local function WaitForKickResult(timeout)
    timeout = timeout or 12
    local startTime = tick()
    
    -- Tunggu sampai InMinigame jadi false lagi (kick selesai)
    -- Atau tunggu sampai dapat brainrot
    while State.Running and (tick() - startTime) < timeout do
        if not KickController.InMinigame then
            -- Kick sudah selesai
            task.wait(0.5)
            return true
        end
        task.wait(0.1)
    end
    
    return false
end

-- ═══════════════════════════════════════════════════
-- MAIN LOOP
-- ═══════════════════════════════════════════════════
local function MainLoop()
    while State.Running do
        if not GetCharacter() then
            State.CurrentPhase = "Waiting Respawn"
            Player.CharacterAdded:Wait()
            task.wait(2)
            GetCharacter()
        end
        
        -- Safety check
        if State.TotalKicks >= Config.MaxKicksPerSession then
            State.Running = false
            State.CurrentPhase = "Max Reached"
            break
        end
        
        -- PHASE 1: Walk ke tempat kick (Lucky Block)
        if Config.AutoWalkToKick then
            State.CurrentPhase = "Walking → Kick"
            
            local kickPos = Config.KickPosition or FindLuckyBlockPosition()
            if kickPos then
                WalkTo(kickPos, 15)
            else
                -- Kalau tidak ketemu posisi, tetap kick di tempat
                task.wait(0.5)
            end
        end
        
        -- PHASE 2: Kick
        State.CurrentPhase = "Kicking..."
        
        -- Pastikan tidak sedang dalam minigame
        local attempts = 0
        while KickController.InMinigame and attempts < 30 do
            task.wait(0.5)
            attempts = attempts + 1
        end
        
        if DoKick() then
            State.TotalKicks = State.TotalKicks + 1
            State.LastKickTime = tick()
            
            -- Tunggu hasil kick
            State.CurrentPhase = "Waiting Result..."
            WaitForKickResult(12)
            
            -- Random delay anti-detect
            local delay = RandomDelay(Config.KickDelayMin, Config.KickDelayMax)
            
            -- PHASE 3: Walk balik ke Base
            if Config.AutoWalkToBase then
                State.CurrentPhase = "Walking → Base"
                TeleportToBase()
                task.wait(0.5)
            end
            
            -- Tunggu sisa delay
            local elapsed = tick() - State.LastKickTime
            local remaining = delay - elapsed
            if remaining > 0 then
                State.CurrentPhase = string.format("Cooldown %.1fs", remaining)
                task.wait(remaining)
            end
        else
            -- Kick gagal, tunggu sebentar
            State.CurrentPhase = "Kick Failed, Retry..."
            task.wait(2)
        end
    end
    
    State.CurrentPhase = "Stopped"
end

-- ═══════════════════════════════════════════════════
-- ANTI-AFK
-- ═══════════════════════════════════════════════════
local function AntiAFK()
    -- Override idle detection
    local VirtualUser = game:GetService("VirtualUser")
    Player.Idled:Connect(function()
        if Config.AntiAFK then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)
end

-- ═══════════════════════════════════════════════════
-- HOOK KE GAME EVENTS (detect brainrot didapat)
-- ═══════════════════════════════════════════════════
local function HookEvents()
    -- Hook ke rev_KickEvent untuk detect brainrot yang didapat
    local Network = ReplicatedStorage:FindFirstChild("Shared")
    if Network then
        local Packages = Network:FindFirstChild("Packages")
        if Packages then
            local NetworkFolder = Packages:FindFirstChild("Network")
            if NetworkFolder then
                for _, remote in pairs(NetworkFolder:GetDescendants()) do
                    if remote:IsA("RemoteEvent") and remote.Name:find("rev_KickEvent") then
                        remote.OnClientEvent:Connect(function(distance, brainrotData)
                            if brainrotData and type(brainrotData) == "table" then
                                State.GotBrainrot = true
                                State.TotalBrainrots = State.TotalBrainrots + 1
                                State.LastBrainrotName = brainrotData.Name or "Unknown"
                                State.LastMutation = brainrotData.Mutation or "None"
                            end
                        end)
                    end
                end
            end
        end
    end
    
    -- Alt method: Hook GameHandler.GotResult
    if GameHandler and GameHandler.GotResult then
        pcall(function()
            GameHandler.GotResult:Connect(function(data)
                if data then
                    State.GotBrainrot = true
                    State.TotalBrainrots = State.TotalBrainrots + 1
                end
            end)
        end)
    end
end

-- ═══════════════════════════════════════════════════
-- CHARACTER RESPAWN HANDLER
-- ═══════════════════════════════════════════════════
Player.CharacterAdded:Connect(function(char)
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    HRP = char:WaitForChild("HumanoidRootPart")
    task.wait(1)
end)

-- ═══════════════════════════════════════════════════
-- GUI (Mobile-Friendly, Delta Executor Compatible)
-- ═══════════════════════════════════════════════════
local function CreateGUI()
    -- Hapus GUI lama jika ada
    if Player.PlayerGui:FindFirstChild("AutoKickGUI") then
        Player.PlayerGui:FindFirstChild("AutoKickGUI"):Destroy()
    end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AutoKickGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = Player.PlayerGui
    
    -- Main Frame (draggable)
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 280, 0, 380)
    MainFrame.Position = UDim2.new(0.5, -140, 0.3, 0)
    MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Parent = ScreenGui
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 12)
    MainCorner.Parent = MainFrame
    
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(100, 60, 200)
    MainStroke.Thickness = 2
    MainStroke.Parent = MainFrame
    
    -- Title Bar
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    TitleBar.BackgroundColor3 = Color3.fromRGB(40, 20, 80)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 12)
    TitleCorner.Parent = TitleBar
    
    -- Fix bottom corners of title
    local TitleFix = Instance.new("Frame")
    TitleFix.Size = UDim2.new(1, 0, 0, 12)
    TitleFix.Position = UDim2.new(0, 0, 1, -12)
    TitleFix.BackgroundColor3 = Color3.fromRGB(40, 20, 80)
    TitleFix.BorderSizePixel = 0
    TitleFix.Parent = TitleBar
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -50, 1, 0)
    TitleLabel.Position = UDim2.new(0, 12, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "⚡ Auto Kick & Walk"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.TextSize = 16
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TitleBar
    
    -- Minimize Button
    local MinBtn = Instance.new("TextButton")
    MinBtn.Name = "MinBtn"
    MinBtn.Size = UDim2.new(0, 30, 0, 30)
    MinBtn.Position = UDim2.new(1, -38, 0, 5)
    MinBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 100)
    MinBtn.Text = "—"
    MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinBtn.TextSize = 18
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.BorderSizePixel = 0
    MinBtn.Parent = TitleBar
    
    local MinCorner = Instance.new("UICorner")
    MinCorner.CornerRadius = UDim.new(0, 6)
    MinCorner.Parent = MinBtn
    
    -- Content Frame
    local Content = Instance.new("Frame")
    Content.Name = "Content"
    Content.Size = UDim2.new(1, -20, 1, -50)
    Content.Position = UDim2.new(0, 10, 0, 45)
    Content.BackgroundTransparency = 1
    Content.Parent = MainFrame
    
    local ContentLayout = Instance.new("UIListLayout")
    ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ContentLayout.Padding = UDim.new(0, 8)
    ContentLayout.Parent = Content
    
    -- Status Label
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "StatusLabel"
    StatusLabel.Size = UDim2.new(1, 0, 0, 22)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "Status: Idle"
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLabel.TextSize = 13
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.LayoutOrder = 1
    StatusLabel.Parent = Content
    
    -- Stats Labels
    local KicksLabel = Instance.new("TextLabel")
    KicksLabel.Name = "KicksLabel"
    KicksLabel.Size = UDim2.new(1, 0, 0, 20)
    KicksLabel.BackgroundTransparency = 1
    KicksLabel.Text = "Kicks: 0 | Brainrots: 0"
    KicksLabel.TextColor3 = Color3.fromRGB(150, 220, 150)
    KicksLabel.TextSize = 12
    KicksLabel.Font = Enum.Font.Gotham
    KicksLabel.TextXAlignment = Enum.TextXAlignment.Left
    KicksLabel.LayoutOrder = 2
    KicksLabel.Parent = Content
    
    local LastBrainrotLabel = Instance.new("TextLabel")
    LastBrainrotLabel.Name = "LastBrainrotLabel"
    LastBrainrotLabel.Size = UDim2.new(1, 0, 0, 20)
    LastBrainrotLabel.BackgroundTransparency = 1
    LastBrainrotLabel.Text = "Last: None"
    LastBrainrotLabel.TextColor3 = Color3.fromRGB(220, 180, 100)
    LastBrainrotLabel.TextSize = 12
    LastBrainrotLabel.Font = Enum.Font.Gotham
    LastBrainrotLabel.TextXAlignment = Enum.TextXAlignment.Left
    LastBrainrotLabel.LayoutOrder = 3
    LastBrainrotLabel.Parent = Content
    
    -- Separator
    local Sep1 = Instance.new("Frame")
    Sep1.Size = UDim2.new(1, 0, 0, 1)
    Sep1.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    Sep1.BorderSizePixel = 0
    Sep1.LayoutOrder = 4
    Sep1.Parent = Content
    
    -- Toggle Buttons Helper
    local function CreateToggle(name, text, default, order)
        local ToggleFrame = Instance.new("Frame")
        ToggleFrame.Name = name
        ToggleFrame.Size = UDim2.new(1, 0, 0, 30)
        ToggleFrame.BackgroundTransparency = 1
        ToggleFrame.LayoutOrder = order
        ToggleFrame.Parent = Content
        
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(0.7, 0, 1, 0)
        Label.BackgroundTransparency = 1
        Label.Text = text
        Label.TextColor3 = Color3.fromRGB(200, 200, 200)
        Label.TextSize = 12
        Label.Font = Enum.Font.Gotham
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = ToggleFrame
        
        local ToggleBtn = Instance.new("TextButton")
        ToggleBtn.Name = "Toggle"
        ToggleBtn.Size = UDim2.new(0, 50, 0, 24)
        ToggleBtn.Position = UDim2.new(1, -55, 0.5, -12)
        ToggleBtn.BackgroundColor3 = default and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(80, 40, 40)
        ToggleBtn.Text = default and "ON" or "OFF"
        ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        ToggleBtn.TextSize = 11
        ToggleBtn.Font = Enum.Font.GothamBold
        ToggleBtn.BorderSizePixel = 0
        ToggleBtn.Parent = ToggleFrame
        
        local BtnCorner = Instance.new("UICorner")
        BtnCorner.CornerRadius = UDim.new(0, 6)
        BtnCorner.Parent = ToggleBtn
        
        return ToggleBtn
    end
    
    -- Toggles
    local WalkToKickToggle = CreateToggle("WalkToKickToggle", "Auto Walk → Kick", Config.AutoWalkToKick, 5)
    local WalkToBaseToggle = CreateToggle("WalkToBaseToggle", "Auto Walk → Base", Config.AutoWalkToBase, 6)
    local AntiAFKToggle = CreateToggle("AntiAFKToggle", "Anti-AFK", Config.AntiAFK, 7)
    
    -- Separator 2
    local Sep2 = Instance.new("Frame")
    Sep2.Size = UDim2.new(1, 0, 0, 1)
    Sep2.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    Sep2.BorderSizePixel = 0
    Sep2.LayoutOrder = 8
    Sep2.Parent = Content
    
    -- START/STOP Button
    local StartBtn = Instance.new("TextButton")
    StartBtn.Name = "StartBtn"
    StartBtn.Size = UDim2.new(1, 0, 0, 40)
    StartBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 60)
    StartBtn.Text = "▶ START"
    StartBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    StartBtn.TextSize = 16
    StartBtn.Font = Enum.Font.GothamBold
    StartBtn.BorderSizePixel = 0
    StartBtn.LayoutOrder = 9
    StartBtn.Parent = Content
    
    local StartCorner = Instance.new("UICorner")
    StartCorner.CornerRadius = UDim.new(0, 8)
    StartCorner.Parent = StartBtn
    
    -- Set Position Button (untuk mark posisi manual)
    local SetPosBtn = Instance.new("TextButton")
    SetPosBtn.Name = "SetPosBtn"
    SetPosBtn.Size = UDim2.new(1, 0, 0, 28)
    SetPosBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
    SetPosBtn.Text = "📍 Set Kick Pos (Stand & Tap)"
    SetPosBtn.TextColor3 = Color3.fromRGB(180, 180, 220)
    SetPosBtn.TextSize = 11
    SetPosBtn.Font = Enum.Font.Gotham
    SetPosBtn.BorderSizePixel = 0
    SetPosBtn.LayoutOrder = 10
    SetPosBtn.Parent = Content
    
    local SetPosCorner = Instance.new("UICorner")
    SetPosCorner.CornerRadius = UDim.new(0, 6)
    SetPosCorner.Parent = SetPosBtn
    
    local SetBaseBtn = Instance.new("TextButton")
    SetBaseBtn.Name = "SetBaseBtn"
    SetBaseBtn.Size = UDim2.new(1, 0, 0, 28)
    SetBaseBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
    SetBaseBtn.Text = "🏠 Set Base Pos (Stand & Tap)"
    SetBaseBtn.TextColor3 = Color3.fromRGB(180, 180, 220)
    SetBaseBtn.TextSize = 11
    SetBaseBtn.Font = Enum.Font.Gotham
    SetBaseBtn.BorderSizePixel = 0
    SetBaseBtn.LayoutOrder = 11
    SetBaseBtn.Parent = Content
    
    local SetBaseCorner = Instance.new("UICorner")
    SetBaseCorner.CornerRadius = UDim.new(0, 6)
    SetBaseCorner.Parent = SetBaseBtn
    
    -- ═══ DRAGGABLE ═══
    local dragging = false
    local dragInput, dragStart, startPos
    
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    TitleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    -- ═══ MINIMIZE ═══
    local minimized = false
    MinBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            Content.Visible = false
            MainFrame.Size = UDim2.new(0, 280, 0, 45)
            MinBtn.Text = "+"
        else
            Content.Visible = true
            MainFrame.Size = UDim2.new(0, 280, 0, 380)
            MinBtn.Text = "—"
        end
    end)
    
    -- ═══ TOGGLE HANDLERS ═══
    local function SetupToggle(btn, configKey)
        btn.MouseButton1Click:Connect(function()
            Config[configKey] = not Config[configKey]
            btn.BackgroundColor3 = Config[configKey] and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(80, 40, 40)
            btn.Text = Config[configKey] and "ON" or "OFF"
        end)
    end
    
    SetupToggle(WalkToKickToggle, "AutoWalkToKick")
    SetupToggle(WalkToBaseToggle, "AutoWalkToBase")
    SetupToggle(AntiAFKToggle, "AntiAFK")
    
    -- ═══ START/STOP ═══
    StartBtn.MouseButton1Click:Connect(function()
        State.Running = not State.Running
        if State.Running then
            StartBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
            StartBtn.Text = "⏹ STOP"
            -- Start main loop
            task.spawn(MainLoop)
        else
            StartBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 60)
            StartBtn.Text = "▶ START"
            State.CurrentPhase = "Stopped"
        end
    end)
    
    -- ═══ SET POSITION BUTTONS ═══
    SetPosBtn.MouseButton1Click:Connect(function()
        if GetCharacter() then
            Config.KickPosition = HRP.Position
            SetPosBtn.Text = string.format("📍 Kick: %.0f, %.0f, %.0f ✓", 
                HRP.Position.X, HRP.Position.Y, HRP.Position.Z)
            SetPosBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
        end
    end)
    
    SetBaseBtn.MouseButton1Click:Connect(function()
        if GetCharacter() then
            Config.BasePosition = HRP.Position
            SetBaseBtn.Text = string.format("🏠 Base: %.0f, %.0f, %.0f ✓", 
                HRP.Position.X, HRP.Position.Y, HRP.Position.Z)
            SetBaseBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
        end
    end)
    
    -- ═══ UPDATE LOOP (UI) ═══
    task.spawn(function()
        while ScreenGui.Parent do
            StatusLabel.Text = "Status: " .. State.CurrentPhase
            KicksLabel.Text = string.format("Kicks: %d | Brainrots: %d", State.TotalKicks, State.TotalBrainrots)
            
            if State.LastBrainrotName ~= "None" then
                local mutText = State.LastMutation ~= "None" and (" [" .. State.LastMutation .. "]") or ""
                LastBrainrotLabel.Text = "Last: " .. State.LastBrainrotName .. mutText
            end
            
            task.wait(0.25)
        end
    end)
    
    return ScreenGui
end

-- ═══════════════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════════════
local function Init()
    -- Setup
    AntiAFK()
    HookEvents()
    
    -- Auto-detect posisi
    task.spawn(function()
        task.wait(2) -- tunggu game load
        Config.KickPosition = FindLuckyBlockPosition()
        Config.BasePosition = FindBasePosition()
    end)
    
    -- Create GUI
    CreateGUI()
    
    print("[AutoKick] Loaded! Tap START untuk mulai.")
    print("[AutoKick] Tips: Set posisi manual jika auto-detect gagal.")
end

Init()
