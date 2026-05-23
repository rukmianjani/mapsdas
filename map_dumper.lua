-- ULTIMATE MAP DUMPER v5.0 GODMODE (Merged)
-- Anti-Error: xpcall + timeout di semua layer
-- 14-Layer Decompile + Bytecode Parser + String Recovery
-- Compatible: ALL executors (Delta, Fluxus, Arceus X, etc)


--[[
    ULTIMATE MAP DUMPER v5.0 - GODMODE EDITION
    ================================================
    Part 01: CORE - Services, State, Utilities, Timeout
    
    ANTI-ERROR SYSTEM:
    - xpcall + debug.traceback everywhere
    - Memory guards & string length limits
    - Safe operations for ALL executor environments
    - Coroutine-safe timeout with cancellation
    
    Compatible: Delta, Fluxus, Arceus X, Hydrogen, 
                Synapse, Wave, Solara, Krnl, Script-Ware,
                Electron, Celery, Oxygen U, JJSploit
    Output: workspace/MapRip/[GameName]/
]]

-- ============================================
-- SERVICES (protected init)
-- ============================================
local function SafeGetService(name)
    local ok, svc = pcall(function()
        return game:GetService(name)
    end)
    return ok and svc or nil
end

local Players = SafeGetService("Players")
local Workspace = SafeGetService("Workspace") or workspace
local ReplicatedStorage = SafeGetService("ReplicatedStorage")
local ReplicatedFirst = SafeGetService("ReplicatedFirst")
local Lighting = SafeGetService("Lighting")
local StarterGui = SafeGetService("StarterGui")
local StarterPack = SafeGetService("StarterPack")
local StarterPlayer = SafeGetService("StarterPlayer")
local SoundService = SafeGetService("SoundService")
local Teams = SafeGetService("Teams")
local UserInputService = SafeGetService("UserInputService")
local TweenService = SafeGetService("TweenService")
local HttpService = SafeGetService("HttpService")
local MarketplaceService = SafeGetService("MarketplaceService")

local LocalPlayer = Players and Players.LocalPlayer or nil

-- ============================================
-- GLOBAL STATE
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
    bytecode_parsed = 0,
    env_dumped = 0,
    closure_decompiled = 0,
    module_required = 0,
    debug_extracted = 0,
    gc_recovered = 0,
    string_recovered = 0,
    total_failed = 0,
    methods = {},
}

-- ============================================
-- EXECUTOR CAPABILITY DETECTION (robust)
-- ============================================
local function HasFunction(name)
    local ok, result = pcall(function()
        local f = getfenv(0)[name] or _G[name]
        return type(f) == "function"
    end)
    if ok and result then return true end
    -- Fallback: try direct eval
    local ok2, result2 = pcall(function()
        return type(loadstring("return " .. name)()) == "function"
    end)
    return ok2 and result2 or false
end

local function GetFunction(name)
    local ok, result = pcall(function()
        return getfenv(0)[name] or _G[name]
    end)
    if ok and type(result) == "function" then return result end
    local ok2, result2 = pcall(function()
        return loadstring("return " .. name)()
    end)
    if ok2 and type(result2) == "function" then return result2 end
    return nil
end

-- All known decompile function aliases across executors
local DECOMPILE_FUNC = GetFunction("decompile") 
    or GetFunction("decompilescript")
    or GetFunction("getscriptsource")
    or GetFunction("disassemble")

local HAS_DECOMPILE = DECOMPILE_FUNC ~= nil
local HAS_GETSCRIPTBYTECODE = HasFunction("getscriptbytecode") or HasFunction("dumpstring")
local HAS_GETSCRIPTHASH = HasFunction("getscripthash")
local HAS_GETSCRIPTCLOSURE = HasFunction("getscriptclosure") or HasFunction("getscriptfunction")
local HAS_GETSENV = HasFunction("getsenv")
local HAS_GETNILINSTANCES = HasFunction("getnilinstances")
local HAS_GETRUNNINGSCRIPTS = HasFunction("getrunningscripts")
local HAS_GETLOADEDMODULES = HasFunction("getloadedmodules")
local HAS_GETGC = HasFunction("getgc")
local HAS_GETINSTANCES = HasFunction("getinstances")
local HAS_DEBUG_GETCONSTANTS = type(debug) == "table" and type(debug.getconstants) == "function"
local HAS_DEBUG_GETUPVALUES = type(debug) == "table" and type(debug.getupvalues) == "function"
local HAS_DEBUG_GETPROTOS = type(debug) == "table" and type(debug.getprotos) == "function"
local HAS_DEBUG_GETINFO = type(debug) == "table" and type(debug.info) == "function"
local HAS_ISCCLOSURE = HasFunction("iscclosure")
local HAS_ISLCLOSURE = HasFunction("islclosure")
local HAS_GETSCRIPTS = HasFunction("getscripts")
local HAS_SAVEINSTANCE = HasFunction("saveinstance")

-- Get actual function references for aliases
local fn_getscriptbytecode = GetFunction("getscriptbytecode") or GetFunction("dumpstring")
local fn_getscriptclosure = GetFunction("getscriptclosure") or GetFunction("getscriptfunction")
local fn_getscripthash = GetFunction("getscripthash")
local fn_decompile = DECOMPILE_FUNC

-- ============================================
-- SAFE STRING OPERATIONS (anti-crash)
-- ============================================
local MAX_STRING_LEN = 1048576 -- 1MB max string to prevent memory issues
local MAX_TABLE_DEPTH = 12
local MAX_TABLE_ENTRIES = 200

local function SafeStr(val, maxLen)
    maxLen = maxLen or 500
    local ok, str = pcall(tostring, val)
    if not ok then return "[tostring_error]" end
    if #str > maxLen then
        return str:sub(1, maxLen) .. "...[truncated:" .. #str .. "]"
    end
    return str
end

local function SafeLen(str)
    if type(str) ~= "string" then return 0 end
    local ok, len = pcall(function() return #str end)
    return ok and len or 0
end

local function SafeConcat(tbl, sep)
    local ok, result = pcall(table.concat, tbl, sep or "")
    if ok then return result end
    -- Fallback: manual concat
    local s = ""
    for i, v in ipairs(tbl) do
        local ok2, str = pcall(tostring, v)
        if ok2 then
            s = s .. (i > 1 and (sep or "") or "") .. str
        end
    end
    return s
end

-- ============================================
-- UTILITIES
-- ============================================
local function SafeName(name)
    if not name or name == "" then return "unnamed" end
    local ok, result = pcall(function()
        return name:gsub("[\\/:*?\"<>|%z%c]", "_"):gsub("%.%.", "_"):sub(1, 80)
    end)
    return ok and result or "unnamed"
end

local function GetGameInfo()
    local id = 0
    pcall(function() id = game.PlaceId end)
    local name = "Unknown"
    pcall(function()
        if MarketplaceService then
            name = MarketplaceService:GetProductInfo(id).Name
        end
    end)
    return SafeName(name), id
end

local function MakeFolder(path)
    local ok, parts = pcall(function() return path:split("/") end)
    if not ok then return end
    local current = ""
    for i, part in ipairs(parts) do
        current = (i == 1) and part or (current .. "/" .. part)
        pcall(function()
            if type(isfolder) == "function" and not isfolder(current) then
                makefolder(current)
            elseif type(makefolder) == "function" then
                makefolder(current)
            end
        end)
    end
end

local function SafeWrite(path, content)
    if type(writefile) ~= "function" then return false end
    -- Guard against oversized content
    if type(content) == "string" and #content > 4194304 then -- 4MB limit
        content = content:sub(1, 4194304) .. "\n-- [FILE TRUNCATED: exceeded 4MB limit]"
    end
    local ok, err = xpcall(function()
        writefile(path, content or "")
    end, function(e) return tostring(e) end)
    if ok then
        totalFiles = totalFiles + 1
        return true
    end
    return false
end

local function SafeAppend(path, content)
    if not content or content == "" then return end
    if type(content) == "string" and #content > 2097152 then -- 2MB chunk limit
        content = content:sub(1, 2097152) .. "\n-- [CHUNK TRUNCATED]"
    end
    -- Method 1: appendfile
    if type(appendfile) == "function" then
        local ok = pcall(appendfile, path, content)
        if ok then return end
    end
    -- Method 2: read + writefile
    xpcall(function()
        local existing = ""
        if type(isfile) == "function" and isfile(path) then
            existing = readfile(path) or ""
        else
            pcall(function() existing = readfile(path) or "" end)
        end
        -- Guard total size
        if #existing + #content > 8388608 then -- 8MB total file limit
            content = "\n-- [APPEND SKIPPED: file exceeds 8MB]"
        end
        writefile(path, existing .. content)
    end, function(e) end)
end

-- ============================================
-- TIMEOUT SYSTEM v2 - Coroutine-safe
-- Handles scripts that hang, infinite loops,
-- and executors that freeze on decompile
-- ============================================
local DECOMPILE_TIMEOUT = 45 -- 45 seconds default
local QUICK_TIMEOUT = 12    -- 12 seconds for secondary ops

local function RunWithTimeout(func, timeoutSec)
    timeoutSec = timeoutSec or DECOMPILE_TIMEOUT
    local result = nil
    local errorMsg = nil
    local finished = false
    
    -- Use task.spawn if available, else coroutine
    local spawnFunc = task and task.spawn or coroutine.wrap
    
    local ok, _ = pcall(function()
        task.spawn(function()
            local ok2, ret = xpcall(func, function(err)
                return tostring(err) .. "\n" .. (debug.traceback and debug.traceback() or "")
            end)
            if ok2 then
                result = ret
            else
                errorMsg = ret
            end
            finished = true
        end)
    end)
    
    -- Fallback if task.spawn failed
    if not ok then
        pcall(function()
            coroutine.wrap(function()
                local ok2, ret = pcall(func)
                if ok2 then result = ret else errorMsg = tostring(ret) end
                finished = true
            end)()
        end)
    end
    
    local start = tick()
    local waitFunc = (task and task.wait) or wait
    
    while not finished and (tick() - start) < timeoutSec do
        pcall(waitFunc, 0.4)
    end
    
    if not finished then
        return nil, "TIMEOUT_" .. timeoutSec .. "s"
    end
    return result, errorMsg
end

-- ============================================
-- LOGGING
-- ============================================
local function Log(msg)
    pcall(function()
        print("[MapRip] " .. SafeStr(msg, 500))
    end)
    pcall(function()
        if logBox then
            logBox.Text = SafeStr(msg, 200) .. "\n" .. logBox.Text
            if #logBox.Text > 8000 then
                logBox.Text = logBox.Text:sub(1, 8000)
            end
        end
    end)
end

local function UpdateStatus(t)
    pcall(function()
        if statusLabel then statusLabel.Text = SafeStr(t, 200) end
    end)
end

local function UpdateProgress()
    pcall(function()
        if progressLabel then
            progressLabel.Text = string.format(
                "Inst: %d | Scripts: %d | Assets: %d | Files: %d | OK: %d | Fail: %d", 
                totalInstances, totalScripts, totalAssets, totalFiles,
                DecompileStats.decompiled + DecompileStats.source_prop + 
                DecompileStats.closure_decompiled + DecompileStats.module_required +
                DecompileStats.bytecode_parsed + DecompileStats.string_recovered,
                DecompileStats.total_failed
            )
        end
    end)
end

-- ============================================
-- BASE64 ENCODER (safe, chunked)
-- ============================================
local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function Base64Encode(data)
    if not data or #data == 0 then return "" end
    local maxLen = math.min(#data, 524288) -- 512KB cap
    local result = {}
    local bytes = {string.byte(data, 1, maxLen)}
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
-- HEX ENCODER (safe)
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
-- DEEP TABLE SERIALIZER (safe, depth-limited)
-- ============================================
local function SerializeDeep(val, depth, visited)
    depth = depth or 0
    visited = visited or {}
    
    if depth > MAX_TABLE_DEPTH then return '"[MAX_DEPTH]"' end
    
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
            if HAS_DEBUG_GETINFO then
                local s, l, n = debug.info(val, "sln")
                info = string.format("source=%s line=%s name=%s", tostring(s), tostring(l), tostring(n))
            end
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
            if count > MAX_TABLE_ENTRIES then
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
            local ok, serialized = pcall(SerializeDeep, v, depth + 1, visited)
            items[#items+1] = indent .. key .. " = " .. (ok and serialized or '"[SERIALIZE_ERROR]"')
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

-- TEST: write test file to confirm filesystem works
pcall(function()
    if type(writefile) == "function" then
        writefile("MapRip_TEST.txt", "MAP DUMPER v5.0 GODMODE OK - " .. os.date())
    end
end)

-- ============================================
-- Part 02: LUAU BYTECODE PARSER
-- Pure Lua bytecode analysis - works even when
-- decompile() fails completely.
-- Extracts: strings, constants, proto info,
-- opcode analysis, obfuscation detection
-- ============================================

-- ============================================
-- LUAU BYTECODE HEADER CONSTANTS
-- ============================================
local LBC_VERSION_MIN = 3
local LBC_VERSION_MAX = 6  -- Luau bytecode v3-v6
local RSB1_MAGIC = "RSB1"  -- Roblox compressed bytecode

-- Luau Type Tags (for constant pool)
local LBC_CONSTANT_NIL = 0
local LBC_CONSTANT_BOOLEAN = 1
local LBC_CONSTANT_NUMBER = 2
local LBC_CONSTANT_STRING = 3
local LBC_CONSTANT_IMPORT = 4
local LBC_CONSTANT_TABLE = 5
local LBC_CONSTANT_CLOSURE = 6
local LBC_CONSTANT_VECTOR = 7

-- Known obfuscator signatures
local OBFUSCATOR_SIGNATURES = {
    {pattern = "IB_", name = "IronBrew/IronBrew2"},
    {pattern = "PSU_", name = "PSU (Prometheus)"},
    {pattern = "Prometheus", name = "Prometheus"},
    {pattern = "Luraph", name = "Luraph"},
    {pattern = "Moonsec", name = "MoonSec"},
    {pattern = "STARTER_VM", name = "VM-based obfuscator"},
    {pattern = "vm_entry", name = "VM-based obfuscator"},
    {pattern = "ByteString", name = "ByteString obfuscator"},
    {pattern = "XOR_KEY", name = "XOR Cipher obfuscator"},
    {pattern = "vmrun", name = "VM runner"},
    {pattern = "AztupBrew", name = "AztupBrew"},
    {pattern = "beautify", name = "Beautify obfuscator"},
    {pattern = "VMFUSCATE", name = "VMFuscate"},
    {pattern = "getfenv", name = "Environment manipulation (possible obfuscation)"},
    {pattern = "loadstring", name = "Dynamic code loading (possible obfuscation)"},
    {pattern = "string.char", name = "String construction (possible obfuscation)"},
    {pattern = "bit32.bxor", name = "Bitwise XOR (possible encryption)"},
    {pattern = "string.byte", name = "Byte manipulation (possible obfuscation)"},
    {pattern = "table.concat", name = "String builder (possible obfuscation)"},
}

-- ============================================
-- BYTECODE READER (safe binary reader)
-- ============================================
local function CreateBytecodeReader(data)
    if not data or type(data) ~= "string" or #data == 0 then
        return nil
    end
    
    local reader = {
        data = data,
        pos = 1,
        len = #data,
        error = nil,
    }
    
    function reader:hasData(n)
        return self.pos + (n or 1) - 1 <= self.len
    end
    
    function reader:readByte()
        if not self:hasData(1) then 
            self.error = "unexpected_eof"
            return 0 
        end
        local b = string.byte(self.data, self.pos)
        self.pos = self.pos + 1
        return b
    end
    
    function reader:readUint32()
        if not self:hasData(4) then
            self.error = "unexpected_eof"
            return 0
        end
        local b1, b2, b3, b4 = string.byte(self.data, self.pos, self.pos + 3)
        self.pos = self.pos + 4
        return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
    end
    
    function reader:readVarInt()
        local result = 0
        local shift = 0
        local maxIter = 5 -- prevent infinite loop
        local iter = 0
        repeat
            if not self:hasData(1) then
                self.error = "unexpected_eof"
                return 0
            end
            iter = iter + 1
            if iter > maxIter then
                self.error = "varint_too_long"
                return result
            end
            local b = self:readByte()
            result = result + bit32.lshift(bit32.band(b, 0x7F), shift)
            shift = shift + 7
            if bit32.band(b, 0x80) == 0 then
                return result
            end
        until false
    end
    
    function reader:readDouble()
        if not self:hasData(8) then
            self.error = "unexpected_eof"
            return 0
        end
        -- Read 8 bytes as raw double
        local bytes = {}
        for i = 1, 8 do
            bytes[i] = self:readByte()
        end
        -- Simple IEEE 754 decode attempt
        -- For most purposes we just report the raw bytes
        -- but try string.unpack if available
        local ok, val = pcall(function()
            if string.unpack then
                self.pos = self.pos - 8
                local v = string.unpack("<d", self.data, self.pos)
                self.pos = self.pos + 8
                return v
            end
        end)
        if ok and val then return val end
        
        -- Fallback: skip and return placeholder
        return 0 -- can't decode without string.unpack
    end
    
    function reader:readString()
        local len = self:readVarInt()
        if len == 0 then return "" end
        if len > 1048576 then -- 1MB string limit
            self.error = "string_too_long"
            self.pos = self.pos + math.min(len, self.len - self.pos + 1)
            return "[STRING_TOO_LONG:" .. len .. "]"
        end
        if not self:hasData(len) then
            self.error = "unexpected_eof"
            return ""
        end
        local str = self.data:sub(self.pos, self.pos + len - 1)
        self.pos = self.pos + len
        return str
    end
    
    function reader:skip(n)
        self.pos = self.pos + n
        if self.pos > self.len + 1 then
            self.pos = self.len + 1
            self.error = "unexpected_eof"
        end
    end
    
    function reader:readBytes(n)
        if not self:hasData(n) then
            self.error = "unexpected_eof"
            return ""
        end
        local bytes = self.data:sub(self.pos, self.pos + n - 1)
        self.pos = self.pos + n
        return bytes
    end
    
    return reader
end

-- ============================================
-- DETECT RSB1 (ZSTD compressed bytecode)
-- ============================================
local function IsRSB1(data)
    if not data or #data < 8 then return false end
    return data:sub(1, 4) == RSB1_MAGIC
end

-- ============================================
-- DETECT BYTECODE VERSION
-- ============================================
local function GetBytecodeVersion(data)
    if not data or #data < 1 then return 0 end
    local firstByte = string.byte(data, 1)
    -- Luau bytecode version is first byte (typically 3-6 for modern, or 0 for error)
    if firstByte == 0 then
        -- Version 0 = compilation error, rest is error message
        return 0, data:sub(2)
    end
    return firstByte
end

-- ============================================
-- MAIN BYTECODE PARSER
-- Extract ALL useful data from raw Luau bytecode
-- Works even on encrypted/obfuscated scripts
-- ============================================
local function ParseLuauBytecode(rawData)
    if not rawData or type(rawData) ~= "string" or #rawData < 4 then
        return nil, "no_data"
    end
    
    local result = {
        isRSB1 = false,
        isCompressed = false,
        version = 0,
        compilationError = nil,
        strings = {},
        stringCount = 0,
        protos = {},
        protoCount = 0,
        totalConstants = 0,
        numberConstants = {},
        importNames = {},
        rawSize = #rawData,
        obfuscators = {},
        readableStrings = {},
        apiCalls = {},
        remoteNames = {},
        parseError = nil,
        headerHex = "",
    }
    
    -- Record header hex for analysis
    local headerLen = math.min(32, #rawData)
    local headerHex = {}
    for i = 1, headerLen do
        headerHex[#headerHex+1] = string.format("%02X", string.byte(rawData, i))
    end
    result.headerHex = table.concat(headerHex, " ")
    
    -- Check if RSB1 compressed
    if IsRSB1(rawData) then
        result.isRSB1 = true
        result.isCompressed = true
        -- Try to decompress if we have the function
        local decompressedData = nil
        pcall(function()
            if type(zstd_decompress) == "function" then
                decompressedData = zstd_decompress(rawData:sub(5))
            end
        end)
        pcall(function()
            if not decompressedData and type(decompress) == "function" then
                decompressedData = decompress(rawData)
            end
        end)
        
        if decompressedData then
            rawData = decompressedData
        else
            -- Can't decompress, try to extract strings anyway via brute force
            result.parseError = "RSB1_cannot_decompress"
            -- Fall through to string scanning below
        end
    end
    
    -- Check version
    local version, compError = GetBytecodeVersion(rawData)
    result.version = version
    
    if version == 0 and compError then
        result.compilationError = compError
        result.parseError = "compilation_error"
        return result, "compilation_error: " .. SafeStr(compError, 200)
    end
    
    -- Try structured parse for known bytecode versions
    if version >= LBC_VERSION_MIN and version <= LBC_VERSION_MAX and not result.isCompressed then
        local ok, parseErr = xpcall(function()
            local reader = CreateBytecodeReader(rawData)
            if not reader then return end
            
            -- Skip version byte (already read)
            reader:skip(1)
            
            -- Read types version (v5+)
            local typesVersion = 0
            if version >= 4 then
                typesVersion = reader:readByte()
            end
            
            -- Read string table
            local stringCount = reader:readVarInt()
            result.stringCount = stringCount
            
            local strings = {}
            for i = 1, math.min(stringCount, 10000) do -- cap at 10k strings
                if reader.error then break end
                local str = reader:readString()
                strings[i] = str
                result.strings[i] = str
                
                -- Categorize string
                if #str > 0 and #str < 1000 then
                    -- Check if readable ASCII
                    local isReadable = true
                    local nonPrintable = 0
                    for ci = 1, math.min(#str, 100) do
                        local byte = string.byte(str, ci)
                        if byte < 32 and byte ~= 10 and byte ~= 13 and byte ~= 9 then
                            nonPrintable = nonPrintable + 1
                        end
                    end
                    if nonPrintable / math.max(1, math.min(#str, 100)) < 0.1 then
                        result.readableStrings[#result.readableStrings+1] = str
                    end
                    
                    -- Detect API calls
                    if str:match("^[A-Z][a-zA-Z]+$") or str:match("^get") or str:match("^set") 
                       or str:match("^Is") or str:match("^Find") or str:match("^Wait")
                       or str:match("^fire") or str:match("^Fire") or str:match("^invoke")
                       or str:match("^Invoke") or str:match("^Connect") or str:match("^Destroy")
                       or str:match("^Clone") or str:match("^Remove") then
                        result.apiCalls[#result.apiCalls+1] = str
                    end
                    
                    -- Detect remote names
                    if str:match("Remote") or str:match("Event") or str:match("Function")
                       or str:match("Bind") or str:match("Signal") then
                        result.remoteNames[#result.remoteNames+1] = str
                    end
                end
            end
            
            -- Read proto count
            local protoCount = reader:readVarInt()
            result.protoCount = protoCount
            
            -- Read protos (limited parsing to avoid crashes)
            for pi = 1, math.min(protoCount, 1000) do
                if reader.error then break end
                
                local proto = {
                    index = pi,
                    maxStackSize = 0,
                    numParams = 0,
                    numUpvalues = 0,
                    isVararg = false,
                    constants = {},
                    instructionCount = 0,
                }
                
                local ok2, _ = pcall(function()
                    proto.maxStackSize = reader:readByte()
                    proto.numParams = reader:readByte()
                    proto.numUpvalues = reader:readByte()
                    proto.isVararg = reader:readByte() ~= 0
                    
                    -- Flags (v5+)
                    if version >= 4 then
                        local flags = reader:readByte() -- native flag etc
                    end
                    
                    -- Types info (if typesVersion > 0)
                    if typesVersion > 0 then
                        local typeSize = reader:readVarInt()
                        if typeSize > 0 then
                            reader:skip(typeSize)
                        end
                    end
                    
                    -- Instructions
                    local sizeCode = reader:readVarInt()
                    proto.instructionCount = sizeCode
                    reader:skip(sizeCode * 4) -- each instruction is 4 bytes
                    
                    -- Constants
                    local sizeK = reader:readVarInt()
                    result.totalConstants = result.totalConstants + sizeK
                    
                    for ki = 1, math.min(sizeK, 5000) do
                        if reader.error then break end
                        local ktype = reader:readByte()
                        
                        if ktype == LBC_CONSTANT_NIL then
                            proto.constants[#proto.constants+1] = {type = "nil", value = "nil"}
                        elseif ktype == LBC_CONSTANT_BOOLEAN then
                            local bval = reader:readByte()
                            proto.constants[#proto.constants+1] = {type = "boolean", value = bval ~= 0}
                        elseif ktype == LBC_CONSTANT_NUMBER then
                            local nval = reader:readDouble()
                            proto.constants[#proto.constants+1] = {type = "number", value = nval}
                            result.numberConstants[#result.numberConstants+1] = nval
                        elseif ktype == LBC_CONSTANT_STRING then
                            local sid = reader:readVarInt()
                            local sval = strings[sid] or ("[string_ref:" .. sid .. "]")
                            proto.constants[#proto.constants+1] = {type = "string", value = sval}
                        elseif ktype == LBC_CONSTANT_IMPORT then
                            local iid = reader:readUint32()
                            -- Decode import: top 2 bits = count, then 10-bit indices
                            local count = bit32.rshift(iid, 30)
                            local names = {}
                            if count >= 1 then
                                local n1 = bit32.band(bit32.rshift(iid, 20), 0x3FF)
                                if strings[n1] then names[#names+1] = strings[n1] end
                            end
                            if count >= 2 then
                                local n2 = bit32.band(bit32.rshift(iid, 10), 0x3FF)
                                if strings[n2] then names[#names+1] = strings[n2] end
                            end
                            if count >= 3 then
                                local n3 = bit32.band(iid, 0x3FF)
                                if strings[n3] then names[#names+1] = strings[n3] end
                            end
                            local importName = table.concat(names, ".")
                            proto.constants[#proto.constants+1] = {type = "import", value = importName}
                            if importName ~= "" then
                                result.importNames[#result.importNames+1] = importName
                            end
                        elseif ktype == LBC_CONSTANT_TABLE then
                            local tkeys = reader:readVarInt()
                            for _ = 1, tkeys do
                                reader:readVarInt() -- key indices
                            end
                            proto.constants[#proto.constants+1] = {type = "table", value = "[table:" .. tkeys .. "keys]"}
                        elseif ktype == LBC_CONSTANT_CLOSURE then
                            local cid = reader:readVarInt()
                            proto.constants[#proto.constants+1] = {type = "closure", value = "[closure:" .. cid .. "]"}
                        elseif ktype == LBC_CONSTANT_VECTOR then
                            -- 4 floats (v6+)
                            reader:skip(16)
                            proto.constants[#proto.constants+1] = {type = "vector", value = "[vector]"}
                        else
                            -- Unknown constant type, bail on this proto
                            proto.constants[#proto.constants+1] = {type = "unknown", value = "[unknown:" .. ktype .. "]"}
                            break
                        end
                    end
                    
                    -- Protos (child function references)
                    local sizeP = reader:readVarInt()
                    reader:skip(sizeP * 4) -- varint indices, approximate
                    -- Actually they're varints, but we approximate
                    
                    -- Line info (optional)
                    local lineDefined = reader:readVarInt()
                    proto.lineDefined = lineDefined
                    
                    local hasLineInfo = reader:readByte()
                    if hasLineInfo ~= 0 then
                        local lineGapLog2 = reader:readByte()
                        local intervals = bit32.rshift(sizeCode - 1, lineGapLog2) + 1
                        reader:skip(sizeCode) -- lineInfo (uint8 per instruction)
                        reader:skip(intervals * 4) -- absLineInfo (int32 per interval)
                    end
                    
                    -- Debug info (optional)
                    local hasDebugInfo = reader:readByte()
                    if hasDebugInfo ~= 0 then
                        local sizeLocVars = reader:readVarInt()
                        for _ = 1, sizeLocVars do
                            reader:readVarInt() -- name
                            reader:readVarInt() -- startpc
                            reader:readVarInt() -- endpc
                            reader:readByte() -- reg
                        end
                        local sizeUpvalues2 = reader:readVarInt()
                        for _ = 1, sizeUpvalues2 do
                            reader:readVarInt() -- name
                        end
                    end
                end)
                
                result.protos[pi] = proto
            end
            
        end, function(err)
            return tostring(err)
        end)
        
        if not ok then
            result.parseError = "structured_parse_failed: " .. SafeStr(parseErr, 200)
        end
    end
    
    -- ============================================
    -- BRUTE-FORCE STRING EXTRACTION
    -- Works on ANY data - even encrypted/compressed
    -- Scans for printable ASCII sequences
    -- ============================================
    if #result.readableStrings < 5 then
        local bruteStrings = {}
        local scanLen = math.min(#rawData, 262144) -- 256KB scan limit
        local currentStr = {}
        
        for i = 1, scanLen do
            local byte = string.byte(rawData, i)
            if byte >= 32 and byte <= 126 then
                currentStr[#currentStr+1] = string.char(byte)
            else
                if #currentStr >= 4 then -- min 4 chars
                    local str = table.concat(currentStr)
                    if #str <= 500 then
                        bruteStrings[#bruteStrings+1] = str
                    end
                end
                currentStr = {}
            end
            if #bruteStrings >= 2000 then break end
        end
        -- Final flush
        if #currentStr >= 4 then
            bruteStrings[#bruteStrings+1] = table.concat(currentStr)
        end
        
        -- Merge into readableStrings if we got more
        if #bruteStrings > #result.readableStrings then
            result.readableStrings = bruteStrings
        end
    end
    
    -- ============================================
    -- OBFUSCATION DETECTION
    -- Check extracted strings for known patterns
    -- ============================================
    local allStringsConcat = ""
    for i = 1, math.min(#result.readableStrings, 500) do
        allStringsConcat = allStringsConcat .. " " .. result.readableStrings[i]
        if #allStringsConcat > 50000 then break end
    end
    
    for _, sig in ipairs(OBFUSCATOR_SIGNATURES) do
        if allStringsConcat:find(sig.pattern, 1, true) then
            result.obfuscators[#result.obfuscators+1] = sig.name
        end
    end
    
    return result, nil
end

-- ============================================
-- FORMAT BYTECODE ANALYSIS INTO READABLE OUTPUT
-- ============================================
local function FormatBytecodeAnalysis(parsed)
    if not parsed then return nil end
    
    local lines = {}
    lines[#lines+1] = "-- ╔══════════════════════════════════════════════════════════╗"
    lines[#lines+1] = "-- ║  LUAU BYTECODE ANALYSIS (Pure Parser v5.0)              ║"
    lines[#lines+1] = "-- ╚══════════════════════════════════════════════════════════╝"
    lines[#lines+1] = ""
    lines[#lines+1] = "-- Raw Size: " .. parsed.rawSize .. " bytes"
    lines[#lines+1] = "-- Bytecode Version: " .. parsed.version
    lines[#lines+1] = "-- Is RSB1 Compressed: " .. tostring(parsed.isRSB1)
    lines[#lines+1] = "-- Header Hex: " .. parsed.headerHex
    
    if parsed.compilationError then
        lines[#lines+1] = "-- Compilation Error: " .. SafeStr(parsed.compilationError, 300)
    end
    if parsed.parseError then
        lines[#lines+1] = "-- Parse Note: " .. SafeStr(parsed.parseError, 300)
    end
    
    lines[#lines+1] = ""
    lines[#lines+1] = "-- String Table: " .. parsed.stringCount .. " entries"
    lines[#lines+1] = "-- Proto Count: " .. parsed.protoCount
    lines[#lines+1] = "-- Total Constants: " .. parsed.totalConstants
    
    -- Obfuscation detection
    if #parsed.obfuscators > 0 then
        lines[#lines+1] = ""
        lines[#lines+1] = "-- ⚠️ OBFUSCATION DETECTED:"
        for _, name in ipairs(parsed.obfuscators) do
            lines[#lines+1] = "--   → " .. name
        end
    end
    
    -- Import names (API usage)
    if #parsed.importNames > 0 then
        lines[#lines+1] = ""
        lines[#lines+1] = "-- ═══ IMPORTS (API Calls) ═══"
        local seen = {}
        for _, imp in ipairs(parsed.importNames) do
            if not seen[imp] then
                seen[imp] = true
                lines[#lines+1] = "-- import: " .. SafeStr(imp, 200)
            end
        end
    end
    
    -- Remote event names
    if #parsed.remoteNames > 0 then
        lines[#lines+1] = ""
        lines[#lines+1] = "-- ═══ REMOTE/EVENT NAMES ═══"
        local seen = {}
        for _, name in ipairs(parsed.remoteNames) do
            if not seen[name] then
                seen[name] = true
                lines[#lines+1] = "-- remote: " .. SafeStr(name, 200)
            end
        end
    end
    
    -- Readable strings (filtered, deduped)
    if #parsed.readableStrings > 0 then
        lines[#lines+1] = ""
        lines[#lines+1] = "-- ═══ EXTRACTED STRINGS (" .. #parsed.readableStrings .. " total) ═══"
        local seen = {}
        local count = 0
        for _, str in ipairs(parsed.readableStrings) do
            if not seen[str] and #str >= 3 and count < 500 then
                -- Filter out noise (hex sequences, random chars)
                if str:match("[%a_]") and not str:match("^[%x]+$") then
                    seen[str] = true
                    count = count + 1
                    lines[#lines+1] = '--   [' .. count .. '] "' .. SafeStr(str, 200) .. '"'
                end
            end
        end
    end
    
    -- Proto details
    if #parsed.protos > 0 then
        lines[#lines+1] = ""
        lines[#lines+1] = "-- ═══ FUNCTION PROTOTYPES ═══"
        for pi, proto in ipairs(parsed.protos) do
            if pi > 50 then
                lines[#lines+1] = "-- ... (" .. #parsed.protos .. " total protos, showing first 50)"
                break
            end
            lines[#lines+1] = string.format("-- Proto[%d]: params=%d upvalues=%d stack=%d instructions=%d line=%s vararg=%s",
                pi, proto.numParams or 0, proto.numUpvalues or 0,
                proto.maxStackSize or 0, proto.instructionCount or 0,
                tostring(proto.lineDefined or "?"), tostring(proto.isVararg))
            
            -- Show string constants for this proto
            if proto.constants then
                for _, k in ipairs(proto.constants) do
                    if k.type == "string" and k.value and #k.value > 0 then
                        lines[#lines+1] = '--     const: "' .. SafeStr(k.value, 150) .. '"'
                    elseif k.type == "import" and k.value and #k.value > 0 then
                        lines[#lines+1] = "--     import: " .. SafeStr(k.value, 150)
                    end
                end
            end
        end
    end
    
    -- Number constants (might reveal game logic)
    if #parsed.numberConstants > 0 then
        lines[#lines+1] = ""
        lines[#lines+1] = "-- ═══ NUMBER CONSTANTS (unique) ═══"
        local seen = {}
        local count = 0
        for _, n in ipairs(parsed.numberConstants) do
            if not seen[n] and count < 100 then
                seen[n] = true
                count = count + 1
                lines[#lines+1] = "--   " .. tostring(n)
            end
        end
    end
    
    return table.concat(lines, "\n")
end

-- ============================================
-- Part 03: ULTIMATE DECOMPILER ENGINE v5.0
-- 14-Layer Fallback System + Anti-Error
-- Every layer wrapped in xpcall with traceback
-- ============================================

-- ============================================
-- FAILURE DETECTION (comprehensive)
-- ============================================
local FAILURE_PATTERNS = {
    "failed to decompile",
    "cannot decompile",
    "decompilation failed",
    "error decompiling",
    "decompile timed out",
    "timed out",
    "-- unsynapse decompiler",
    "unsynapse",
    "this executor does not support",
    "not supported",
    "could not decompile",
    "server script",
    "-- decompiler error",
    "bytecode version mismatch",
    "invalid bytecode",
    "this script was not decompiled",
    "no source available",
    "protected script",
    "access denied",
    "script is empty",
    "nil source",
    "core script",
    "attempt to decompile",
}

local function IsDecompileFailure(src)
    if not src or type(src) ~= "string" or #src == 0 then return true end
    local lower = src:lower()
    for _, pattern in ipairs(FAILURE_PATTERNS) do
        if lower:find(pattern, 1, true) then
            return true
        end
    end
    -- Also check if output is suspiciously short and looks like an error
    if #src < 30 and lower:find("error") then return true end
    if #src < 10 and not src:find("\n") then return true end -- likely just an error message
    return false
end

-- ============================================
-- SAFE DECOMPILE WRAPPERS
-- All decompile calls go through timeout + xpcall
-- ============================================
local function SafeDecompile(...)
    if not fn_decompile then return nil, "decompile_not_available" end
    local args = {...}
    local src, err = RunWithTimeout(function()
        return fn_decompile(unpack(args))
    end, DECOMPILE_TIMEOUT)
    return src, err
end

local function QuickDecompile(target)
    if not fn_decompile then return nil, "decompile_not_available" end
    local src, err = RunWithTimeout(function()
        return fn_decompile(target)
    end, QUICK_TIMEOUT)
    return src, err
end

-- ============================================
-- LAYER 5: getsenv() ENVIRONMENT DUMPER
-- ============================================
local function DumpScriptEnvironment(scriptObj)
    if not HAS_GETSENV then return nil end
    
    local env, envErr = RunWithTimeout(function()
        return getsenv(scriptObj)
    end, 20)
    
    if not env or type(env) ~= "table" then return nil end
    
    local lines = {}
    lines[#lines+1] = "-- ╔══════════════════════════════════════════════════╗"
    lines[#lines+1] = "-- ║  RUNTIME ENVIRONMENT DUMP (getsenv)             ║"
    lines[#lines+1] = "-- ║  Script: " .. SafeStr(scriptObj.Name, 40)
    lines[#lines+1] = "-- ╚══════════════════════════════════════════════════╝"
    lines[#lines+1] = ""
    
    local funcCount = 0
    local varCount = 0
    local tableCount = 0
    
    local keys = {}
    for k in pairs(env) do
        if type(k) == "string" then
            keys[#keys+1] = k
        end
    end
    pcall(function() table.sort(keys) end)
    
    for _, k in ipairs(keys) do
        local ok, _ = xpcall(function()
            local v = env[k]
            local vtype = type(v)
            
            if vtype == "function" then
                funcCount = funcCount + 1
                lines[#lines+1] = "-- ═══ FUNCTION: " .. k .. " ═══"
                
                pcall(function()
                    if HAS_DEBUG_GETINFO then
                        local src, line, name = debug.info(v, "sln")
                        lines[#lines+1] = "-- source: " .. tostring(src)
                        lines[#lines+1] = "-- line: " .. tostring(line)
                        lines[#lines+1] = "-- name: " .. tostring(name)
                    end
                end)
                
                pcall(function()
                    if HAS_ISCCLOSURE then
                        lines[#lines+1] = "-- is_c_closure: " .. tostring(iscclosure(v))
                    end
                    if HAS_ISLCLOSURE then
                        lines[#lines+1] = "-- is_lua_closure: " .. tostring(islclosure(v))
                    end
                end)
                
                pcall(function()
                    if HAS_DEBUG_GETCONSTANTS then
                        local consts = debug.getconstants(v)
                        if consts and #consts > 0 then
                            lines[#lines+1] = "-- constants: {"
                            for ci, cv in pairs(consts) do
                                lines[#lines+1] = "--   [" .. tostring(ci) .. "] = " .. SafeStr(cv, 200) .. " (" .. type(cv) .. ")"
                            end
                            lines[#lines+1] = "-- }"
                        end
                    end
                end)
                
                pcall(function()
                    if HAS_DEBUG_GETUPVALUES then
                        local upvals = debug.getupvalues(v)
                        if upvals then
                            local hasData = false
                            for _ in pairs(upvals) do hasData = true; break end
                            if hasData then
                                lines[#lines+1] = "-- upvalues: {"
                                for ui, uv in pairs(upvals) do
                                    local uvStr = SafeStr(uv, 200)
                                    if type(uv) == "table" then
                                        local ok3, s = pcall(SerializeDeep, uv, 0)
                                        if ok3 then uvStr = s:sub(1, 500) end
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
                
                pcall(function()
                    if HAS_DEBUG_GETPROTOS then
                        local protos = debug.getprotos(v)
                        if protos and #protos > 0 then
                            lines[#lines+1] = "-- sub_functions: " .. #protos
                            for pi, pf in ipairs(protos) do
                                pcall(function()
                                    if HAS_DEBUG_GETINFO then
                                        local ps, pl, pn = debug.info(pf, "sln")
                                        lines[#lines+1] = "--   proto[" .. pi .. "]: name=" .. tostring(pn) .. " line=" .. tostring(pl)
                                    end
                                end)
                                pcall(function()
                                    if HAS_DEBUG_GETCONSTANTS then
                                        local pconsts = debug.getconstants(pf)
                                        if pconsts and #pconsts > 0 then
                                            lines[#lines+1] = "--     constants: {"
                                            for pci, pcv in pairs(pconsts) do
                                                lines[#lines+1] = "--       [" .. tostring(pci) .. "] = " .. SafeStr(pcv, 150)
                                            end
                                            lines[#lines+1] = "--     }"
                                        end
                                    end
                                end)
                            end
                        end
                    end
                end)
                
                -- Decompile individual function
                pcall(function()
                    if fn_decompile and HAS_ISLCLOSURE and islclosure(v) then
                        local fsrc = QuickDecompile(v)
                        if fsrc and not IsDecompileFailure(fsrc) then
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
                local ok3, serialized = pcall(SerializeDeep, v, 0)
                if ok3 then
                    if #serialized > 5000 then
                        serialized = serialized:sub(1, 5000) .. "\n-- ... [TABLE TRUNCATED]"
                    end
                    lines[#lines+1] = "local " .. k .. " = " .. serialized
                else
                    lines[#lines+1] = "local " .. k .. " = {} -- [SERIALIZE_ERROR]"
                end
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
        end, function(err) end)
    end
    
    lines[#lines+1] = ""
    lines[#lines+1] = string.format("-- ENV STATS: %d functions, %d variables, %d tables", funcCount, varCount, tableCount)
    
    if funcCount == 0 and varCount == 0 and tableCount == 0 then
        return nil
    end
    
    return table.concat(lines, "\n")
end

-- ============================================
-- LAYER 9: DEBUG INFO EXTRACTOR (enhanced)
-- ============================================
local function ExtractDebugInfo(scriptObj)
    if not fn_getscriptclosure and not HAS_GETSCRIPTCLOSURE then return nil end
    
    local closureFunc = fn_getscriptclosure or getscriptclosure
    local ok, closure = pcall(closureFunc, scriptObj)
    if not ok or not closure then return nil end
    
    local info = {lines = {}}
    
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
    
    pcall(function()
        if HAS_DEBUG_GETCONSTANTS then
            local consts = debug.getconstants(closure)
            if consts then
                info.constants = consts
                info.lines[#info.lines+1] = "-- ═══ MAIN FUNCTION CONSTANTS ═══"
                local strConsts = {}
                local numConsts = {}
                for i, c in pairs(consts) do
                    if type(c) == "string" then
                        strConsts[#strConsts+1] = {i, c}
                    elseif type(c) == "number" then
                        numConsts[#numConsts+1] = {i, c}
                    end
                end
                if #strConsts > 0 then
                    info.lines[#info.lines+1] = "-- String Constants:"
                    for _, sc in ipairs(strConsts) do
                        info.lines[#info.lines+1] = '--   [' .. sc[1] .. '] = "' .. SafeStr(sc[2], 200) .. '"'
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
    
    pcall(function()
        if HAS_DEBUG_GETUPVALUES then
            local upvals = debug.getupvalues(closure)
            if upvals then
                local hasData = false
                for _ in pairs(upvals) do hasData = true; break end
                if hasData then
                    info.lines[#info.lines+1] = "-- ═══ UPVALUES ═══"
                    for i, uv in pairs(upvals) do
                        local uvStr = SafeStr(uv, 300)
                        if type(uv) == "table" then
                            local ok3, s = pcall(SerializeDeep, uv, 0)
                            if ok3 then uvStr = s:sub(1, 1000) end
                        elseif type(uv) == "string" then
                            uvStr = '"' .. uv:sub(1, 300) .. '"'
                        end
                        info.lines[#info.lines+1] = "--   upvalue[" .. tostring(i) .. "] = " .. uvStr .. " (" .. type(uv) .. ")"
                    end
                end
            end
        end
    end)
    
    pcall(function()
        if HAS_DEBUG_GETPROTOS then
            local protos = debug.getprotos(closure)
            if protos and #protos > 0 then
                info.lines[#info.lines+1] = "-- ═══ SUB-FUNCTIONS (" .. #protos .. " protos) ═══"
                
                for pi, pf in ipairs(protos) do
                    if pi > 100 then
                        info.lines[#info.lines+1] = "-- ... (showing first 100 of " .. #protos .. " protos)"
                        break
                    end
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
                                        info.lines[#info.lines+1] = '--     [' .. pci .. '] = "' .. SafeStr(pcv, 150) .. '"'
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
                                        info.lines[#info.lines+1] = "--     [" .. pui .. "] = " .. SafeStr(puv, 200)
                                    end
                                end
                            end
                        end
                    end)
                    
                    -- Decompile proto (quick timeout)
                    pcall(function()
                        if fn_decompile and HAS_ISLCLOSURE and islclosure(pf) then
                            local fsrc = QuickDecompile(pf)
                            if fsrc and not IsDecompileFailure(fsrc) then
                                info.lines[#info.lines+1] = "--   DECOMPILED:"
                                local lineCount = 0
                                for srcLine in fsrc:gmatch("[^\n]+") do
                                    lineCount = lineCount + 1
                                    if lineCount > 100 then
                                        info.lines[#info.lines+1] = "--     ... [TRUNCATED]"
                                        break
                                    end
                                    info.lines[#info.lines+1] = "--     " .. srcLine
                                end
                            end
                        end
                    end)
                    
                    -- Nested protos (1 level)
                    pcall(function()
                        if HAS_DEBUG_GETPROTOS then
                            local subProtos = debug.getprotos(pf)
                            if subProtos and #subProtos > 0 then
                                info.lines[#info.lines+1] = "--   nested_protos: " .. #subProtos
                                for spi, spf in ipairs(subProtos) do
                                    if spi > 20 then break end
                                    pcall(function()
                                        if HAS_DEBUG_GETINFO then
                                            local ss, sl, sn = debug.info(spf, "sln")
                                            info.lines[#info.lines+1] = "--     sub[" .. spi .. "]: " .. tostring(sn) .. " @ line " .. tostring(sl)
                                        end
                                    end)
                                    pcall(function()
                                        if HAS_DEBUG_GETCONSTANTS then
                                            local sconsts = debug.getconstants(spf)
                                            if sconsts then
                                                for sci, scv in pairs(sconsts) do
                                                    if type(scv) == "string" then
                                                        info.lines[#info.lines+1] = '--       const[' .. sci .. '] = "' .. SafeStr(scv, 100) .. '"'
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
-- MAIN: UltimateDecompile() - 14 LAYERS
-- GODMODE: every single layer is pcall-protected
-- Returns data even if ALL decompile methods fail
-- ============================================
local function UltimateDecompile(scriptObj)
    DecompileStats.total = DecompileStats.total + 1
    
    local result = {
        source = nil,
        method = "failed",
        bytecodeB64 = nil,
        bytecodeHex = nil,
        bytecodeSize = 0,
        bytecodeAnalysis = nil,
        hash = nil,
        envDump = nil,
        debugInfo = nil,
        error = nil,
        layers = {},
    }
    
    local scriptName = "unknown"
    pcall(function() scriptName = scriptObj:GetFullName() end)
    
    -- ═══════════════════════════════════════════
    -- LAYER 1: Direct Source Property
    -- ═══════════════════════════════════════════
    xpcall(function()
        local src = scriptObj.Source
        if src and type(src) == "string" and #src > 0 then
            result.source = src
            result.method = "source_property"
            DecompileStats.source_prop = DecompileStats.source_prop + 1
            result.layers[#result.layers+1] = "L1:source=OK"
        end
    end, function(e) 
        result.layers[#result.layers+1] = "L1:source=ERR:" .. SafeStr(e, 50)
    end)
    if result.source and not IsDecompileFailure(result.source) then return result end
    if not result.layers[#result.layers] or not result.layers[#result.layers]:find("L1") then
        result.layers[#result.layers+1] = "L1:source=FAIL"
    end
    result.source = nil
    
    -- ═══════════════════════════════════════════
    -- LAYER 2: decompile() with RETRY + TIMEOUT
    -- ═══════════════════════════════════════════
    if fn_decompile then
        for attempt = 1, 3 do
            Log("  L2: decompile attempt " .. attempt .. "/3 [timeout " .. DECOMPILE_TIMEOUT .. "s]...")
            
            local src, err = SafeDecompile(scriptObj)
            
            if err and tostring(err):find("TIMEOUT") then
                Log("  ⏰ TIMEOUT attempt " .. attempt .. " - skip!")
                result.layers[#result.layers+1] = "L2:attempt" .. attempt .. "=TIMEOUT"
                break
            end
            
            if src and type(src) == "string" and #src > 0 and not IsDecompileFailure(src) then
                result.source = src
                result.method = "decompiled_attempt" .. attempt
                DecompileStats.decompiled = DecompileStats.decompiled + 1
                result.layers[#result.layers+1] = "L2:retry" .. attempt .. "=OK"
                return result
            end
            
            if not src and err then
                result.error = SafeStr(err, 300)
            end
            if attempt < 3 then 
                pcall(function() 
                    local w = task and task.wait or wait
                    w(0.3 * attempt)
                end)
            end
        end
        result.layers[#result.layers+1] = "L2:decompile=FAIL"
    else
        result.layers[#result.layers+1] = "L2:decompile=NOT_AVAILABLE"
    end
    
    -- ═══════════════════════════════════════════
    -- LAYER 3: Decompile alternative params
    -- ═══════════════════════════════════════════
    if fn_decompile then
        local tryModes = {
            {args = {scriptObj, 30}, name = "timeout30"},
            {args = {scriptObj, 60}, name = "timeout60"},
            {args = {scriptObj, true}, name = "flag_true"},
            {args = {scriptObj, "new"}, name = "mode_new"},
            {args = {scriptObj, false}, name = "flag_false"},
        }
        for _, mode in ipairs(tryModes) do
            local src, err = RunWithTimeout(function()
                return fn_decompile(unpack(mode.args))
            end, DECOMPILE_TIMEOUT)
            
            if err and tostring(err):find("TIMEOUT") then
                result.layers[#result.layers+1] = "L3:" .. mode.name .. "=TIMEOUT"
                break
            end
            
            if src and type(src) == "string" and #src > 0 and not IsDecompileFailure(src) then
                result.source = src
                result.method = "decompile_" .. mode.name
                DecompileStats.decompiled = DecompileStats.decompiled + 1
                result.layers[#result.layers+1] = "L3:" .. mode.name .. "=OK"
                return result
            end
        end
        result.layers[#result.layers+1] = "L3:alt_modes=FAIL"
    end
    
    -- ═══════════════════════════════════════════
    -- LAYER 4: getscriptclosure → decompile closure
    -- ═══════════════════════════════════════════
    if (fn_getscriptclosure or HAS_GETSCRIPTCLOSURE) and fn_decompile then
        xpcall(function()
            local closureFunc = fn_getscriptclosure or getscriptclosure
            local closure = closureFunc(scriptObj)
            if closure then
                local src, err = RunWithTimeout(function()
                    return fn_decompile(closure)
                end, DECOMPILE_TIMEOUT)
                
                if err and tostring(err):find("TIMEOUT") then
                    result.layers[#result.layers+1] = "L4:closure=TIMEOUT"
                elseif src and type(src) == "string" and #src > 0 and not IsDecompileFailure(src) then
                    result.source = src
                    result.method = "closure_decompile"
                    DecompileStats.closure_decompiled = DecompileStats.closure_decompiled + 1
                    result.layers[#result.layers+1] = "L4:closure=OK"
                end
            end
        end, function(e) 
            result.layers[#result.layers+1] = "L4:closure=ERR"
        end)
        if result.source then return result end
        if not result.layers[#result.layers]:find("L4") then
            result.layers[#result.layers+1] = "L4:closure=FAIL"
        end
    end
    
    -- ═══════════════════════════════════════════
    -- LAYER 5: getsenv() - Runtime Environment
    -- ═══════════════════════════════════════════
    xpcall(function()
        local envResult = DumpScriptEnvironment(scriptObj)
        if envResult then
            result.envDump = envResult
            DecompileStats.env_dumped = DecompileStats.env_dumped + 1
            result.layers[#result.layers+1] = "L5:getsenv=OK"
        else
            result.layers[#result.layers+1] = "L5:getsenv=FAIL"
        end
    end, function(e)
        result.layers[#result.layers+1] = "L5:getsenv=ERR"
    end)
    
    -- ═══════════════════════════════════════════
    -- LAYER 6: require() for ModuleScripts
    -- ═══════════════════════════════════════════
    xpcall(function()
        if scriptObj:IsA("ModuleScript") then
            local moduleData, modErr = RunWithTimeout(function()
                return require(scriptObj)
            end, 20)
            
            if modErr and tostring(modErr):find("TIMEOUT") then
                result.layers[#result.layers+1] = "L6:require=TIMEOUT"
            elseif moduleData ~= nil then
                local ok3, serialized = pcall(SerializeDeep, moduleData, 0)
                if ok3 and serialized and #serialized > 0 then
                    result.source = "-- MODULE require() RETURN VALUE:\n-- Module: " .. scriptName .. "\n\nreturn " .. serialized
                    result.method = "module_required"
                    DecompileStats.module_required = DecompileStats.module_required + 1
                    result.layers[#result.layers+1] = "L6:require=OK"
                end
            else
                result.layers[#result.layers+1] = "L6:require=FAIL"
            end
        end
    end, function(e)
        result.layers[#result.layers+1] = "L6:require=ERR"
    end)
    if result.source then return result end
    
    -- ═══════════════════════════════════════════
    -- LAYER 7: getscriptbytecode → Base64 + Hex
    -- ═══════════════════════════════════════════
    local rawBytecode = nil
    if fn_getscriptbytecode or HAS_GETSCRIPTBYTECODE then
        xpcall(function()
            local bcFunc = fn_getscriptbytecode or getscriptbytecode or dumpstring
            local bytecode = bcFunc(scriptObj)
            if bytecode and type(bytecode) == "string" and #bytecode > 0 then
                rawBytecode = bytecode
                result.bytecodeB64 = Base64Encode(bytecode)
                result.bytecodeSize = #bytecode
                DecompileStats.bytecode_saved = DecompileStats.bytecode_saved + 1
                result.layers[#result.layers+1] = "L7:bytecode=" .. #bytecode .. "bytes"
                if #bytecode < 16384 then
                    result.bytecodeHex = HexEncode(bytecode)
                end
            end
        end, function(e)
            result.layers[#result.layers+1] = "L7:bytecode=ERR"
        end)
    else
        result.layers[#result.layers+1] = "L7:bytecode=NOT_AVAILABLE"
    end
    
    -- ═══════════════════════════════════════════
    -- LAYER 8: getscripthash
    -- ═══════════════════════════════════════════
    if fn_getscripthash or HAS_GETSCRIPTHASH then
        xpcall(function()
            local hashFunc = fn_getscripthash or getscripthash
            result.hash = hashFunc(scriptObj)
            if result.hash then
                result.layers[#result.layers+1] = "L8:hash=" .. SafeStr(result.hash, 64)
            end
        end, function(e) end)
    end
    
    -- ═══════════════════════════════════════════
    -- LAYER 9: Debug Info Deep Extraction
    -- ═══════════════════════════════════════════
    xpcall(function()
        local dbgInfo = ExtractDebugInfo(scriptObj)
        if dbgInfo then
            result.debugInfo = dbgInfo
            DecompileStats.debug_extracted = DecompileStats.debug_extracted + 1
            result.layers[#result.layers+1] = "L9:debug=OK"
        else
            result.layers[#result.layers+1] = "L9:debug=FAIL"
        end
    end, function(e)
        result.layers[#result.layers+1] = "L9:debug=ERR"
    end)
    
    -- ═══════════════════════════════════════════
    -- LAYER 10: getgc() - GC function recovery
    -- ═══════════════════════════════════════════
    if HAS_GETGC then
        xpcall(function()
            local gcFuncs = getgc(false)
            local relatedFuncs = {}
            
            for _, func in ipairs(gcFuncs) do
                if type(func) == "function" then
                    pcall(function()
                        if HAS_DEBUG_GETINFO then
                            local src, line, name = debug.info(func, "sln")
                            if src and tostring(src):find(scriptObj.Name, 1, true) then
                                relatedFuncs[#relatedFuncs+1] = {
                                    source = src, line = line,
                                    name = name, func = func,
                                }
                            end
                        end
                    end)
                end
                if #relatedFuncs >= 50 then break end
            end
            
            if #relatedFuncs > 0 then
                result.layers[#result.layers+1] = "L10:gc=" .. #relatedFuncs .. "_funcs"
                DecompileStats.gc_recovered = DecompileStats.gc_recovered + 1
                
                local gcLines = {"-- ═══ GC RECOVERED FUNCTIONS ═══"}
                for fi, fdata in ipairs(relatedFuncs) do
                    gcLines[#gcLines+1] = string.format("-- GC[%d] name=%s line=%s source=%s",
                        fi, tostring(fdata.name), tostring(fdata.line), tostring(fdata.source))
                    
                    if fn_decompile then
                        local fsrc = QuickDecompile(fdata.func)
                        if fsrc and not IsDecompileFailure(fsrc) then
                            gcLines[#gcLines+1] = fsrc
                            gcLines[#gcLines+1] = ""
                        end
                    end
                    
                    pcall(function()
                        if HAS_DEBUG_GETCONSTANTS then
                            local consts = debug.getconstants(fdata.func)
                            if consts and #consts > 0 then
                                gcLines[#gcLines+1] = "-- constants:"
                                for ci, cv in pairs(consts) do
                                    gcLines[#gcLines+1] = "--   " .. tostring(ci) .. " = " .. SafeStr(cv, 200)
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
        end, function(e)
            result.layers[#result.layers+1] = "L10:gc=ERR"
        end)
    end
    
    -- ═══════════════════════════════════════════
    -- LAYER 11: BYTECODE PARSER (NEW in v5.0)
    -- Pure Lua analysis - works on everything
    -- ═══════════════════════════════════════════
    if rawBytecode then
        xpcall(function()
            local parsed, parseErr = ParseLuauBytecode(rawBytecode)
            if parsed then
                local analysis = FormatBytecodeAnalysis(parsed)
                if analysis then
                    result.bytecodeAnalysis = analysis
                    DecompileStats.bytecode_parsed = DecompileStats.bytecode_parsed + 1
                    result.layers[#result.layers+1] = "L11:bytecode_parse=OK(v" .. parsed.version .. ",str:" .. parsed.stringCount .. ",proto:" .. parsed.protoCount .. ")"
                    
                    -- Check for obfuscation
                    if #parsed.obfuscators > 0 then
                        result.layers[#result.layers+1] = "L11:obfuscation=" .. table.concat(parsed.obfuscators, "+")
                    end
                else
                    result.layers[#result.layers+1] = "L11:bytecode_parse=NO_DATA"
                end
            end
        end, function(e)
            result.layers[#result.layers+1] = "L11:bytecode_parse=ERR:" .. SafeStr(e, 50)
        end)
    else
        result.layers[#result.layers+1] = "L11:bytecode_parse=NO_BYTECODE"
    end
    
    -- ═══════════════════════════════════════════
    -- LAYER 12: STRING PATTERN RECOVERY (NEW)
    -- Even if bytecode can't be parsed, scan raw
    -- memory for string patterns
    -- ═══════════════════════════════════════════
    if rawBytecode and not result.bytecodeAnalysis then
        xpcall(function()
            local strings = {}
            local scanData = rawBytecode
            local scanLen = math.min(#scanData, 131072) -- 128KB
            local current = {}
            
            for i = 1, scanLen do
                local byte = string.byte(scanData, i)
                if byte >= 32 and byte <= 126 then
                    current[#current+1] = string.char(byte)
                else
                    if #current >= 4 then
                        local str = table.concat(current)
                        if str:match("[%a]") and #str < 500 then
                            strings[#strings+1] = str
                        end
                    end
                    current = {}
                end
            end
            if #current >= 4 then
                strings[#strings+1] = table.concat(current)
            end
            
            if #strings > 0 then
                DecompileStats.string_recovered = DecompileStats.string_recovered + 1
                local strLines = {"-- ═══ RAW STRING RECOVERY (brute-force scan) ═══"}
                strLines[#strLines+1] = "-- Found " .. #strings .. " strings in bytecode"
                local seen = {}
                local count = 0
                for _, s in ipairs(strings) do
                    if not seen[s] and count < 500 then
                        seen[s] = true
                        count = count + 1
                        strLines[#strLines+1] = '--   [' .. count .. '] "' .. SafeStr(s, 200) .. '"'
                    end
                end
                
                if not result.envDump then
                    result.envDump = table.concat(strLines, "\n")
                else
                    result.envDump = result.envDump .. "\n\n" .. table.concat(strLines, "\n")
                end
                result.layers[#result.layers+1] = "L12:string_recovery=" .. count .. "_strings"
            else
                result.layers[#result.layers+1] = "L12:string_recovery=NONE"
            end
        end, function(e)
            result.layers[#result.layers+1] = "L12:string_recovery=ERR"
        end)
    end
    
    -- ═══════════════════════════════════════════
    -- LAYER 13: SECONDARY DECOMPILE FUNCTIONS (NEW)
    -- Try ALL known executor decompile aliases
    -- ═══════════════════════════════════════════
    if not result.source then
        local altDecompilers = {}
        pcall(function()
            if type(decompile) == "function" and decompile ~= fn_decompile then
                altDecompilers[#altDecompilers+1] = {func = decompile, name = "decompile_alt"}
            end
        end)
        pcall(function()
            if type(getscriptsource) == "function" then
                altDecompilers[#altDecompilers+1] = {func = getscriptsource, name = "getscriptsource"}
            end
        end)
        pcall(function()
            if type(disassemble) == "function" then
                altDecompilers[#altDecompilers+1] = {func = disassemble, name = "disassemble"}
            end
        end)
        pcall(function()
            if type(decompilescript) == "function" then
                altDecompilers[#altDecompilers+1] = {func = decompilescript, name = "decompilescript"}
            end
        end)
        
        for _, alt in ipairs(altDecompilers) do
            local src, err = RunWithTimeout(function()
                return alt.func(scriptObj)
            end, DECOMPILE_TIMEOUT)
            
            if src and type(src) == "string" and #src > 0 and not IsDecompileFailure(src) then
                result.source = src
                result.method = alt.name
                DecompileStats.decompiled = DecompileStats.decompiled + 1
                result.layers[#result.layers+1] = "L13:" .. alt.name .. "=OK"
                return result
            end
        end
        result.layers[#result.layers+1] = "L13:alt_decompilers=FAIL"
    end
    
    -- ═══════════════════════════════════════════
    -- LAYER 14: CLONE + DECOMPILE (NEW)
    -- Some executors can decompile cloned scripts
    -- ═══════════════════════════════════════════
    if not result.source and fn_decompile then
        xpcall(function()
            if scriptObj.Archivable then
                local cloned = scriptObj:Clone()
                if cloned then
                    local src, err = RunWithTimeout(function()
                        return fn_decompile(cloned)
                    end, DECOMPILE_TIMEOUT)
                    
                    if src and type(src) == "string" and #src > 0 and not IsDecompileFailure(src) then
                        result.source = src
                        result.method = "clone_decompile"
                        DecompileStats.decompiled = DecompileStats.decompiled + 1
                        result.layers[#result.layers+1] = "L14:clone=OK"
                    end
                    pcall(function() cloned:Destroy() end)
                end
            end
        end, function(e)
            result.layers[#result.layers+1] = "L14:clone=ERR"
        end)
        if result.source then return result end
        if not result.layers[#result.layers]:find("L14") then
            result.layers[#result.layers+1] = "L14:clone=FAIL"
        end
    end
    
    -- ═══════════════════════════════════════════
    -- BUILD FINAL COMPOSITE SOURCE
    -- Even when decompile fails, provide MAX data
    -- ═══════════════════════════════════════════
    local parts = {}
    parts[#parts+1] = "-- ╔═══════════════════════════════════════════════════════════╗"
    parts[#parts+1] = "-- ║  DECOMPILE FAILED - MAXIMUM DATA EXTRACTION v5.0        ║"
    parts[#parts+1] = "-- ╚═══════════════════════════════════════════════════════════╝"
    parts[#parts+1] = "-- Script: " .. SafeStr(scriptName, 200)
    parts[#parts+1] = "-- Class: " .. scriptObj.ClassName
    parts[#parts+1] = "-- Error: " .. SafeStr(result.error, 300)
    parts[#parts+1] = "-- Layers: " .. SafeConcat(result.layers, " → ")
    if result.hash then
        parts[#parts+1] = "-- Hash: " .. SafeStr(result.hash, 64)
    end
    if result.bytecodeSize > 0 then
        parts[#parts+1] = "-- Bytecode: " .. result.bytecodeSize .. " bytes"
    end
    
    pcall(function()
        parts[#parts+1] = "-- Enabled: " .. tostring(scriptObj.Enabled)
    end)
    pcall(function()
        parts[#parts+1] = "-- RunContext: " .. tostring(scriptObj.RunContext)
    end)
    
    parts[#parts+1] = ""
    
    local hasUsefulData = false
    
    -- Bytecode analysis (from layer 11)
    if result.bytecodeAnalysis then
        parts[#parts+1] = result.bytecodeAnalysis
        parts[#parts+1] = ""
        hasUsefulData = true
    end
    
    if result.envDump then
        parts[#parts+1] = result.envDump
        parts[#parts+1] = ""
        hasUsefulData = true
    end
    
    if result.debugInfo and result.debugInfo.lines and #result.debugInfo.lines > 0 then
        parts[#parts+1] = "-- ═══ DEBUG INFO ═══"
        for _, line in ipairs(result.debugInfo.lines) do
            parts[#parts+1] = line
        end
        parts[#parts+1] = ""
        hasUsefulData = true
    end
    
    if result.bytecodeB64 then
        parts[#parts+1] = string.format("-- ═══ BYTECODE (%d bytes) ═══", result.bytecodeSize)
        parts[#parts+1] = "--[[BYTECODE_BASE64_START"
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
        parts[#parts+1] = "-- COMPLETE FAILURE: No data extracted"
        parts[#parts+1] = "-- Possible: server-side only / not loaded / obfuscated / protected"
        result.method = "failed"
    else
        result.method = "fallback_composite"
    end
    
    result.source = table.concat(parts, "\n")
    DecompileStats.methods[scriptName] = result.method
    
    return result
end

-- ============================================
-- Part 04: PROPERTY SERIALIZER & ASSET COLLECTOR
-- Safe serialization of all Roblox properties
-- ============================================

-- ============================================
-- PROPERTY SERIALIZER - SAFE VALUE CONVERSION
-- ============================================
local function SerializeValue(val)
    local ok, result = xpcall(function()
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
        elseif t == "Instance" then 
            local fn = ""
            pcall(function() fn = val:GetFullName() end)
            return fn
        elseif t == "Ray" then return "Ray.new(...)"
        elseif t == "Faces" then return "Faces(...)"
        elseif t == "Axes" then return "Axes(...)"
        elseif t == "PhysicalProperties" then return "PhysicalProperties(...)"
        elseif t == "Font" then return tostring(val)
        else return tostring(val)
        end
    end, function(e)
        return "[serialize_error]"
    end)
    return ok and result or "[error]"
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
-- ASSET COLLECTOR - EXTRACT ALL ASSET IDS
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
        xpcall(function()
            local val = instance[prop]
            if val and type(val) == "string" and (val:find("rbxasset") or val:find("://")) then
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
        end, function(e) end)
    end
end

-- ============================================
-- Part 05: SCANNER & MAIN DUMPER
-- Script Discovery + Streaming Save Engine
-- All operations wrapped in xpcall for zero crashes
-- ============================================

-- ============================================
-- EXTRA SCRIPT DISCOVERY - Find ALL scripts
-- 9 methods to find every script in the game
-- ============================================
local function DiscoverAllScripts()
    local allScripts = {}
    local seen = {}
    
    local function addScript(obj, source)
        if not seen[obj] then
            seen[obj] = true
            allScripts[#allScripts+1] = {instance = obj, source = source}
        end
    end
    
    -- METHOD 1: Standard services descendants scan
    local servicesToScan = {}
    local function tryAddService(svc, name)
        if svc then
            servicesToScan[#servicesToScan+1] = {svc, name}
        end
    end
    
    tryAddService(Workspace, "Workspace")
    tryAddService(ReplicatedStorage, "ReplicatedStorage")
    tryAddService(ReplicatedFirst, "ReplicatedFirst")
    tryAddService(Lighting, "Lighting")
    tryAddService(StarterGui, "StarterGui")
    tryAddService(StarterPack, "StarterPack")
    tryAddService(StarterPlayer, "StarterPlayer")
    tryAddService(SoundService, "SoundService")
    tryAddService(Teams, "Teams")
    
    pcall(function() tryAddService(game:GetService("Chat"), "Chat") end)
    pcall(function() tryAddService(game:GetService("LocalizationService"), "LocalizationService") end)
    pcall(function() tryAddService(game:GetService("TestService"), "TestService") end)
    pcall(function() tryAddService(game:GetService("ServerStorage"), "ServerStorage") end)
    pcall(function() tryAddService(game:GetService("ServerScriptService"), "ServerScriptService") end)
    
    for _, svc in ipairs(servicesToScan) do
        xpcall(function()
            for _, obj in ipairs(svc[1]:GetDescendants()) do
                xpcall(function()
                    if obj:IsA("BaseScript") or obj:IsA("ModuleScript") then
                        addScript(obj, "service:" .. svc[2])
                    end
                end, function(e) end)
            end
        end, function(e) end)
    end
    Log("  Discovery [Services]: " .. #allScripts .. " scripts")
    
    -- METHOD 2: Player containers
    if LocalPlayer then
        pcall(function()
            local before = #allScripts
            for _, child in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
                pcall(function()
                    if child:IsA("BaseScript") or child:IsA("ModuleScript") then
                        addScript(child, "PlayerGui")
                    end
                end)
            end
            Log("  Discovery [PlayerGui]: +" .. (#allScripts - before))
        end)
        
        pcall(function()
            local before = #allScripts
            for _, child in ipairs(LocalPlayer.Backpack:GetDescendants()) do
                pcall(function()
                    if child:IsA("BaseScript") or child:IsA("ModuleScript") then
                        addScript(child, "Backpack")
                    end
                end)
            end
            Log("  Discovery [Backpack]: +" .. (#allScripts - before))
        end)
        
        pcall(function()
            local before = #allScripts
            for _, child in ipairs(LocalPlayer.PlayerScripts:GetDescendants()) do
                pcall(function()
                    if child:IsA("BaseScript") or child:IsA("ModuleScript") then
                        addScript(child, "PlayerScripts")
                    end
                end)
            end
            Log("  Discovery [PlayerScripts]: +" .. (#allScripts - before))
        end)
    end
    
    -- METHOD 3: CoreGui
    pcall(function()
        local before = #allScripts
        for _, child in ipairs(game:GetService("CoreGui"):GetDescendants()) do
            pcall(function()
                if child:IsA("BaseScript") or child:IsA("ModuleScript") then
                    addScript(child, "CoreGui")
                end
            end)
        end
        Log("  Discovery [CoreGui]: +" .. (#allScripts - before))
    end)
    
    -- METHOD 4: getscripts()
    pcall(function()
        if type(getscripts) == "function" then
            local before = #allScripts
            for _, obj in ipairs(getscripts()) do
                pcall(function()
                    if obj:IsA("BaseScript") or obj:IsA("ModuleScript") then
                        addScript(obj, "getscripts()")
                    end
                end)
            end
            Log("  Discovery [getscripts]: +" .. (#allScripts - before))
        end
    end)
    
    -- METHOD 5: getrunningscripts()
    pcall(function()
        if type(getrunningscripts) == "function" then
            local before = #allScripts
            for _, obj in ipairs(getrunningscripts()) do
                pcall(function()
                    addScript(obj, "getrunningscripts()")
                end)
            end
            Log("  Discovery [getrunningscripts]: +" .. (#allScripts - before))
        end
    end)
    
    -- METHOD 6: getloadedmodules()
    pcall(function()
        if type(getloadedmodules) == "function" then
            local before = #allScripts
            for _, obj in ipairs(getloadedmodules()) do
                pcall(function()
                    addScript(obj, "getloadedmodules()")
                end)
            end
            Log("  Discovery [getloadedmodules]: +" .. (#allScripts - before))
        end
    end)
    
    -- METHOD 7: getnilinstances()
    pcall(function()
        if type(getnilinstances) == "function" then
            local before = #allScripts
            for _, obj in ipairs(getnilinstances()) do
                pcall(function()
                    if obj:IsA("BaseScript") or obj:IsA("ModuleScript") then
                        addScript(obj, "nil_instance")
                    end
                end)
            end
            Log("  Discovery [nil_instances]: +" .. (#allScripts - before))
        end
    end)
    
    -- METHOD 8: getinstances()
    pcall(function()
        if type(getinstances) == "function" then
            local before = #allScripts
            for _, obj in ipairs(getinstances()) do
                pcall(function()
                    if obj:IsA("BaseScript") or obj:IsA("ModuleScript") then
                        addScript(obj, "getinstances()")
                    end
                end)
            end
            Log("  Discovery [getinstances]: +" .. (#allScripts - before))
        end
    end)
    
    -- METHOD 9: getgc() scan
    pcall(function()
        if type(getgc) == "function" then
            local before = #allScripts
            local gcItems = getgc(true)
            for _, item in ipairs(gcItems) do
                if type(item) == "table" then
                    pcall(function()
                        for k, v in pairs(item) do
                            pcall(function()
                                if typeof(v) == "Instance" and (v:IsA("BaseScript") or v:IsA("ModuleScript")) then
                                    addScript(v, "gc_table")
                                end
                            end)
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
-- MAIN DUMPER - STREAMING SAVE ENGINE
-- Every file written immediately on extraction
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
        bytecode_saved = 0, bytecode_parsed = 0, env_dumped = 0,
        closure_decompiled = 0, module_required = 0, debug_extracted = 0,
        gc_recovered = 0, string_recovered = 0, total_failed = 0, methods = {},
    }
    
    local gameName, gameId = GetGameInfo()
    local ROOT = "MapRip/" .. gameName .. "_" .. gameId
    
    Log("=== STARTING ULTIMATE MAP RIP v5.0 GODMODE ===")
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
    MakeFolder(ROOT .. "/Scripts/BytecodeAnalysis")
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
    
    -- Streaming file paths
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
    
    local chunkSizes = {
        combined = 0, combinedNum = 1,
        props = 0, propsNum = 1,
        guis = 0, guisNum = 1,
        models = 0, modelsNum = 1,
    }
    local CHUNK_LIMIT = 400000
    
    SafeWrite(STREAM.combined, "-- ALL SCRIPTS FROM MAP - ULTIMATE DUMP v5.0 GODMODE (STREAMING)\n-- Game: " .. gameName .. "\n\n")
    SafeWrite(STREAM.tree, "FULL HIERARCHY TREE\nGame: " .. gameName .. " (ID: " .. gameId .. ")\n\n")
    SafeWrite(STREAM.props, "ALL PROPERTIES\nGame: " .. gameName .. "\n\n")
    SafeWrite(STREAM.sounds, "ALL SOUNDS\n" .. string.rep("=", 40) .. "\n\n")
    SafeWrite(STREAM.guis, "ALL GUI ELEMENTS\n" .. string.rep("=", 40) .. "\n\n")
    SafeWrite(STREAM.values, "ALL VALUE OBJECTS\n" .. string.rep("=", 40) .. "\n\n")
    SafeWrite(STREAM.anims, "ALL ANIMATIONS\n" .. string.rep("=", 40) .. "\n\n")
    SafeWrite(STREAM.models, "ALL MODELS/PARTS\n" .. string.rep("=", 40) .. "\n\n")
    SafeWrite(STREAM.assets, "ALL ASSET IDS FROM MAP\n" .. string.rep("=", 60) .. "\n\n")
    
    local function StreamAppend(key, content)
        SafeAppend(STREAM[key], content)
        chunkSizes[key] = (chunkSizes[key] or 0) + #content
        
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
    
    -- Services to scan
    local services = {}
    local function tryAddSvc(svc, name)
        if svc then services[#services+1] = {svc, name} end
    end
    tryAddSvc(Workspace, "Workspace")
    tryAddSvc(ReplicatedStorage, "ReplicatedStorage")
    tryAddSvc(ReplicatedFirst, "ReplicatedFirst")
    tryAddSvc(Lighting, "Lighting")
    tryAddSvc(StarterGui, "StarterGui")
    tryAddSvc(StarterPack, "StarterPack")
    tryAddSvc(StarterPlayer, "StarterPlayer")
    tryAddSvc(SoundService, "SoundService")
    tryAddSvc(Teams, "Teams")
    pcall(function() tryAddSvc(game:GetService("Chat"), "Chat") end)
    pcall(function() tryAddSvc(game:GetService("LocalizationService"), "LocalizationService") end)
    pcall(function() tryAddSvc(game:GetService("TestService"), "TestService") end)
    pcall(function() tryAddSvc(game:GetService("ServerStorage"), "ServerStorage") end)
    pcall(function() tryAddSvc(game:GetService("ServerScriptService"), "ServerScriptService") end)
    
    local scriptCounter = 0
    local processedScripts = {}
    
    -- ========== PROCESS SINGLE SCRIPT (shared logic) ==========
    local function ProcessScript(instance, serviceName, discoverySource, isNilFlag)
        if processedScripts[instance] then return end
        processedScripts[instance] = true
        totalScripts = totalScripts + 1
        scriptCounter = scriptCounter + 1
        
        local currentNum = scriptCounter
        
        local ok, err = xpcall(function()
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
            
            local isNil = isNilFlag or false
            if not isNilFlag then
                pcall(function() isNil = instance.Parent == nil end)
            end
            if isNil then scriptType = "NilScripts" end
            
            local fullName = "unknown"
            pcall(function() fullName = instance:GetFullName() end)
            
            local name = SafeName(instance.Name)
            
            local header = string.format(
                "-- ============================================================\n" ..
                "-- SCRIPT: %s\n" ..
                "-- TYPE: %s (%s)\n" ..
                "-- PATH: %s\n" ..
                "-- PARENT: %s [%s]\n" ..
                "-- DISCOVERY: %s\n" ..
                "-- SERVICE: %s\n" ..
                "-- NIL_INSTANCE: %s\n" ..
                "-- METHOD: %s\n" ..
                "-- LAYERS: %s\n" ..
                "-- ============================================================\n\n",
                instance.Name, typeLabel, instance.ClassName, fullName,
                (instance.Parent and instance.Parent.Name or "nil"),
                (instance.Parent and instance.Parent.ClassName or "nil"),
                discoverySource or "scan",
                serviceName or "unknown",
                tostring(isNil),
                decompResult.method,
                SafeConcat(decompResult.layers or {}, " → ")
            )
            
            local scriptContent = header .. (decompResult.source or "-- EMPTY")
            
            -- SAVE INDIVIDUAL FILE
            local fileName = string.format("%04d", currentNum) .. "_" .. name .. ext
            SafeWrite(ROOT .. "/Scripts/" .. scriptType .. "/" .. fileName, scriptContent)
            
            -- APPEND TO COMBINED FILE
            local combinedEntry = string.format(
                "\n\n%s\n-- [%d] %s (%s) [%s] from %s\n-- Path: %s\n%s\n",
                string.rep("=", 70), currentNum,
                instance.Name, instance.ClassName, decompResult.method,
                discoverySource or serviceName or "scan", fullName, string.rep("=", 70)
            ) .. (decompResult.source or "-- EMPTY") .. "\n"
            StreamAppend("combined", combinedEntry)
            
            -- SAVE BYTECODE
            if decompResult.bytecodeB64 then
                SafeWrite(ROOT .. "/Scripts/Bytecode/" .. string.format("%04d", currentNum) .. "_" .. name .. ".b64", decompResult.bytecodeB64)
                if decompResult.bytecodeHex then
                    SafeWrite(ROOT .. "/Scripts/Bytecode/" .. string.format("%04d", currentNum) .. "_" .. name .. ".hex", decompResult.bytecodeHex)
                end
            end
            
            -- SAVE BYTECODE ANALYSIS (NEW in v5.0)
            if decompResult.bytecodeAnalysis then
                SafeWrite(ROOT .. "/Scripts/BytecodeAnalysis/" .. string.format("%04d", currentNum) .. "_" .. name .. "_analysis.txt", decompResult.bytecodeAnalysis)
            end
            
            -- SAVE ENV
            if decompResult.envDump then
                SafeWrite(ROOT .. "/Scripts/Environment/" .. string.format("%04d", currentNum) .. "_" .. name .. "_env.lua", decompResult.envDump)
            end
            
            -- SAVE DEBUG INFO
            if decompResult.debugInfo and decompResult.debugInfo.lines and #decompResult.debugInfo.lines > 0 then
                SafeWrite(ROOT .. "/Scripts/DebugInfo/" .. string.format("%04d", currentNum) .. "_" .. name .. "_debug.txt",
                    table.concat(decompResult.debugInfo.lines, "\n"))
            end
            
            local icon = "✅"
            if decompResult.method == "failed" then icon = "❌"
            elseif decompResult.method == "fallback_composite" then icon = "⚠️"
            elseif decompResult.method:find("bytecode") then icon = "📦"
            end
            
            Log(icon .. " #" .. currentNum .. " [" .. decompResult.method .. "] " .. instance.Name .. " → SAVED")
        end, function(e)
            Log("❌ #" .. currentNum .. " ERROR: " .. SafeStr(e, 200))
        end)
    end
    
    -- ========== RECURSIVE SCANNER ==========
    local function ScanRecursive(instance, path, depth, serviceName)
        if depth > 100 then return end
        
        local ok, _ = xpcall(function()
            totalInstances = totalInstances + 1
            
            local name = SafeName(instance.Name)
            local className = instance.ClassName
            local fullPath = path .. "/" .. name
            
            -- Tree
            local indent = string.rep("│ ", depth)
            SafeAppend(STREAM.tree, indent .. "├─ [" .. className .. "] " .. instance.Name .. "\n")
            
            -- Collect assets
            CollectAssets(instance)
            
            -- Scripts
            if instance:IsA("BaseScript") or instance:IsA("ModuleScript") then
                ProcessScript(instance, serviceName, "service:" .. serviceName)
            end
            
            -- Sounds
            if instance:IsA("Sound") then
                xpcall(function()
                    local soundInfo = string.format("Name: %s\nPath: %s\nSoundId: %s\nVolume: %s\nLooped: %s\nPlaybackSpeed: %s\n%s\n",
                        instance.Name, instance:GetFullName(),
                        tostring(pcall(function() return instance.SoundId end) and instance.SoundId or "?"),
                        tostring(pcall(function() return instance.Volume end) and instance.Volume or "?"),
                        tostring(pcall(function() return instance.Looped end) and instance.Looped or "?"),
                        tostring(pcall(function() return instance.PlaybackSpeed end) and instance.PlaybackSpeed or "?"),
                        string.rep("-", 30))
                    SafeAppend(STREAM.sounds, soundInfo)
                end, function(e) end)
            end
            
            -- GUI Elements
            if instance:IsA("GuiObject") or instance:IsA("ScreenGui") or instance:IsA("BillboardGui") or instance:IsA("SurfaceGui") then
                xpcall(function()
                    local guiInfo = string.format("[%s] %s\n  Path: %s\n", className, instance.Name, instance:GetFullName())
                    local props = GetAllProperties(instance)
                    for k, v in pairs(props) do
                        guiInfo = guiInfo .. "  " .. k .. " = " .. v .. "\n"
                    end
                    StreamAppend("guis", guiInfo .. "\n")
                end, function(e) end)
            end
            
            -- Value Objects
            if instance:IsA("ValueBase") then
                xpcall(function()
                    local valOk, valVal = pcall(function() return instance.Value end)
                    SafeAppend(STREAM.values, string.format("[%s] %s = %s\n  Path: %s\n\n",
                        className, instance.Name, valOk and tostring(valVal) or "?", instance:GetFullName()))
                end, function(e) end)
            end
            
            -- Animations
            if instance:IsA("Animation") or instance:IsA("AnimationTrack") or className == "Animator" then
                xpcall(function()
                    local animId = ""
                    pcall(function() animId = instance.AnimationId end)
                    SafeAppend(STREAM.anims, string.format("[%s] %s\n  Path: %s\n  AnimationId: %s\n\n",
                        className, instance.Name, instance:GetFullName(), animId))
                end, function(e) end)
            end
            
            -- Models/Parts
            if instance:IsA("BasePart") then
                xpcall(function()
                    local props = GetAllProperties(instance)
                    local modelInfo = string.format("[%s] %s\n  Path: %s\n", className, instance.Name, instance:GetFullName())
                    for k, v in pairs(props) do
                        modelInfo = modelInfo .. "  " .. k .. " = " .. v .. "\n"
                    end
                    StreamAppend("models", modelInfo .. "\n")
                end, function(e) end)
            end
            
            -- Properties
            xpcall(function()
                local propsLine = string.format("\n=== [%s] %s ===\nPath: %s\n", className, instance.Name, instance:GetFullName())
                local props = GetAllProperties(instance)
                for k, v in pairs(props) do
                    propsLine = propsLine .. "  " .. k .. " = " .. v .. "\n"
                end
                StreamAppend("props", propsLine)
            end, function(e) end)
            
            -- Yield
            if totalInstances % 150 == 0 then
                pcall(function() (task and task.wait or wait)() end)
                UpdateStatus("Scanning " .. serviceName .. "... (" .. totalInstances .. " | " .. scriptCounter .. " scripts saved)")
                UpdateProgress()
            end
            
            -- Scan children
            local children = {}
            pcall(function() children = instance:GetChildren() end)
            
            for _, child in ipairs(children) do
                local skip = false
                pcall(function()
                    if LocalPlayer and child == LocalPlayer.Character then skip = true end
                    if child:IsA("Camera") and child.Parent == Workspace then skip = true end
                end)
                if not skip then
                    ScanRecursive(child, fullPath, depth + 1, serviceName)
                end
            end
        end, function(e) end)
    end
    
    -- ========== PHASE 1: SCAN SERVICES ==========
    Log(">>> PHASE 1: Scanning Services (streaming save)...")
    for _, svc in ipairs(services) do
        local container, svcName = svc[1], svc[2]
        Log(">>> Scanning: " .. svcName)
        UpdateStatus("Scanning: " .. svcName)
        
        SafeAppend(STREAM.tree, "\n" .. string.rep("=", 60) .. "\nSERVICE: " .. svcName .. "\n" .. string.rep("=", 60) .. "\n")
        
        xpcall(function()
            for _, child in ipairs(container:GetChildren()) do
                ScanRecursive(child, svcName, 1, svcName)
            end
        end, function(e)
            Log("⚠️ Error scanning " .. svcName .. ": " .. SafeStr(e, 100))
        end)
    end
    
    -- ========== PHASE 2: SCAN PLAYER DATA ==========
    Log(">>> PHASE 2: Scanning Player data...")
    UpdateStatus("Scanning Player data...")
    if LocalPlayer then
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
    end
    
    -- ========== PHASE 3: EXTRA DISCOVERY ==========
    Log(">>> PHASE 3: Extra Script Discovery (nil/running/gc)...")
    UpdateStatus("Extra Discovery: nil, running, gc...")
    
    local extraScripts = DiscoverAllScripts()
    local extraFound = 0
    
    for _, entry in ipairs(extraScripts) do
        local obj = entry.instance
        if not processedScripts[obj] then
            extraFound = extraFound + 1
            
            local isNil = false
            pcall(function() isNil = obj.Parent == nil end)
            
            ProcessScript(obj, entry.source, entry.source, isNil)
            
            if extraFound % 5 == 0 then
                pcall(function() (task and task.wait or wait)() end)
                UpdateProgress()
            end
        end
    end
    Log("Extra scripts found: " .. extraFound)
    
    -- ========== PHASE 4: FINAL DATA ==========
    UpdateStatus("Saving final data...")
    Log(">>> PHASE 4: Final data...")
    
    -- Assets
    local assetText = ""
    for id, info in pairs(assetList) do
        assetText = assetText .. string.format("Asset: %s\n  Property: %s\n  Instance: %s\n  Class: %s\n\n",
            id, info.property, info.instance, info.className)
    end
    SafeAppend(STREAM.assets, assetText)
    
    -- saveinstance
    pcall(function()
        if type(saveinstance) == "function" then
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
    reportLines[#reportLines+1] = "  DECOMPILE REPORT - ULTIMATE MAP DUMPER v5.0 GODMODE"
    reportLines[#reportLines+1] = string.rep("=", 60)
    reportLines[#reportLines+1] = ""
    reportLines[#reportLines+1] = "Game: " .. gameName .. " (ID: " .. gameId .. ")"
    reportLines[#reportLines+1] = "Date: " .. os.date("%Y-%m-%d %H:%M:%S")
    reportLines[#reportLines+1] = "Player: " .. (LocalPlayer and LocalPlayer.Name or "N/A")
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
    reportLines[#reportLines+1] = "  saveinstance:        " .. tostring(HAS_SAVEINSTANCE)
    reportLines[#reportLines+1] = ""
    reportLines[#reportLines+1] = "=== STATISTICS ==="
    reportLines[#reportLines+1] = "  Total Scripts:          " .. DecompileStats.total
    reportLines[#reportLines+1] = "  Decompiled:             " .. DecompileStats.decompiled
    reportLines[#reportLines+1] = "  Source Property:        " .. DecompileStats.source_prop
    reportLines[#reportLines+1] = "  Closure Decompiled:     " .. DecompileStats.closure_decompiled
    reportLines[#reportLines+1] = "  Module Required:        " .. DecompileStats.module_required
    reportLines[#reportLines+1] = "  Bytecode Saved:         " .. DecompileStats.bytecode_saved
    reportLines[#reportLines+1] = "  Bytecode Parsed:        " .. DecompileStats.bytecode_parsed
    reportLines[#reportLines+1] = "  Env Dumped:             " .. DecompileStats.env_dumped
    reportLines[#reportLines+1] = "  Debug Extracted:        " .. DecompileStats.debug_extracted
    reportLines[#reportLines+1] = "  GC Recovered:           " .. DecompileStats.gc_recovered
    reportLines[#reportLines+1] = "  String Recovered:       " .. DecompileStats.string_recovered
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
        reportLines[#reportLines+1] = "  " .. icon .. " [" .. method .. "] " .. SafeStr(scriptPath, 200)
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
        "ULTIMATE MAP RIP v5.0 GODMODE - SUMMARY\n" ..
        string.rep("=", 50) .. "\n" ..
        "Game: %s | ID: %d\n" ..
        "Date: %s | By: %s\n" ..
        "Scripts: %d | Success: %d%% | Data: %d%%\n" ..
        "Instances: %d | Assets: %d | Files: %d\n" ..
        "Extra (hidden): %d\n" ..
        string.rep("=", 50) .. "\n",
        gameName, game.PlaceId,
        os.date("%Y-%m-%d %H:%M:%S"), (LocalPlayer and LocalPlayer.Name or "N/A"),
        DecompileStats.total, successRate, dataRate,
        totalInstances, totalAssets, totalFiles, extraFound
    )
    SafeWrite(ROOT .. "/SUMMARY.txt", summary)
    
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
    MakeFolder(ROOT .. "/BytecodeAnalysis")
    MakeFolder(ROOT .. "/Environment")
    MakeFolder(ROOT .. "/ByFolder")
    
    DecompileStats = {
        total = 0, decompiled = 0, source_prop = 0,
        bytecode_saved = 0, bytecode_parsed = 0, env_dumped = 0,
        closure_decompiled = 0, module_required = 0, debug_extracted = 0,
        gc_recovered = 0, string_recovered = 0, total_failed = 0, methods = {},
    }
    
    local scriptCount = 0
    local localCount = 0
    local serverCount = 0
    local moduleCount = 0
    local fileCount = 0
    
    local combinedPath = ROOT .. "/ALL_SCRIPTS_combined.lua"
    local combinedPartNum = 1
    local combinedSize = 0
    local CHUNK_LIMIT = 600000
    
    SafeWrite(combinedPath, string.format(
        "-- ALL GAME SCRIPTS - ULTIMATE DUMP v5.0 GODMODE (STREAMING)\n" ..
        "-- Game: %s (ID: %d)\n" ..
        "-- Date: %s\n\n",
        gameName, gameId, os.date("%Y-%m-%d %H:%M:%S")
    ))
    fileCount = fileCount + 1
    
    local indexPath = ROOT .. "/INDEX.txt"
    SafeWrite(indexPath, string.format(
        "ULTIMATE SCRIPTS DUMP - LIVE INDEX\n" ..
        string.rep("=", 60) .. "\n" ..
        "Game: %s (ID: %d)\n" ..
        "Date: %s\n\n" ..
        string.rep("=", 60) .. "\n\n",
        gameName, gameId, os.date("%Y-%m-%d %H:%M:%S")
    ))
    fileCount = fileCount + 1
    
    Log("=== ULTIMATE SCRIPTS DUMP v5.0 (STREAMING) ===")
    UpdateStatus("Discovering ALL scripts...")
    
    local allScripts = DiscoverAllScripts()
    local total = #allScripts
    
    Log("Found " .. total .. " scripts. Starting extraction...")
    
    for idx, entry in ipairs(allScripts) do
        local obj = entry.instance
        local discoverySource = entry.source
        
        scriptCount = scriptCount + 1
        
        UpdateStatus(string.format("Decompiling %d/%d: %s", idx, total, SafeStr(obj.Name, 30)))
        
        local ok, _ = xpcall(function()
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
                (obj.Parent and obj.Parent.Name or "nil"),
                (obj.Parent and obj.Parent.ClassName or "nil"),
                discoverySource, tostring(isNil),
                decompResult.method,
                tostring(pcall(function() return obj.Enabled end) and (obj.Enabled ~= false) or "N/A"),
                SafeConcat(decompResult.layers or {}, " → ")
            )
            
            local scriptContent = header .. (decompResult.source or "-- EMPTY")
            
            -- SAVE INDIVIDUAL FILE
            local fileName = string.format("%04d", scriptCount) .. "_" .. name .. ext
            SafeWrite(ROOT .. "/" .. folder .. "/" .. fileName, scriptContent)
            fileCount = fileCount + 1
            
            -- APPEND TO COMBINED
            local combinedEntry = string.format(
                "\n\n%s\n-- [%d/%d] %s (%s) [%s] from %s\n-- Path: %s\n%s\n",
                string.rep("=", 70), scriptCount, total,
                obj.Name, obj.ClassName, decompResult.method,
                discoverySource, fullPath, string.rep("=", 70)
            ) .. (decompResult.source or "-- EMPTY") .. "\n"
            
            SafeAppend(combinedPath, combinedEntry)
            combinedSize = combinedSize + #combinedEntry
            
            if combinedSize > CHUNK_LIMIT then
                combinedPartNum = combinedPartNum + 1
                combinedPath = ROOT .. "/ALL_SCRIPTS_combined_part" .. combinedPartNum .. ".lua"
                SafeWrite(combinedPath, "-- ALL SCRIPTS (Part " .. combinedPartNum .. ")\n\n")
                fileCount = fileCount + 1
                combinedSize = 0
            end
            
            -- SAVE BYTECODE
            if decompResult.bytecodeB64 then
                SafeWrite(ROOT .. "/Bytecode/" .. string.format("%04d", scriptCount) .. "_" .. name .. ".b64", decompResult.bytecodeB64)
                fileCount = fileCount + 1
            end
            
            -- SAVE BYTECODE ANALYSIS
            if decompResult.bytecodeAnalysis then
                SafeWrite(ROOT .. "/BytecodeAnalysis/" .. string.format("%04d", scriptCount) .. "_" .. name .. "_analysis.txt", decompResult.bytecodeAnalysis)
                fileCount = fileCount + 1
            end
            
            -- SAVE ENV
            if decompResult.envDump then
                SafeWrite(ROOT .. "/Environment/" .. string.format("%04d", scriptCount) .. "_" .. name .. "_env.lua", decompResult.envDump)
                fileCount = fileCount + 1
            end
            
            -- SAVE BY-FOLDER
            local svcName = discoverySource:match("service:(.+)") or discoverySource
            local folderKey = SafeName(svcName .. "/" .. (obj.Parent and obj.Parent.Name or "root"))
            local byFolderPath = ROOT .. "/ByFolder/" .. folderKey
            MakeFolder(byFolderPath)
            SafeWrite(byFolderPath .. "/" .. name .. "_" .. scriptCount .. ext, scriptContent)
            fileCount = fileCount + 1
            
            -- APPEND TO INDEX
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
        end, function(e)
            Log("❌ Script error: " .. SafeStr(e, 200))
        end)
        
        if scriptCount % 3 == 0 then
            pcall(function() (task and task.wait or wait)(0.1) end)
            UpdateProgress()
        end
        if scriptCount % 15 == 0 then
            pcall(function() (task and task.wait or wait)(0.3) end)
        end
    end
    
    -- Final index update
    local successRate = DecompileStats.total > 0 and math.floor((DecompileStats.decompiled + DecompileStats.source_prop + DecompileStats.closure_decompiled + DecompileStats.module_required) / DecompileStats.total * 100) or 0
    
    SafeAppend(indexPath, string.format(
        "\n" .. string.rep("=", 60) .. "\n" ..
        "FINAL STATS:\n" ..
        "  Total: %d (Local: %d, Server: %d, Module: %d)\n" ..
        "  Success Rate: %d%%\n" ..
        "  Decompiled: %d | Source: %d | Closure: %d | Module: %d\n" ..
        "  Bytecode: %d | Parsed: %d | Env: %d | Debug: %d | GC: %d | Strings: %d\n" ..
        "  Failed: %d\n" ..
        "  Files Written: %d\n",
        scriptCount, localCount, serverCount, moduleCount,
        successRate,
        DecompileStats.decompiled, DecompileStats.source_prop,
        DecompileStats.closure_decompiled, DecompileStats.module_required,
        DecompileStats.bytecode_saved, DecompileStats.bytecode_parsed,
        DecompileStats.env_dumped, DecompileStats.debug_extracted,
        DecompileStats.gc_recovered, DecompileStats.string_recovered,
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
-- Part 06: GUI - Mobile Compatible (Touch + Drag)
-- Enhanced with error-proof UI creation
-- ============================================

local function CreateGUI()
    -- Cleanup old GUI
    pcall(function()
        local old = game:GetService("CoreGui"):FindFirstChild("MapRipGUI")
        if old then old:Destroy() end
    end)
    pcall(function()
        if LocalPlayer and LocalPlayer.PlayerGui then
            local old = LocalPlayer.PlayerGui:FindFirstChild("MapRipGUI")
            if old then old:Destroy() end
        end
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
    TitleText.Text = "💀 ULTIMATE MAP RIPPER v5.0 GODMODE"
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
    Content.CanvasSize = UDim2.new(0, 0, 0, 1200)
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
    
    -- Capability display
    local capText = "🔧 "
    capText = capText .. (HAS_DECOMPILE and "decompile ✅ " or "decompile ❌ ")
    capText = capText .. (HAS_GETSENV and "getsenv ✅ " or "getsenv ❌ ")
    capText = capText .. (HAS_GETSCRIPTBYTECODE and "bytecode ✅ " or "bytecode ❌ ")
    capText = capText .. (HAS_GETNILINSTANCES and "nil ✅ " or "nil ❌ ")
    capText = capText .. (HAS_GETGC and "gc ✅" or "gc ❌")
    
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
    
    -- Version info
    local verLabel = Instance.new("TextLabel")
    verLabel.Text = "🛡️ v5.0 GODMODE | 14-Layer Decompile | Bytecode Parser | Anti-Error"
    verLabel.Size = UDim2.new(1, 0, 0, 16)
    verLabel.BackgroundTransparency = 1
    verLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
    verLabel.TextSize = 9
    verLabel.Font = Enum.Font.GothamBold
    verLabel.LayoutOrder = 2.5
    verLabel.Parent = Content
    
    statusLabel = Instance.new("TextLabel")
    statusLabel.Text = "⏸️ Ready - GODMODE Active"
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
    locInfo.Text = "📁 Output: /sdcard/[Executor]/workspace/MapRip/\n🔥 STREAMING: file langsung tersedia tanpa tunggu selesai!\n🛡️ ANTI-ERROR: xpcall + timeout semua layer"
    locInfo.Size = UDim2.new(1, 0, 0, 48)
    locInfo.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
    locInfo.TextColor3 = Color3.fromRGB(255, 190, 70)
    locInfo.TextSize = 9
    locInfo.Font = Enum.Font.Gotham
    locInfo.TextWrapped = true
    locInfo.LayoutOrder = 16
    locInfo.Parent = Content
    Instance.new("UICorner", locInfo).CornerRadius = UDim.new(0, 6)
    
    logBox = Instance.new("TextLabel")
    logBox.Text = "[Ready] v5.0 GODMODE + Streaming Save + Bytecode Parser\n"
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
    
    if UserInputService then
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end
    
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
            local ok, err = xpcall(function()
                local folder = DumpEverything()
                DumpAllBtn.Text = "✅ DONE! " .. totalFiles .. " files"
                DumpAllBtn.BackgroundColor3 = Color3.fromRGB(30, 160, 30)
            end, function(e)
                DumpAllBtn.Text = "❌ ERROR (check log)"
                Log("CRITICAL ERROR: " .. SafeStr(e, 500))
                DUMP_RUNNING = false
            end)
            pcall(function()
                (task and task.wait or wait)(5)
                DumpAllBtn.Text = "⬇️ RIP EVERYTHING (Streaming Save)"
                DumpAllBtn.BackgroundColor3 = Color3.fromRGB(140, 20, 220)
            end)
        end)
    end)
    
    ScriptsDeepBtn.MouseButton1Click:Connect(function()
        if DUMP_RUNNING then return end
        ScriptsDeepBtn.Text = "⏳ EXTRACTING (streaming)..."
        ScriptsDeepBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        task.spawn(function()
            local ok, err = xpcall(function()
                local folder, count, files, rate = ScriptsOnlyDump()
                ScriptsDeepBtn.Text = string.format("✅ %d scripts | %d%%", count or 0, rate or 0)
                ScriptsDeepBtn.BackgroundColor3 = Color3.fromRGB(30, 160, 30)
            end, function(e)
                ScriptsDeepBtn.Text = "❌ ERROR (check log)"
                Log("CRITICAL ERROR: " .. SafeStr(e, 500))
                DUMP_RUNNING = false
            end)
            pcall(function()
                (task and task.wait or wait)(5)
                ScriptsDeepBtn.Text = "📜 SCRIPTS ONLY (Streaming Save)"
                ScriptsDeepBtn.BackgroundColor3 = Color3.fromRGB(220, 100, 0)
            end)
        end)
    end)
    
    SaveInstanceBtn.MouseButton1Click:Connect(function()
        if not HAS_SAVEINSTANCE then
            Log("❌ saveinstance not supported!")
            SaveInstanceBtn.Text = "❌ NOT SUPPORTED"
            pcall(function() (task and task.wait or wait)(2) end)
            SaveInstanceBtn.Text = "💾 SAVE FULL MAP (.rbxlx)"
            return
        end
        SaveInstanceBtn.Text = "⏳ SAVING..."
        task.spawn(function()
            local gn, gi = GetGameInfo()
            local ok, err = xpcall(function()
                saveinstance({
                    FilePath = "MapRip/" .. gn .. "_" .. gi .. "_FULL.rbxlx",
                    Decompile = true, DecompileTimeout = 30,
                    NilInstances = true, RemovePlayerCharacters = true,
                    ExcludePlayerCharacter = true, ExcludePlayerGui = false,
                    ShowStatus = true, SaveBytecode = true, mode = "full",
                })
            end, function(e) return tostring(e) end)
            SaveInstanceBtn.Text = ok and "✅ SAVED!" or ("❌ " .. SafeStr(err, 40))
            pcall(function() (task and task.wait or wait)(3) end)
            SaveInstanceBtn.Text = "💾 SAVE FULL MAP (.rbxlx)"
        end)
    end)
    
    ClipboardBtn.MouseButton1Click:Connect(function()
        ClipboardBtn.Text = "⏳ COLLECTING..."
        task.spawn(function()
            local ok, err = xpcall(function()
                local allScripts = DiscoverAllScripts()
                local all = {}
                local count = 0
                for _, entry in ipairs(allScripts) do
                    local obj = entry.instance
                    count = count + 1
                    local dr = UltimateDecompile(obj)
                    all[#all+1] = "\n" .. string.rep("=", 60) .. "\n-- [" .. count .. "] " .. SafeStr(obj:GetFullName(), 200) .. "\n-- Class: " .. obj.ClassName .. "\n-- Method: " .. dr.method .. "\n" .. string.rep("=", 60) .. "\n" .. (dr.source or "-- EMPTY")
                    if count % 5 == 0 then 
                        pcall(function() (task and task.wait or wait)(0.1) end)
                    end
                end
                local text = "-- TOTAL: " .. count .. "\n" .. table.concat(all, "\n")
                if type(setclipboard) == "function" then setclipboard(text)
                elseif type(toclipboard) == "function" then toclipboard(text)
                else
                    MakeFolder("MapRip")
                    SafeWrite("MapRip/clipboard_dump.lua", text)
                end
                ClipboardBtn.Text = "✅ " .. count .. " scripts copied!"
            end, function(e)
                ClipboardBtn.Text = "❌ ERROR"
                Log("Clipboard error: " .. SafeStr(e, 200))
            end)
            pcall(function() (task and task.wait or wait)(4) end)
            ClipboardBtn.Text = "📋 COPY ALL SCRIPTS TO CLIPBOARD"
        end)
    end)
    
    TreeOnlyBtn.MouseButton1Click:Connect(function()
        TreeOnlyBtn.Text = "⏳ MAPPING..."
        task.spawn(function()
            local ok, _ = xpcall(function()
                local gn, _ = GetGameInfo()
                local lines = {}
                local count = 0
                local function MapTree(inst, depth)
                    count = count + 1
                    lines[#lines+1] = string.rep("│ ", depth) .. "├─ [" .. inst.ClassName .. "] " .. inst.Name
                    pcall(function()
                        for _, child in ipairs(inst:GetChildren()) do MapTree(child, depth + 1) end
                    end)
                    if count % 500 == 0 then 
                        pcall(function() (task and task.wait or wait)() end)
                    end
                end
                
                local svcs = {}
                local names = {}
                local function addSvc(s, n)
                    if s then svcs[#svcs+1] = s; names[#names+1] = n end
                end
                addSvc(Workspace, "Workspace")
                addSvc(ReplicatedStorage, "ReplicatedStorage")
                addSvc(ReplicatedFirst, "ReplicatedFirst")
                addSvc(Lighting, "Lighting")
                addSvc(StarterGui, "StarterGui")
                addSvc(StarterPack, "StarterPack")
                addSvc(StarterPlayer, "StarterPlayer")
                addSvc(SoundService, "SoundService")
                
                for i, svc in ipairs(svcs) do
                    lines[#lines+1] = "\n" .. string.rep("=", 50) .. "\n" .. names[i] .. "\n" .. string.rep("=", 50)
                    pcall(function() for _, c in ipairs(svc:GetChildren()) do MapTree(c, 1) end end)
                end
                MakeFolder("MapRip")
                SafeWrite("MapRip/TREE_" .. gn .. ".txt", "INSTANCES: " .. count .. "\n\n" .. table.concat(lines, "\n"))
                TreeOnlyBtn.Text = "✅ " .. count .. " instances"
            end, function(e)
                TreeOnlyBtn.Text = "❌ ERROR"
                Log("Tree error: " .. SafeStr(e, 200))
            end)
            pcall(function() (task and task.wait or wait)(3) end)
            TreeOnlyBtn.Text = "🌳 EXPORT TREE STRUCTURE ONLY"
        end)
    end)
    
    -- Parent GUI (CoreGui first, fallback PlayerGui)
    local ok = pcall(function() Gui.Parent = game:GetService("CoreGui") end)
    if not ok then
        pcall(function() Gui.Parent = LocalPlayer.PlayerGui end)
    end
    
    Log("GUI Ready! Game: " .. game.PlaceId)
    Log("Mode: v5.0 GODMODE + 14-Layer Decompile + Bytecode Parser")
    Log("APIs: decompile=" .. tostring(HAS_DECOMPILE) .. " getsenv=" .. tostring(HAS_GETSENV) .. " bytecode=" .. tostring(HAS_GETSCRIPTBYTECODE))
    Log("Anti-Error: xpcall + timeout protection aktif di SEMUA layer")
    return Gui
end

-- ============================================
-- RUN
-- ============================================
CreateGUI()
