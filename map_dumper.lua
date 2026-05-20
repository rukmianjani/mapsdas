-- ULTIMATE MAP DUMPER v4.0 OP (Merged)
-- Jika ada error, akan muncul di output executor


-- TEST: tulis file test dulu untuk pastikan filesystem works
pcall(function()
    writefile("MapRip_TEST.txt", "MAP DUMPER v4.0 OK - " .. os.date())
end)

--[[
    ULTIMATE MAP DUMPER v4.0 - OVERPOWERED EDITION
    ================================================
    MAXIMUM EXTRACTION - Tembus semua script tanpa pengecualian
    
    10+ Layer Decompile Fallback:
      1. Source Property
      2. decompile() dengan Retry 3x
      3. decompile() mode alternatif (timeout/new)
      4. getscriptclosure() → decompile closure
      5. getsenv() - Dump Runtime Environment
      6. require() untuk ModuleScript
      7. getscriptbytecode() → Base64 + Hex
      8. getscripthash() untuk identifikasi
      9. debug.info/getconstants/getupvalues/getprotos
     10. getgc() scan untuk function recovery
    
    Extra Scanner:
      - getnilinstances() - Script tersembunyi (parent = nil)
      - getrunningscripts() - Script yang sedang aktif
      - getloadedmodules() - ModuleScript yang sudah di-load
      - getgc() - Scan Garbage Collector
      - CoreGui scan
      - PlayerGui/Backpack/PlayerScripts deep scan
    
    Compatible: Delta, Fluxus, Arceus X, Hydrogen, Synapse, Wave, Solara
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

-- Decompile Statistics
local DecompileStats = {
    total = 0,
    decompiled = 0,
    source_prop = 0,
    bytecode_saved = 0,
    env_dumped = 0,
    closure_decompiled = 0,
    module_required = 0,
    debug_extracted = 0,
    gc_recovered = 0,
    total_failed = 0,
    methods = {}, -- per-script tracking
}

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
        pcall(function()
            if not isfolder(current) then
                makefolder(current)
            end
        end)
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

local function SafeAppend(path, content)
    if not content or content == "" then return end
    -- Method 1: appendfile (not all executors have this)
    if type(appendfile) == "function" then
        local ok = pcall(appendfile, path, content)
        if ok then return end
    end
    -- Method 2: read existing + writefile
    local ok2 = pcall(function()
        local existing = ""
        if type(isfile) == "function" and isfile(path) then
            existing = readfile(path)
        else
            pcall(function() existing = readfile(path) end)
        end
        writefile(path, existing .. content)
    end)
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
        progressLabel.Text = string.format(
            "Inst: %d | Scripts: %d | Assets: %d | Files: %d | OK: %d | Fail: %d", 
            totalInstances, totalScripts, totalAssets, totalFiles,
            DecompileStats.decompiled + DecompileStats.source_prop + DecompileStats.closure_decompiled + DecompileStats.module_required,
            DecompileStats.total_failed
        )
    end
end

-- ============================================
-- BASE64 ENCODER
-- ============================================
local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function Base64Encode(data)
    if not data or #data == 0 then return "" end
    local result = {}
    local bytes = {string.byte(data, 1, math.min(#data, 262144))} -- cap at 256KB
    local padding = (3 - (#bytes % 3)) % 3
    for i = 1, padding do bytes[#bytes + 1] = 0 end
    
    for i = 1, #bytes, 3 do
        local b1, b2, b3 = bytes[i], bytes[i+1] or 0, bytes[i+2] or 0
        local n = b1 * 65536 + b2 * 256 + b3
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        result[#result+1] = B64_CHARS:sub(c1+1, c1+1)
        result[#result+1] = B64_CHARS:sub(c2+1, c2+1)
        result[#result+1] = B64_CHARS:sub(c3+1, c3+1)
        result[#result+1] = B64_CHARS:sub(c4+1, c4+1)
    end
    if padding >= 1 then result[#result] = "=" end
    if padding >= 2 then result[#result-1] = "=" end
    return table.concat(result)
end

-- ============================================
-- HEX ENCODER
-- ============================================
local function HexEncode(data, maxBytes)
    if not data or #data == 0 then return "" end
    maxBytes = maxBytes or 8192
    local hex = {}
    local len = math.min(#data, maxBytes)
    for i = 1, len do
        hex[#hex+1] = string.format("%02X", string.byte(data, i))
        if i % 32 == 0 then hex[#hex+1] = "\n" end
    end
    if len < #data then
        hex[#hex+1] = string.format("\n... (truncated, showing %d/%d bytes)", len, #data)
    end
    return table.concat(hex, " ")
end

-- ============================================
-- DEEP TABLE SERIALIZER (for require/getsenv)
-- ============================================
local function SerializeDeep(val, depth, visited)
    depth = depth or 0
    visited = visited or {}
    
    if depth > 8 then return '"[MAX_DEPTH]"' end
    
    local t = type(val)
    if t == "nil" then return "nil"
    elseif t == "string" then 
        if #val > 500 then
            return '"' .. val:sub(1, 500):gsub('"', '\\"'):gsub("\n", "\\n") .. '... [truncated]"'
        end
        return '"' .. val:gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
    elseif t == "number" or t == "boolean" then return tostring(val)
    elseif t == "function" then
        local info = ""
        pcall(function()
            local s, l, n = debug.info(val, "sln")
            info = string.format("source=%s line=%s name=%s", tostring(s), tostring(l), tostring(n))
        end)
        return '"[function: ' .. info .. ']"'
    elseif t == "table" then
        if visited[val] then return '"[CIRCULAR_REF]"' end
        visited[val] = true
        
        local items = {}
        local count = 0
        local indent = string.rep("  ", depth + 1)
        
        for k, v in pairs(val) do
            count = count + 1
            if count > 100 then
                items[#items+1] = indent .. "-- ... (" .. count .. "+ entries, truncated)"
                break
            end
            local key
            if type(k) == "string" then
                if k:match("^[%a_][%w_]*$") then
                    key = k
                else
                    key = '["' .. k:gsub('"', '\\"') .. '"]'
                end
            else
                key = "[" .. tostring(k) .. "]"
            end
            items[#items+1] = indent .. key .. " = " .. SerializeDeep(v, depth + 1, visited)
        end
        
        if #items == 0 then return "{}" end
        local outerIndent = string.rep("  ", depth)
        return "{\n" .. table.concat(items, ",\n") .. "\n" .. outerIndent .. "}"
    elseif t == "userdata" then
        local str = ""
        pcall(function() str = tostring(val) end)
        return '"[userdata: ' .. str .. ']"'
    else
        return '"[' .. t .. ': ' .. tostring(val) .. ']"'
    end
end

-- ============================================
-- ULTIMATE DECOMPILER ENGINE v4.0
-- 10+ Layer Fallback - Tembus Semua
-- ============================================

-- Check available executor functions
local HAS_DECOMPILE = type(decompile) == "function"
local HAS_GETSCRIPTBYTECODE = type(getscriptbytecode) == "function"
local HAS_GETSCRIPTHASH = type(getscripthash) == "function"
local HAS_GETSCRIPTCLOSURE = type(getscriptclosure) == "function"
local HAS_GETSENV = type(getsenv) == "function"
local HAS_GETNILINSTANCES = type(getnilinstances) == "function"
local HAS_GETRUNNINGSCRIPTS = type(getrunningscripts) == "function"
local HAS_GETLOADEDMODULES = type(getloadedmodules) == "function"
local HAS_GETGC = type(getgc) == "function"
local HAS_GETINSTANCES = type(getinstances) == "function"
local HAS_DEBUG_GETCONSTANTS = type(debug) == "table" and type(debug.getconstants) == "function"
local HAS_DEBUG_GETUPVALUES = type(debug) == "table" and type(debug.getupvalues) == "function"
local HAS_DEBUG_GETPROTOS = type(debug) == "table" and type(debug.getprotos) == "function"
local HAS_DEBUG_GETINFO = type(debug) == "table" and type(debug.info) == "function"
local HAS_ISCCLOSURE = type(iscclosure) == "function"
local HAS_ISLCLOSURE = type(islclosure) == "function"

local function IsDecompileFailure(src)
    if not src or type(src) ~= "string" or #src == 0 then return true end
    local lower = src:lower()
    return lower:find("failed to decompile") ~= nil
        or lower:find("cannot decompile") ~= nil
        or lower:find("decompilation failed") ~= nil
        or lower:find("error decompiling") ~= nil
        or lower:find("decompile timed out") ~= nil
        or lower:find("-- unsynapse decompiler") ~= nil
        or lower:find("timed out") ~= nil
end

-- ============================================
-- LAYER 5: getsenv() ENVIRONMENT DUMPER
-- ============================================
local function DumpScriptEnvironment(scriptObj)
    if not HAS_GETSENV then return nil end
    
    local ok, env = pcall(getsenv, scriptObj)
    if not ok or not env or type(env) ~= "table" then return nil end
    
    local lines = {}
    lines[#lines+1] = "-- ╔══════════════════════════════════════════════════╗"
    lines[#lines+1] = "-- ║  RUNTIME ENVIRONMENT DUMP (getsenv)             ║"
    lines[#lines+1] = "-- ║  Script: " .. scriptObj.Name
    lines[#lines+1] = "-- ╚══════════════════════════════════════════════════╝"
    lines[#lines+1] = ""
    
    local funcCount = 0
    local varCount = 0
    local tableCount = 0
    
    -- Sort keys for consistent output
    local keys = {}
    for k in pairs(env) do
        if type(k) == "string" then
            keys[#keys+1] = k
        end
    end
    table.sort(keys)
    
    for _, k in ipairs(keys) do
        local v = env[k]
        local vtype = type(v)
        
        if vtype == "function" then
            funcCount = funcCount + 1
            lines[#lines+1] = "-- ═══ FUNCTION: " .. k .. " ═══"
            
            -- debug.info
            pcall(function()
                if HAS_DEBUG_GETINFO then
                    local src, line, name = debug.info(v, "sln")
                    lines[#lines+1] = "-- source: " .. tostring(src)
                    lines[#lines+1] = "-- line: " .. tostring(line)
                    lines[#lines+1] = "-- name: " .. tostring(name)
                end
            end)
            
            -- closure type
            pcall(function()
                if HAS_ISCCLOSURE then
                    lines[#lines+1] = "-- is_c_closure: " .. tostring(iscclosure(v))
                end
                if HAS_ISLCLOSURE then
                    lines[#lines+1] = "-- is_lua_closure: " .. tostring(islclosure(v))
                end
            end)
            
            -- constants
            pcall(function()
                if HAS_DEBUG_GETCONSTANTS then
                    local consts = debug.getconstants(v)
                    if consts and #consts > 0 then
                        lines[#lines+1] = "-- constants: {"
                        for ci, cv in pairs(consts) do
                            lines[#lines+1] = "--   [" .. tostring(ci) .. "] = " .. tostring(cv) .. " (" .. type(cv) .. ")"
                        end
                        lines[#lines+1] = "-- }"
                    end
                end
            end)
            
            -- upvalues
            pcall(function()
                if HAS_DEBUG_GETUPVALUES then
                    local upvals = debug.getupvalues(v)
                    if upvals then
                        local hasData = false
                        for _ in pairs(upvals) do hasData = true; break end
                        if hasData then
                            lines[#lines+1] = "-- upvalues: {"
                            for ui, uv in pairs(upvals) do
                                local uvStr = tostring(uv)
                                if type(uv) == "table" then
                                    uvStr = SerializeDeep(uv, 0)
                                    if #uvStr > 500 then uvStr = uvStr:sub(1, 500) .. "..." end
                                elseif type(uv) == "string" then
                                    uvStr = '"' .. uv:sub(1, 200) .. '"'
                                end
                                lines[#lines+1] = "--   [" .. tostring(ui) .. "] = " .. uvStr
                            end
                            lines[#lines+1] = "-- }"
                        end
                    end
                end
            end)
            
            -- protos (sub-functions)
            pcall(function()
                if HAS_DEBUG_GETPROTOS then
                    local protos = debug.getprotos(v)
                    if protos and #protos > 0 then
                        lines[#lines+1] = "-- sub_functions: " .. #protos
                        for pi, pf in ipairs(protos) do
                            pcall(function()
                                local ps, pl, pn = debug.info(pf, "sln")
                                lines[#lines+1] = "--   proto[" .. pi .. "]: name=" .. tostring(pn) .. " line=" .. tostring(pl)
                            end)
                            -- Proto constants
                            pcall(function()
                                if HAS_DEBUG_GETCONSTANTS then
                                    local pconsts = debug.getconstants(pf)
                                    if pconsts and #pconsts > 0 then
                                        lines[#lines+1] = "--     constants: {"
                                        for pci, pcv in pairs(pconsts) do
                                            lines[#lines+1] = "--       [" .. tostring(pci) .. "] = " .. tostring(pcv)
                                        end
                                        lines[#lines+1] = "--     }"
                                    end
                                end
                            end)
                        end
                    end
                end
            end)
            
            -- Try decompile the individual function
            pcall(function()
                if HAS_DECOMPILE and HAS_ISLCLOSURE and islclosure(v) then
                    local fok, fsrc = pcall(decompile, v)
                    if fok and fsrc and not IsDecompileFailure(fsrc) then
                        lines[#lines+1] = "-- DECOMPILED FUNCTION SOURCE:"
                        lines[#lines+1] = fsrc
                    end
                end
            end)
            
            lines[#lines+1] = "function " .. k .. "(...) --[[ see debug info above ]] end"
            lines[#lines+1] = ""
            
        elseif vtype == "table" then
            tableCount = tableCount + 1
            lines[#lines+1] = "-- ═══ TABLE: " .. k .. " ═══"
            local serialized = SerializeDeep(v, 0)
            if #serialized > 5000 then
                serialized = serialized:sub(1, 5000) .. "\n-- ... [TABLE TRUNCATED]"
            end
            lines[#lines+1] = "local " .. k .. " = " .. serialized
            lines[#lines+1] = ""
            
        elseif vtype == "string" then
            varCount = varCount + 1
            local display = v
            if #display > 1000 then display = display:sub(1, 1000) .. "... [TRUNCATED]" end
            lines[#lines+1] = 'local ' .. k .. ' = "' .. display:gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
            
        elseif vtype == "number" or vtype == "boolean" then
            varCount = varCount + 1
            lines[#lines+1] = "local " .. k .. " = " .. tostring(v)
            
        elseif vtype == "userdata" then
            varCount = varCount + 1
            local str = ""
            pcall(function() str = tostring(v) end)
            lines[#lines+1] = "local " .. k .. " = nil -- [userdata: " .. str .. "]"
        end
    end
    
    lines[#lines+1] = ""
    lines[#lines+1] = string.format("-- ENV STATS: %d functions, %d variables, %d tables", funcCount, varCount, tableCount)
    
    if funcCount == 0 and varCount == 0 and tableCount == 0 then
        return nil -- Empty environment
    end
    
    return table.concat(lines, "\n")
end

-- ============================================
-- LAYER 9: DEBUG INFO EXTRACTOR
-- ============================================
local function ExtractDebugInfo(scriptObj)
    if not HAS_GETSCRIPTCLOSURE then return nil end
    
    local ok, closure = pcall(getscriptclosure, scriptObj)
    if not ok or not closure then return nil end
    
    local info = {}
    info.lines = {}
    
    -- Basic info
    pcall(function()
        if HAS_DEBUG_GETINFO then
            local src, line, name = debug.info(closure, "sln")
            info.source = src
            info.line = line
            info.name = name
            info.lines[#info.lines+1] = "-- Debug Source: " .. tostring(src)
            info.lines[#info.lines+1] = "-- Debug Line: " .. tostring(line)
            info.lines[#info.lines+1] = "-- Debug Name: " .. tostring(name)
        end
    end)
    
    -- Constants
    pcall(function()
        if HAS_DEBUG_GETCONSTANTS then
            local consts = debug.getconstants(closure)
            if consts then
                info.constants = consts
                info.lines[#info.lines+1] = "-- ═══ MAIN FUNCTION CONSTANTS ═══"
                local strConsts = {}
                local numConsts = {}
                local otherConsts = {}
                for i, c in pairs(consts) do
                    if type(c) == "string" then
                        strConsts[#strConsts+1] = {i, c}
                    elseif type(c) == "number" then
                        numConsts[#numConsts+1] = {i, c}
                    else
                        otherConsts[#otherConsts+1] = {i, tostring(c), type(c)}
                    end
                end
                if #strConsts > 0 then
                    info.lines[#info.lines+1] = "-- String Constants:"
                    for _, sc in ipairs(strConsts) do
                        info.lines[#info.lines+1] = '--   [' .. sc[1] .. '] = "' .. tostring(sc[2]):sub(1, 200) .. '"'
                    end
                end
                if #numConsts > 0 then
                    info.lines[#info.lines+1] = "-- Number Constants:"
                    for _, nc in ipairs(numConsts) do
                        info.lines[#info.lines+1] = "--   [" .. nc[1] .. "] = " .. nc[2]
                    end
                end
            end
        end
    end)
    
    -- Upvalues
    pcall(function()
        if HAS_DEBUG_GETUPVALUES then
            local upvals = debug.getupvalues(closure)
            if upvals then
                info.upvalues = upvals
                local hasData = false
                for _ in pairs(upvals) do hasData = true; break end
                if hasData then
                    info.lines[#info.lines+1] = "-- ═══ UPVALUES ═══"
                    for i, uv in pairs(upvals) do
                        local uvStr = tostring(uv)
                        if type(uv) == "table" then
                            uvStr = SerializeDeep(uv, 0)
                            if #uvStr > 1000 then uvStr = uvStr:sub(1, 1000) .. "..." end
                        elseif type(uv) == "string" then
                            uvStr = '"' .. uv:sub(1, 300) .. '"'
                        end
                        info.lines[#info.lines+1] = "--   upvalue[" .. tostring(i) .. "] = " .. uvStr .. " (" .. type(uv) .. ")"
                    end
                end
            end
        end
    end)
    
    -- Protos (sub-functions) - RECURSIVE
    pcall(function()
        if HAS_DEBUG_GETPROTOS then
            local protos = debug.getprotos(closure)
            if protos and #protos > 0 then
                info.protos = protos
                info.lines[#info.lines+1] = "-- ═══ SUB-FUNCTIONS (" .. #protos .. " protos) ═══"
                
                for pi, pf in ipairs(protos) do
                    info.lines[#info.lines+1] = "-- ┌─ Proto[" .. pi .. "]"
                    
                    pcall(function()
                        if HAS_DEBUG_GETINFO then
                            local ps, pl, pn = debug.info(pf, "sln")
                            info.lines[#info.lines+1] = "--   name: " .. tostring(pn) .. " | line: " .. tostring(pl)
                        end
                    end)
                    
                    pcall(function()
                        if HAS_DEBUG_GETCONSTANTS then
                            local pconsts = debug.getconstants(pf)
                            if pconsts then
                                info.lines[#info.lines+1] = "--   constants:"
                                for pci, pcv in pairs(pconsts) do
                                    if type(pcv) == "string" then
                                        info.lines[#info.lines+1] = '--     [' .. pci .. '] = "' .. pcv:sub(1, 150) .. '"'
                                    elseif type(pcv) == "number" then
                                        info.lines[#info.lines+1] = "--     [" .. pci .. "] = " .. pcv
                                    end
                                end
                            end
                        end
                    end)
                    
                    pcall(function()
                        if HAS_DEBUG_GETUPVALUES then
                            local pupvals = debug.getupvalues(pf)
                            if pupvals then
                                local hasP = false
                                for _ in pairs(pupvals) do hasP = true; break end
                                if hasP then
                                    info.lines[#info.lines+1] = "--   upvalues:"
                                    for pui, puv in pairs(pupvals) do
                                        info.lines[#info.lines+1] = "--     [" .. pui .. "] = " .. tostring(puv):sub(1, 200)
                                    end
                                end
                            end
                        end
                    end)
                    
                    -- Try decompile individual proto
                    pcall(function()
                        if HAS_DECOMPILE and HAS_ISLCLOSURE and islclosure(pf) then
                            local fok, fsrc = pcall(decompile, pf)
                            if fok and fsrc and not IsDecompileFailure(fsrc) then
                                info.lines[#info.lines+1] = "--   DECOMPILED:"
                                for srcLine in fsrc:gmatch("[^\n]+") do
                                    info.lines[#info.lines+1] = "--     " .. srcLine
                                end
                            end
                        end
                    end)
                    
                    -- Nested protos (1 level deep)
                    pcall(function()
                        if HAS_DEBUG_GETPROTOS then
                            local subProtos = debug.getprotos(pf)
                            if subProtos and #subProtos > 0 then
                                info.lines[#info.lines+1] = "--   nested_protos: " .. #subProtos
                                for spi, spf in ipairs(subProtos) do
                                    pcall(function()
                                        local ss, sl, sn = debug.info(spf, "sln")
                                        info.lines[#info.lines+1] = "--     sub[" .. spi .. "]: " .. tostring(sn) .. " @ line " .. tostring(sl)
                                    end)
                                    pcall(function()
                                        if HAS_DEBUG_GETCONSTANTS then
                                            local sconsts = debug.getconstants(spf)
                                            if sconsts then
                                                for sci, scv in pairs(sconsts) do
                                                    if type(scv) == "string" then
                                                        info.lines[#info.lines+1] = '--       const[' .. sci .. '] = "' .. scv:sub(1, 100) .. '"'
                                                    end
                                                end
                                            end
                                        end
                                    end)
                                end
                            end
                        end
                    end)
                    
                    info.lines[#info.lines+1] = "-- └─────────────────"
                end
            end
        end
    end)
    
    if #info.lines == 0 then return nil end
    return info
end

-- ============================================
-- MAIN: UltimateDecompile() - 10+ LAYERS
-- ============================================
local function UltimateDecompile(scriptObj)
    DecompileStats.total = DecompileStats.total + 1
    
    local result = {
        source = nil,
        method = "failed",
        bytecodeB64 = nil,
        bytecodeHex = nil,
        bytecodeSize = 0,
        hash = nil,
        envDump = nil,
        debugInfo = nil,
        error = nil,
        layers = {}, -- track which layers were attempted
    }
    
    local scriptName = "unknown"
    pcall(function() scriptName = scriptObj:GetFullName() end)
    
    -- ═══════════════════════════════════════════
    -- LAYER 1: Direct Source Property
    -- ═══════════════════════════════════════════
    pcall(function()
        local src = scriptObj.Source
        if src and type(src) == "string" and #src > 0 then
            result.source = src
            result.method = "source_property"
            DecompileStats.source_prop = DecompileStats.source_prop + 1
            result.layers[#result.layers+1] = "L1:source_property=OK"
        end
    end)
    if result.source and not IsDecompileFailure(result.source) then return result end
    result.layers[#result.layers+1] = "L1:source_property=FAIL"
    result.source = nil
    
    -- ═══════════════════════════════════════════
    -- LAYER 2: decompile() with RETRY (3 attempts)
    -- ═══════════════════════════════════════════
    if HAS_DECOMPILE then
        for attempt = 1, 3 do
            local ok, src = pcall(decompile, scriptObj)
            if ok and src and type(src) == "string" and #src > 0 and not IsDecompileFailure(src) then
                result.source = src
                result.method = "decompiled_attempt" .. attempt
                DecompileStats.decompiled = DecompileStats.decompiled + 1
                result.layers[#result.layers+1] = "L2:decompile_retry" .. attempt .. "=OK"
                return result
            end
            if not ok then
                result.error = tostring(src)
            elseif src then
                result.error = src
            end
            if attempt < 3 then task.wait(0.3 * attempt) end
        end
        result.layers[#result.layers+1] = "L2:decompile_retry=FAIL"
    else
        result.layers[#result.layers+1] = "L2:decompile=NOT_AVAILABLE"
    end
    
    -- ═══════════════════════════════════════════
    -- LAYER 3: Decompile with alternative parameters
    -- ═══════════════════════════════════════════
    if HAS_DECOMPILE then
        -- Try timeout parameter
        local tryModes = {
            {args = {scriptObj, 30}, name = "timeout30"},
            {args = {scriptObj, 60}, name = "timeout60"},
            {args = {scriptObj, true}, name = "flag_true"},
            {args = {scriptObj, "new"}, name = "mode_new"},
        }
        for _, mode in ipairs(tryModes) do
            pcall(function()
                local src = decompile(unpack(mode.args))
                if src and type(src) == "string" and #src > 0 and not IsDecompileFailure(src) then
                    result.source = src
                    result.method = "decompile_" .. mode.name
                    DecompileStats.decompiled = DecompileStats.decompiled + 1
                    result.layers[#result.layers+1] = "L3:" .. mode.name .. "=OK"
                end
            end)
            if result.source then return result end
        end
        result.layers[#result.layers+1] = "L3:alt_modes=FAIL"
    end
    
    -- ═══════════════════════════════════════════
    -- LAYER 4: getscriptclosure → decompile closure
    -- ═══════════════════════════════════════════
    if HAS_GETSCRIPTCLOSURE and HAS_DECOMPILE then
        pcall(function()
            local closure = getscriptclosure(scriptObj)
            if closure then
                local src = decompile(closure)
                if src and type(src) == "string" and #src > 0 and not IsDecompileFailure(src) then
                    result.source = src
                    result.method = "closure_decompile"
                    DecompileStats.closure_decompiled = DecompileStats.closure_decompiled + 1
                    result.layers[#result.layers+1] = "L4:closure_decompile=OK"
                end
            end
        end)
        if result.source then return result end
        result.layers[#result.layers+1] = "L4:closure_decompile=FAIL"
    end
    
    -- ═══════════════════════════════════════════
    -- LAYER 5: getsenv() - Runtime Environment Dump
    -- ═══════════════════════════════════════════
    local envResult = DumpScriptEnvironment(scriptObj)
    if envResult then
        result.envDump = envResult
        DecompileStats.env_dumped = DecompileStats.env_dumped + 1
        result.layers[#result.layers+1] = "L5:getsenv=OK"
    else
        result.layers[#result.layers+1] = "L5:getsenv=FAIL"
    end
    
    -- ═══════════════════════════════════════════
    -- LAYER 6: require() for ModuleScripts
    -- ═══════════════════════════════════════════
    if scriptObj:IsA("ModuleScript") then
        pcall(function()
            local moduleData = require(scriptObj)
            if moduleData ~= nil then
                local serialized = SerializeDeep(moduleData, 0)
                if serialized and #serialized > 0 then
                    result.source = "-- MODULE require() RETURN VALUE:\n-- Module: " .. scriptName .. "\n\nreturn " .. serialized
                    result.method = "module_required"
                    DecompileStats.module_required = DecompileStats.module_required + 1
                    result.layers[#result.layers+1] = "L6:require=OK"
                end
            end
        end)
        if result.source then return result end
        result.layers[#result.layers+1] = "L6:require=FAIL"
    end
    
    -- ═══════════════════════════════════════════
    -- LAYER 7: getscriptbytecode → Base64 + Hex
    -- ═══════════════════════════════════════════
    if HAS_GETSCRIPTBYTECODE then
        pcall(function()
            local bytecode = getscriptbytecode(scriptObj)
            if bytecode and type(bytecode) == "string" and #bytecode > 0 then
                result.bytecodeB64 = Base64Encode(bytecode)
                result.bytecodeSize = #bytecode
                DecompileStats.bytecode_saved = DecompileStats.bytecode_saved + 1
                result.layers[#result.layers+1] = "L7:bytecode=" .. #bytecode .. "bytes"
                
                -- Hex dump for smaller scripts (useful for analysis)
                if #bytecode < 16384 then
                    result.bytecodeHex = HexEncode(bytecode)
                end
            end
        end)
    else
        result.layers[#result.layers+1] = "L7:bytecode=NOT_AVAILABLE"
    end
    
    -- ═══════════════════════════════════════════
    -- LAYER 8: getscripthash
    -- ═══════════════════════════════════════════
    if HAS_GETSCRIPTHASH then
        pcall(function()
            result.hash = getscripthash(scriptObj)
            if result.hash then
                result.layers[#result.layers+1] = "L8:hash=" .. tostring(result.hash)
            end
        end)
    end
    
    -- ═══════════════════════════════════════════
    -- LAYER 9: Debug Info Deep Extraction
    -- ═══════════════════════════════════════════
    local dbgInfo = ExtractDebugInfo(scriptObj)
    if dbgInfo then
        result.debugInfo = dbgInfo
        DecompileStats.debug_extracted = DecompileStats.debug_extracted + 1
        result.layers[#result.layers+1] = "L9:debug_info=OK"
    else
        result.layers[#result.layers+1] = "L9:debug_info=FAIL"
    end
    
    -- ═══════════════════════════════════════════
    -- LAYER 10: getgc() - Scan GC for related functions
    -- ═══════════════════════════════════════════
    if HAS_GETGC then
        pcall(function()
            local gcFuncs = getgc(false) -- functions only
            local relatedFuncs = {}
            local scriptPath = scriptObj:GetFullName()
            
            for _, func in ipairs(gcFuncs) do
                if type(func) == "function" then
                    pcall(function()
                        if HAS_DEBUG_GETINFO then
                            local src, line, name = debug.info(func, "sln")
                            if src and tostring(src):find(scriptObj.Name, 1, true) then
                                relatedFuncs[#relatedFuncs+1] = {
                                    source = src,
                                    line = line,
                                    name = name,
                                    func = func,
                                }
                            end
                        end
                    end)
                end
                if #relatedFuncs >= 50 then break end
            end
            
            if #relatedFuncs > 0 then
                result.layers[#result.layers+1] = "L10:gc_found=" .. #relatedFuncs .. "_funcs"
                DecompileStats.gc_recovered = DecompileStats.gc_recovered + 1
                
                -- Try decompile GC functions
                local gcLines = {"-- ═══ GC RECOVERED FUNCTIONS ═══"}
                for fi, fdata in ipairs(relatedFuncs) do
                    gcLines[#gcLines+1] = string.format("-- GC[%d] name=%s line=%s source=%s", 
                        fi, tostring(fdata.name), tostring(fdata.line), tostring(fdata.source))
                    
                    if HAS_DECOMPILE then
                        pcall(function()
                            local fsrc = decompile(fdata.func)
                            if fsrc and not IsDecompileFailure(fsrc) then
                                gcLines[#gcLines+1] = fsrc
                                gcLines[#gcLines+1] = ""
                            end
                        end)
                    end
                    
                    -- Get constants
                    pcall(function()
                        if HAS_DEBUG_GETCONSTANTS then
                            local consts = debug.getconstants(fdata.func)
                            if consts and #consts > 0 then
                                gcLines[#gcLines+1] = "-- constants:"
                                for ci, cv in pairs(consts) do
                                    gcLines[#gcLines+1] = "--   " .. tostring(ci) .. " = " .. tostring(cv)
                                end
                            end
                        end
                    end)
                end
                
                if not result.envDump then
                    result.envDump = table.concat(gcLines, "\n")
                else
                    result.envDump = result.envDump .. "\n\n" .. table.concat(gcLines, "\n")
                end
            else
                result.layers[#result.layers+1] = "L10:gc=NO_MATCH"
            end
        end)
    end
    
    -- ═══════════════════════════════════════════
    -- BUILD FINAL COMPOSITE SOURCE
    -- ═══════════════════════════════════════════
    local parts = {}
    parts[#parts+1] = "-- ╔═══════════════════════════════════════════════════════════╗"
    parts[#parts+1] = "-- ║  DECOMPILE FAILED - FALLBACK DATA EXTRACTION             ║"
    parts[#parts+1] = "-- ╚═══════════════════════════════════════════════════════════╝"
    parts[#parts+1] = "-- Script: " .. scriptName
    parts[#parts+1] = "-- Class: " .. scriptObj.ClassName
    parts[#parts+1] = "-- Error: " .. tostring(result.error)
    parts[#parts+1] = "-- Extraction Layers: " .. table.concat(result.layers, " → ")
    if result.hash then
        parts[#parts+1] = "-- Hash: " .. tostring(result.hash)
    end
    if result.bytecodeSize > 0 then
        parts[#parts+1] = "-- Bytecode Size: " .. result.bytecodeSize .. " bytes"
    end
    
    -- Enabled/RunContext info
    pcall(function()
        local enabled = scriptObj.Enabled
        parts[#parts+1] = "-- Enabled: " .. tostring(enabled)
    end)
    pcall(function()
        local rc = scriptObj.RunContext
        parts[#parts+1] = "-- RunContext: " .. tostring(rc)
    end)
    
    parts[#parts+1] = ""
    
    local hasUsefulData = false
    
    -- Add env dump
    if result.envDump then
        parts[#parts+1] = result.envDump
        parts[#parts+1] = ""
        hasUsefulData = true
    end
    
    -- Add debug info
    if result.debugInfo and result.debugInfo.lines and #result.debugInfo.lines > 0 then
        parts[#parts+1] = "-- ═══════════════════════════════════"
        parts[#parts+1] = "-- DEBUG INFO EXTRACTION"
        parts[#parts+1] = "-- ═══════════════════════════════════"
        for _, line in ipairs(result.debugInfo.lines) do
            parts[#parts+1] = line
        end
        parts[#parts+1] = ""
        hasUsefulData = true
    end
    
    -- Add bytecode
    if result.bytecodeB64 then
        parts[#parts+1] = string.format("-- ═══ BYTECODE (%d bytes) ═══", result.bytecodeSize)
        parts[#parts+1] = "-- Base64 encoded - decode + decompile offline dengan tools external"
        parts[#parts+1] = "--[[BYTECODE_BASE64_START"
        -- Split base64 into 76-char lines
        local b64 = result.bytecodeB64
        for i = 1, #b64, 76 do
            parts[#parts+1] = b64:sub(i, i + 75)
        end
        parts[#parts+1] = "BYTECODE_BASE64_END]]"
        parts[#parts+1] = ""
        hasUsefulData = true
        
        if result.bytecodeHex then
            parts[#parts+1] = "-- ═══ HEX DUMP ═══"
            parts[#parts+1] = "--[[BYTECODE_HEX_START"
            parts[#parts+1] = result.bytecodeHex
            parts[#parts+1] = "BYTECODE_HEX_END]]"
            parts[#parts+1] = ""
        end
    end
    
    if not hasUsefulData then
        DecompileStats.total_failed = DecompileStats.total_failed + 1
        parts[#parts+1] = "-- ██████████████████████████████████████████"
        parts[#parts+1] = "-- ██ COMPLETE FAILURE: No data extracted  ██"
        parts[#parts+1] = "-- ██████████████████████████████████████████"
        parts[#parts+1] = "-- Possible reasons:"
        parts[#parts+1] = "--   1. Server-side script (never sent to client)"
        parts[#parts+1] = "--   2. Script belum di-load/running"
        parts[#parts+1] = "--   3. Executor tidak support API yang dibutuhkan"
        parts[#parts+1] = "--   4. Script heavily obfuscated (Luraph/Moonsec/IronBrew)"
        parts[#parts+1] = "--   5. Bytecode version incompatible"
        result.method = "failed"
    else
        result.method = "fallback_composite"
    end
    
    result.source = table.concat(parts, "\n")
    
    -- Track method
    DecompileStats.methods[scriptName] = result.method
    
    return result
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
    elseif t == "BrickColor" then return 'BrickColor.new("' .. tostring(val) .. '")'
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
    "Rate", "Lifetime", "SpreadAngle", "RotSpeed",
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
        if ok and val and type(val) == "string" and (val:find("rbxasset") or val:find("://")) then
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
-- EXTRA SCRIPT DISCOVERY - Tembus Semua
-- ============================================

-- Discover ALL scripts from every possible source
local function DiscoverAllScripts()
    local allScripts = {} -- [instance] = source_method
    local seen = {}
    
    local function addScript(obj, source)
        if not seen[obj] then
            seen[obj] = true
            allScripts[#allScripts+1] = {instance = obj, source = source}
        end
    end
    
    -- METHOD 1: Standard services descendants scan
    local servicesToScan = {
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
    
    -- Extra services
    pcall(function() table.insert(servicesToScan, {game:GetService("Chat"), "Chat"}) end)
    pcall(function() table.insert(servicesToScan, {game:GetService("LocalizationService"), "LocalizationService"}) end)
    pcall(function() table.insert(servicesToScan, {game:GetService("TestService"), "TestService"}) end)
    pcall(function() table.insert(servicesToScan, {game:GetService("ServerStorage"), "ServerStorage"}) end)
    pcall(function() table.insert(servicesToScan, {game:GetService("ServerScriptService"), "ServerScriptService"}) end)
    
    for _, svc in ipairs(servicesToScan) do
        pcall(function()
            for _, obj in ipairs(svc[1]:GetDescendants()) do
                if obj:IsA("BaseScript") or obj:IsA("ModuleScript") then
                    addScript(obj, "service:" .. svc[2])
                end
            end
        end)
    end
    Log("  Discovery [Services]: " .. #allScripts .. " scripts")
    
    -- METHOD 2: Player containers
    pcall(function()
        local before = #allScripts
        for _, child in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if child:IsA("BaseScript") or child:IsA("ModuleScript") then
                addScript(child, "PlayerGui")
            end
        end
        Log("  Discovery [PlayerGui]: +" .. (#allScripts - before))
    end)
    
    pcall(function()
        local before = #allScripts
        for _, child in ipairs(LocalPlayer.Backpack:GetDescendants()) do
            if child:IsA("BaseScript") or child:IsA("ModuleScript") then
                addScript(child, "Backpack")
            end
        end
        Log("  Discovery [Backpack]: +" .. (#allScripts - before))
    end)
    
    pcall(function()
        local before = #allScripts
        for _, child in ipairs(LocalPlayer.PlayerScripts:GetDescendants()) do
            if child:IsA("BaseScript") or child:IsA("ModuleScript") then
                addScript(child, "PlayerScripts")
            end
        end
        Log("  Discovery [PlayerScripts]: +" .. (#allScripts - before))
    end)
    
    -- METHOD 3: CoreGui
    pcall(function()
        local before = #allScripts
        for _, child in ipairs(game:GetService("CoreGui"):GetDescendants()) do
            if child:IsA("BaseScript") or child:IsA("ModuleScript") then
                addScript(child, "CoreGui")
            end
        end
        Log("  Discovery [CoreGui]: +" .. (#allScripts - before))
    end)
    
    -- METHOD 4: getscripts() - ALL scripts in memory
    pcall(function()
        if type(getscripts) == "function" then
            local before = #allScripts
            for _, obj in ipairs(getscripts()) do
                if obj:IsA("BaseScript") or obj:IsA("ModuleScript") then
                    addScript(obj, "getscripts()")
                end
            end
            Log("  Discovery [getscripts]: +" .. (#allScripts - before))
        end
    end)
    
    -- METHOD 5: getrunningscripts() - currently RUNNING scripts
    pcall(function()
        if type(getrunningscripts) == "function" then
            local before = #allScripts
            for _, obj in ipairs(getrunningscripts()) do
                addScript(obj, "getrunningscripts()")
            end
            Log("  Discovery [getrunningscripts]: +" .. (#allScripts - before))
        end
    end)
    
    -- METHOD 6: getloadedmodules() - loaded ModuleScripts
    pcall(function()
        if type(getloadedmodules) == "function" then
            local before = #allScripts
            for _, obj in ipairs(getloadedmodules()) do
                addScript(obj, "getloadedmodules()")
            end
            Log("  Discovery [getloadedmodules]: +" .. (#allScripts - before))
        end
    end)
    
    -- METHOD 7: getnilinstances() - Hidden/removed scripts (parent = nil)
    pcall(function()
        if type(getnilinstances) == "function" then
            local before = #allScripts
            for _, obj in ipairs(getnilinstances()) do
                if obj:IsA("BaseScript") or obj:IsA("ModuleScript") then
                    addScript(obj, "nil_instance")
                end
            end
            Log("  Discovery [nil_instances]: +" .. (#allScripts - before))
        end
    end)
    
    -- METHOD 8: getinstances() - ALL instances in memory
    pcall(function()
        if type(getinstances) == "function" then
            local before = #allScripts
            for _, obj in ipairs(getinstances()) do
                if (obj:IsA("BaseScript") or obj:IsA("ModuleScript")) then
                    addScript(obj, "getinstances()")
                end
            end
            Log("  Discovery [getinstances]: +" .. (#allScripts - before))
        end
    end)
    
    -- METHOD 9: getgc() - Scan garbage collector for script closures
    pcall(function()
        if type(getgc) == "function" then
            local before = #allScripts
            local gcItems = getgc(true) -- include tables
            for _, item in ipairs(gcItems) do
                if type(item) == "table" then
                    pcall(function()
                        for k, v in pairs(item) do
                            if typeof(v) == "Instance" and (v:IsA("BaseScript") or v:IsA("ModuleScript")) then
                                addScript(v, "gc_table")
                            end
                        end
                    end)
                end
            end
            Log("  Discovery [getgc]: +" .. (#allScripts - before))
        end
    end)
    
    Log("  TOTAL SCRIPTS DISCOVERED: " .. #allScripts)
    return allScripts
end

-- ============================================
-- MAIN DUMPER - OVERPOWERED EDITION
-- STREAMING SAVE: setiap data langsung ditulis
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
    DecompileStats = {
        total = 0, decompiled = 0, source_prop = 0,
        bytecode_saved = 0, env_dumped = 0, closure_decompiled = 0,
        module_required = 0, debug_extracted = 0, gc_recovered = 0,
        total_failed = 0, methods = {},
    }
    
    local gameName, gameId = GetGameInfo()
    local ROOT = "MapRip/" .. gameName .. "_" .. gameId
    
    Log("=== STARTING ULTIMATE MAP RIP v4.0 ===")
    Log("Game: " .. gameName .. " (ID: " .. gameId .. ")")
    Log("MODE: Streaming Save (langsung tulis per-item)")
    UpdateStatus("Initializing...")
    
    -- Create folder structure
    MakeFolder(ROOT)
    MakeFolder(ROOT .. "/Scripts/LocalScripts")
    MakeFolder(ROOT .. "/Scripts/ServerScripts")
    MakeFolder(ROOT .. "/Scripts/ModuleScripts")
    MakeFolder(ROOT .. "/Scripts/NilScripts")
    MakeFolder(ROOT .. "/Scripts/Bytecode")
    MakeFolder(ROOT .. "/Scripts/Environment")
    MakeFolder(ROOT .. "/Scripts/DebugInfo")
    MakeFolder(ROOT .. "/Hierarchy")
    MakeFolder(ROOT .. "/Properties")
    MakeFolder(ROOT .. "/Assets")
    MakeFolder(ROOT .. "/Models")
    MakeFolder(ROOT .. "/Sounds")
    MakeFolder(ROOT .. "/GUIs")
    MakeFolder(ROOT .. "/Values")
    MakeFolder(ROOT .. "/Animations")
    MakeFolder(ROOT .. "/Terrain")
    MakeFolder(ROOT .. "/Reports")
    
    -- ═══ STREAMING FILE PATHS ═══
    local STREAM = {
        combined  = ROOT .. "/Scripts/ALL_SCRIPTS.lua",
        tree      = ROOT .. "/Hierarchy/FULL_TREE.txt",
        props     = ROOT .. "/Properties/properties_001.txt",
        sounds    = ROOT .. "/Sounds/ALL_SOUNDS.txt",
        guis      = ROOT .. "/GUIs/gui_data_1.txt",
        values    = ROOT .. "/Values/ALL_VALUES.txt",
        anims     = ROOT .. "/Animations/ALL_ANIMATIONS.txt",
        models    = ROOT .. "/Models/parts_1.txt",
        assets    = ROOT .. "/Assets/ALL_ASSETS.txt",
    }
    
    -- Chunk size trackers (for splitting large files)
    local chunkSizes = {
        combined = 0, combinedNum = 1,
        props = 0, propsNum = 1,
        guis = 0, guisNum = 1,
        models = 0, modelsNum = 1,
    }
    local CHUNK_LIMIT = 400000
    
    -- Init streaming files with headers
    SafeWrite(STREAM.combined, "-- ALL SCRIPTS FROM MAP - ULTIMATE DUMP v4.0 (STREAMING)\n-- Game: " .. gameName .. "\n-- Setiap script ditulis langsung saat berhasil di-extract\n\n")
    SafeWrite(STREAM.tree, "FULL HIERARCHY TREE\nGame: " .. gameName .. " (ID: " .. gameId .. ")\n\n")
    SafeWrite(STREAM.props, "ALL PROPERTIES\nGame: " .. gameName .. "\n\n")
    SafeWrite(STREAM.sounds, "ALL SOUNDS\n" .. string.rep("=", 40) .. "\n\n")
    SafeWrite(STREAM.guis, "ALL GUI ELEMENTS\n" .. string.rep("=", 40) .. "\n\n")
    SafeWrite(STREAM.values, "ALL VALUE OBJECTS\n" .. string.rep("=", 40) .. "\n\n")
    SafeWrite(STREAM.anims, "ALL ANIMATIONS\n" .. string.rep("=", 40) .. "\n\n")
    SafeWrite(STREAM.models, "ALL MODELS/PARTS\n" .. string.rep("=", 40) .. "\n\n")
    SafeWrite(STREAM.assets, "ALL ASSET IDS FROM MAP\n" .. string.rep("=", 60) .. "\n\n")
    
    -- Helper: append to chunked file
    local function StreamAppend(key, content)
        SafeAppend(STREAM[key], content)
        chunkSizes[key] = (chunkSizes[key] or 0) + #content
        
        -- Auto-split jika terlalu besar
        if chunkSizes[key] and chunkSizes[key] > CHUNK_LIMIT then
            if key == "combined" then
                chunkSizes.combinedNum = chunkSizes.combinedNum + 1
                STREAM.combined = ROOT .. "/Scripts/ALL_SCRIPTS_part" .. chunkSizes.combinedNum .. ".lua"
                SafeWrite(STREAM.combined, "-- ALL SCRIPTS (Part " .. chunkSizes.combinedNum .. ")\n\n")
            elseif key == "props" then
                chunkSizes.propsNum = chunkSizes.propsNum + 1
                STREAM.props = ROOT .. "/Properties/properties_" .. string.format("%03d", chunkSizes.propsNum) .. ".txt"
                SafeWrite(STREAM.props, "")
            elseif key == "guis" then
                chunkSizes.guisNum = chunkSizes.guisNum + 1
                STREAM.guis = ROOT .. "/GUIs/gui_data_" .. chunkSizes.guisNum .. ".txt"
                SafeWrite(STREAM.guis, "")
            elseif key == "models" then
                chunkSizes.modelsNum = chunkSizes.modelsNum + 1
                STREAM.models = ROOT .. "/Models/parts_" .. chunkSizes.modelsNum .. ".txt"
                SafeWrite(STREAM.models, "")
            end
            chunkSizes[key] = 0
        end
    end
    
    -- ALL containers to scan
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
    pcall(function() table.insert(services, {game:GetService("Chat"), "Chat"}) end)
    pcall(function() table.insert(services, {game:GetService("LocalizationService"), "LocalizationService"}) end)
    pcall(function() table.insert(services, {game:GetService("TestService"), "TestService"}) end)
    pcall(function() table.insert(services, {game:GetService("ServerStorage"), "ServerStorage"}) end)
    pcall(function() table.insert(services, {game:GetService("ServerScriptService"), "ServerScriptService"}) end)
    
    local scriptCounter = 0
    local processedScripts = {}
    
    -- ========== RECURSIVE SCANNER (STREAMING) ==========
    local function ScanRecursive(instance, path, depth, serviceName)
        if depth > 100 then return end
        
        totalInstances = totalInstances + 1
        
        local name = SafeName(instance.Name)
        local className = instance.ClassName
        local fullPath = path .. "/" .. name
        local fullName = instance:GetFullName()
        
        -- ═══ STREAM: Tree ═══
        local indent = string.rep("│ ", depth)
        SafeAppend(STREAM.tree, indent .. "├─ [" .. className .. "] " .. instance.Name .. "\n")
        
        -- Collect assets
        CollectAssets(instance)
        
        -- ═══ SCRIPTS: Process + SAVE IMMEDIATELY ═══
        if (instance:IsA("BaseScript") or instance:IsA("ModuleScript")) and not processedScripts[instance] then
            processedScripts[instance] = true
            totalScripts = totalScripts + 1
            scriptCounter = scriptCounter + 1
            
            local decompResult = UltimateDecompile(instance)
            
            local scriptType = "ServerScripts"
            local ext = ".server.lua"
            local typeLabel = "Server"
            
            if instance:IsA("LocalScript") then
                scriptType = "LocalScripts"
                ext = ".client.lua"
                typeLabel = "Local"
            elseif instance:IsA("ModuleScript") then
                scriptType = "ModuleScripts"
                ext = ".module.lua"
                typeLabel = "Module"
            end
            
            local header = string.format(
                "-- ============================================================\n" ..
                "-- SCRIPT: %s\n" ..
                "-- TYPE: %s (%s)\n" ..
                "-- PATH: %s\n" ..
                "-- PARENT: %s [%s]\n" ..
                "-- SERVICE: %s\n" ..
                "-- ENABLED: %s\n" ..
                "-- METHOD: %s\n" ..
                "-- LAYERS: %s\n" ..
                "-- ============================================================\n\n",
                instance.Name, typeLabel, className, fullName,
                instance.Parent and instance.Parent.Name or "nil",
                instance.Parent and instance.Parent.ClassName or "nil",
                serviceName,
                tostring(pcall(function() return instance.Enabled end) and (instance.Enabled ~= false) or "N/A"),
                decompResult.method,
                table.concat(decompResult.layers or {}, " → ")
            )
            
            local scriptContent = header .. (decompResult.source or "-- EMPTY")
            
            -- ✅ SAVE INDIVIDUAL FILE IMMEDIATELY
            local fileName = string.format("%04d", scriptCounter) .. "_" .. name .. ext
            SafeWrite(ROOT .. "/Scripts/" .. scriptType .. "/" .. fileName, scriptContent)
            
            -- ✅ APPEND TO COMBINED FILE IMMEDIATELY
            local combinedEntry = string.format(
                "\n\n%s\n-- [%d] %s (%s) [%s]\n-- Path: %s\n-- Service: %s\n%s\n",
                string.rep("=", 70), scriptCounter,
                instance.Name, className, decompResult.method,
                fullName, serviceName, string.rep("=", 70)
            ) .. (decompResult.source or "-- EMPTY") .. "\n"
            StreamAppend("combined", combinedEntry)
            
            -- ✅ SAVE BYTECODE IMMEDIATELY
            if decompResult.bytecodeB64 then
                SafeWrite(ROOT .. "/Scripts/Bytecode/" .. string.format("%04d", scriptCounter) .. "_" .. name .. ".b64", decompResult.bytecodeB64)
                if decompResult.bytecodeHex then
                    SafeWrite(ROOT .. "/Scripts/Bytecode/" .. string.format("%04d", scriptCounter) .. "_" .. name .. ".hex", decompResult.bytecodeHex)
                end
            end
            
            -- ✅ SAVE ENV IMMEDIATELY
            if decompResult.envDump then
                SafeWrite(ROOT .. "/Scripts/Environment/" .. string.format("%04d", scriptCounter) .. "_" .. name .. "_env.lua", decompResult.envDump)
            end
            
            -- ✅ SAVE DEBUG INFO IMMEDIATELY
            if decompResult.debugInfo and decompResult.debugInfo.lines and #decompResult.debugInfo.lines > 0 then
                SafeWrite(ROOT .. "/Scripts/DebugInfo/" .. string.format("%04d", scriptCounter) .. "_" .. name .. "_debug.txt",
                    table.concat(decompResult.debugInfo.lines, "\n"))
            end
            
            local icon = "✅"
            if decompResult.method == "failed" then icon = "❌"
            elseif decompResult.method == "fallback_composite" then icon = "⚠️"
            elseif decompResult.method:find("bytecode") then icon = "📦"
            end
            
            Log(icon .. " #" .. scriptCounter .. " [" .. decompResult.method .. "] " .. instance.Name .. " → SAVED")
        end
        
        -- ═══ STREAM: Sounds ═══
        if instance:IsA("Sound") then
            local soundInfo = string.format("Name: %s\nPath: %s\nSoundId: %s\nVolume: %s\nLooped: %s\nPlaybackSpeed: %s\n%s\n",
                instance.Name, fullName,
                tostring(pcall(function() return instance.SoundId end) and instance.SoundId or "?"),
                tostring(pcall(function() return instance.Volume end) and instance.Volume or "?"),
                tostring(pcall(function() return instance.Looped end) and instance.Looped or "?"),
                tostring(pcall(function() return instance.PlaybackSpeed end) and instance.PlaybackSpeed or "?"),
                string.rep("-", 30)
            )
            SafeAppend(STREAM.sounds, soundInfo)
        end
        
        -- ═══ STREAM: GUI Elements ═══
        if instance:IsA("GuiObject") or instance:IsA("ScreenGui") or instance:IsA("BillboardGui") or instance:IsA("SurfaceGui") then
            local guiInfo = string.format("[%s] %s\n  Path: %s\n", className, instance.Name, fullName)
            local props = GetAllProperties(instance)
            for k, v in pairs(props) do
                guiInfo = guiInfo .. "  " .. k .. " = " .. v .. "\n"
            end
            StreamAppend("guis", guiInfo .. "\n")
        end
        
        -- ═══ STREAM: Value Objects ═══
        if instance:IsA("ValueBase") then
            local valOk, valVal = pcall(function() return instance.Value end)
            SafeAppend(STREAM.values, string.format("[%s] %s = %s\n  Path: %s\n\n",
                className, instance.Name, valOk and tostring(valVal) or "?", fullName))
        end
        
        -- ═══ STREAM: Animations ═══
        if instance:IsA("Animation") or instance:IsA("AnimationTrack") or className == "Animator" then
            local animId = ""
            pcall(function() animId = instance.AnimationId end)
            SafeAppend(STREAM.anims, string.format("[%s] %s\n  Path: %s\n  AnimationId: %s\n\n",
                className, instance.Name, fullName, animId))
        end
        
        -- ═══ STREAM: Models/Parts ═══
        if instance:IsA("BasePart") then
            local props = GetAllProperties(instance)
            local modelInfo = string.format("[%s] %s\n  Path: %s\n", className, instance.Name, fullName)
            for k, v in pairs(props) do
                modelInfo = modelInfo .. "  " .. k .. " = " .. v .. "\n"
            end
            StreamAppend("models", modelInfo .. "\n")
        end
        
        -- ═══ STREAM: Properties ═══
        local propsLine = string.format("\n=== [%s] %s ===\nPath: %s\n", className, instance.Name, fullName)
        local props = GetAllProperties(instance)
        for k, v in pairs(props) do
            propsLine = propsLine .. "  " .. k .. " = " .. v .. "\n"
        end
        StreamAppend("props", propsLine)
        
        -- Yield
        if totalInstances % 150 == 0 then
            task.wait()
            UpdateStatus("Scanning " .. serviceName .. "... (" .. totalInstances .. " | " .. scriptCounter .. " scripts saved)")
            UpdateProgress()
        end
        
        -- Scan children
        local children = {}
        pcall(function() children = instance:GetChildren() end)
        
        for _, child in ipairs(children) do
            local skip = false
            if child == LocalPlayer.Character then skip = true end
            if child:IsA("Camera") and child.Parent == Workspace then skip = true end
            if not skip then
                ScanRecursive(child, fullPath, depth + 1, serviceName)
            end
        end
    end
    
    -- ========== PHASE 1: SCAN ALL SERVICES ==========
    Log(">>> PHASE 1: Scanning Services (streaming save)...")
    for _, svc in ipairs(services) do
        local container, svcName = svc[1], svc[2]
        Log(">>> Scanning: " .. svcName)
        UpdateStatus("Scanning: " .. svcName)
        
        SafeAppend(STREAM.tree, "\n" .. string.rep("=", 60) .. "\nSERVICE: " .. svcName .. "\n" .. string.rep("=", 60) .. "\n")
        
        pcall(function()
            for _, child in ipairs(container:GetChildren()) do
                ScanRecursive(child, svcName, 1, svcName)
            end
        end)
    end
    
    -- ========== PHASE 2: SCAN PLAYER DATA ==========
    Log(">>> PHASE 2: Scanning Player data...")
    UpdateStatus("Scanning Player data...")
    pcall(function()
        SafeAppend(STREAM.tree, "\n" .. string.rep("=", 60) .. "\nPLAYER DATA: " .. LocalPlayer.Name .. "\n" .. string.rep("=", 60) .. "\n")
        
        pcall(function()
            for _, child in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
                ScanRecursive(child, "PlayerGui", 1, "PlayerGui")
            end
        end)
        pcall(function()
            for _, child in ipairs(LocalPlayer.Backpack:GetChildren()) do
                ScanRecursive(child, "Backpack", 1, "Backpack")
            end
        end)
        pcall(function()
            for _, child in ipairs(LocalPlayer.PlayerScripts:GetChildren()) do
                ScanRecursive(child, "PlayerScripts", 1, "PlayerScripts")
            end
        end)
    end)
    
    -- ========== PHASE 3: EXTRA SCRIPT DISCOVERY ==========
    Log(">>> PHASE 3: Extra Script Discovery (nil/running/gc)...")
    UpdateStatus("Extra Discovery: nil, running, gc...")
    
    local extraScripts = DiscoverAllScripts()
    local extraFound = 0
    
    for _, entry in ipairs(extraScripts) do
        local obj = entry.instance
        local discoverySource = entry.source
        
        if not processedScripts[obj] then
            processedScripts[obj] = true
            extraFound = extraFound + 1
            totalScripts = totalScripts + 1
            scriptCounter = scriptCounter + 1
            
            local decompResult = UltimateDecompile(obj)
            
            local scriptType = "ServerScripts"
            local ext = ".server.lua"
            local typeLabel = "Server"
            
            if obj:IsA("LocalScript") then
                scriptType = "LocalScripts"
                ext = ".client.lua"
                typeLabel = "Local"
            elseif obj:IsA("ModuleScript") then
                scriptType = "ModuleScripts"
                ext = ".module.lua"
                typeLabel = "Module"
            end
            
            local isNil = false
            pcall(function() isNil = obj.Parent == nil end)
            if isNil then scriptType = "NilScripts" end
            
            local fullName = "unknown"
            pcall(function() fullName = obj:GetFullName() end)
            
            local header = string.format(
                "-- ============================================================\n" ..
                "-- SCRIPT: %s\n" ..
                "-- TYPE: %s (%s)\n" ..
                "-- PATH: %s\n" ..
                "-- DISCOVERY: %s\n" ..
                "-- NIL_INSTANCE: %s\n" ..
                "-- METHOD: %s\n" ..
                "-- LAYERS: %s\n" ..
                "-- ============================================================\n\n",
                obj.Name, typeLabel, obj.ClassName, fullName,
                discoverySource, tostring(isNil),
                decompResult.method,
                table.concat(decompResult.layers or {}, " → ")
            )
            
            local name = SafeName(obj.Name)
            
            -- ✅ SAVE IMMEDIATELY
            local fileName = string.format("%04d", scriptCounter) .. "_EXTRA_" .. name .. ext
            SafeWrite(ROOT .. "/Scripts/" .. scriptType .. "/" .. fileName, header .. (decompResult.source or "-- EMPTY"))
            
            -- ✅ APPEND TO COMBINED IMMEDIATELY
            local combinedEntry = string.format(
                "\n\n%s\n-- [%d] EXTRA %s (%s) [%s] from %s\n-- Path: %s\n%s\n",
                string.rep("=", 70), scriptCounter,
                obj.Name, obj.ClassName, decompResult.method,
                discoverySource, fullName, string.rep("=", 70)
            ) .. (decompResult.source or "-- EMPTY") .. "\n"
            StreamAppend("combined", combinedEntry)
            
            if decompResult.bytecodeB64 then
                SafeWrite(ROOT .. "/Scripts/Bytecode/" .. string.format("%04d", scriptCounter) .. "_" .. name .. ".b64", decompResult.bytecodeB64)
            end
            if decompResult.envDump then
                SafeWrite(ROOT .. "/Scripts/Environment/" .. string.format("%04d", scriptCounter) .. "_" .. name .. "_env.lua", decompResult.envDump)
            end
            
            Log("🔍 EXTRA #" .. scriptCounter .. " [" .. discoverySource .. "] " .. obj.Name .. " → SAVED")
            
            if extraFound % 5 == 0 then
                task.wait()
                UpdateProgress()
            end
        end
    end
    Log("Extra scripts found: " .. extraFound)
    
    -- ========== PHASE 4: FINAL DATA (assets + report + summary) ==========
    UpdateStatus("Saving final data...")
    Log(">>> PHASE 4: Final data...")
    
    -- Assets (collected during scan, write now)
    local assetText = ""
    for id, info in pairs(assetList) do
        assetText = assetText .. string.format("Asset: %s\n  Property: %s\n  Instance: %s\n  Class: %s\n\n",
            id, info.property, info.instance, info.className)
    end
    SafeAppend(STREAM.assets, assetText)
    
    -- saveinstance
    pcall(function()
        if saveinstance then
            UpdateStatus("Saving full instance (RBXLX)...")
            Log("Attempting saveinstance...")
            saveinstance({
                FilePath = ROOT .. "/FULL_MAP.rbxlx",
                Decompile = true,
                DecompileTimeout = 30,
                NilInstances = true,
                RemovePlayerCharacters = true,
                ExcludePlayerCharacter = true,
                ExcludePlayerGui = false,
                IsolateStarterPlayer = false,
                ShowStatus = true,
                SaveBytecode = true,
                mode = "full",
            })
            Log("Full .rbxlx saved!")
        end
    end)
    
    -- Decompile Report
    local reportLines = {}
    reportLines[#reportLines+1] = string.rep("=", 60)
    reportLines[#reportLines+1] = "  DECOMPILE REPORT - ULTIMATE MAP DUMPER v4.0"
    reportLines[#reportLines+1] = string.rep("=", 60)
    reportLines[#reportLines+1] = ""
    reportLines[#reportLines+1] = "Game: " .. gameName .. " (ID: " .. gameId .. ")"
    reportLines[#reportLines+1] = "Date: " .. os.date("%Y-%m-%d %H:%M:%S")
    reportLines[#reportLines+1] = "Player: " .. LocalPlayer.Name
    reportLines[#reportLines+1] = ""
    reportLines[#reportLines+1] = "=== EXECUTOR CAPABILITIES ==="
    reportLines[#reportLines+1] = "  decompile:           " .. tostring(HAS_DECOMPILE)
    reportLines[#reportLines+1] = "  getscriptbytecode:   " .. tostring(HAS_GETSCRIPTBYTECODE)
    reportLines[#reportLines+1] = "  getscripthash:       " .. tostring(HAS_GETSCRIPTHASH)
    reportLines[#reportLines+1] = "  getscriptclosure:    " .. tostring(HAS_GETSCRIPTCLOSURE)
    reportLines[#reportLines+1] = "  getsenv:             " .. tostring(HAS_GETSENV)
    reportLines[#reportLines+1] = "  getnilinstances:     " .. tostring(HAS_GETNILINSTANCES)
    reportLines[#reportLines+1] = "  getrunningscripts:   " .. tostring(HAS_GETRUNNINGSCRIPTS)
    reportLines[#reportLines+1] = "  getloadedmodules:    " .. tostring(HAS_GETLOADEDMODULES)
    reportLines[#reportLines+1] = "  getgc:               " .. tostring(HAS_GETGC)
    reportLines[#reportLines+1] = "  getinstances:        " .. tostring(HAS_GETINSTANCES)
    reportLines[#reportLines+1] = "  debug.getconstants:  " .. tostring(HAS_DEBUG_GETCONSTANTS)
    reportLines[#reportLines+1] = "  debug.getupvalues:   " .. tostring(HAS_DEBUG_GETUPVALUES)
    reportLines[#reportLines+1] = "  debug.getprotos:     " .. tostring(HAS_DEBUG_GETPROTOS)
    reportLines[#reportLines+1] = "  debug.info:          " .. tostring(HAS_DEBUG_GETINFO)
    reportLines[#reportLines+1] = "  saveinstance:        " .. tostring(type(saveinstance) == "function")
    reportLines[#reportLines+1] = ""
    reportLines[#reportLines+1] = "=== STATISTICS ==="
    reportLines[#reportLines+1] = "  Total Scripts:          " .. DecompileStats.total
    reportLines[#reportLines+1] = "  Decompiled:             " .. DecompileStats.decompiled
    reportLines[#reportLines+1] = "  Source Property:        " .. DecompileStats.source_prop
    reportLines[#reportLines+1] = "  Closure Decompiled:     " .. DecompileStats.closure_decompiled
    reportLines[#reportLines+1] = "  Module Required:        " .. DecompileStats.module_required
    reportLines[#reportLines+1] = "  Bytecode Saved:         " .. DecompileStats.bytecode_saved
    reportLines[#reportLines+1] = "  Env Dumped:             " .. DecompileStats.env_dumped
    reportLines[#reportLines+1] = "  Debug Extracted:        " .. DecompileStats.debug_extracted
    reportLines[#reportLines+1] = "  GC Recovered:           " .. DecompileStats.gc_recovered
    reportLines[#reportLines+1] = "  Total Failed:           " .. DecompileStats.total_failed
    
    local successRate = 0
    if DecompileStats.total > 0 then
        local success = DecompileStats.decompiled + DecompileStats.source_prop + DecompileStats.closure_decompiled + DecompileStats.module_required
        successRate = math.floor(success / DecompileStats.total * 100)
    end
    local dataRate = 0
    if DecompileStats.total > 0 then
        dataRate = math.floor((DecompileStats.total - DecompileStats.total_failed) / DecompileStats.total * 100)
    end
    reportLines[#reportLines+1] = ""
    reportLines[#reportLines+1] = "  SUCCESS RATE:           " .. successRate .. "%"
    reportLines[#reportLines+1] = "  DATA RATE:              " .. dataRate .. "%"
    reportLines[#reportLines+1] = ""
    reportLines[#reportLines+1] = "=== PER-SCRIPT RESULTS ==="
    for scriptPath, method in pairs(DecompileStats.methods) do
        local icon = "[OK]"
        if method == "failed" then icon = "[FAIL]"
        elseif method == "fallback_composite" then icon = "[PARTIAL]"
        elseif method:find("bytecode") then icon = "[BYTES]" end
        reportLines[#reportLines+1] = "  " .. icon .. " [" .. method .. "] " .. scriptPath
    end
    reportLines[#reportLines+1] = ""
    reportLines[#reportLines+1] = "=== GENERAL ==="
    reportLines[#reportLines+1] = "  Total Instances:        " .. totalInstances
    reportLines[#reportLines+1] = "  Total Scripts:          " .. totalScripts
    reportLines[#reportLines+1] = "  Extra Scripts:          " .. extraFound
    reportLines[#reportLines+1] = "  Total Assets:           " .. totalAssets
    reportLines[#reportLines+1] = "  Total Files:            " .. totalFiles
    
    SafeWrite(ROOT .. "/Reports/DECOMPILE_REPORT.txt", table.concat(reportLines, "\n"))
    
    -- Summary
    local summary = string.format(
        "ULTIMATE MAP RIP v4.0 - SUMMARY\n" ..
        string.rep("=", 50) .. "\n" ..
        "Game: %s | ID: %d\n" ..
        "Date: %s | By: %s\n" ..
        "Scripts: %d | Success: %d%% | Data: %d%%\n" ..
        "Instances: %d | Assets: %d | Files: %d\n" ..
        "Extra (hidden): %d\n" ..
        string.rep("=", 50) .. "\n",
        gameName, game.PlaceId,
        os.date("%Y-%m-%d %H:%M:%S"), LocalPlayer.Name,
        DecompileStats.total, successRate, dataRate,
        totalInstances, totalAssets, totalFiles, extraFound
    )
    SafeWrite(ROOT .. "/SUMMARY.txt", summary)
    
    -- Done!
    Log("=== RIP COMPLETE ===")
    Log(string.format("Total: %d instances, %d scripts (%d%% success), %d files",
        totalInstances, totalScripts, successRate, totalFiles))
    UpdateStatus("✅ COMPLETE! " .. totalFiles .. " files | " .. successRate .. "% decompiled")
    UpdateProgress()
    
    DUMP_RUNNING = false
    return ROOT
end

-- ============================================
-- SCRIPTS ONLY DEEP DUMP (STREAMING SAVE)
-- ============================================
local function ScriptsOnlyDump()
    if DUMP_RUNNING then return end
    DUMP_RUNNING = true
    
    local gameName, gameId = GetGameInfo()
    local ROOT = "MapRip/" .. gameName .. "_" .. gameId .. "_SCRIPTS_ONLY"
    MakeFolder(ROOT)
    MakeFolder(ROOT .. "/LocalScripts")
    MakeFolder(ROOT .. "/ServerScripts")
    MakeFolder(ROOT .. "/ModuleScripts")
    MakeFolder(ROOT .. "/NilScripts")
    MakeFolder(ROOT .. "/Bytecode")
    MakeFolder(ROOT .. "/Environment")
    MakeFolder(ROOT .. "/ByFolder")
    
    DecompileStats = {
        total = 0, decompiled = 0, source_prop = 0,
        bytecode_saved = 0, env_dumped = 0, closure_decompiled = 0,
        module_required = 0, debug_extracted = 0, gc_recovered = 0,
        total_failed = 0, methods = {},
    }
    
    local scriptCount = 0
    local localCount = 0
    local serverCount = 0
    local moduleCount = 0
    local fileCount = 0
    
    -- ═══ STREAMING: init combined file ═══
    local combinedPath = ROOT .. "/ALL_SCRIPTS_combined.lua"
    local combinedPartNum = 1
    local combinedSize = 0
    local CHUNK_LIMIT = 600000
    
    SafeWrite(combinedPath, string.format(
        "-- ALL GAME SCRIPTS - ULTIMATE DUMP v4.0 (STREAMING)\n" ..
        "-- Game: %s (ID: %d)\n" ..
        "-- Date: %s\n" ..
        "-- Setiap script ditulis langsung saat berhasil di-extract\n\n",
        gameName, gameId, os.date("%Y-%m-%d %H:%M:%S")
    ))
    fileCount = fileCount + 1
    
    -- ═══ STREAMING: init index file ═══
    local indexPath = ROOT .. "/INDEX.txt"
    SafeWrite(indexPath, string.format(
        "ULTIMATE SCRIPTS DUMP - LIVE INDEX\n" ..
        string.rep("=", 60) .. "\n" ..
        "Game: %s (ID: %d)\n" ..
        "Date: %s\n" ..
        "(stats update di akhir proses)\n\n" ..
        string.rep("=", 60) .. "\n\n",
        gameName, gameId, os.date("%Y-%m-%d %H:%M:%S")
    ))
    fileCount = fileCount + 1
    
    Log("=== ULTIMATE SCRIPTS DUMP (STREAMING) ===")
    Log("Setiap script langsung disave saat berhasil di-extract")
    UpdateStatus("Discovering ALL scripts...")
    
    local allScripts = DiscoverAllScripts()
    local total = #allScripts
    
    Log("Found " .. total .. " scripts. Starting extraction + streaming save...")
    
    for idx, entry in ipairs(allScripts) do
        local obj = entry.instance
        local discoverySource = entry.source
        
        scriptCount = scriptCount + 1
        
        UpdateStatus(string.format("Decompiling %d/%d: %s", idx, total, obj.Name))
        
        local decompResult = UltimateDecompile(obj)
        local name = SafeName(obj.Name)
        local fullPath = "unknown"
        pcall(function() fullPath = obj:GetFullName() end)
        
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
        
        local isNil = false
        pcall(function() isNil = obj.Parent == nil end)
        if isNil then folder = "NilScripts" end
        
        local header = string.format(
            "-- ============================================================\n" ..
            "-- SCRIPT: %s\n" ..
            "-- TYPE: %s (%s)\n" ..
            "-- PATH: %s\n" ..
            "-- PARENT: %s [%s]\n" ..
            "-- DISCOVERY: %s\n" ..
            "-- NIL_INSTANCE: %s\n" ..
            "-- METHOD: %s\n" ..
            "-- ENABLED: %s\n" ..
            "-- LAYERS: %s\n" ..
            "-- ============================================================\n\n",
            obj.Name, typeLabel, obj.ClassName, fullPath,
            obj.Parent and obj.Parent.Name or "nil",
            obj.Parent and obj.Parent.ClassName or "nil",
            discoverySource, tostring(isNil),
            decompResult.method,
            tostring(pcall(function() return obj.Enabled end) and (obj.Enabled ~= false) or "N/A"),
            table.concat(decompResult.layers or {}, " → ")
        )
        
        local scriptContent = header .. (decompResult.source or "-- EMPTY")
        
        -- ✅ SAVE INDIVIDUAL FILE IMMEDIATELY
        local fileName = string.format("%04d", scriptCount) .. "_" .. name .. ext
        SafeWrite(ROOT .. "/" .. folder .. "/" .. fileName, scriptContent)
        fileCount = fileCount + 1
        
        -- ✅ APPEND TO COMBINED FILE IMMEDIATELY
        local combinedEntry = string.format(
            "\n\n%s\n-- [%d/%d] %s (%s) [%s] from %s\n-- Path: %s\n%s\n",
            string.rep("=", 70), scriptCount, total,
            obj.Name, obj.ClassName, decompResult.method,
            discoverySource, fullPath, string.rep("=", 70)
        ) .. (decompResult.source or "-- EMPTY") .. "\n"
        
        SafeAppend(combinedPath, combinedEntry)
        combinedSize = combinedSize + #combinedEntry
        
        -- Auto-split combined if too large
        if combinedSize > CHUNK_LIMIT then
            combinedPartNum = combinedPartNum + 1
            combinedPath = ROOT .. "/ALL_SCRIPTS_combined_part" .. combinedPartNum .. ".lua"
            SafeWrite(combinedPath, "-- ALL SCRIPTS (Part " .. combinedPartNum .. ")\n\n")
            fileCount = fileCount + 1
            combinedSize = 0
        end
        
        -- ✅ SAVE BYTECODE IMMEDIATELY
        if decompResult.bytecodeB64 then
            SafeWrite(ROOT .. "/Bytecode/" .. string.format("%04d", scriptCount) .. "_" .. name .. ".b64", decompResult.bytecodeB64)
            fileCount = fileCount + 1
        end
        
        -- ✅ SAVE ENV IMMEDIATELY
        if decompResult.envDump then
            SafeWrite(ROOT .. "/Environment/" .. string.format("%04d", scriptCount) .. "_" .. name .. "_env.lua", decompResult.envDump)
            fileCount = fileCount + 1
        end
        
        -- ✅ SAVE BY-FOLDER IMMEDIATELY
        local svcName = discoverySource:match("service:(.+)") or discoverySource
        local folderKey = SafeName(svcName .. "/" .. (obj.Parent and obj.Parent.Name or "root"))
        local byFolderPath = ROOT .. "/ByFolder/" .. folderKey
        MakeFolder(byFolderPath)
        SafeWrite(byFolderPath .. "/" .. name .. "_" .. scriptCount .. ext, scriptContent)
        fileCount = fileCount + 1
        
        -- ✅ APPEND TO INDEX IMMEDIATELY
        local icon = "[OK]"
        if decompResult.method == "failed" then icon = "[FAIL]"
        elseif decompResult.method == "fallback_composite" then icon = "[PARTIAL]" end
        
        SafeAppend(indexPath, string.format("  %s %d. [%s] %s (%s)\n     Path: %s\n     From: %s\n\n",
            icon, scriptCount, obj.ClassName, obj.Name, decompResult.method, fullPath, discoverySource))
        
        -- Log icon
        local logIcon = "✅"
        if decompResult.method == "failed" then logIcon = "❌"
        elseif decompResult.method == "fallback_composite" then logIcon = "⚠️" end
        
        Log(logIcon .. " [" .. typeLabel .. "] " .. obj.Name .. " → SAVED")
        
        if scriptCount % 3 == 0 then
            task.wait(0.1)
            UpdateProgress()
        end
        if scriptCount % 15 == 0 then
            task.wait(0.3)
        end
    end
    
    -- ═══ FINAL: Update index with final stats ═══
    local successRate = DecompileStats.total > 0 and math.floor((DecompileStats.decompiled + DecompileStats.source_prop + DecompileStats.closure_decompiled + DecompileStats.module_required) / DecompileStats.total * 100) or 0
    
    SafeAppend(indexPath, string.format(
        "\n" .. string.rep("=", 60) .. "\n" ..
        "FINAL STATS:\n" ..
        "  Total: %d (Local: %d, Server: %d, Module: %d)\n" ..
        "  Success Rate: %d%%\n" ..
        "  Decompiled: %d | Source: %d | Closure: %d | Module: %d\n" ..
        "  Bytecode: %d | Env: %d | Debug: %d | GC: %d\n" ..
        "  Failed: %d\n" ..
        "  Files Written: %d\n",
        scriptCount, localCount, serverCount, moduleCount,
        successRate,
        DecompileStats.decompiled, DecompileStats.source_prop,
        DecompileStats.closure_decompiled, DecompileStats.module_required,
        DecompileStats.bytecode_saved, DecompileStats.env_dumped,
        DecompileStats.debug_extracted, DecompileStats.gc_recovered,
        DecompileStats.total_failed, fileCount
    ))
    
    Log("=== SCRIPTS DUMP COMPLETE ===")
    Log(string.format("Found %d scripts (L:%d S:%d M:%d) | Success: %d%%",
        scriptCount, localCount, serverCount, moduleCount, successRate))
    UpdateStatus("✅ " .. scriptCount .. " scripts | " .. successRate .. "% decompiled | " .. fileCount .. " files")
    
    DUMP_RUNNING = false
    return ROOT, scriptCount, fileCount, successRate
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
    
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Size = UDim2.new(0.92, 0, 0.78, 0)
    Main.Position = UDim2.new(0.04, 0, 0.10, 0)
    Main.BackgroundColor3 = Color3.fromRGB(12, 12, 22)
    Main.BorderSizePixel = 0
    Main.Parent = Gui
    
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)
    local stroke = Instance.new("UIStroke", Main)
    stroke.Color = Color3.fromRGB(180, 50, 255)
    stroke.Thickness = 2
    
    local Title = Instance.new("Frame")
    Title.Size = UDim2.new(1, 0, 0, 48)
    Title.BackgroundColor3 = Color3.fromRGB(25, 10, 55)
    Title.BorderSizePixel = 0
    Title.Parent = Main
    Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 14)
    
    local TitleFix = Instance.new("Frame")
    TitleFix.Size = UDim2.new(1, 0, 0, 14)
    TitleFix.Position = UDim2.new(0, 0, 1, -14)
    TitleFix.BackgroundColor3 = Color3.fromRGB(25, 10, 55)
    TitleFix.BorderSizePixel = 0
    TitleFix.Parent = Title
    
    local TitleText = Instance.new("TextLabel")
    TitleText.Text = "💀 ULTIMATE MAP RIPPER v4.0 OP"
    TitleText.Size = UDim2.new(0.70, 0, 1, 0)
    TitleText.Position = UDim2.new(0.03, 0, 0, 0)
    TitleText.BackgroundTransparency = 1
    TitleText.TextColor3 = Color3.fromRGB(230, 140, 255)
    TitleText.TextSize = 15
    TitleText.Font = Enum.Font.GothamBold
    TitleText.TextXAlignment = Enum.TextXAlignment.Left
    TitleText.Parent = Title
    
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
    
    local Content = Instance.new("ScrollingFrame")
    Content.Size = UDim2.new(1, -16, 1, -56)
    Content.Position = UDim2.new(0, 8, 0, 52)
    Content.BackgroundTransparency = 1
    Content.BorderSizePixel = 0
    Content.ScrollBarThickness = 4
    Content.ScrollBarImageColor3 = Color3.fromRGB(180, 50, 255)
    Content.CanvasSize = UDim2.new(0, 0, 0, 1000)
    Content.Parent = Main
    
    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 6)
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Parent = Content
    
    local gameInfo = Instance.new("TextLabel")
    gameInfo.Text = "🎮 Place: " .. game.PlaceId .. " | Game: " .. game.GameId
    gameInfo.Size = UDim2.new(1, 0, 0, 22)
    gameInfo.BackgroundTransparency = 1
    gameInfo.TextColor3 = Color3.fromRGB(170, 170, 200)
    gameInfo.TextSize = 11
    gameInfo.Font = Enum.Font.Gotham
    gameInfo.LayoutOrder = 1
    gameInfo.Parent = Content
    
    local capText = "🔧 "
    if HAS_DECOMPILE then capText = capText .. "decompile ✅ " else capText = capText .. "decompile ❌ " end
    if HAS_GETSENV then capText = capText .. "getsenv ✅ " else capText = capText .. "getsenv ❌ " end
    if HAS_GETSCRIPTBYTECODE then capText = capText .. "bytecode ✅ " else capText = capText .. "bytecode ❌ " end
    if HAS_GETNILINSTANCES then capText = capText .. "nil ✅" else capText = capText .. "nil ❌" end
    
    local capLabel = Instance.new("TextLabel")
    capLabel.Text = capText
    capLabel.Size = UDim2.new(1, 0, 0, 18)
    capLabel.BackgroundTransparency = 1
    capLabel.TextColor3 = Color3.fromRGB(140, 140, 170)
    capLabel.TextSize = 9
    capLabel.Font = Enum.Font.Code
    capLabel.TextWrapped = true
    capLabel.LayoutOrder = 2
    capLabel.Parent = Content
    
    statusLabel = Instance.new("TextLabel")
    statusLabel.Text = "⏸️ Ready - Streaming Save Active"
    statusLabel.Size = UDim2.new(1, 0, 0, 28)
    statusLabel.BackgroundColor3 = Color3.fromRGB(20, 30, 20)
    statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    statusLabel.TextSize = 11
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.LayoutOrder = 3
    statusLabel.Parent = Content
    Instance.new("UICorner", statusLabel).CornerRadius = UDim.new(0, 6)
    
    progressLabel = Instance.new("TextLabel")
    progressLabel.Text = "Inst: 0 | Scripts: 0 | Assets: 0 | Files: 0 | OK: 0 | Fail: 0"
    progressLabel.Size = UDim2.new(1, 0, 0, 18)
    progressLabel.BackgroundTransparency = 1
    progressLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
    progressLabel.TextSize = 9
    progressLabel.Font = Enum.Font.Code
    progressLabel.TextWrapped = true
    progressLabel.LayoutOrder = 4
    progressLabel.Parent = Content
    
    local function MakeButton(text, color, order)
        local btn = Instance.new("TextButton")
        btn.Text = text
        btn.Size = UDim2.new(1, 0, 0, 46)
        btn.BackgroundColor3 = color
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 13
        btn.Font = Enum.Font.GothamBold
        btn.BorderSizePixel = 0
        btn.LayoutOrder = order
        btn.Parent = Content
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
        return btn
    end
    
    local DumpAllBtn = MakeButton("⬇️ RIP EVERYTHING (Streaming Save)", Color3.fromRGB(140, 20, 220), 10)
    local ScriptsDeepBtn = MakeButton("📜 SCRIPTS ONLY (Streaming Save)", Color3.fromRGB(220, 100, 0), 11)
    local SaveInstanceBtn = MakeButton("💾 SAVE FULL MAP (.rbxlx)", Color3.fromRGB(200, 80, 30), 12)
    local ClipboardBtn = MakeButton("📋 COPY ALL SCRIPTS TO CLIPBOARD", Color3.fromRGB(30, 130, 80), 13)
    local TreeOnlyBtn = MakeButton("🌳 EXPORT TREE STRUCTURE ONLY", Color3.fromRGB(30, 80, 150), 14)
    
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(0.9, 0, 0, 1)
    sep.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    sep.BorderSizePixel = 0
    sep.LayoutOrder = 15
    sep.Parent = Content
    
    local locInfo = Instance.new("TextLabel")
    locInfo.Text = "📁 Output: /sdcard/[Executor]/workspace/MapRip/\n🔥 STREAMING: file langsung tersedia tanpa tunggu selesai!"
    locInfo.Size = UDim2.new(1, 0, 0, 40)
    locInfo.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
    locInfo.TextColor3 = Color3.fromRGB(255, 190, 70)
    locInfo.TextSize = 9
    locInfo.Font = Enum.Font.Gotham
    locInfo.TextWrapped = true
    locInfo.LayoutOrder = 16
    locInfo.Parent = Content
    Instance.new("UICorner", locInfo).CornerRadius = UDim.new(0, 6)
    
    logBox = Instance.new("TextLabel")
    logBox.Text = "[Ready] v4.0 OP + Streaming Save\n"
    logBox.Size = UDim2.new(1, 0, 0, 280)
    logBox.BackgroundColor3 = Color3.fromRGB(8, 8, 16)
    logBox.TextColor3 = Color3.fromRGB(120, 255, 120)
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
    
    -- Dragging
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
    
    -- Button Handlers
    CloseBtn.MouseButton1Click:Connect(function() Gui:Destroy() end)
    
    local minimized = false
    MinBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        Content.Visible = not minimized
        Main.Size = minimized and UDim2.new(0.92, 0, 0, 48) or UDim2.new(0.92, 0, 0.78, 0)
        MinBtn.Text = minimized and "□" or "—"
    end)
    
    DumpAllBtn.MouseButton1Click:Connect(function()
        if DUMP_RUNNING then return end
        DumpAllBtn.Text = "⏳ RIPPING (streaming save)..."
        DumpAllBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        task.spawn(function()
            local folder = DumpEverything()
            DumpAllBtn.Text = "✅ DONE! " .. totalFiles .. " files"
            DumpAllBtn.BackgroundColor3 = Color3.fromRGB(30, 160, 30)
            task.wait(5)
            DumpAllBtn.Text = "⬇️ RIP EVERYTHING (Streaming Save)"
            DumpAllBtn.BackgroundColor3 = Color3.fromRGB(140, 20, 220)
        end)
    end)
    
    ScriptsDeepBtn.MouseButton1Click:Connect(function()
        if DUMP_RUNNING then return end
        ScriptsDeepBtn.Text = "⏳ EXTRACTING (streaming)..."
        ScriptsDeepBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        task.spawn(function()
            local folder, count, files, rate = ScriptsOnlyDump()
            ScriptsDeepBtn.Text = string.format("✅ %d scripts | %d%%", count or 0, rate or 0)
            ScriptsDeepBtn.BackgroundColor3 = Color3.fromRGB(30, 160, 30)
            task.wait(5)
            ScriptsDeepBtn.Text = "📜 SCRIPTS ONLY (Streaming Save)"
            ScriptsDeepBtn.BackgroundColor3 = Color3.fromRGB(220, 100, 0)
        end)
    end)
    
    SaveInstanceBtn.MouseButton1Click:Connect(function()
        if not (type(saveinstance) == "function") then
            Log("❌ saveinstance not supported!")
            SaveInstanceBtn.Text = "❌ NOT SUPPORTED"
            task.wait(2)
            SaveInstanceBtn.Text = "💾 SAVE FULL MAP (.rbxlx)"
            return
        end
        SaveInstanceBtn.Text = "⏳ SAVING..."
        task.spawn(function()
            local gn, gi = GetGameInfo()
            local ok, err = pcall(function()
                saveinstance({
                    FilePath = "MapRip/" .. gn .. "_" .. gi .. "_FULL.rbxlx",
                    Decompile = true, DecompileTimeout = 30,
                    NilInstances = true, RemovePlayerCharacters = true,
                    ExcludePlayerCharacter = true, ExcludePlayerGui = false,
                    ShowStatus = true, SaveBytecode = true, mode = "full",
                })
            end)
            SaveInstanceBtn.Text = ok and "✅ SAVED!" or ("❌ " .. tostring(err):sub(1, 40))
            task.wait(3)
            SaveInstanceBtn.Text = "💾 SAVE FULL MAP (.rbxlx)"
        end)
    end)
    
    ClipboardBtn.MouseButton1Click:Connect(function()
        ClipboardBtn.Text = "⏳ COLLECTING..."
        task.spawn(function()
            local allScripts = DiscoverAllScripts()
            local all = {}
            local count = 0
            for _, entry in ipairs(allScripts) do
                local obj = entry.instance
                count = count + 1
                local dr = UltimateDecompile(obj)
                all[#all+1] = "\n" .. string.rep("=", 60) .. "\n-- [" .. count .. "] " .. obj:GetFullName() .. "\n-- Class: " .. obj.ClassName .. "\n-- Method: " .. dr.method .. "\n" .. string.rep("=", 60) .. "\n" .. (dr.source or "-- EMPTY")
                if count % 5 == 0 then task.wait(0.1) end
            end
            local text = "-- TOTAL: " .. count .. "\n" .. table.concat(all, "\n")
            if setclipboard then setclipboard(text)
            elseif toclipboard then toclipboard(text)
            else
                MakeFolder("MapRip")
                SafeWrite("MapRip/clipboard_dump.lua", text)
            end
            ClipboardBtn.Text = "✅ " .. count .. " scripts copied!"
            task.wait(4)
            ClipboardBtn.Text = "📋 COPY ALL SCRIPTS TO CLIPBOARD"
        end)
    end)
    
    TreeOnlyBtn.MouseButton1Click:Connect(function()
        TreeOnlyBtn.Text = "⏳ MAPPING..."
        task.spawn(function()
            local gn, _ = GetGameInfo()
            local lines = {}
            local count = 0
            local function MapTree(inst, depth)
                count = count + 1
                lines[#lines+1] = string.rep("│ ", depth) .. "├─ [" .. inst.ClassName .. "] " .. inst.Name
                pcall(function()
                    for _, child in ipairs(inst:GetChildren()) do MapTree(child, depth + 1) end
                end)
                if count % 500 == 0 then task.wait() end
            end
            local svcs = {Workspace, ReplicatedStorage, ReplicatedFirst, Lighting, StarterGui, StarterPack, StarterPlayer, SoundService}
            local names = {"Workspace", "ReplicatedStorage", "ReplicatedFirst", "Lighting", "StarterGui", "StarterPack", "StarterPlayer", "SoundService"}
            for i, svc in ipairs(svcs) do
                lines[#lines+1] = "\n" .. string.rep("=", 50) .. "\n" .. names[i] .. "\n" .. string.rep("=", 50)
                pcall(function() for _, c in ipairs(svc:GetChildren()) do MapTree(c, 1) end end)
            end
            MakeFolder("MapRip")
            SafeWrite("MapRip/TREE_" .. gn .. ".txt", "INSTANCES: " .. count .. "\n\n" .. table.concat(lines, "\n"))
            TreeOnlyBtn.Text = "✅ " .. count .. " instances"
            task.wait(3)
            TreeOnlyBtn.Text = "🌳 EXPORT TREE STRUCTURE ONLY"
        end)
    end)
    
    local ok = pcall(function() Gui.Parent = game:GetService("CoreGui") end)
    if not ok then Gui.Parent = LocalPlayer.PlayerGui end
    
    Log("GUI Ready! Game: " .. game.PlaceId)
    Log("Mode: STREAMING SAVE (file langsung tersedia)")
    Log("APIs: decompile=" .. tostring(HAS_DECOMPILE) .. " getsenv=" .. tostring(HAS_GETSENV) .. " bytecode=" .. tostring(HAS_GETSCRIPTBYTECODE))
    return Gui
end

-- ============================================
-- RUN
-- ============================================
CreateGUI()
