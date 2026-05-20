--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║  TENDANG BLOK KEBERUNTUNGAN - FULL AUTO FARM SCRIPT         ║
    ║  Game ID: 89469502395769                                     ║
    ║  Untuk: Roblox Executor (Synapse/Fluxus/Wave/dll)           ║
    ╚══════════════════════════════════════════════════════════════╝
    
    FLOW:
    1. Auto kick lucky block (max power)
    2. Auto collect brainrot yang jatuh
    3. Auto teleport kembali ke base
    4. Auto place brainrot ke slot
    5. Repeat infinitely
    
    BONUS:
    - Auto upgrade kick power
    - Auto wheel spin
    - Auto weight lifting (squat)
    - Speed hack
    - Anti-AFK
]]

-- ═══════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════
local CONFIG = {
    AUTO_KICK = true,           -- Auto kick lucky block
    AUTO_COLLECT = true,        -- Auto collect brainrot setelah kick
    AUTO_TELEPORT_BASE = true,  -- Auto teleport ke base setelah collect
    AUTO_UPGRADE_KICK = true,   -- Auto upgrade kick power
    AUTO_WHEEL_SPIN = true,     -- Auto wheel spin (free)
    AUTO_WEIGHT = false,        -- Auto weight/squat
    SPEED_HACK = true,          -- Speed boost
    ANTI_AFK = true,            -- Anti kick AFK
    
    KICK_DELAY = 0.5,           -- Delay antara kick (detik)
    COLLECT_WAIT = 2,           -- Waktu tunggu setelah kick untuk collect
    LOOP_DELAY = 0.3,           -- Delay antar loop utama
    TARGET_SPEED = 100,         -- Speed yang diinginkan (normal=13, max=550)
}

-- ═══════════════════════════════════════
-- SERVICES & REFERENCES
-- ═══════════════════════════════════════
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Game modules (dari ReplicatedStorage)
local Modules = RS:WaitForChild("Modules")
local Shared = RS:WaitForChild("Shared")

-- ═══════════════════════════════════════
-- MODULE LOADERS
-- ═══════════════════════════════════════
local function safeRequire(module)
    local ok, result = pcall(require, module)
    if ok then return result end
    warn("[AutoFarm] Failed to require:", module:GetFullName(), result)
    return nil
end

-- Load game services
local ServicesLoader = safeRequire(Modules:WaitForChild("ServicesLoader"))
local ControllerLoader = safeRequire(Modules:WaitForChild("ControllerLoader"))
local Network = safeRequire(Shared:WaitForChild("Packages"):WaitForChild("Network"))

-- Individual services (via direct access setelah game load)
local KickServiceClient, ClientBalanceService, WheelSpinService, TeleportController
local KickController, PlotHitboxController, PlacementController

local function loadServices()
    pcall(function()
        -- Coba akses via require atau via loaded modules
        KickServiceClient = require(Modules.ServicesLoader.KickServiceClient)
        ClientBalanceService = require(Modules.ServicesLoader.ClientBalanceService)
        WheelSpinService = require(Modules.ServicesLoader.WheelSpinServiceClient)
        KickController = require(Modules.ControllerLoader.KickController)
        TeleportController = require(Modules.ControllerLoader.TeleportController)
        PlotHitboxController = require(Modules.ControllerLoader.PlotHitboxController)
        PlacementController = require(Modules.ControllerLoader.PlacementController)
    end)
end

-- ═══════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════
local function getCharacter()
    character = player.Character
    if character then
        humanoid = character:FindFirstChildOfClass("Humanoid")
        rootPart = character:FindFirstChild("HumanoidRootPart")
    end
    return character and humanoid and rootPart
end

local function teleportTo(position)
    if not getCharacter() then return end
    rootPart.CFrame = CFrame.new(position)
    task.wait(0.1)
end

local function findNearestLuckyBlock()
    -- Lucky blocks biasanya ada di Workspace dengan tag/attribute tertentu
    local closest = nil
    local closestDist = math.huge
    
    -- Cari di workspace berdasarkan nama/tag LuckyBlock
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and (
            obj.Name:find("LuckyBlock") or 
            obj.Name:find("Lucky") or
            obj:GetAttribute("LuckyBlock")
        ) then
            local primary = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
            if primary and getCharacter() then
                local dist = (primary.Position - rootPart.Position).Magnitude
                if dist < closestDist then
                    closest = primary
                    closestDist = dist
                end
            end
        end
    end
    
    -- Fallback: cari part dengan CollectionService tag
    if not closest then
        local CollectionService = game:GetService("CollectionService")
        for _, tag in pairs({"LuckyBlockTool", "LuckyBlock", "Entity"}) do
            local tagged = CollectionService:GetTagged(tag)
            for _, obj in pairs(tagged) do
                if obj:IsA("BasePart") or obj:IsA("Model") then
                    local part = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
                    if part and getCharacter() then
                        local dist = (part.Position - rootPart.Position).Magnitude
                        if dist < closestDist then
                            closest = part
                            closestDist = dist
                        end
                    end
                end
            end
        end
    end
    
    return closest
end

local function findPlayerPlot()
    -- Plot player biasanya di Workspace.Plots atau langsung assigned
    local plots = workspace:FindFirstChild("Plots") or workspace:FindFirstChild("PlayerPlots")
    if plots then
        for _, plot in pairs(plots:GetChildren()) do
            if plot:GetAttribute("Owner") == player.Name or plot:GetAttribute("Owner") == player.UserId then
                return plot
            end
        end
    end
    
    -- Fallback via ClientPlotService
    if PlotHitboxController then
        -- Plot model bisa diakses dari service
        return workspace:FindFirstChild("Plot" .. tostring(player.UserId))
    end
    
    return nil
end

-- ═══════════════════════════════════════
-- CORE: AUTO KICK
-- ═══════════════════════════════════════
local function performKick()
    if not getCharacter() then return false end
    
    -- Method 1: Via KickController langsung
    if KickController and KickController.PerformKick then
        pcall(function()
            KickController.TravelRatio = 1  -- Max power ratio
            KickController.Scale = 1
            KickController:PerformKick()
        end)
        return true
    end
    
    -- Method 2: Via Network remote (fire ke server)
    if Network then
        pcall(function()
            Network.FireServer("Kick")
        end)
        return true
    end
    
    -- Method 3: Simulate click pada lucky block
    -- Cari lucky block terdekat dan fire ProximityPrompt atau touch
    local luckyBlock = findNearestLuckyBlock()
    if luckyBlock then
        -- Fire touch event
        pcall(function()
            firetouchinterest(rootPart, luckyBlock, 0) -- Begin touch
            task.wait(0.1)
            firetouchinterest(rootPart, luckyBlock, 1) -- End touch
        end)
        return true
    end
    
    -- Method 4: Fire semua RemoteEvents yang related ke "Kick"
    pcall(function()
        for _, remote in pairs(RS:GetDescendants()) do
            if remote:IsA("RemoteEvent") and remote.Name:lower():find("kick") then
                remote:FireServer()
            end
        end
    end)
    
    return false
end

-- ═══════════════════════════════════════
-- CORE: AUTO COLLECT BRAINROT
-- ═══════════════════════════════════════
local function collectBrainrot()
    -- Setelah kick, brainrot jatuh di area landing
    -- Kita perlu "touch" atau "equip" brainrot yang jatuh
    
    -- Method 1: Cari entity yang baru spawn (collectible)
    local CollectionService = game:GetService("CollectionService")
    local entities = CollectionService:GetTagged("EntityTool")
    
    for _, entity in pairs(entities) do
        if entity:IsA("Model") or entity:IsA("BasePart") then
            local part = entity:IsA("BasePart") and entity or (entity.PrimaryPart or entity:FindFirstChildWhichIsA("BasePart"))
            if part then
                -- Teleport ke entity dan touch
                teleportTo(part.Position)
                task.wait(0.2)
                pcall(function()
                    firetouchinterest(rootPart, part, 0)
                    task.wait(0.1)
                    firetouchinterest(rootPart, part, 1)
                end)
            end
        end
    end
    
    -- Method 2: Fire network event untuk collect
    pcall(function()
        if Network then
            Network.FireServer("Collect")
            Network.FireServer("PickupBrainrot")
        end
    end)
    
    -- Method 3: Cari proximity prompts yang muncul
    pcall(function()
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Enabled then
                fireproximityprompt(obj)
            end
        end
    end)
end

-- ═══════════════════════════════════════
-- CORE: AUTO TELEPORT TO BASE
-- ═══════════════════════════════════════
local function teleportToBase()
    -- Method 1: Via TeleportController
    if TeleportController and TeleportController.TeleportToBase then
        pcall(function()
            TeleportController.TeleportToBase()
        end)
        return true
    end
    
    -- Method 2: Via Network
    pcall(function()
        if Network then
            Network.FireServer("TeleportToBase")
        end
    end)
    
    -- Method 3: Cari plot dan teleport langsung
    local plot = findPlayerPlot()
    if plot then
        local primary = plot.PrimaryPart or plot:FindFirstChildWhichIsA("BasePart")
        if primary then
            teleportTo(primary.Position + Vector3.new(0, 5, 0))
            return true
        end
    end
    
    -- Method 4: Scan workspace untuk base/plot indicators
    pcall(function()
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj.Name == "PlotBase" or obj.Name == "BasePart" then
                if obj:GetAttribute("Owner") == player.Name then
                    teleportTo(obj.Position + Vector3.new(0, 5, 0))
                    return
                end
            end
        end
    end)
    
    return false
end

-- ═══════════════════════════════════════
-- CORE: AUTO PLACE BRAINROT
-- ═══════════════════════════════════════
local function placeBrainrot()
    -- Brainrot otomatis di-place saat player di plot area (PlotHitboxController.IsInPlot)
    -- Tapi kita bisa trigger manual
    
    if PlacementController and not PlacementController.IsHolding then
        -- Tidak sedang hold = brainrot sudah placed atau belum pickup
        return
    end
    
    -- Fire placement ke server
    pcall(function()
        if Network then
            Network.FireServer("PlaceBrainrot")
            Network.FireServer("Place")
        end
    end)
    
    -- Fire semua related remotes
    pcall(function()
        for _, remote in pairs(RS:GetDescendants()) do
            if remote:IsA("RemoteEvent") and (
                remote.Name:lower():find("place") or
                remote.Name:lower():find("slot")
            ) then
                remote:FireServer()
            end
        end
    end)
end

-- ═══════════════════════════════════════
-- BONUS: AUTO UPGRADE KICK
-- ═══════════════════════════════════════
local function autoUpgradeKick()
    if not CONFIG.AUTO_UPGRADE_KICK then return end
    
    pcall(function()
        if Network then
            Network.FireServer("UpgradeKick")
            Network.FireServer("BuyKickUpgrade")
        end
        
        -- Fire related remotes
        for _, remote in pairs(RS:GetDescendants()) do
            if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                if remote.Name:lower():find("upgrade") and remote.Name:lower():find("kick") then
                    if remote:IsA("RemoteEvent") then
                        remote:FireServer()
                    else
                        pcall(function() remote:InvokeServer() end)
                    end
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════
-- BONUS: AUTO WHEEL SPIN
-- ═══════════════════════════════════════
local function autoWheelSpin()
    if not CONFIG.AUTO_WHEEL_SPIN then return end
    
    pcall(function()
        if WheelSpinService and WheelSpinService.RequestSpin then
            -- Reset cooldown (client-side only, server might reject)
            WheelSpinService.LastFreeSpin = 0
            WheelSpinService:RequestSpin()
        end
        
        -- Via Network
        if Network then
            Network.FireServer("SpinWheel")
            Network.FireServer("RequestSpin")
            Network.FireServer("FreeSpin")
        end
    end)
end

-- ═══════════════════════════════════════
-- BONUS: SPEED HACK
-- ═══════════════════════════════════════
local function applySpeedHack()
    if not CONFIG.SPEED_HACK then return end
    if not getCharacter() then return end
    
    pcall(function()
        humanoid.WalkSpeed = CONFIG.TARGET_SPEED
    end)
end

-- ═══════════════════════════════════════
-- BONUS: ANTI-AFK
-- ═══════════════════════════════════════
local function setupAntiAFK()
    if not CONFIG.ANTI_AFK then return end
    
    -- Override idle detection
    local vu = game:GetService("VirtualUser")
    player.Idled:Connect(function()
        vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
end

-- ═══════════════════════════════════════
-- BONUS: AUTO WEIGHT/SQUAT (Machine)
-- ═══════════════════════════════════════
local function autoWeight()
    if not CONFIG.AUTO_WEIGHT then return end
    
    -- Machine ada di Workspace.Machine.Hitbox
    local machine = workspace:FindFirstChild("Machine")
    if not machine then return end
    
    local hitbox = machine:FindFirstChild("Hitbox")
    if not hitbox then return end
    
    -- Teleport ke machine dan trigger
    teleportTo(hitbox.Position + Vector3.new(0, 3, 0))
    task.wait(0.3)
    
    pcall(function()
        -- Fire touch pada hitbox
        firetouchinterest(rootPart, hitbox, 0)
        task.wait(0.1)
        firetouchinterest(rootPart, hitbox, 1)
        
        -- Atau fire proximity prompt
        local prompt = hitbox:FindFirstChildOfClass("ProximityPrompt")
        if prompt then
            fireproximityprompt(prompt)
        end
    end)
end

-- ═══════════════════════════════════════
-- REMOTE SCANNER (untuk debugging)
-- ═══════════════════════════════════════
local function scanRemotes()
    print("\n[AutoFarm] === SCANNING REMOTE EVENTS ===")
    for _, obj in pairs(RS:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
            print(string.format("  [%s] %s", obj.ClassName, obj:GetFullName()))
        end
    end
    print("[AutoFarm] === END SCAN ===\n")
end

-- ═══════════════════════════════════════
-- MAIN LOOP
-- ═══════════════════════════════════════
local running = true
local loopCount = 0

local function mainLoop()
    print("[AutoFarm] Starting main loop...")
    
    while running do
        loopCount = loopCount + 1
        
        -- Refresh character reference
        if not getCharacter() then
            task.wait(1)
            continue
        end
        
        -- Apply speed hack setiap loop
        applySpeedHack()
        
        -- === STEP 1: KICK LUCKY BLOCK ===
        if CONFIG.AUTO_KICK then
            performKick()
            task.wait(CONFIG.KICK_DELAY)
        end
        
        -- === STEP 2: WAIT FOR BRAINROT TO LAND ===
        if CONFIG.AUTO_COLLECT then
            task.wait(CONFIG.COLLECT_WAIT)
            collectBrainrot()
        end
        
        -- === STEP 3: TELEPORT TO BASE ===
        if CONFIG.AUTO_TELEPORT_BASE then
            task.wait(0.3)
            teleportToBase()
            task.wait(0.5)
        end
        
        -- === STEP 4: PLACE BRAINROT ===
        placeBrainrot()
        
        -- === PERIODIC TASKS (setiap 10 loops) ===
        if loopCount % 10 == 0 then
            autoUpgradeKick()
        end
        
        -- === WHEEL SPIN (setiap 60 loops) ===
        if loopCount % 60 == 0 then
            autoWheelSpin()
        end
        
        -- === WEIGHT (setiap 20 loops) ===
        if loopCount % 20 == 0 then
            autoWeight()
        end
        
        -- Loop delay
        task.wait(CONFIG.LOOP_DELAY)
    end
end

-- ═══════════════════════════════════════
-- HOOKUP: Remote Spy (intercept game communication)
-- ═══════════════════════════════════════
local function setupRemoteSpy()
    -- Hook __namecall untuk capture semua remote calls
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        
        if method == "FireServer" or method == "InvokeServer" then
            -- Log remote calls untuk reverse engineering
            -- print(string.format("[SPY] %s:%s(%s)", self:GetFullName(), method, table.concat({...}, ", ")))
        end
        
        return oldNamecall(self, ...)
    end)
    
    print("[AutoFarm] Remote spy hooked")
end

-- ═══════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════
local function init()
    print("╔══════════════════════════════════════╗")
    print("║  TENDANG BLOK KEBERUNTUNGAN         ║")
    print("║  AUTO FARM v1.0                      ║")
    print("╚══════════════════════════════════════╝")
    
    -- Wait for game to fully load
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
    task.wait(3)  -- Extra wait for modules to init
    
    -- Load modules
    loadServices()
    
    -- Setup anti-AFK
    setupAntiAFK()
    
    -- Setup remote spy (optional, uncomment untuk debug)
    -- pcall(setupRemoteSpy)
    
    -- Scan remotes (uncomment untuk debug)
    -- scanRemotes()
    
    -- Re-hook on respawn
    player.CharacterAdded:Connect(function(char)
        character = char
        humanoid = char:WaitForChild("Humanoid")
        rootPart = char:WaitForChild("HumanoidRootPart")
        task.wait(1)
        applySpeedHack()
    end)
    
    -- Start main loop
    task.spawn(mainLoop)
    
    print("[AutoFarm] Initialized! Running...")
    print("[AutoFarm] Config:", CONFIG)
end

-- ═══════════════════════════════════════
-- STOP COMMAND
-- ═══════════════════════════════════════
_G.StopAutoFarm = function()
    running = false
    print("[AutoFarm] Stopped!")
end

-- RUN
init()
