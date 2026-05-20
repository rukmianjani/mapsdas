--[[
    GITHUB SCRIPT LOADER - Delta Executor Compatible
    =================================================
    Paste link GitHub (raw) → Klik Execute → Script jalan otomatis
    
    Supported links:
    - https://raw.githubusercontent.com/user/repo/branch/file.lua
    - https://github.com/user/repo/blob/main/file.lua (auto-convert to raw)
    - https://gist.githubusercontent.com/...
    - Pastebin, hastebin, etc.
    
    Compatible: Delta, Fluxus, Arceus X, Hydrogen, Synapse
]]

-- ============================================
-- SERVICES
-- ============================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- ============================================
-- UTILITIES
-- ============================================
local function ConvertToRaw(url)
    -- Convert github.com blob URL to raw
    -- https://github.com/user/repo/blob/main/file.lua → https://raw.githubusercontent.com/user/repo/main/file.lua
    if url:find("github%.com") and url:find("/blob/") then
        url = url:gsub("github%.com", "raw.githubusercontent.com")
        url = url:gsub("/blob/", "/")
    end
    
    -- Convert gist URL to raw
    if url:find("gist%.github%.com") and not url:find("gist%.githubusercontent") then
        url = url:gsub("gist%.github%.com", "gist.githubusercontent.com")
        if not url:find("/raw") then
            url = url .. "/raw"
        end
    end
    
    -- Convert pastebin to raw
    if url:find("pastebin%.com") and not url:find("/raw/") then
        url = url:gsub("pastebin%.com/", "pastebin.com/raw/")
    end
    
    -- Remove trailing whitespace/newlines
    url = url:gsub("%s+$", ""):gsub("^%s+", "")
    
    return url
end

local function FetchScript(url)
    local rawUrl = ConvertToRaw(url)
    
    -- Try game:HttpGet first (most executors support this)
    local success, result = pcall(function()
        return game:HttpGet(rawUrl)
    end)
    
    if success and result and #result > 0 then
        return true, result, rawUrl
    end
    
    -- Try HttpService
    success, result = pcall(function()
        return HttpService:GetAsync(rawUrl)
    end)
    
    if success and result and #result > 0 then
        return true, result, rawUrl
    end
    
    -- Try request/http_request
    if request or http_request or syn then
        local reqFunc = request or http_request or (syn and syn.request)
        if reqFunc then
            success, result = pcall(function()
                local resp = reqFunc({Url = rawUrl, Method = "GET"})
                return resp.Body
            end)
            if success and result and #result > 0 then
                return true, result, rawUrl
            end
        end
    end
    
    return false, "Failed to fetch: " .. rawUrl, rawUrl
end

local function ExecuteScript(source)
    local fn, err = loadstring(source)
    if fn then
        local success, execErr = pcall(fn)
        if success then
            return true, "Executed successfully!"
        else
            return false, "Runtime error: " .. tostring(execErr)
        end
    else
        return false, "Compile error: " .. tostring(err)
    end
end

-- ============================================
-- HISTORY
-- ============================================
local history = {}
local MAX_HISTORY = 20

local function AddHistory(url, status)
    table.insert(history, 1, {
        url = url,
        status = status,
        time = os.date("%H:%M:%S")
    })
    if #history > MAX_HISTORY then
        table.remove(history, #history)
    end
end

-- ============================================
-- GUI
-- ============================================
local function CreateGUI()
    -- Destroy existing
    pcall(function()
        (game:GetService("CoreGui"):FindFirstChild("GHLoaderGUI") or LocalPlayer.PlayerGui:FindFirstChild("GHLoaderGUI")):Destroy()
    end)
    
    local Gui = Instance.new("ScreenGui")
    Gui.Name = "GHLoaderGUI"
    Gui.ResetOnSpawn = false
    Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Main Frame
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Size = UDim2.new(0.92, 0, 0.6, 0)
    Main.Position = UDim2.new(0.04, 0, 0.2, 0)
    Main.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
    Main.BorderSizePixel = 0
    Main.Parent = Gui
    
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)
    local mainStroke = Instance.new("UIStroke", Main)
    mainStroke.Color = Color3.fromRGB(0, 180, 255)
    mainStroke.Thickness = 2
    
    -- Title Bar
    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 44)
    TitleBar.BackgroundColor3 = Color3.fromRGB(12, 12, 22)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = Main
    Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 14)
    
    local TitleFix = Instance.new("Frame")
    TitleFix.Size = UDim2.new(1, 0, 0, 14)
    TitleFix.Position = UDim2.new(0, 0, 1, -14)
    TitleFix.BackgroundColor3 = Color3.fromRGB(12, 12, 22)
    TitleFix.BorderSizePixel = 0
    TitleFix.Parent = TitleBar
    
    local TitleText = Instance.new("TextLabel")
    TitleText.Text = "⚡ GITHUB SCRIPT LOADER"
    TitleText.Size = UDim2.new(0.7, 0, 1, 0)
    TitleText.Position = UDim2.new(0.04, 0, 0, 0)
    TitleText.BackgroundTransparency = 1
    TitleText.TextColor3 = Color3.fromRGB(100, 200, 255)
    TitleText.TextSize = 15
    TitleText.Font = Enum.Font.GothamBold
    TitleText.TextXAlignment = Enum.TextXAlignment.Left
    TitleText.Parent = TitleBar
    
    -- Minimize
    local MinBtn = Instance.new("TextButton")
    MinBtn.Text = "—"
    MinBtn.Size = UDim2.new(0, 36, 0, 36)
    MinBtn.Position = UDim2.new(1, -78, 0, 4)
    MinBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 40)
    MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinBtn.TextSize = 14
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.BorderSizePixel = 0
    MinBtn.Parent = TitleBar
    Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 8)
    
    -- Close
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Text = "✕"
    CloseBtn.Size = UDim2.new(0, 36, 0, 36)
    CloseBtn.Position = UDim2.new(1, -40, 0, 4)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.TextSize = 14
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Parent = TitleBar
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)
    
    -- Content
    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -16, 1, -52)
    Content.Position = UDim2.new(0, 8, 0, 48)
    Content.BackgroundTransparency = 1
    Content.Parent = Main
    
    -- URL Input Label
    local UrlLabel = Instance.new("TextLabel")
    UrlLabel.Text = "📎 Paste GitHub/Raw URL:"
    UrlLabel.Size = UDim2.new(1, 0, 0, 20)
    UrlLabel.Position = UDim2.new(0, 0, 0, 0)
    UrlLabel.BackgroundTransparency = 1
    UrlLabel.TextColor3 = Color3.fromRGB(180, 180, 210)
    UrlLabel.TextSize = 11
    UrlLabel.Font = Enum.Font.Gotham
    UrlLabel.TextXAlignment = Enum.TextXAlignment.Left
    UrlLabel.Parent = Content
    
    -- URL Input Box
    local UrlBox = Instance.new("TextBox")
    UrlBox.Name = "UrlInput"
    UrlBox.Size = UDim2.new(1, 0, 0, 42)
    UrlBox.Position = UDim2.new(0, 0, 0, 22)
    UrlBox.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    UrlBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    UrlBox.PlaceholderText = "https://raw.githubusercontent.com/user/repo/main/script.lua"
    UrlBox.PlaceholderColor3 = Color3.fromRGB(80, 80, 100)
    UrlBox.Text = ""
    UrlBox.TextSize = 11
    UrlBox.Font = Enum.Font.Code
    UrlBox.TextXAlignment = Enum.TextXAlignment.Left
    UrlBox.ClearTextOnFocus = false
    UrlBox.MultiLine = false
    UrlBox.BorderSizePixel = 0
    UrlBox.Parent = Content
    Instance.new("UICorner", UrlBox).CornerRadius = UDim.new(0, 8)
    local urlStroke = Instance.new("UIStroke", UrlBox)
    urlStroke.Color = Color3.fromRGB(60, 60, 100)
    urlStroke.Thickness = 1
    local urlPad = Instance.new("UIPadding", UrlBox)
    urlPad.PaddingLeft = UDim.new(0, 8)
    urlPad.PaddingRight = UDim.new(0, 8)
    
    -- Button Row
    local BtnRow = Instance.new("Frame")
    BtnRow.Size = UDim2.new(1, 0, 0, 44)
    BtnRow.Position = UDim2.new(0, 0, 0, 70)
    BtnRow.BackgroundTransparency = 1
    BtnRow.Parent = Content
    
    -- Execute Button
    local ExecBtn = Instance.new("TextButton")
    ExecBtn.Text = "▶ EXECUTE"
    ExecBtn.Size = UDim2.new(0.48, 0, 1, 0)
    ExecBtn.Position = UDim2.new(0, 0, 0, 0)
    ExecBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 80)
    ExecBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ExecBtn.TextSize = 14
    ExecBtn.Font = Enum.Font.GothamBold
    ExecBtn.BorderSizePixel = 0
    ExecBtn.Parent = BtnRow
    Instance.new("UICorner", ExecBtn).CornerRadius = UDim.new(0, 10)
    
    -- Clear Button
    local ClearBtn = Instance.new("TextButton")
    ClearBtn.Text = "🗑 CLEAR"
    ClearBtn.Size = UDim2.new(0.24, 0, 1, 0)
    ClearBtn.Position = UDim2.new(0.5, 0, 0, 0)
    ClearBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
    ClearBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ClearBtn.TextSize = 12
    ClearBtn.Font = Enum.Font.GothamBold
    ClearBtn.BorderSizePixel = 0
    ClearBtn.Parent = BtnRow
    Instance.new("UICorner", ClearBtn).CornerRadius = UDim.new(0, 10)
    
    -- Save Button (save fetched script to workspace)
    local SaveBtn = Instance.new("TextButton")
    SaveBtn.Text = "💾 SAVE"
    SaveBtn.Size = UDim2.new(0.24, 0, 1, 0)
    SaveBtn.Position = UDim2.new(0.76, 0, 0, 0)
    SaveBtn.BackgroundColor3 = Color3.fromRGB(50, 80, 150)
    SaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    SaveBtn.TextSize = 12
    SaveBtn.Font = Enum.Font.GothamBold
    SaveBtn.BorderSizePixel = 0
    SaveBtn.Parent = BtnRow
    Instance.new("UICorner", SaveBtn).CornerRadius = UDim.new(0, 10)
    
    -- Status
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Text = "⏸ Ready"
    StatusLabel.Size = UDim2.new(1, 0, 0, 24)
    StatusLabel.Position = UDim2.new(0, 0, 0, 118)
    StatusLabel.BackgroundColor3 = Color3.fromRGB(20, 30, 20)
    StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    StatusLabel.TextSize = 11
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.TextWrapped = true
    StatusLabel.BorderSizePixel = 0
    StatusLabel.Parent = Content
    Instance.new("UICorner", StatusLabel).CornerRadius = UDim.new(0, 6)
    
    -- Quick Links Section
    local QuickLabel = Instance.new("TextLabel")
    QuickLabel.Text = "⚡ Quick Buttons (tap to load):"
    QuickLabel.Size = UDim2.new(1, 0, 0, 18)
    QuickLabel.Position = UDim2.new(0, 0, 0, 148)
    QuickLabel.BackgroundTransparency = 1
    QuickLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
    QuickLabel.TextSize = 10
    QuickLabel.Font = Enum.Font.Gotham
    QuickLabel.TextXAlignment = Enum.TextXAlignment.Left
    QuickLabel.Parent = Content
    
    -- Quick Slots (saveable favorites)
    local quickSlots = {}
    local SLOT_FILE = "GHLoader_slots.txt"
    
    -- Load saved slots
    pcall(function()
        if isfile(SLOT_FILE) then
            local data = readfile(SLOT_FILE)
            for line in data:gmatch("[^\n]+") do
                table.insert(quickSlots, line)
            end
        end
    end)
    
    local QuickFrame = Instance.new("ScrollingFrame")
    QuickFrame.Size = UDim2.new(1, 0, 0, 60)
    QuickFrame.Position = UDim2.new(0, 0, 0, 168)
    QuickFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 35)
    QuickFrame.BorderSizePixel = 0
    QuickFrame.ScrollBarThickness = 3
    QuickFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    QuickFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    QuickFrame.Parent = Content
    Instance.new("UICorner", QuickFrame).CornerRadius = UDim.new(0, 6)
    
    local QuickLayout = Instance.new("UIListLayout")
    QuickLayout.Padding = UDim.new(0, 3)
    QuickLayout.SortOrder = Enum.SortOrder.LayoutOrder
    QuickLayout.Parent = QuickFrame
    
    local function RefreshSlots()
        for _, child in ipairs(QuickFrame:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        for i, url in ipairs(quickSlots) do
            local slotBtn = Instance.new("TextButton")
            slotBtn.Text = "  " .. i .. ". " .. url:sub(1, 50) .. (url:len() > 50 and "..." or "")
            slotBtn.Size = UDim2.new(1, -6, 0, 22)
            slotBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
            slotBtn.TextColor3 = Color3.fromRGB(180, 220, 255)
            slotBtn.TextSize = 9
            slotBtn.Font = Enum.Font.Code
            slotBtn.TextXAlignment = Enum.TextXAlignment.Left
            slotBtn.BorderSizePixel = 0
            slotBtn.LayoutOrder = i
            slotBtn.Parent = QuickFrame
            Instance.new("UICorner", slotBtn).CornerRadius = UDim.new(0, 4)
            
            slotBtn.MouseButton1Click:Connect(function()
                UrlBox.Text = url
            end)
        end
        QuickFrame.CanvasSize = UDim2.new(0, 0, 0, #quickSlots * 25)
    end
    
    RefreshSlots()
    
    -- Log / Output Box
    local LogLabel = Instance.new("TextLabel")
    LogLabel.Text = "📋 Output Log:"
    LogLabel.Size = UDim2.new(1, 0, 0, 16)
    LogLabel.Position = UDim2.new(0, 0, 0, 234)
    LogLabel.BackgroundTransparency = 1
    LogLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
    LogLabel.TextSize = 10
    LogLabel.Font = Enum.Font.Gotham
    LogLabel.TextXAlignment = Enum.TextXAlignment.Left
    LogLabel.Parent = Content
    
    local LogBox = Instance.new("ScrollingFrame")
    LogBox.Size = UDim2.new(1, 0, 1, -254)
    LogBox.Position = UDim2.new(0, 0, 0, 252)
    LogBox.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
    LogBox.BorderSizePixel = 0
    LogBox.ScrollBarThickness = 3
    LogBox.ScrollBarImageColor3 = Color3.fromRGB(0, 180, 255)
    LogBox.CanvasSize = UDim2.new(0, 0, 0, 0)
    LogBox.Parent = Content
    Instance.new("UICorner", LogBox).CornerRadius = UDim.new(0, 6)
    
    local LogText = Instance.new("TextLabel")
    LogText.Text = ""
    LogText.Size = UDim2.new(1, -8, 1, 0)
    LogText.Position = UDim2.new(0, 4, 0, 0)
    LogText.BackgroundTransparency = 1
    LogText.TextColor3 = Color3.fromRGB(130, 255, 180)
    LogText.TextSize = 9
    LogText.Font = Enum.Font.Code
    LogText.TextWrapped = true
    LogText.TextXAlignment = Enum.TextXAlignment.Left
    LogText.TextYAlignment = Enum.TextYAlignment.Top
    LogText.Parent = LogBox
    
    local function AppendLog(msg)
        local timestamp = os.date("[%H:%M:%S] ")
        LogText.Text = timestamp .. msg .. "\n" .. LogText.Text
        if #LogText.Text > 5000 then
            LogText.Text = LogText.Text:sub(1, 5000)
        end
        LogBox.CanvasSize = UDim2.new(0, 0, 0, LogText.TextBounds.Y + 10)
    end
    
    -- ===== DRAGGING =====
    local dragging, dragStart, startPos = false, nil, nil
    
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
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
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    -- ===== HANDLERS =====
    local lastFetchedSource = nil
    
    CloseBtn.MouseButton1Click:Connect(function() Gui:Destroy() end)
    
    local minimized = false
    MinBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        Content.Visible = not minimized
        Main.Size = minimized and UDim2.new(0.92, 0, 0, 44) or UDim2.new(0.92, 0, 0.6, 0)
        MinBtn.Text = minimized and "□" or "—"
    end)
    
    ClearBtn.MouseButton1Click:Connect(function()
        UrlBox.Text = ""
        StatusLabel.Text = "⏸ Ready"
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    end)
    
    -- EXECUTE
    ExecBtn.MouseButton1Click:Connect(function()
        local url = UrlBox.Text:gsub("%s+", "")
        
        if url == "" then
            StatusLabel.Text = "❌ URL kosong! Paste link dulu"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        
        -- Validate URL
        if not (url:find("http") or url:find("://")) then
            StatusLabel.Text = "❌ URL tidak valid!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        
        ExecBtn.Text = "⏳ LOADING..."
        ExecBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 40)
        StatusLabel.Text = "🔄 Fetching script..."
        StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
        AppendLog("Fetching: " .. url)
        
        task.spawn(function()
            -- Fetch
            local success, source, rawUrl = FetchScript(url)
            
            if not success then
                StatusLabel.Text = "❌ " .. tostring(source)
                StatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
                AppendLog("FETCH FAILED: " .. tostring(source))
                ExecBtn.Text = "▶ EXECUTE"
                ExecBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 80)
                return
            end
            
            lastFetchedSource = source
            AppendLog("Fetched " .. #source .. " bytes from: " .. rawUrl)
            StatusLabel.Text = "🔄 Executing (" .. #source .. " bytes)..."
            
            -- Execute
            local execOk, execMsg = ExecuteScript(source)
            
            if execOk then
                StatusLabel.Text = "✅ " .. execMsg
                StatusLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
                AppendLog("SUCCESS: Script executed!")
                AddHistory(url, "✅")
            else
                StatusLabel.Text = "❌ " .. execMsg:sub(1, 80)
                StatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
                AppendLog("ERROR: " .. execMsg)
                AddHistory(url, "❌")
            end
            
            ExecBtn.Text = "▶ EXECUTE"
            ExecBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 80)
        end)
    end)
    
    -- SAVE (save to quick slots + workspace file)
    SaveBtn.MouseButton1Click:Connect(function()
        local url = UrlBox.Text:gsub("%s+", "")
        
        if url == "" then
            StatusLabel.Text = "❌ URL kosong!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        
        -- Add to quick slots if not exists
        local exists = false
        for _, v in ipairs(quickSlots) do
            if v == url then exists = true break end
        end
        
        if not exists then
            table.insert(quickSlots, url)
            -- Save to file
            pcall(function()
                writefile(SLOT_FILE, table.concat(quickSlots, "\n"))
            end)
            RefreshSlots()
            AppendLog("Saved to quick slots: " .. url)
        end
        
        -- Also save the fetched script if available
        if lastFetchedSource then
            local filename = url:match("([^/]+)$") or "script"
            filename = filename:gsub("[%?#].*", ""):gsub("[^%w%._%-]", "_")
            if not filename:find("%.lua$") then
                filename = filename .. ".lua"
            end
            
            pcall(function()
                if not isfolder("GHLoader_saved") then
                    makefolder("GHLoader_saved")
                end
                writefile("GHLoader_saved/" .. filename, lastFetchedSource)
                AppendLog("Script saved to: workspace/GHLoader_saved/" .. filename)
            end)
        end
        
        StatusLabel.Text = "✅ Saved!"
        StatusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
        task.delay(2, function()
            StatusLabel.Text = "⏸ Ready"
            StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        end)
    end)
    
    -- Execute on Enter key
    UrlBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            ExecBtn.MouseButton1Click:Fire()
        end
    end)
    
    -- Parent GUI
    local ok = pcall(function() Gui.Parent = game:GetService("CoreGui") end)
    if not ok then Gui.Parent = LocalPlayer.PlayerGui end
    
    AppendLog("GitHub Loader ready!")
    AppendLog("Paste any GitHub URL and tap Execute")
    
    return Gui
end

-- ============================================
-- RUN
-- ============================================
CreateGUI()
