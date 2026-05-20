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
-- MODULE ACCESS (via getgc / registry - Delta compatible)
-- ═══════════════════════════════════════════════════
local KickController = nil
local TeleportController = nil
local GameHandler = nil

-- Method 1: Cari module dari GC (garbage collector) - paling reliable di Delta
local function FindModuleInGC(moduleName)
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" then
            -- Cek rawget untuk avoid metatables yang error
            local success, result = pcall(function()
                if rawget(v, "Kick") and rawget(v, "InMinigame") ~= nil and rawget(v, "PerformKick") then
                    return "KickController"
                end
                if rawget(v, "TeleportToBase") and rawget(v, "TeleportToSeller") then
                    return "TeleportController"
                end
                if rawget(v, "Status") and rawget(v, "InGame") ~= nil and rawget(v, "GotResult") then
                    return "GameHandler"
                end
            end)
            if success and result == moduleName then
                return v
            end
        end
    end
    return nil
end

-- Method 2: Cari via require pada children ModuleScript
local function FindModuleViaRequire()
    local success, err = pcall(function()
        local Modules = ReplicatedStorage:FindFirstChild("Modules")
        if not Modules then return end
        
        local CL = Modules:FindFirstChild("ControllerLoader")
        if CL then
            for _, child in pairs(CL:GetChildren()) do
                if child:IsA("ModuleScript") then
                    local ok, mod = pcall(require, child)
                    if ok and type(mod) == "table" then
                        if mod.Kick and mod.InMinigame ~= nil then
                            KickController = mod
                        elseif mod.TeleportToBase then
                            TeleportController = mod
                        end
                    end
                end
            end
        end
        
        local HL = Modules:FindFirstChild("HandlerLoader")
        if HL then
            for _, child in pairs(HL:GetChildren()) do
                if child:IsA("ModuleScript") then
                    local ok, mod = pcall(require, child)
                    if ok and type(mod) == "table" then
                        if mod.Status and mod.InGame ~= nil then
                            GameHandler = mod
                        end
                    end
                end
            end
        end
    end)
end

-- Load modules
local function LoadModules()
    print("[AutoKick] Loading modules...")
    
    -- Try GC method first (most reliable for Delta)
    if getgc then
        KickController = FindModuleInGC("KickController")
        TeleportController = FindModuleInGC("TeleportController")
        GameHandler = FindModuleInGC("GameHandler")
    end
    
    -- Fallback to require method
    if not KickController then
        FindModuleViaRequire()
    end
    
    -- Report what we found
    print("[AutoKick] KickController:", KickController and "FOUND" or "NOT FOUND")
    print("[AutoKick] TeleportController:", TeleportController and "FOUND" or "NOT FOUND")
    print("[AutoKick] GameHandler:", GameHandler and "FOUND" or "NOT FOUND")
    
    return KickController ~= nil
end

-- ═══════════════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════════════
local Config = {
    -- Timing (dengan jitter anti-detect)
    KickDelayMin = 4.0,
    KickDelayMax = 6.5,
    WalkSpeed = 32,
    
    -- Auto Walk
    AutoWalkToKick = true,
    AutoWalkToBase = true,
    
    -- Safety
    MaxKicksPerSession = 999,
    AntiAFK = true,
    
    -- Lokasi (set manual via GUI)
    KickPosition = nil,
    BasePosition = nil,
}

-- ═══════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════
local State = {
    Running = false,
    TotalKicks = 0,
    TotalBrainrots = 0,
    CurrentPhase = "Idle",
    LastKickTime = 0,
    GotBrainrot = false,
    LastBrainrotName = "None",
    LastMutation = "None",
    ModulesLoaded = false,
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
    return Character ~= nil and Humanoid ~= nil and HRP ~= nil
end

local function WalkTo(targetPosition, timeout)
    if not GetCharacter() then return false end
    timeout = timeout or 15
    
    local startTime = tick()
    
    -- Simple MoveTo approach (paling kompatibel di mobile)
    local reached = false
    local connection
    
    connection = Humanoid.MoveToFinished:Connect(function(didReach)
        reached = didReach
    end)
    
    -- Jalan langsung ke target
    Humanoid:MoveTo(targetPosition)
    
    -- Tunggu sampai sampai atau timeout
    repeat
        task.wait(0.15)
        if not GetCharacter() then break end
        
        -- Re-issue MoveTo setiap 6 detik (Roblox auto-cancel setelah 8 detik)
        if (tick() - startTime) % 6 < 0.2 then
            Humanoid:MoveTo(targetPosition)
        end
    until reached 
          or (HRP.Position - targetPosition).Magnitude < 6 
          or (tick() - startTime) > timeout
          or not State.Running
    
    if connection then
        connection:Disconnect()
    end
    
    -- Stop movement
    if GetCharacter() then
        Humanoid:MoveTo(HRP.Position)
    end
    
    return reached or (GetCharacter() and (HRP.Position - targetPosition).Magnitude < 6)
end

local function TeleportToBase()
    -- Method 1: Gunakan TeleportController bawaan game
    if TeleportController and TeleportController.TeleportToBase then
        local success = pcall(function()
            TeleportController:TeleportToBase()
        end)
        if success then
            task.wait(0.5)
            return true
        end
    end
    
    -- Method 2: Walk manual ke base position
    if Config.BasePosition then
        return WalkTo(Config.BasePosition, 20)
    end
    
    return false
end

-- ═══════════════════════════════════════════════════
-- CORE AUTOMATION
-- ═══════════════════════════════════════════════════
local function DoKick()
    if not GetCharacter() then return false end
    if not KickController then return false end
    
    -- Cek apakah sedang dalam minigame
    if KickController.InMinigame then
        return false
    end
    
    -- Panggil kick function
    local success, err = pcall(function()
        KickController:Kick()
    end)
    
    if not success then
        print("[AutoKick] Kick error:", err)
    end
    
    return success
end

local function WaitForKickResult(timeout)
    timeout = timeout or 12
    local startTime = tick()
    
    if not KickController then
        task.wait(4)
        return true
    end
    
    -- Tunggu sampai InMinigame jadi false lagi
    while State.Running and (tick() - startTime) < timeout do
        if not KickController.InMinigame then
            task.wait(0.3)
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
        
        -- PHASE 1: Walk ke tempat kick
        if Config.AutoWalkToKick and Config.KickPosition then
            State.CurrentPhase = "Walking > Kick"
            WalkTo(Config.KickPosition, 15)
            task.wait(0.3)
        end
        
        -- PHASE 2: Kick
        State.CurrentPhase = "Kicking..."
        
        -- Tunggu kalau masih dalam minigame
        local attempts = 0
        while KickController and KickController.InMinigame and attempts < 30 do
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
            if Config.AutoWalkToBase and Config.BasePosition then
                State.CurrentPhase = "Walking > Base"
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
            State.CurrentPhase = "Kick Failed, Retry..."
            task.wait(2)
        end
    end
    
    State.CurrentPhase = "Stopped"
end

-- ═══════════════════════════════════════════════════
-- ANTI-AFK (Delta compatible - no VirtualUser)
-- ═══════════════════════════════════════════════════
local function AntiAFK()
    -- Method: Simulated movement setiap 4 menit
    task.spawn(function()
        while true do
            task.wait(240) -- 4 menit
            if Config.AntiAFK and GetCharacter() then
                -- Kecil movement agar tidak idle
                pcall(function()
                    Humanoid.Jump = true
                end)
            end
        end
    end)
    
    -- Method 2: Override Idled connection (jika tersedia)
    pcall(function()
        local con
        con = Player.Idled:Connect(function()
            if Config.AntiAFK then
                pcall(function()
                    -- Reconnect ke game
                    game:GetService("TeleportService"):Teleport(game.PlaceId, Player)
                end)
            end
        end)
    end)
end

-- ═══════════════════════════════════════════════════
-- HOOK GAME EVENTS (detect brainrot)
-- ═══════════════════════════════════════════════════
local function HookEvents()
    pcall(function()
        -- Cari RemoteEvent di network folder
        local Shared = ReplicatedStorage:FindFirstChild("Shared")
        if not Shared then return end
        
        local Packages = Shared:FindFirstChild("Packages")
        if not Packages then return end
        
        local NetworkFolder = Packages:FindFirstChild("Network")
        if not NetworkFolder then return end
        
        for _, remote in pairs(NetworkFolder:GetDescendants()) do
            if remote:IsA("RemoteEvent") then
                pcall(function()
                    remote.OnClientEvent:Connect(function(arg1, arg2)
                        -- Detect kick result (distance + brainrot table)
                        if type(arg1) == "number" and type(arg2) == "table" then
                            if arg2.Name then
                                State.GotBrainrot = true
                                State.TotalBrainrots = State.TotalBrainrots + 1
                                State.LastBrainrotName = tostring(arg2.Name)
                                State.LastMutation = tostring(arg2.Mutation or "None")
                            end
                        end
                    end)
                end)
            end
        end
    end)
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
    pcall(function()
        local old = Player.PlayerGui:FindFirstChild("AutoKickGUI")
        if old then old:Destroy() end
    end)
    
    -- Gunakan CoreGui jika bisa (lebih stabil di Delta), fallback ke PlayerGui
    local guiParent = (gethui and gethui()) or (syn and syn.protect_gui and game:GetService("CoreGui")) or Player.PlayerGui
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AutoKickGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    pcall(function()
        if guiParent == game:GetService("CoreGui") then
            -- Protect gui untuk Delta/Synapse
            if syn and syn.protect_gui then
                syn.protect_gui(ScreenGui)
            end
        end
    end)
    
    ScreenGui.Parent = guiParent
    
    -- Main Frame
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 260, 0, 340)
    MainFrame.Position = UDim2.new(0.5, -130, 0.3, 0)
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
    TitleBar.Size = UDim2.new(1, 0, 0, 36)
    TitleBar.BackgroundColor3 = Color3.fromRGB(40, 20, 80)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 12)
    TitleCorner.Parent = TitleBar
    
    local TitleFix = Instance.new("Frame")
    TitleFix.Size = UDim2.new(1, 0, 0, 12)
    TitleFix.Position = UDim2.new(0, 0, 1, -12)
    TitleFix.BackgroundColor3 = Color3.fromRGB(40, 20, 80)
    TitleFix.BorderSizePixel = 0
    TitleFix.Parent = TitleBar
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -50, 1, 0)
    TitleLabel.Position = UDim2.new(0, 10, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "Auto Kick & Walk"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.TextSize = 14
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TitleBar
    
    -- Minimize Button
    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, 28, 0, 28)
    MinBtn.Position = UDim2.new(1, -34, 0, 4)
    MinBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 100)
    MinBtn.Text = "-"
    MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinBtn.TextSize = 16
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.BorderSizePixel = 0
    MinBtn.Parent = TitleBar
    
    Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)
    
    -- Content Frame
    local Content = Instance.new("Frame")
    Content.Name = "Content"
    Content.Size = UDim2.new(1, -16, 1, -44)
    Content.Position = UDim2.new(0, 8, 0, 40)
    Content.BackgroundTransparency = 1
    Content.Parent = MainFrame
    
    local Layout = Instance.new("UIListLayout")
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Padding = UDim.new(0, 6)
    Layout.Parent = Content
    
    -- Helper: Create Label
    local function MakeLabel(text, color, order)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 18)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = color
        lbl.TextSize = 11
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.LayoutOrder = order
        lbl.Parent = Content
        return lbl
    end
    
    -- Helper: Create Toggle
    local function MakeToggle(text, default, order)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 26)
        frame.BackgroundTransparency = 1
        frame.LayoutOrder = order
        frame.Parent = Content
        
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.7, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
        lbl.TextSize = 11
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame
        
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 44, 0, 22)
        btn.Position = UDim2.new(1, -48, 0.5, -11)
        btn.BackgroundColor3 = default and Color3.fromRGB(50, 160, 70) or Color3.fromRGB(80, 40, 40)
        btn.Text = default and "ON" or "OFF"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 10
        btn.Font = Enum.Font.GothamBold
        btn.BorderSizePixel = 0
        btn.Parent = frame
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
        
        return btn
    end
    
    -- Helper: Create Button
    local function MakeButton(text, color, order)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = color
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 12
        btn.Font = Enum.Font.GothamBold
        btn.BorderSizePixel = 0
        btn.LayoutOrder = order
        btn.Parent = Content
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
        return btn
    end
    
    -- === UI Elements ===
    local StatusLabel = MakeLabel("Status: Idle", Color3.fromRGB(200, 200, 200), 1)
    local KicksLabel = MakeLabel("Kicks: 0 | Brainrots: 0", Color3.fromRGB(150, 220, 150), 2)
    local LastLabel = MakeLabel("Last: -", Color3.fromRGB(220, 180, 100), 3)
    
    -- Separator
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(1, 0, 0, 1)
    sep.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    sep.BorderSizePixel = 0
    sep.LayoutOrder = 4
    sep.Parent = Content
    
    -- Toggles
    local WalkKickBtn = MakeToggle("Auto Walk > Kick", Config.AutoWalkToKick, 5)
    local WalkBaseBtn = MakeToggle("Auto Walk > Base", Config.AutoWalkToBase, 6)
    local AfkBtn = MakeToggle("Anti-AFK", Config.AntiAFK, 7)
    
    -- Separator 2
    local sep2 = Instance.new("Frame")
    sep2.Size = UDim2.new(1, 0, 0, 1)
    sep2.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    sep2.BorderSizePixel = 0
    sep2.LayoutOrder = 8
    sep2.Parent = Content
    
    -- Buttons
    local StartBtn = MakeButton("START", Color3.fromRGB(40, 150, 60), 9)
    local SetKickBtn = MakeButton("Set Kick Pos (berdiri disini)", Color3.fromRGB(50, 50, 80), 10)
    local SetBaseBtn = MakeButton("Set Base Pos (berdiri disini)", Color3.fromRGB(50, 50, 80), 11)
    
    -- === DRAGGABLE ===
    local dragging = false
    local dragStart, startPos
    
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)
    
    TitleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    -- === MINIMIZE ===
    local minimized = false
    MinBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        Content.Visible = not minimized
        MainFrame.Size = minimized and UDim2.new(0, 260, 0, 40) or UDim2.new(0, 260, 0, 340)
        MinBtn.Text = minimized and "+" or "-"
    end)
    
    -- === TOGGLE LOGIC ===
    local function BindToggle(btn, key)
        btn.MouseButton1Click:Connect(function()
            Config[key] = not Config[key]
            btn.BackgroundColor3 = Config[key] and Color3.fromRGB(50, 160, 70) or Color3.fromRGB(80, 40, 40)
            btn.Text = Config[key] and "ON" or "OFF"
        end)
    end
    
    BindToggle(WalkKickBtn, "AutoWalkToKick")
    BindToggle(WalkBaseBtn, "AutoWalkToBase")
    BindToggle(AfkBtn, "AntiAFK")
    
    -- === START/STOP ===
    StartBtn.MouseButton1Click:Connect(function()
        State.Running = not State.Running
        if State.Running then
            StartBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
            StartBtn.Text = "STOP"
            task.spawn(MainLoop)
        else
            StartBtn.BackgroundColor3 = Color3.fromRGB(40, 150, 60)
            StartBtn.Text = "START"
            State.CurrentPhase = "Stopped"
        end
    end)
    
    -- === SET POSITION ===
    SetKickBtn.MouseButton1Click:Connect(function()
        if GetCharacter() then
            Config.KickPosition = HRP.Position
            SetKickBtn.Text = string.format("Kick: %.0f, %.0f, %.0f", HRP.Position.X, HRP.Position.Y, HRP.Position.Z)
            SetKickBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
        end
    end)
    
    SetBaseBtn.MouseButton1Click:Connect(function()
        if GetCharacter() then
            Config.BasePosition = HRP.Position
            SetBaseBtn.Text = string.format("Base: %.0f, %.0f, %.0f", HRP.Position.X, HRP.Position.Y, HRP.Position.Z)
            SetBaseBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
        end
    end)
    
    -- === UI UPDATE LOOP ===
    task.spawn(function()
        while ScreenGui and ScreenGui.Parent do
            pcall(function()
                StatusLabel.Text = "Status: " .. State.CurrentPhase
                KicksLabel.Text = string.format("Kicks: %d | Brainrots: %d", State.TotalKicks, State.TotalBrainrots)
                if State.LastBrainrotName ~= "None" then
                    local mut = State.LastMutation ~= "None" and (" [" .. State.LastMutation .. "]") or ""
                    LastLabel.Text = "Last: " .. State.LastBrainrotName .. mut
                end
            end)
            task.wait(0.3)
        end
    end)
    
    return ScreenGui
end

-- ═══════════════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════════════
local function Init()
    -- Load game modules
    local loaded = LoadModules()
    
    if not loaded then
        warn("[AutoKick] KickController tidak ditemukan! Script mungkin tidak bekerja.")
        warn("[AutoKick] Pastikan game sudah fully loaded sebelum execute script.")
    end
    
    -- Setup
    AntiAFK()
    HookEvents()
    
    -- Create GUI
    CreateGUI()
    
    print("[AutoKick] =====================================")
    print("[AutoKick] Script loaded!")
    print("[AutoKick] 1. Berdiri di tempat kick > tap 'Set Kick Pos'")
    print("[AutoKick] 2. Berdiri di base > tap 'Set Base Pos'")
    print("[AutoKick] 3. Tap START")
    print("[AutoKick] =====================================")
end

Init()
