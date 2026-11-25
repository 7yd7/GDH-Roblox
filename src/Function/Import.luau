local HttpService = game:GetService("HttpService")
local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or (typeof(shared) == "table" and shared)
    or (typeof(getfenv) == "function" and getfenv())
    or {}

local Import = {
    _cache = {},
    _assetCache = {},
    _fontCache = {},
    BaseURL = genv.GDH_BASE_URL or "http://localhost:4000" or "https://github.com/7yd7/GDH-Roblox/main",
    StorageFolder = "GDH/Assets",
}

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64lookup = {}
for i = 1, 64 do
    b64lookup[b64chars:sub(i, i)] = i - 1
end

local function b64decode(data: string): string
    if not data or data == "" then return "" end
    local out = {}
    local bits = 0
    local value = 0
    local len = #data
    for i = 1, len do
        local c = data:sub(i, i)
        if c == "=" then break end
        local n = b64lookup[c]
        if n then
            value = value * 64 + n
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                out[#out + 1] = string.char(math.floor(value / (2 ^ bits)) % 256)
                value = value % (2 ^ bits)
            end
        end
    end
    return table.concat(out)
end

genv.GDH_B64DECODE = genv.GDH_B64DECODE or b64decode

local function getCustomAssetLoader()
    if typeof(getcustomasset) == "function" then return getcustomasset end
    if typeof(getsynasset) == "function" then return getsynasset end
    if typeof(get_custom_asset) == "function" then return get_custom_asset end
    return nil
end

local function safeHttpGet(url: string): string?
    local ok, res = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and typeof(res) == "string" and #res > 0 then
        return res
    end
    return nil
end

local function ensureDirectory(folderPath: string)
    if typeof(makefolder) ~= "function" or typeof(isfolder) ~= "function" then return end
    local parts = folderPath:split("/")
    local current = ""
    for _, part in ipairs(parts) do
        if part ~= "" then
            current = current == "" and part or (current .. "/" .. part)
            if not isfolder(current) then
                pcall(makefolder, current)
            end
        end
    end
end

local function normalizePath(p: string): string
    p = p:gsub("\\", "/")
    p = p:gsub("^%./", "")
    return p
end

local function getFileName(p: string): string
    return p:match("([^/]+)$") or p
end

function Import.Script(path: string)
    path = normalizePath(path)
    if not path:match("%.luau$") and not path:match("%.lua$") then
        path = path .. ".luau"
    end

    if Import._cache[path] ~= nil then
        return Import._cache[path]
    end

    local candidatePaths = {
        path,
        "Script/" .. path,
        "src/" .. path,
        "src/interface/Pc/" .. path,
        path:gsub("^src/", ""),
    }

    local modules = genv.GDH_MODULES
    if modules then
        for _, cp in ipairs(candidatePaths) do
            if typeof(modules[cp]) == "function" then
                local ok, result = pcall(modules[cp])
                if ok then
                    Import._cache[path] = result
                    return result
                else
                    error("[GDH Import] Error in module " .. cp .. ": " .. tostring(result))
                end
            end
        end
    end

    local pkg = genv.GDH_PACKAGE
    if pkg and typeof(loadstring) == "function" then
        for _, cp in ipairs(candidatePaths) do
            if typeof(pkg[cp]) == "string" then
                local fn, err = loadstring(pkg[cp], cp)
                if fn then
                    local result = fn()
                    Import._cache[path] = result
                    return result
                end
            end
        end
    end

    local localPaths = {
        path,
        "GDH/" .. path,
        "GDH/src/" .. path,
    }
    if typeof(isfile) == "function" and typeof(readfile) == "function" and typeof(loadstring) == "function" then
        for _, lp in ipairs(localPaths) do
            if isfile(lp) then
                local success, content = pcall(readfile, lp)
                if success and content then
                    local fn = loadstring(content, lp)
                    if fn then
                        local result = fn()
                        Import._cache[path] = result
                        return result
                    end
                end
            end
        end
    end

    local baseUrl = Import.BaseURL or genv.GDH_BASE_URL
    if baseUrl and typeof(loadstring) == "function" then
        if baseUrl:sub(-1) == "/" then baseUrl = baseUrl:sub(1, -2) end
        local fullUrl = baseUrl .. "/" .. path
        local content = safeHttpGet(fullUrl)
        if content and #content > 0 and content:sub(1, 1) ~= "<" then
            local fn = loadstring(content, path)
            if fn then
                local result = fn()
                Import._cache[path] = result
                return result
            end
        end
    end

    warn("[GDH Import] Could not locate or load script: " .. path)
    return nil
end

function Import.Asset(assetPath: string): string
    assetPath = normalizePath(assetPath)
    local fileName = getFileName(assetPath)

    if Import._assetCache[fileName] then
        return Import._assetCache[fileName]
    end

    local localFilePath = Import.StorageFolder .. "/" .. fileName
    local localDirectory = Import.StorageFolder
    local customAssetFn = getCustomAssetLoader()

    if typeof(isfile) == "function" and isfile(localFilePath) and customAssetFn then
        local ok, customAsset = pcall(customAssetFn, localFilePath)
        if ok and customAsset then
            Import._assetCache[fileName] = customAsset
            return customAsset
        end
    end

    local pkg = genv.GDH_PACKAGE
    local b64Candidates = {
        assetPath,
        "Assets/GDH/" .. fileName,
        "Assets/" .. fileName,
        fileName,
    }

    local b64Data = nil
    if pkg then
        for _, candidate in ipairs(b64Candidates) do
            if pkg[candidate] and typeof(pkg[candidate]) == "string" then
                b64Data = pkg[candidate]
                break
            end
        end
    end

    if b64Data then
        ensureDirectory(localDirectory)
        local decodeFn = genv.GDH_B64DECODE or b64decode
        local okD, binData = pcall(decodeFn, b64Data)
        if okD and binData and #binData > 0 then
            if typeof(writefile) == "function" then
                pcall(writefile, localFilePath, binData)
            end
            if customAssetFn then
                local s, customAsset = pcall(customAssetFn, localFilePath)
                if s and customAsset then
                    Import._assetCache[fileName] = customAsset
                    return customAsset
                end
            end
        end
    end

    local baseUrl = Import.BaseURL or genv.GDH_BASE_URL
    if baseUrl then
        if baseUrl:sub(-1) == "/" then baseUrl = baseUrl:sub(1, -2) end
        local urlCandidates = {
            baseUrl .. "/Assets/GDH/" .. fileName,
            baseUrl .. "/Assets/" .. fileName,
            baseUrl .. "/" .. assetPath,
        }

        for _, fullUrl in ipairs(urlCandidates) do
            local content = safeHttpGet(fullUrl)
            if content and #content > 50 and content:sub(1, 1) ~= "<" then
                ensureDirectory(localDirectory)
                if typeof(writefile) == "function" then
                    pcall(writefile, localFilePath, content)
                end
                if customAssetFn then
                    local s, customAsset = pcall(customAssetFn, localFilePath)
                    if s and customAsset then
                        Import._assetCache[fileName] = customAsset
                        return customAsset
                    end
                end
                break
            end
        end
    end

    return ""
end

function Import.Font(assetPath: string, familyName: string?): Font?
    local cacheKey = familyName or getFileName(normalizePath(assetPath))
    local cached = Import._fontCache[cacheKey]
    if cached then
        return cached
    end

    local customAssetFn = getCustomAssetLoader()
    if not customAssetFn or typeof(writefile) ~= "function" then
        return nil
    end

    local fontAsset = Import.Asset(assetPath)
    if fontAsset == "" then
        return nil
    end

    local family = {
        name = cacheKey,
        faces = {
            {
                name = "Regular",
                weight = 400,
                style = "normal",
                assetId = fontAsset,
            },
        },
    }

    local okEncode, encoded = pcall(function()
        return HttpService:JSONEncode(family)
    end)
    if not okEncode or typeof(encoded) ~= "string" then
        return nil
    end

    ensureDirectory(Import.StorageFolder)
    local jsonFileName = (cacheKey:gsub("[^%w_%-]", "_")) .. "_family.json"
    local jsonPath = Import.StorageFolder .. "/" .. jsonFileName
    local okWrite = pcall(writefile, jsonPath, encoded)
    if not okWrite then
        return nil
    end

    local okCustom, familyAsset = pcall(customAssetFn, jsonPath)
    if not okCustom or typeof(familyAsset) ~= "string" or familyAsset == "" then
        return nil
    end

    local okFont, face = pcall(Font.new, familyAsset, Enum.FontWeight.Regular)
    if not okFont or face == nil then
        return nil
    end

    Import._fontCache[cacheKey] = face
    return face
end

function Import.JSON(path: string): any
    path = normalizePath(path)
    if not path:match("%.json$") then path = path .. ".json" end

    local pkg = genv.GDH_PACKAGE
    if pkg and pkg[path] then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(pkg[path])
        end)
        if ok then return data end
    end

    if typeof(isfile) == "function" and isfile(path) and typeof(readfile) == "function" then
        local ok, content = pcall(readfile, path)
        if ok then
            local okD, data = pcall(function() return HttpService:JSONDecode(content) end)
            if okD then return data end
        end
    end

    local baseUrl = Import.BaseURL or genv.GDH_BASE_URL
    if baseUrl then
        local fullUrl = baseUrl .. "/" .. path
        local content = safeHttpGet(fullUrl)
        if content then
            local okD, data = pcall(function() return HttpService:JSONDecode(content) end)
            if okD then return data end
        end
    end

    return nil
end

setmetatable(Import, {
    __call = function(_, path: string)
        if path:match("%.png$") or path:match("%.ttf$") or path:match("%.otf$") or path:match("%.jpg$") then
            return Import.Asset(path)
        elseif path:match("%.json$") then
            return Import.JSON(path)
        else
            return Import.Script(path)
        end
    end,
})

genv.Import = Import
genv.ImportAsset = Import.Asset

return Import
