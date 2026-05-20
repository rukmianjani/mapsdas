--[[
    ULTIMATE MAP DUMPER v3.0 - Delta Executor Compatible
    ====================================================
    AMBIL SEMUA tanpa pengecualian:
    - Semua Script (LocalScript, Script, ModuleScript)
    - Semua Model, Part, MeshPart, Union
    - Semua Sound, Animation, Particle
    - Semua GUI (ScreenGui, BillboardGui, SurfaceGui)
    - Semua Lighting effects
    - Semua Terrain data
    - Semua Asset IDs (Texture, Decal, Sound, Mesh, Animation)
    - Semua Value objects (StringValue, IntValue, etc)
    - Semua Folders & struktur lengkap
    - TANPA FILTER - semua diambil termasuk nama random/acak
    
    Compatible: Delta, Fluxus, Arceus X, Hydrogen, Synapse
    Output: workspace/MapRip/[GameName]/
]]

-- ============================================
-- SERVICES
-- ============================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local StarterPack = game:GetService("StarterPack")
local StarterPlayer = game:GetService("StarterPlayer")
local SoundService = game:GetService("SoundService")
local Teams = game:GetService("Teams")
local ServerStorage = game:GetService("ServerStorage")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

-- ============================================
-- STATE
-- ============================================
local DUMP_RUNNING = false
local totalInstances = 0
local totalScripts = 0
local totalAssets = 0
local totalFiles = 0
local statusLabel, progressLabel, logBox

-- ============================================
-- UTILITIES
-- ============================================
local function SafeName(name)
    if not name or name == "" then return "unnamed" end
    return name:gsub("[%\\/:*?\"<>|%z%c]", "_"):gsub("%.%.", "_"):sub(1, 80)
end

local function GetGameInfo()
    local id = game.PlaceId
    local name = "Unknown"
    pcall(function()
        name = game:GetService("MarketplaceService"):GetProductInfo(id).Name
    end)
    return SafeName(name), id
end

local function MakeFolder(path)
    local parts = path:split("/")
    local current = ""
    for i, part in ipairs(parts) do
        current = (i == 1) and part or (current .. "/" .. part)
        if not isfolder(current) then
            makefolder(current)
        end
    end
end

local function SafeWrite(path, content)
    local ok, err = pcall(function()
        writefile(path, content or "")
    end)
    if ok then
        totalFiles = totalFiles + 1
        return true
    end
    return false
end

local function Log(msg)
    print("[MapRip] " .. msg)
    if logBox then
        logBox.Text = msg .. "\n" .. logBox.Text
        if #logBox.Text > 8000 then
            logBox.Text = logBox.Text:sub(1, 8000)
        end
    end
end

local function UpdateStatus(t)
    if statusLabel then statusLabel.Text = t end
end

local function UpdateProgress()
    if progressLabel then
        progressLabel.Text = string.format("Instances: %d | Scripts: %d | Assets: %d | Files: %d", 
            totalInstances, totalScripts, totalAssets, totalFiles)
    end
end

-- ============================================
-- DECOMPILER
-- ============================================
local function DecompileScript(scr)
    local src = nil
    -- Try direct source access
    pcall(function() src = scr.Source end)
    if src and src ~= "" then return src end
    
    -- Try decompile
    if decompile then
        local ok, result = pcall(decompile, scr)
        if ok and result then return result end
    end
    
    -- Try getscriptbytecode
    if getscriptbytecode then
        local ok, result = pcall(getscriptbytecode, scr)
        if ok and result then return "-- [Bytecode]\n" .. result end
    end
    
    return "-- [Cannot decompile: " .. scr:GetFullName() .. "]"
end

-- ============================================
-- PROPERTY SERIALIZER - AMBIL SEMUA PROPERTIES
-- ============================================
local function SerializeValue(val)
    local t = typeof(val)
    if t == "string" then return '"' .. val:gsub('"', '\\"'):sub(1, 500) .. '"'
    elseif t == "number" or t == "boolean" then return tostring(val)
    elseif t == "Vector3" then return string.format("Vector3.new(%s, %s, %s)", val.X, val.Y, val.Z)
    elseif t == "Vector2" then return string.format("Vector2.new(%s, %s)", val.X, val.Y)
    elseif t == "CFrame" then 
        local c = {val:GetComponents()}
        return "CFrame.new(" .. table.concat(c, ", "):sub(1, 200) .. ")"
    elseif t == "Color3" then return string.format("Color3.new(%s, %s, %s)", val.R, val.G, val.B)
    elseif t == "BrickColor" then return "BrickColor.new(\"" .. tostring(val) .. "\")"
    elseif t == "UDim2" then return string.format("UDim2.new(%s, %s, %s, %s)", val.X.Scale, val.X.Offset, val.Y.Scale, val.Y.Offset)
    elseif t == "UDim" then return string.format("UDim.new(%s, %s)", val.Scale, val.Offset)
    elseif t == "Rect" then return string.format("Rect.new(%s, %s, %s, %s)", val.Min.X, val.Min.Y, val.Max.X, val.Max.Y)
    elseif t == "NumberRange" then return string.format("NumberRange.new(%s, %s)", val.Min, val.Max)
    elseif t == "NumberSequence" then return "NumberSequence(...)"
    elseif t == "ColorSequence" then return "ColorSequence(...)"
    elseif t == "EnumItem" then return tostring(val)
    elseif t == "Instance" then return val:GetFullName()
    elseif t == "Ray" then return "Ray.new(...)"
    else return tostring(val)
    end
end

local ALL_PROPERTIES = {
    -- Transform
    "Position", "Size", "CFrame", "Rotation", "Orientation",
    "Anchored", "CanCollide", "CanTouch", "CanQuery", "Massless",
    -- Appearance
    "Color", "BrickColor", "Material", "MaterialVariant", "Reflectance",
    "Transparency", "CastShadow", "Color3",
    -- Mesh
    "MeshId", "MeshType", "TextureID", "TextureId", "Offset", "Scale", "VertexColor",
    -- Decal/Texture
    "Texture", "Face", "StudsPerTileU", "StudsPerTileV",
    "Image", "ImageColor3", "ImageTransparency", "ScaleType", "SliceCenter",
    -- Sound
    "SoundId", "Volume", "PlaybackSpeed", "Looped", "Playing", "TimePosition",
    "RollOffMode", "RollOffMinDistance", "RollOffMaxDistance",
    -- Animation
    "AnimationId", "Priority", "Speed",
    -- Particle
    "Rate", "Lifetime", "Speed", "SpreadAngle", "RotSpeed",
    "LightEmission", "LightInfluence", "Drag", "VelocityInheritance",
    "Acceleration", "EmissionDirection", "Enabled",
    -- Light
    "Brightness", "Range", "Shadows", "Angle",
    -- GUI
    "Text", "TextColor3", "TextSize", "TextTransparency", "TextWrapped",
    "Font", "RichText", "TextScaled", "TextXAlignment", "TextYAlignment",
    "BackgroundColor3", "BackgroundTransparency", "BorderSizePixel", "BorderColor3",
    "Visible", "Active", "ZIndex", "LayoutOrder", "AnchorPoint",
    "AutomaticSize", "ClipsDescendants", "SizeConstraint",
    -- Value objects
    "Value",
    -- Beam/Trail
    "Attachment0", "Attachment1", "Width0", "Width1", "FaceCamera",
    "TextureMode", "TextureLength", "TextureSpeed",
    -- Constraint
    "MaxForce", "MaxTorque", "Responsiveness", "Stiffness", "Damping",
    -- Humanoid
    "MaxHealth", "Health", "WalkSpeed", "JumpPower", "JumpHeight",
    "HipHeight", "AutoRotate", "DisplayDistanceType", "HealthDisplayDistance",
    "NameDisplayDistance", "DisplayName",
    -- Misc
    "Name", "ClassName", "Archivable", "Parent",
    "Shape", "TopSurface", "BottomSurface", "FrontSurface", "BackSurface",
    "LeftSurface", "RightSurface",
    "CollisionGroupId", "CustomPhysicalProperties",
    "AssemblyLinearVelocity", "AssemblyAngularVelocity",
    "FormFactor", "Locked",
    -- Terrain
    "WaterWaveSize", "WaterWaveSpeed", "WaterReflectance", "WaterTransparency", "WaterColor",
    -- Atmosphere/Sky
    "Density", "Glare", "Haze", "SunAngularSize", "SunTextureId",
    "MoonAngularSize", "MoonTextureId", "StarCount", "CelestialBodiesShown",
    "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp",
}

local function GetAllProperties(instance)
    local props = {}
    for _, propName in ipairs(ALL_PROPERTIES) do
        local ok, val = pcall(function() return instance[propName] end)
        if ok and val ~= nil then
            local serialized = SerializeValue(val)
            if serialized and serialized ~= "" and serialized ~= '""' then
                props[propName] = serialized
            end
        end
    end
    return props
end

-- ============================================
-- ASSET COLLECTOR - AMBIL SEMUA ASSET IDS
-- ============================================
local assetList = {}

local ASSET_PROPERTIES = {
    "MeshId", "TextureId", "TextureID", "SoundId", "AnimationId",
    "Image", "Texture", "SkyboxBk", "SkyboxDn", "SkyboxFt",
    "SkyboxLf", "SkyboxRt", "SkyboxUp", "SunTextureId", "MoonTextureId",
    "Face", "Decal",
}

local function CollectAssets(instance)
    for _, prop in ipairs(ASSET_PROPERTIES) do
        local ok, val = pcall(function() return instance[prop] end)
        if ok and val and type(val) == "string" and val:find("rbxasset") or (val and tostring(val):find("://")) then
            local id = tostring(val)
            if id ~= "" and not assetList[id] then
                assetList[id] = {
                    property = prop,
                    instance = instance:GetFullName(),
                    className = instance.ClassName
                }
                totalAssets = totalAssets + 1
            end
        end
    end
end

-- ============================================
-- MAIN DUMPER - TANPA BATASAN
-- ============================================
local function DumpEverything()
    if DUMP_RUNNING then
        Log("Already running!")
        return
    end
    DUMP_RUNNING = true
    
    -- Reset counters
    totalInstances = 0
    totalScripts = 0
    totalAssets = 0
    totalFiles = 0
    assetList = {}
    
    local gameName, gameId = GetGameInfo()
    local ROOT = "MapRip/" .. gameName .. "_" .. gameId
    
    Log("=== STARTING FULL MAP RIP ===")
    Log("Game: " .. gameName .. " (ID: " .. gameId .. ")")
    UpdateStatus("Initializing...")
    
    -- Create folder structure
    MakeFolder(ROOT)
    MakeFolder(ROOT .. "/Scripts/LocalScripts")
    MakeFolder(ROOT .. "/Scripts/ServerScripts")
    MakeFolder(ROOT .. "/Scripts/ModuleScripts")
    MakeFolder(ROOT .. "/Hierarchy")
    MakeFolder(ROOT .. "/Properties")
    MakeFolder(ROOT .. "/Assets")
    MakeFolder(ROOT .. "/Models")
    MakeFolder(ROOT .. "/Sounds")
    MakeFolder(ROOT .. "/GUIs")
    MakeFolder(ROOT .. "/Values")
    MakeFolder(ROOT .. "/Animations")
    MakeFolder(ROOT .. "/Terrain")
    
    -- ALL containers to scan - TANPA PENGECUALIAN
    local SCAN_TARGETS = {}
    
    -- Add main services
    local services = {
        {Workspace, "Workspace"},
        {ReplicatedStorage, "ReplicatedStorage"},
        {ReplicatedFirst, "ReplicatedFirst"},
        {Lighting, "Lighting"},
        {StarterGui, "StarterGui"},
        {StarterPack, "StarterPack"},
        {StarterPlayer, "StarterPlayer"},
        {SoundService, "SoundService"},
        {Teams, "Teams"},
    }
    
    -- Try additional services that might be accessible
    pcall(function() table.insert(services, {game:GetService("Chat"), "Chat"}) end)
    pcall(function() table.insert(services, {game:GetService("LocalizationService"), "LocalizationService"}) end)
    pcall(function() table.insert(services, {game:GetService("TestService"), "TestService"}) end)
    pcall(function() table.insert(services, {game:GetService("ServerStorage"), "ServerStorage"}) end)
    pcall(function() table.insert(services, {game:GetService("ServerScriptService"), "ServerScriptService"}) end)
    
    -- Data storage
    local allScriptData = {}
    local allTreeLines = {}
    local allPropertiesData = {}
    local allSoundData = {}
    local allGuiData = {}
    local allValueData = {}
    local allAnimData = {}
    local allModelData = {}
    local scriptCounter = 0
    
    -- ========== RECURSIVE SCANNER ==========
    local function ScanRecursive(instance, path, depth, serviceName)
        if depth > 100 then return end -- safety limit only
        
        totalInstances = totalInstances + 1
        
        local name = SafeName(instance.Name)
        local className = instance.ClassName
        local fullPath = path .. "/" .. name
        local fullName = instance:GetFullName()
        
        -- Tree line
        local indent = string.rep("│ ", depth)
        local treeEntry = indent .. "├─ [" .. className .. "] " .. instance.Name
        table.insert(allTreeLines, treeEntry)
        
        -- Collect ALL assets from this instance
        CollectAssets(instance)
        
        -- ===== SCRIPTS - Ambil semua =====
        if instance:IsA("BaseScript") or instance:IsA("ModuleScript") then
            totalScripts = totalScripts + 1
            scriptCounter = scriptCounter + 1
            
            local source = DecompileScript(instance)
            local scriptType = "ServerScripts"
            local ext = ".server.lua"
            
            if instance:IsA("LocalScript") then
                scriptType = "LocalScripts"
                ext = ".client.lua"
            elseif instance:IsA("ModuleScript") then
                scriptType = "ModuleScripts"
                ext = ".module.lua"
            end
            
            local header = string.format(
                "-- =============================================\n" ..
                "-- Name: %s\n" ..
                "-- ClassName: %s\n" ..
                "-- FullPath: %s\n" ..
                "-- Parent: %s\n" ..
                "-- Service: %s\n" ..
                "-- =============================================\n\n",
                instance.Name, className, fullName,
                instance.Parent and instance.Parent:GetFullName() or "nil",
                serviceName
            )
            
            local scriptPath = ROOT .. "/Scripts/" .. scriptType .. "/" .. 
                string.format("%04d", scriptCounter) .. "_" .. name .. ext
            SafeWrite(scriptPath, header .. source)
            
            -- Also store for combined file
            table.insert(allScriptData, {
                name = instance.Name,
                class = className,
                path = fullName,
                service = serviceName,
                source = source
            })
            
            Log("Script #" .. scriptCounter .. ": " .. instance.Name)
        end
        
        -- ===== SOUNDS =====
        if instance:IsA("Sound") then
            local soundInfo = string.format("Name: %s\nPath: %s\nSoundId: %s\nVolume: %s\nLooped: %s\nPlaybackSpeed: %s\n",
                instance.Name, fullName,
                tostring(pcall(function() return instance.SoundId end) and instance.SoundId or "?"),
                tostring(pcall(function() return instance.Volume end) and instance.Volume or "?"),
                tostring(pcall(function() return instance.Looped end) and instance.Looped or "?"),
                tostring(pcall(function() return instance.PlaybackSpeed end) and instance.PlaybackSpeed or "?")
            )
            table.insert(allSoundData, soundInfo)
        end
        
        -- ===== GUI ELEMENTS =====
        if instance:IsA("GuiObject") or instance:IsA("ScreenGui") or instance:IsA("BillboardGui") or instance:IsA("SurfaceGui") then
            local guiInfo = string.format("[%s] %s\n  Path: %s\n", className, instance.Name, fullName)
            local props = GetAllProperties(instance)
            for k, v in pairs(props) do
                guiInfo = guiInfo .. "  " .. k .. " = " .. v .. "\n"
            end
            table.insert(allGuiData, guiInfo)
        end
        
        -- ===== VALUE OBJECTS =====
        if instance:IsA("ValueBase") then
            local valOk, valVal = pcall(function() return instance.Value end)
            local valueInfo = string.format("[%s] %s = %s\n  Path: %s\n",
                className, instance.Name,
                valOk and tostring(valVal) or "?",
                fullName
            )
            table.insert(allValueData, valueInfo)
        end
        
        -- ===== ANIMATIONS =====
        if instance:IsA("Animation") or instance:IsA("AnimationTrack") or className == "Animator" then
            local animId = ""
            pcall(function() animId = instance.AnimationId end)
            local animInfo = string.format("[%s] %s\n  Path: %s\n  AnimationId: %s\n",
                className, instance.Name, fullName, animId)
            table.insert(allAnimData, animInfo)
        end
        
        -- ===== MODELS (BasePart data) =====
        if instance:IsA("BasePart") then
            local props = GetAllProperties(instance)
            local modelInfo = string.format("[%s] %s\n  Path: %s\n", className, instance.Name, fullName)
            for k, v in pairs(props) do
                modelInfo = modelInfo .. "  " .. k .. " = " .. v .. "\n"
            end
            table.insert(allModelData, modelInfo)
        end
        
        -- ===== ALL PROPERTIES for everything =====
        local propsLine = string.format("\n=== [%s] %s ===\nPath: %s\n", className, instance.Name, fullName)
        local props = GetAllProperties(instance)
        for k, v in pairs(props) do
            propsLine = propsLine .. "  " .. k .. " = " .. v .. "\n"
        end
        table.insert(allPropertiesData, propsLine)
        
        -- Yield to prevent crash
        if totalInstances % 200 == 0 then
            task.wait()
            UpdateStatus("Scanning " .. serviceName .. "... (" .. totalInstances .. ")")
            UpdateProgress()
        end
        
        -- ===== SCAN ALL CHILDREN - TANPA PENGECUALIAN =====
        local children = {}
        pcall(function() children = instance:GetChildren() end)
        
        for _, child in ipairs(children) do
            -- Skip only current player character to avoid self-referencing issues
            local skip = false
            if child == LocalPlayer.Character then skip = true end
            if child:IsA("Camera") and child.Parent == Workspace then skip = true end
            
            if not skip then
                ScanRecursive(child, fullPath, depth + 1, serviceName)
            end
        end
    end
    
    -- ========== START SCANNING ALL SERVICES ==========
    for _, svc in ipairs(services) do
        local container, svcName = svc[1], svc[2]
        Log(">>> Scanning: " .. svcName)
        UpdateStatus("Scanning: " .. svcName)
        
        table.insert(allTreeLines, "\n" .. string.rep("=", 60))
        table.insert(allTreeLines, "SERVICE: " .. svcName)
        table.insert(allTreeLines, string.rep("=", 60))
        
        pcall(function()
            local children = container:GetChildren()
            for _, child in ipairs(children) do
                ScanRecursive(child, svcName, 1, svcName)
            end
        end)
    end
    
    -- ========== ALSO SCAN: game.Players (Backpacks, PlayerGui) ==========
    Log(">>> Scanning Player data...")
    UpdateStatus("Scanning Player data...")
    pcall(function()
        table.insert(allTreeLines, "\n" .. string.rep("=", 60))
        table.insert(allTreeLines, "PLAYER DATA: " .. LocalPlayer.Name)
        table.insert(allTreeLines, string.rep("=", 60))
        
        -- PlayerGui
        pcall(function()
            for _, child in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
                ScanRecursive(child, "PlayerGui", 1, "PlayerGui")
            end
        end)
        
        -- Backpack
        pcall(function()
            for _, child in ipairs(LocalPlayer.Backpack:GetChildren()) do
                ScanRecursive(child, "Backpack", 1, "Backpack")
            end
        end)
        
        -- PlayerScripts
        pcall(function()
            for _, child in ipairs(LocalPlayer.PlayerScripts:GetChildren()) do
                ScanRecursive(child, "PlayerScripts", 1, "PlayerScripts")
            end
        end)
    end)
    
    -- ========== SAVE ALL DATA ==========
    UpdateStatus("Saving all data...")
    Log("Saving files...")
    
    -- 1. Full hierarchy tree
    SafeWrite(ROOT .. "/Hierarchy/FULL_TREE.txt", table.concat(allTreeLines, "\n"))
    
    -- 2. All scripts combined
    local combinedScripts = "-- ALL SCRIPTS FROM MAP\n-- Game: " .. gameName .. "\n-- Total: " .. #allScriptData .. " scripts\n\n"
    for i, s in ipairs(allScriptData) do
        combinedScripts = combinedScripts .. string.format(
            "\n\n%s\n-- [%d/%d] %s (%s)\n-- Path: %s\n-- Service: %s\n%s\n",
            string.rep("=", 70), i, #allScriptData,
            s.name, s.class, s.path, s.service,
            string.rep("=", 70)
        ) .. s.source
        
        -- Write in chunks if too large
        if #combinedScripts > 500000 then
            local chunkNum = math.floor(i / 100)
            SafeWrite(ROOT .. "/Scripts/ALL_SCRIPTS_part" .. chunkNum .. ".lua", combinedScripts)
            combinedScripts = ""
        end
    end
    if combinedScripts ~= "" then
        SafeWrite(ROOT .. "/Scripts/ALL_SCRIPTS.lua", combinedScripts)
    end
    
    -- 3. Properties (chunked)
    local propsChunk = ""
    local propsChunkNum = 1
    for i, p in ipairs(allPropertiesData) do
        propsChunk = propsChunk .. p
        if #propsChunk > 300000 then
            SafeWrite(ROOT .. "/Properties/properties_" .. string.format("%03d", propsChunkNum) .. ".txt", propsChunk)
            propsChunk = ""
            propsChunkNum = propsChunkNum + 1
        end
    end
    if propsChunk ~= "" then
        SafeWrite(ROOT .. "/Properties/properties_" .. string.format("%03d", propsChunkNum) .. ".txt", propsChunk)
    end
    
    -- 4. Asset list
    local assetText = "ALL ASSET IDS FROM MAP\n" .. string.rep("=", 60) .. "\n\n"
    for id, info in pairs(assetList) do
        assetText = assetText .. string.format("Asset: %s\n  Property: %s\n  Instance: %s\n  Class: %s\n\n",
            id, info.property, info.instance, info.className)
    end
    SafeWrite(ROOT .. "/Assets/ALL_ASSETS.txt", assetText)
    
    -- 5. Sounds
    if #allSoundData > 0 then
        SafeWrite(ROOT .. "/Sounds/ALL_SOUNDS.txt", "ALL SOUNDS\n" .. string.rep("=", 40) .. "\n\n" .. table.concat(allSoundData, "\n" .. string.rep("-", 30) .. "\n"))
    end
    
    -- 6. GUIs
    if #allGuiData > 0 then
        local guiChunk = ""
        local guiChunkNum = 1
        for i, g in ipairs(allGuiData) do
            guiChunk = guiChunk .. g .. "\n"
            if #guiChunk > 300000 then
                SafeWrite(ROOT .. "/GUIs/gui_data_" .. guiChunkNum .. ".txt", guiChunk)
                guiChunk = ""
                guiChunkNum = guiChunkNum + 1
            end
        end
        if guiChunk ~= "" then
            SafeWrite(ROOT .. "/GUIs/gui_data_" .. guiChunkNum .. ".txt", guiChunk)
        end
    end
    
    -- 7. Values
    if #allValueData > 0 then
        SafeWrite(ROOT .. "/Values/ALL_VALUES.txt", "ALL VALUE OBJECTS\n" .. string.rep("=", 40) .. "\n\n" .. table.concat(allValueData, "\n"))
    end
    
    -- 8. Animations
    if #allAnimData > 0 then
        SafeWrite(ROOT .. "/Animations/ALL_ANIMATIONS.txt", "ALL ANIMATIONS\n" .. string.rep("=", 40) .. "\n\n" .. table.concat(allAnimData, "\n"))
    end
    
    -- 9. Models/Parts data (chunked)
    if #allModelData > 0 then
        local modelChunk = ""
        local modelChunkNum = 1
        for i, m in ipairs(allModelData) do
            modelChunk = modelChunk .. m .. "\n"
            if #modelChunk > 300000 then
                SafeWrite(ROOT .. "/Models/parts_" .. modelChunkNum .. ".txt", modelChunk)
                modelChunk = ""
                modelChunkNum = modelChunkNum + 1
            end
        end
        if modelChunk ~= "" then
            SafeWrite(ROOT .. "/Models/parts_" .. modelChunkNum .. ".txt", modelChunk)
        end
    end
    
    -- 10. Try saveinstance if available (exports full .rbxl)
    pcall(function()
        if saveinstance then
            UpdateStatus("Saving full instance (RBXL)...")
            Log("Attempting saveinstance...")
            saveinstance({
                FilePath = ROOT .. "/FULL_MAP.rbxlx",
                ExcludePlayerCharacter = true,
                ExcludePlayerGui = false,
                NilInstances = true,
                RemovePlayerCharacters = true,
            })
            Log("Full .rbxlx saved!")
        end
    end)
    
    -- 11. Summary
    local summary = string.format([[
================================================================
           ULTIMATE MAP RIP - COMPLETE SUMMARY
================================================================

Game Name     : %s
Place ID      : %d
Game ID       : %d
Date          : %s
Dumped By     : %s

================================================================
                        STATISTICS
================================================================

Total Instances Scanned  : %d
Total Scripts Found      : %d  
Total Unique Assets      : %d
Total Files Written      : %d

================================================================
                     OUTPUT STRUCTURE
================================================================

📁 %s/
├── 📁 Scripts/
│   ├── 📁 LocalScripts/     (client scripts .client.lua)
│   ├── 📁 ServerScripts/    (server scripts .server.lua)
│   ├── 📁 ModuleScripts/    (modules .module.lua)
│   └── 📄 ALL_SCRIPTS.lua   (semua script digabung 1 file)
├── 📁 Hierarchy/
│   └── 📄 FULL_TREE.txt     (complete game tree structure)
├── 📁 Properties/
│   └── 📄 properties_*.txt  (semua properties tiap instance)
├── 📁 Assets/
│   └── 📄 ALL_ASSETS.txt    (semua asset IDs: mesh, texture, sound, dll)
├── 📁 Models/
│   └── 📄 parts_*.txt       (semua BasePart data + positions)
├── 📁 Sounds/
│   └── 📄 ALL_SOUNDS.txt    (semua Sound objects + IDs)
├── 📁 GUIs/
│   └── 📄 gui_data_*.txt    (semua GUI elements + properties)
├── 📁 Values/
│   └── 📄 ALL_VALUES.txt    (semua ValueBase objects)
├── 📁 Animations/
│   └── 📄 ALL_ANIMATIONS.txt (semua Animation IDs)
├── 📁 Terrain/
│   └── (terrain data if available)
└── 📄 SUMMARY.txt           (this file)

================================================================
                     FILE LOCATIONS
================================================================

Delta Executor:
  /storage/emulated/0/Delta/workspace/%s/

Fluxus:
  /storage/emulated/0/Fluxus/workspace/%s/

Arceus X:
  /storage/emulated/0/ArceusX/workspace/%s/

Hydrogen:  
  /storage/emulated/0/Hydrogen/workspace/%s/

================================================================
                         NOTES
================================================================

- Semua file termasuk yang punya nama acak/random sudah diambil
- Script di-decompile otomatis (jika executor support)
- Tidak ada filter - SEMUA instance diambil tanpa pengecualian
- File besar di-split jadi beberapa chunk agar tidak crash

================================================================
]], 
    gameName, game.PlaceId, game.GameId, os.date("%Y-%m-%d %H:%M:%S"), LocalPlayer.Name,
    totalInstances, totalScripts, totalAssets, totalFiles,
    ROOT, ROOT, ROOT, ROOT, ROOT)
    
    SafeWrite(ROOT .. "/SUMMARY.txt", summary)
    
    -- Done!
    Log("=== RIP COMPLETE ===")
    Log("Total: " .. totalInstances .. " instances, " .. totalScripts .. " scripts, " .. totalFiles .. " files")
    UpdateStatus("✅ COMPLETE! " .. totalFiles .. " files saved!")
    UpdateProgress()
    
    DUMP_RUNNING = false
    return ROOT
end

-- ============================================
-- GUI - MOBILE COMPATIBLE (Touch + Drag)
-- ============================================
local function CreateGUI()
    pcall(function()
        (game:GetService("CoreGui"):FindFirstChild("MapRipGUI") or LocalPlayer.PlayerGui:FindFirstChild("MapRipGUI")):Destroy()
    end)
    
    local Gui = Instance.new("ScreenGui")
    Gui.Name = "MapRipGUI"
    Gui.ResetOnSpawn = false
    Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Main Frame
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Size = UDim2.new(0.92, 0, 0.75, 0)
    Main.Position = UDim2.new(0.04, 0, 0.12, 0)
    Main.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    Main.BorderSizePixel = 0
    Main.Parent = Gui
    
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)
    local stroke = Instance.new("UIStroke", Main)
    stroke.Color = Color3.fromRGB(130, 50, 255)
    stroke.Thickness = 2
    
    -- Title
    local Title = Instance.new("Frame")
    Title.Size = UDim2.new(1, 0, 0, 48)
    Title.BackgroundColor3 = Color3.fromRGB(25, 15, 50)
    Title.BorderSizePixel = 0
    Title.Parent = Main
    Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 14)
    
    local TitleFix = Instance.new("Frame")
    TitleFix.Size = UDim2.new(1, 0, 0, 14)
    TitleFix.Position = UDim2.new(0, 0, 1, -14)
    TitleFix.BackgroundColor3 = Color3.fromRGB(25, 15, 50)
    TitleFix.BorderSizePixel = 0
    TitleFix.Parent = Title
    
    local TitleText = Instance.new("TextLabel")
    TitleText.Text = "💀 ULTIMATE MAP RIPPER v3.0"
    TitleText.Size = UDim2.new(0.75, 0, 1, 0)
    TitleText.Position = UDim2.new(0.05, 0, 0, 0)
    TitleText.BackgroundTransparency = 1
    TitleText.TextColor3 = Color3.fromRGB(220, 150, 255)
    TitleText.TextSize = 16
    TitleText.Font = Enum.Font.GothamBold
    TitleText.TextXAlignment = Enum.TextXAlignment.Left
    TitleText.Parent = Title
    
    -- Minimize button
    local MinBtn = Instance.new("TextButton")
    MinBtn.Text = "—"
    MinBtn.Size = UDim2.new(0, 38, 0, 38)
    MinBtn.Position = UDim2.new(1, -82, 0, 5)
    MinBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 40)
    MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinBtn.TextSize = 16
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.BorderSizePixel = 0
    MinBtn.Parent = Title
    Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 8)
    
    -- Close button
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Text = "✕"
    CloseBtn.Size = UDim2.new(0, 38, 0, 38)
    CloseBtn.Position = UDim2.new(1, -42, 0, 5)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.TextSize = 16
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Parent = Title
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)
    
    -- Content
    local Content = Instance.new("ScrollingFrame")
    Content.Size = UDim2.new(1, -16, 1, -56)
    Content.Position = UDim2.new(0, 8, 0, 52)
    Content.BackgroundTransparency = 1
    Content.BorderSizePixel = 0
    Content.ScrollBarThickness = 4
    Content.ScrollBarImageColor3 = Color3.fromRGB(130, 50, 255)
    Content.CanvasSize = UDim2.new(0, 0, 0, 850)
    Content.Parent = Main
    
    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 6)
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Parent = Content
    
    -- Game info
    local gameInfo = Instance.new("TextLabel")
    gameInfo.Text = "🎮 Place ID: " .. game.PlaceId .. " | Game ID: " .. game.GameId
    gameInfo.Size = UDim2.new(1, 0, 0, 22)
    gameInfo.BackgroundTransparency = 1
    gameInfo.TextColor3 = Color3.fromRGB(170, 170, 200)
    gameInfo.TextSize = 11
    gameInfo.Font = Enum.Font.Gotham
    gameInfo.LayoutOrder = 1
    gameInfo.Parent = Content
    
    -- Status
    statusLabel = Instance.new("TextLabel")
    statusLabel.Text = "⏸️ Ready - Tekan tombol untuk mulai"
    statusLabel.Size = UDim2.new(1, 0, 0, 28)
    statusLabel.BackgroundColor3 = Color3.fromRGB(20, 30, 20)
    statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    statusLabel.TextSize = 12
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.LayoutOrder = 2
    statusLabel.Parent = Content
    Instance.new("UICorner", statusLabel).CornerRadius = UDim.new(0, 6)
    
    -- Progress
    progressLabel = Instance.new("TextLabel")
    progressLabel.Text = "Instances: 0 | Scripts: 0 | Assets: 0 | Files: 0"
    progressLabel.Size = UDim2.new(1, 0, 0, 20)
    progressLabel.BackgroundTransparency = 1
    progressLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
    progressLabel.TextSize = 10
    progressLabel.Font = Enum.Font.Code
    progressLabel.LayoutOrder = 3
    progressLabel.Parent = Content
    
    -- Helper function for buttons
    local function MakeButton(text, color, order)
        local btn = Instance.new("TextButton")
        btn.Text = text
        btn.Size = UDim2.new(1, 0, 0, 48)
        btn.BackgroundColor3 = color
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 14
        btn.Font = Enum.Font.GothamBold
        btn.BorderSizePixel = 0
        btn.LayoutOrder = order
        btn.Parent = Content
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
        return btn
    end
    
    -- Buttons
    local DumpAllBtn = MakeButton("⬇️ RIP EVERYTHING (Semua tanpa pengecualian)", Color3.fromRGB(130, 30, 200), 10)
    local ScriptsDeepBtn = MakeButton("📜 SCRIPTS ONLY (Logic Game, Skip Assets)", Color3.fromRGB(220, 120, 0), 11)
    local SaveInstanceBtn = MakeButton("💾 SAVE FULL MAP (.rbxlx) - If Supported", Color3.fromRGB(200, 100, 30), 12)
    local ClipboardBtn = MakeButton("📋 COPY ALL SCRIPTS TO CLIPBOARD", Color3.fromRGB(30, 130, 80), 13)
    local TreeOnlyBtn = MakeButton("🌳 EXPORT TREE STRUCTURE ONLY", Color3.fromRGB(30, 80, 150), 14)
    
    -- Separator
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(0.9, 0, 0, 1)
    sep.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    sep.BorderSizePixel = 0
    sep.LayoutOrder = 15
    sep.Parent = Content
    
    -- Location info
    local locInfo = Instance.new("TextLabel")
    locInfo.Text = "📁 Output: /sdcard/[Executor]/workspace/MapRip/\n📱 Buka File Manager → Internal → Delta/workspace/"
    locInfo.Size = UDim2.new(1, 0, 0, 40)
    locInfo.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    locInfo.TextColor3 = Color3.fromRGB(255, 200, 80)
    locInfo.TextSize = 10
    locInfo.Font = Enum.Font.Gotham
    locInfo.TextWrapped = true
    locInfo.LayoutOrder = 16
    locInfo.Parent = Content
    Instance.new("UICorner", locInfo).CornerRadius = UDim.new(0, 6)
    
    -- Log box
    logBox = Instance.new("TextLabel")
    logBox.Text = "[Ready] Logs appear here...\n"
    logBox.Size = UDim2.new(1, 0, 0, 250)
    logBox.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
    logBox.TextColor3 = Color3.fromRGB(130, 255, 130)
    logBox.TextSize = 9
    logBox.Font = Enum.Font.Code
    logBox.TextWrapped = true
    logBox.TextXAlignment = Enum.TextXAlignment.Left
    logBox.TextYAlignment = Enum.TextYAlignment.Top
    logBox.BorderSizePixel = 0
    logBox.LayoutOrder = 17
    logBox.Parent = Content
    Instance.new("UICorner", logBox).CornerRadius = UDim.new(0, 6)
    local lp = Instance.new("UIPadding", logBox)
    lp.PaddingTop = UDim.new(0, 4)
    lp.PaddingLeft = UDim.new(0, 4)
    lp.PaddingRight = UDim.new(0, 4)
    
    -- ===== DRAGGING (Touch + Mouse) =====
    local dragging, dragStart, startPos = false, nil, nil
    
    Title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
        end
    end)
    
    Title.InputEnded:Connect(function(input)
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
    
    -- ===== BUTTON HANDLERS =====
    CloseBtn.MouseButton1Click:Connect(function() Gui:Destroy() end)
    
    local minimized = false
    MinBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        Content.Visible = not minimized
        Main.Size = minimized and UDim2.new(0.92, 0, 0, 48) or UDim2.new(0.92, 0, 0.75, 0)
        MinBtn.Text = minimized and "□" or "—"
    end)
    
    DumpAllBtn.MouseButton1Click:Connect(function()
        if DUMP_RUNNING then return end
        DumpAllBtn.Text = "⏳ RIPPING MAP..."
        DumpAllBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        
        task.spawn(function()
            local folder = DumpEverything()
            DumpAllBtn.Text = "✅ DONE! " .. totalFiles .. " files → workspace/" .. (folder or "MapRip")
            DumpAllBtn.BackgroundColor3 = Color3.fromRGB(30, 160, 30)
            task.wait(5)
            DumpAllBtn.Text = "⬇️ RIP EVERYTHING (Semua tanpa pengecualian)"
            DumpAllBtn.BackgroundColor3 = Color3.fromRGB(130, 30, 200)
        end)
    end)
    
    -- ===== SCRIPTS ONLY DEEP DUMP (Skip all assets, only grab logic/code) =====
    ScriptsDeepBtn.MouseButton1Click:Connect(function()
        if DUMP_RUNNING then return end
        DUMP_RUNNING = true
        ScriptsDeepBtn.Text = "⏳ EXTRACTING SCRIPTS..."
        ScriptsDeepBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        
        task.spawn(function()
            local gameName, gameId = GetGameInfo()
            local ROOT = "MapRip/" .. gameName .. "_" .. gameId .. "_SCRIPTS_ONLY"
            MakeFolder(ROOT)
            MakeFolder(ROOT .. "/LocalScripts")
            MakeFolder(ROOT .. "/ServerScripts")
            MakeFolder(ROOT .. "/ModuleScripts")
            MakeFolder(ROOT .. "/ByFolder")
            
            local scriptCount = 0
            local localCount = 0
            local serverCount = 0
            local moduleCount = 0
            local fileCount = 0
            local scannedInstances = 0
            
            -- Organized by parent folder path
            local folderScripts = {} -- [folderPath] = {scripts...}
            
            Log("=== SCRIPTS ONLY DUMP ===")
            Log("Skipping: Sound, Texture, Decal, Image, MeshPart geometry, Particles, etc")
            Log("Grabbing: ALL LocalScript, Script, ModuleScript")
            UpdateStatus("Scanning for scripts...")
            
            local allServices = {
                {Workspace, "Workspace"},
                {ReplicatedStorage, "ReplicatedStorage"},
                {ReplicatedFirst, "ReplicatedFirst"},
                {Lighting, "Lighting"},
                {StarterGui, "StarterGui"},
                {StarterPack, "StarterPack"},
                {StarterPlayer, "StarterPlayer"},
                {SoundService, "SoundService"},
                {Teams, "Teams"},
            }
            pcall(function() table.insert(allServices, {game:GetService("Chat"), "Chat"}) end)
            pcall(function() table.insert(allServices, {LocalPlayer.PlayerGui, "PlayerGui"}) end)
            pcall(function() table.insert(allServices, {LocalPlayer.PlayerScripts, "PlayerScripts"}) end)
            pcall(function() table.insert(allServices, {LocalPlayer.Backpack, "Backpack"}) end)
            
            for _, svcInfo in ipairs(allServices) do
                local container, svcName = svcInfo[1], svcInfo[2]
                UpdateStatus("Scanning: " .. svcName)
                
                pcall(function()
                    local descendants = container:GetDescendants()
                    for _, obj in ipairs(descendants) do
                        scannedInstances = scannedInstances + 1
                        
                        if obj:IsA("BaseScript") or obj:IsA("ModuleScript") then
                            scriptCount = scriptCount + 1
                            
                            local source = DecompileScript(obj)
                            local name = SafeName(obj.Name)
                            local fullPath = obj:GetFullName()
                            local parentPath = SafeName(obj.Parent and obj.Parent:GetFullName() or "Unknown")
                            
                            -- Determine type
                            local folder = "ServerScripts"
                            local ext = ".server.lua"
                            local typeLabel = "Server"
                            
                            if obj:IsA("LocalScript") then
                                folder = "LocalScripts"
                                ext = ".client.lua"
                                typeLabel = "Local"
                                localCount = localCount + 1
                            elseif obj:IsA("ModuleScript") then
                                folder = "ModuleScripts"
                                ext = ".module.lua"
                                typeLabel = "Module"
                                moduleCount = moduleCount + 1
                            else
                                serverCount = serverCount + 1
                            end
                            
                            -- Header with full context
                            local header = string.format(
                                "-- ============================================================\n" ..
                                "-- SCRIPT: %s\n" ..
                                "-- TYPE: %s (%s)\n" ..
                                "-- PATH: %s\n" ..
                                "-- PARENT: %s [%s]\n" ..
                                "-- SERVICE: %s\n" ..
                                "-- ENABLED: %s\n" ..
                                "-- ============================================================\n\n",
                                obj.Name,
                                typeLabel, obj.ClassName,
                                fullPath,
                                obj.Parent and obj.Parent.Name or "nil",
                                obj.Parent and obj.Parent.ClassName or "nil",
                                svcName,
                                tostring(pcall(function() return obj.Enabled end) and (obj.Enabled ~= false) or "N/A")
                            )
                            
                            -- Save individually by type
                            local fileName = string.format("%04d", scriptCount) .. "_" .. name .. ext
                            SafeWrite(ROOT .. "/" .. folder .. "/" .. fileName, header .. source)
                            fileCount = fileCount + 1
                            
                            -- Also organize by parent folder
                            local folderKey = SafeName(svcName .. "/" .. (obj.Parent and obj.Parent.Name or "root"))
                            if not folderScripts[folderKey] then
                                folderScripts[folderKey] = {}
                            end
                            table.insert(folderScripts[folderKey], {
                                name = obj.Name,
                                class = obj.ClassName,
                                path = fullPath,
                                source = source,
                                header = header,
                            })
                            
                            Log("[" .. typeLabel .. "] " .. obj.Name .. " ← " .. svcName)
                            
                            if scriptCount % 20 == 0 then
                                UpdateProgress()
                                task.wait()
                            end
                        end
                        
                        if scannedInstances % 300 == 0 then
                            task.wait()
                        end
                    end
                end)
            end
            
            -- Save organized by folder
            UpdateStatus("Saving by folder structure...")
            for folderKey, scripts in pairs(folderScripts) do
                local folderPath = ROOT .. "/ByFolder/" .. folderKey
                MakeFolder(folderPath)
                
                for i, s in ipairs(scripts) do
                    local ext = ".lua"
                    if s.class == "LocalScript" then ext = ".client.lua"
                    elseif s.class == "ModuleScript" then ext = ".module.lua"
                    else ext = ".server.lua" end
                    
                    local fn = SafeName(s.name) .. "_" .. i .. ext
                    SafeWrite(folderPath .. "/" .. fn, s.header .. s.source)
                    fileCount = fileCount + 1
                end
            end
            
            -- Save combined file (all scripts in 1 file)
            UpdateStatus("Saving combined file...")
            local combined = string.format(
                "-- ============================================================\n" ..
                "-- ALL GAME SCRIPTS (Logic Only, No Assets)\n" ..
                "-- Game: %s (ID: %d)\n" ..
                "-- Total Scripts: %d (Local: %d, Server: %d, Module: %d)\n" ..
                "-- Instances Scanned: %d\n" ..
                "-- Date: %s\n" ..
                "-- ============================================================\n\n",
                gameName, gameId, scriptCount, localCount, serverCount, moduleCount,
                scannedInstances, os.date("%Y-%m-%d %H:%M:%S")
            )
            
            for folderKey, scripts in pairs(folderScripts) do
                combined = combined .. "\n\n" .. string.rep("=", 70) .. "\n"
                combined = combined .. "-- FOLDER: " .. folderKey .. " (" .. #scripts .. " scripts)\n"
                combined = combined .. string.rep("=", 70) .. "\n"
                
                for _, s in ipairs(scripts) do
                    combined = combined .. "\n" .. s.header .. s.source .. "\n"
                end
                
                -- Chunk if too large
                if #combined > 800000 then
                    SafeWrite(ROOT .. "/ALL_SCRIPTS_combined_part" .. fileCount .. ".lua", combined)
                    fileCount = fileCount + 1
                    combined = ""
                end
            end
            if combined ~= "" then
                SafeWrite(ROOT .. "/ALL_SCRIPTS_combined.lua", combined)
                fileCount = fileCount + 1
            end
            
            -- Save script index/map
            local indexText = string.format(
                "SCRIPTS ONLY DUMP - INDEX\n" ..
                string.rep("=", 60) .. "\n" ..
                "Game: %s (ID: %d)\n" ..
                "Total Scripts: %d\n" ..
                "  LocalScripts: %d\n" ..
                "  ServerScripts: %d\n" ..
                "  ModuleScripts: %d\n" ..
                "Total Instances Scanned: %d\n" ..
                "Date: %s\n\n" ..
                string.rep("=", 60) .. "\n" ..
                "FOLDER STRUCTURE:\n" ..
                string.rep("=", 60) .. "\n\n",
                gameName, gameId, scriptCount, localCount, serverCount, moduleCount,
                scannedInstances, os.date("%Y-%m-%d %H:%M:%S")
            )
            
            for folderKey, scripts in pairs(folderScripts) do
                indexText = indexText .. "\n📁 " .. folderKey .. "/ (" .. #scripts .. " scripts)\n"
                for i, s in ipairs(scripts) do
                    indexText = indexText .. "  " .. i .. ". [" .. s.class .. "] " .. s.name .. "\n"
                    indexText = indexText .. "     Path: " .. s.path .. "\n"
                end
            end
            
            indexText = indexText .. "\n\n" .. string.rep("=", 60) .. "\n"
            indexText = indexText .. "OUTPUT LOCATION:\n"
            indexText = indexText .. "  Delta: /sdcard/Delta/workspace/" .. ROOT .. "/\n"
            indexText = indexText .. "  Fluxus: /sdcard/Fluxus/workspace/" .. ROOT .. "/\n"
            indexText = indexText .. "\nFOLDER LAYOUT:\n"
            indexText = indexText .. "  /LocalScripts/    - Client-side scripts\n"
            indexText = indexText .. "  /ServerScripts/   - Server-side scripts\n"
            indexText = indexText .. "  /ModuleScripts/   - Module scripts (shared logic)\n"
            indexText = indexText .. "  /ByFolder/        - Scripts organized by parent folder\n"
            indexText = indexText .. "  ALL_SCRIPTS_combined.lua - Semua script dalam 1 file\n"
            
            SafeWrite(ROOT .. "/INDEX.txt", indexText)
            fileCount = fileCount + 1
            
            -- Done
            Log("=== SCRIPTS DUMP COMPLETE ===")
            Log(string.format("Found %d scripts (L:%d S:%d M:%d) from %d instances",
                scriptCount, localCount, serverCount, moduleCount, scannedInstances))
            Log("Saved to: workspace/" .. ROOT)
            UpdateStatus("✅ DONE! " .. scriptCount .. " scripts → " .. fileCount .. " files")
            
            ScriptsDeepBtn.Text = "✅ " .. scriptCount .. " scripts extracted!"
            ScriptsDeepBtn.BackgroundColor3 = Color3.fromRGB(30, 160, 30)
            task.wait(5)
            ScriptsDeepBtn.Text = "📜 SCRIPTS ONLY (Logic Game, Skip Assets)"
            ScriptsDeepBtn.BackgroundColor3 = Color3.fromRGB(220, 120, 0)
            DUMP_RUNNING = false
        end)
    end)
    
    SaveInstanceBtn.MouseButton1Click:Connect(function()
        if not saveinstance then
            Log("❌ saveinstance not supported by this executor!")
            SaveInstanceBtn.Text = "❌ NOT SUPPORTED"
            task.wait(2)
            SaveInstanceBtn.Text = "💾 SAVE FULL MAP (.rbxlx) - If Supported"
            return
        end
        
        SaveInstanceBtn.Text = "⏳ SAVING..."
        task.spawn(function()
            local gameName, gameId = GetGameInfo()
            local ok, err = pcall(function()
                saveinstance({
                    FilePath = "MapRip/" .. gameName .. "_" .. gameId .. "_FULL.rbxlx",
                    ExcludePlayerCharacter = true,
                    NilInstances = true,
                })
            end)
            if ok then
                SaveInstanceBtn.Text = "✅ SAVED .rbxlx!"
                Log("Full .rbxlx saved successfully!")
            else
                SaveInstanceBtn.Text = "❌ Error: " .. tostring(err):sub(1, 40)
                Log("saveinstance error: " .. tostring(err))
            end
            task.wait(3)
            SaveInstanceBtn.Text = "💾 SAVE FULL MAP (.rbxlx) - If Supported"
        end)
    end)
    
    ClipboardBtn.MouseButton1Click:Connect(function()
        ClipboardBtn.Text = "⏳ COLLECTING..."
        task.spawn(function()
            local all = {}
            local count = 0
            
            local function Grab(parent)
                pcall(function()
                    for _, obj in ipairs(parent:GetDescendants()) do
                        if obj:IsA("BaseScript") or obj:IsA("ModuleScript") then
                            count = count + 1
                            local src = DecompileScript(obj)
                            table.insert(all, "\n" .. string.rep("=", 60) .. "\n-- [" .. count .. "] " .. obj:GetFullName() .. "\n-- Class: " .. obj.ClassName .. "\n" .. string.rep("=", 60) .. "\n" .. src)
                        end
                    end
                end)
            end
            
            Grab(Workspace)
            Grab(ReplicatedStorage)
            Grab(ReplicatedFirst)
            Grab(Lighting)
            Grab(StarterGui)
            Grab(StarterPack)
            Grab(StarterPlayer)
            Grab(SoundService)
            pcall(function() Grab(LocalPlayer.PlayerGui) end)
            pcall(function() Grab(LocalPlayer.PlayerScripts) end)
            pcall(function() Grab(LocalPlayer.Backpack) end)
            
            local text = "-- TOTAL SCRIPTS: " .. count .. "\n" .. table.concat(all, "\n")
            
            if setclipboard then
                setclipboard(text)
                ClipboardBtn.Text = "✅ COPIED! (" .. count .. " scripts)"
            elseif toclipboard then
                toclipboard(text)
                ClipboardBtn.Text = "✅ COPIED! (" .. count .. " scripts)"
            else
                local gameName, gameId = GetGameInfo()
                MakeFolder("MapRip")
                SafeWrite("MapRip/clipboard_" .. gameName .. ".lua", text)
                ClipboardBtn.Text = "✅ SAVED TO FILE (" .. count .. " scripts)"
            end
            
            task.wait(4)
            ClipboardBtn.Text = "📋 COPY ALL SCRIPTS TO CLIPBOARD"
        end)
    end)
    
    TreeOnlyBtn.MouseButton1Click:Connect(function()
        TreeOnlyBtn.Text = "⏳ MAPPING..."
        task.spawn(function()
            local gameName, gameId = GetGameInfo()
            local lines = {}
            local count = 0
            
            local function MapTree(inst, depth)
                count = count + 1
                local indent = string.rep("│ ", depth)
                table.insert(lines, indent .. "├─ [" .. inst.ClassName .. "] " .. inst.Name)
                pcall(function()
                    for _, child in ipairs(inst:GetChildren()) do
                        MapTree(child, depth + 1)
                    end
                end)
                if count % 500 == 0 then task.wait() end
            end
            
            local services = {Workspace, ReplicatedStorage, ReplicatedFirst, Lighting, StarterGui, StarterPack, StarterPlayer, SoundService}
            local names = {"Workspace", "ReplicatedStorage", "ReplicatedFirst", "Lighting", "StarterGui", "StarterPack", "StarterPlayer", "SoundService"}
            
            for i, svc in ipairs(services) do
                table.insert(lines, "\n" .. string.rep("=", 50) .. "\n" .. names[i] .. "\n" .. string.rep("=", 50))
                pcall(function()
                    for _, child in ipairs(svc:GetChildren()) do
                        MapTree(child, 1)
                    end
                end)
            end
            
            MakeFolder("MapRip")
            SafeWrite("MapRip/TREE_" .. gameName .. ".txt", "INSTANCES: " .. count .. "\n\n" .. table.concat(lines, "\n"))
            TreeOnlyBtn.Text = "✅ TREE SAVED! (" .. count .. " instances)"
            Log("Tree exported: " .. count .. " instances")
            task.wait(3)
            TreeOnlyBtn.Text = "🌳 EXPORT TREE STRUCTURE ONLY"
        end)
    end)
    
    -- Parent GUI
    local ok = pcall(function() Gui.Parent = game:GetService("CoreGui") end)
    if not ok then Gui.Parent = LocalPlayer.PlayerGui end
    
    Log("GUI Ready! Game: " .. game.PlaceId)
    return Gui
end

-- ============================================
-- RUN
-- ============================================
CreateGUI()
