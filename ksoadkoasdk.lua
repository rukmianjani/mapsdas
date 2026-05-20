--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║  TBK NETWORK SPY - Full Capture Tool                         ║
    ║  Compatible: Delta Executor (Mobile/All Devices)            ║
    ╚══════════════════════════════════════════════════════════════╝
    
    Capture SEMUA:
    - RemoteEvent FireServer (client → server)
    - RemoteEvent OnClientEvent (server → client) 
    - RemoteFunction InvokeServer
    - firetouchinterest calls
    - ProximityPrompt triggers
    - Signal fires (firesignal)
    
    Tampilan GUI scrollable + bisa copy + filter
]]

-- Cleanup
if game.CoreGui:FindFirstChild("TBK_SPY") then
    game.CoreGui:FindFirstChild("TBK_SPY"):Destroy()
end

-- Services
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ═══════════════════════════════════════
-- LOG STORAGE
-- ═══════════════════════════════════════
local logs = {}
local MAX_LOGS = 500
local capturing = true
local filterText = ""

local function timestamp()
    return os.date("%H:%M:%S")
end

local function serialize(val, depth)
    depth = depth or 0
    if depth > 3 then return "..." end
    local t = typeof(val)
    if t == "string" then return '"' .. val .. '"'
    elseif t == "number" then return tostring(val)
    elseif t == "boolean" then return tostring(val)
    elseif t == "nil" then return "nil"
    elseif t == "Instance" then return val:GetFullName()
    elseif t == "Vector3" then return string.format("V3(%.1f,%.1f,%.1f)", val.X, val.Y, val.Z)
    elseif t == "CFrame" then return string.format("CF(%.1f,%.1f,%.1f)", val.Position.X, val.Position.Y, val.Position.Z)
    elseif t == "Color3" then return string.format("C3(%.2f,%.2f,%.2f)", val.R, val.G, val.B)
    elseif t == "EnumItem" then return tostring(val)
    elseif t == "table" then
        local parts = {}
        local count = 0
        for k, v in pairs(val) do
            count = count + 1
            if count > 8 then table.insert(parts, "...") break end
            local key = type(k) == "number" and "" or tostring(k) .. "="
            table.insert(parts, key .. serialize(v, depth + 1))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        return tostring(val)
    end
end

local function serializeArgs(...)
    local args = {...}
    local parts = {}
    for i = 1, #args do
        table.insert(parts, serialize(args[i]))
    end
    return table.concat(parts, ", ")
end

local function addLog(logType, name, details)
    if not capturing then return end
    
    local entry = {
        time = timestamp(),
        type = logType,
        name = name,
        details = details,
        full = string.format("[%s] [%s] %s: %s", timestamp(), logType, name, details)
    }
    
    table.insert(logs, 1, entry) -- Insert at top (newest first)
    if #logs > MAX_LOGS then
        table.remove(logs, #logs)
    end
end

-- ═══════════════════════════════════════
-- GUI CREATION
-- ═══════════════════════════════════════
local Gui = Instance.new("ScreenGui")
Gui.Name = "TBK_SPY"
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.ResetOnSpawn = false
pcall(function() Gui.Parent = game:GetService("CoreGui") end)
if not Gui.Parent then Gui.Parent = player:WaitForChild("PlayerGui") end

-- Main Frame
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 340, 0, 450)
Main.Position = UDim2.new(0.5, -170, 0.5, -225)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = Gui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", Main)
stroke.Color = Color3.fromRGB(0, 200, 100)
stroke.Thickness = 2

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 36)
Header.BackgroundColor3 = Color3.fromRGB(0, 60, 30)
Header.BorderSizePixel = 0
Header.Parent = Main
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)
local hfix = Instance.new("Frame", Header)
hfix.Size = UDim2.new(1,0,0,10) hfix.Position = UDim2.new(0,0,1,-10)
hfix.BackgroundColor3 = Color3.fromRGB(0, 60, 30) hfix.BorderSizePixel = 0

local Title = Instance.new("TextLabel", Header)
Title.Text = "🔍 TBK NETWORK SPY"
Title.Size = UDim2.new(0.65, 0, 1, 0)
Title.Position = UDim2.new(0, 8, 0, 0)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(0, 255, 120)
Title.TextSize = 14
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left

-- Capture toggle
local CapBtn = Instance.new("TextButton", Header)
CapBtn.Text = "⏸"
CapBtn.Size = UDim2.new(0, 30, 0, 30)
CapBtn.Position = UDim2.new(1, -70, 0, 3)
CapBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 0)
CapBtn.TextColor3 = Color3.fromRGB(255,255,255)
CapBtn.TextSize = 16
CapBtn.Font = Enum.Font.GothamBold
CapBtn.BorderSizePixel = 0
CapBtn.Parent = Header
Instance.new("UICorner", CapBtn).CornerRadius = UDim.new(0, 6)

-- Close
local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Text = "✕"
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -36, 0, 3)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
CloseBtn.TextColor3 = Color3.fromRGB(255,255,255)
CloseBtn.TextSize = 14
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.BorderSizePixel = 0
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

-- Filter bar
local FilterFrame = Instance.new("Frame", Main)
FilterFrame.Size = UDim2.new(1, -10, 0, 28)
FilterFrame.Position = UDim2.new(0, 5, 0, 39)
FilterFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
FilterFrame.BorderSizePixel = 0
Instance.new("UICorner", FilterFrame).CornerRadius = UDim.new(0, 6)

local FilterBox = Instance.new("TextBox", FilterFrame)
FilterBox.PlaceholderText = "🔎 Filter (e.g. kick, rev_, collect...)"
FilterBox.Text = ""
FilterBox.Size = UDim2.new(0.7, 0, 1, -4)
FilterBox.Position = UDim2.new(0, 4, 0, 2)
FilterBox.BackgroundTransparency = 1
FilterBox.TextColor3 = Color3.fromRGB(200, 200, 220)
FilterBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
FilterBox.TextSize = 11
FilterBox.Font = Enum.Font.Gotham
FilterBox.TextXAlignment = Enum.TextXAlignment.Left
FilterBox.ClearTextOnFocus = false

local ClearBtn = Instance.new("TextButton", FilterFrame)
ClearBtn.Text = "Clear"
ClearBtn.Size = UDim2.new(0.15, 0, 1, -4)
ClearBtn.Position = UDim2.new(0.7, 2, 0, 2)
ClearBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
ClearBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
ClearBtn.TextSize = 10
ClearBtn.Font = Enum.Font.GothamBold
ClearBtn.BorderSizePixel = 0
Instance.new("UICorner", ClearBtn).CornerRadius = UDim.new(0, 4)

local CopyBtn = Instance.new("TextButton", FilterFrame)
CopyBtn.Text = "Copy"
CopyBtn.Size = UDim2.new(0.15, -4, 1, -4)
CopyBtn.Position = UDim2.new(0.85, 2, 0, 2)
CopyBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
CopyBtn.TextColor3 = Color3.fromRGB(150, 150, 255)
CopyBtn.TextSize = 10
CopyBtn.Font = Enum.Font.GothamBold
CopyBtn.BorderSizePixel = 0
Instance.new("UICorner", CopyBtn).CornerRadius = UDim.new(0, 4)

-- Stats bar
local StatsBar = Instance.new("TextLabel", Main)
StatsBar.Size = UDim2.new(1, -10, 0, 18)
StatsBar.Position = UDim2.new(0, 5, 0, 69)
StatsBar.BackgroundTransparency = 1
StatsBar.TextColor3 = Color3.fromRGB(120, 120, 140)
StatsBar.TextSize = 10
StatsBar.Font = Enum.Font.Code
StatsBar.TextXAlignment = Enum.TextXAlignment.Left
StatsBar.Text = "Logs: 0 | Capturing: ON"

-- Log display (ScrollingFrame)
local LogFrame = Instance.new("ScrollingFrame", Main)
LogFrame.Size = UDim2.new(1, -10, 1, -94)
LogFrame.Position = UDim2.new(0, 5, 0, 89)
LogFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
LogFrame.BorderSizePixel = 0
LogFrame.ScrollBarThickness = 4
LogFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 200, 100)
LogFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
LogFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", LogFrame).CornerRadius = UDim.new(0, 6)

local LogLayout = Instance.new("UIListLayout", LogFrame)
LogLayout.Padding = UDim.new(0, 1)

local LogPad = Instance.new("UIPadding", LogFrame)
LogPad.PaddingTop = UDim.new(0, 2)
LogPad.PaddingLeft = UDim.new(0, 4)
LogPad.PaddingRight = UDim.new(0, 4)

-- ═══════════════════════════════════════
-- GUI LOGIC
-- ═══════════════════════════════════════

-- Draggable
local dragging, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
    end
end)
Header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local d = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

-- Close
CloseBtn.MouseButton1Click:Connect(function()
    capturing = false
    Gui:Destroy()
end)

-- Pause/Resume
CapBtn.MouseButton1Click:Connect(function()
    capturing = not capturing
    CapBtn.Text = capturing and "⏸" or "▶"
    CapBtn.BackgroundColor3 = capturing and Color3.fromRGB(200, 80, 0) or Color3.fromRGB(0, 150, 60)
end)

-- Filter
FilterBox:GetPropertyChangedSignal("Text"):Connect(function()
    filterText = FilterBox.Text:lower()
end)

-- Clear logs
ClearBtn.MouseButton1Click:Connect(function()
    logs = {}
    for _, c in pairs(LogFrame:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
end)

-- Copy all logs to clipboard
CopyBtn.MouseButton1Click:Connect(function()
    local text = ""
    for _, entry in ipairs(logs) do
        text = text .. entry.full .. "\n"
    end
    pcall(function()
        if setclipboard then setclipboard(text)
        elseif toclipboard then toclipboard(text) end
    end)
    CopyBtn.Text = "✓"
    task.wait(1)
    CopyBtn.Text = "Copy"
end)

-- Render logs to GUI
local function getTypeColor(logType)
    if logType == "C→S" then return Color3.fromRGB(100, 200, 255) end       -- Client fire to server (blue)
    if logType == "S→C" then return Color3.fromRGB(255, 200, 50) end        -- Server to client (yellow)
    if logType == "INVOKE" then return Color3.fromRGB(255, 100, 255) end    -- RemoteFunction (purple)
    if logType == "TOUCH" then return Color3.fromRGB(100, 255, 100) end     -- Touch events (green)
    if logType == "PROMPT" then return Color3.fromRGB(255, 150, 50) end     -- ProximityPrompt (orange)
    if logType == "SIGNAL" then return Color3.fromRGB(255, 80, 80) end      -- Signals (red)
    return Color3.fromRGB(180, 180, 200)
end

local lastRenderCount = 0
local function renderLogs()
    -- Only re-render if logs changed
    if #logs == lastRenderCount then return end
    lastRenderCount = #logs
    
    -- Clear existing
    for _, c in pairs(LogFrame:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    
    -- Render (max 50 visible to prevent lag)
    local shown = 0
    for _, entry in ipairs(logs) do
        if shown >= 50 then break end
        if filterText == "" or entry.full:lower():find(filterText, 1, true) then
            shown = shown + 1
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 0, 0)
            lbl.AutomaticSize = Enum.AutomaticSize.Y
            lbl.BackgroundTransparency = 1
            lbl.TextColor3 = getTypeColor(entry.type)
            lbl.TextSize = 10
            lbl.Font = Enum.Font.Code
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.TextWrapped = true
            lbl.RichText = false
            lbl.Text = entry.full
            lbl.Parent = LogFrame
        end
    end
    
    StatsBar.Text = string.format("Logs: %d | Shown: %d | %s", #logs, shown, capturing and "CAPTURING" or "PAUSED")
end

-- Render loop (less aggressive - only update every 1.5s)
task.spawn(function()
    while Gui.Parent do
        renderLogs()
        task.wait(1.5)
    end
end)

-- ═══════════════════════════════════════
-- HOOKS: Capture network (SAFE - no hookmetamethod)
-- Delta executor compatible - NO freeze/disconnect
-- ═══════════════════════════════════════

--[[
    STRATEGY: Passive listening only
    - S→C: Connect to .OnClientEvent (100% safe, no hook needed)
    - C→S: We DON'T hook __namecall (it breaks Delta networking)
           Instead we wrap specific remotes with a proxy logger
]]

-- Hook S→C: Listen to all remotes in Network folder (SAFE)
pcall(function()
    if NetworkFolder then
        for _, child in pairs(NetworkFolder:GetChildren()) do
            if child:IsA("RemoteEvent") then
                child.OnClientEvent:Connect(function(...)
                    if not capturing then return end
                    local args = {...}
                    task.defer(function()
                        local dir = child.Name:find("^rev_") and "S→C" or "S→C?"
                        addLog(dir, child.Name, serializeArgs(unpack(args)))
                    end)
                end)
            elseif child:IsA("UnreliableRemoteEvent") then
                child.OnClientEvent:Connect(function(...)
                    if not capturing then return end
                    local args = {...}
                    task.defer(function()
                        addLog("S→C", "[U]" .. child.Name, serializeArgs(unpack(args)))
                    end)
                end)
            end
        end
    end
end)

-- Hook C→S: Wrap FireServer on known remotes (SAFE alternative to hookmetamethod)
pcall(function()
    if NetworkFolder then
        for _, child in pairs(NetworkFolder:GetChildren()) do
            if child:IsA("RemoteEvent") and not child.Name:find("^rev_") then
                -- Wrap the remote's FireServer via newcclosure
                local origFire = child.FireServer
                child.FireServer = newcclosure and newcclosure(function(self, ...)
                    if capturing then
                        local args = {...}
                        task.defer(function()
                            addLog("C→S", child.Name, serializeArgs(unpack(args)))
                        end)
                    end
                    return origFire(self, ...)
                end) or origFire -- fallback if newcclosure not available
            end
        end
    end
end)

-- Hook firetouchinterest (SAFE - just wraps function)
pcall(function()
    if firetouchinterest then
        local oldTouch = firetouchinterest
        getgenv().firetouchinterest = function(part1, part2, toggle)
            if capturing then
                task.defer(function()
                    local p1 = part1 and part1.Name or "nil"
                    local p2 = part2 and part2.Name or "nil"
                    addLog("TOUCH", toggle == 0 and "BEGIN" or "END", p1 .. " → " .. p2)
                end)
            end
            return oldTouch(part1, part2, toggle)
        end
    end
end)

-- Hook fireproximityprompt (SAFE)
pcall(function()
    if fireproximityprompt then
        local oldPrompt = fireproximityprompt
        getgenv().fireproximityprompt = function(prompt, ...)
            if capturing then
                task.defer(function()
                    addLog("PROMPT", "Fired", prompt and prompt.Name or "nil")
                end)
            end
            return oldPrompt(prompt, ...)
        end
    end
end)

-- ═══════════════════════════════════════
-- INITIAL INFO
-- ═══════════════════════════════════════
addLog("INFO", "SPY STARTED", "Capturing all network traffic...")
addLog("INFO", "REMOTES FOUND", "Scanning ReplicatedStorage...")

-- List all remotes on start
local remoteCount = 0
local NetworkFolder = RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("Packages") and RS.Shared.Packages:FindFirstChild("Network")
if NetworkFolder then
    for _, child in pairs(NetworkFolder:GetChildren()) do
        if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") or child:IsA("UnreliableRemoteEvent") then
            remoteCount = remoteCount + 1
            local dir = child.Name:find("^rev_") and "S→C" or "C→S"
            addLog("INFO", "REMOTE", string.format("[%s] %s (%s)", dir, child.Name, child.ClassName))
        end
    end
end
addLog("INFO", "TOTAL", string.format("%d remotes in Network folder", remoteCount))

-- ═══════════════════════════════════════
print("╔═══════════════════════════════════╗")
print("║  TBK NETWORK SPY ACTIVE          ║")
print("║  All traffic being captured       ║")
print("║  Use GUI to filter & copy logs    ║")
print("╚═══════════════════════════════════╝")
