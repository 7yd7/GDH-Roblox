local WorkspaceService = workspace

local Storage: any = {}

local GDH_ROOT_NAME = "GDH"
local MACROS_SUBPATH = "Macros"
local MACRO_EXTENSION = ".re4"
local MACRO_FS_DIR = "GDH/Macros"

local function normalizePath(path: string?): string
    local value = if path ~= nil then tostring(path) else ""
    value = value:gsub("\\+", "/")
    value = value:gsub("^/+", "")
    value = value:gsub("/+$", "")
    while value:find("//", 1, true) ~= nil do
        value = value:gsub("//", "/")
    end
    return value
end

local function splitPath(path: string): { string }
    local parts: { string } = {}
    for _, part in string.split(path, "/") do
        if part ~= "" then
            table.insert(parts, part)
        end
    end
    return parts
end

local function isControlFree(part: string): boolean
    for i = 1, #part do
        local byte = string.byte(part, i)
        if byte < 32 or byte == 127 then
            return false
        end
    end
    return true
end

local function validLeafName(name: string): boolean
    if name == "" or name == "." or name == ".." then
        return false
    end
    if name:find("[/]", 1, false) ~= nil then
        return false
    end
    return isControlFree(name)
end

local function validSegment(part: string): boolean
    if not validLeafName(part) then
        return false
    end
    if part:find("[\\:%*%?\"<>|]", 1, false) ~= nil then
        return false
    end
    return true
end

local function ensureRoot(): Folder?
    local ok, result = pcall(function(): Folder
        local existing = WorkspaceService:FindFirstChild(GDH_ROOT_NAME)
        if existing ~= nil and existing:IsA("Folder") then
            return existing
        end
        if existing ~= nil then
            existing:Destroy()
        end
        local folder = Instance.new("Folder")
        folder.Name = GDH_ROOT_NAME
        folder.Parent = WorkspaceService
        return folder
    end)
    if ok and typeof(result) == "Instance" then
        return result
    end
    return nil
end

function Storage.Root(): Instance?
    return ensureRoot()
end

function Storage:Folder(path: string?): Instance?
    local current = ensureRoot()
    if current == nil then
        return nil
    end
    local parts = splitPath(normalizePath(path))
    for _, part in parts do
        if not validSegment(part) then
            return nil
        end
        local child = current:FindFirstChild(part)
        if child ~= nil and child:IsA("Folder") then
            current = child
        else
            if child ~= nil then
                child:Destroy()
            end
            local folder = Instance.new("Folder")
            folder.Name = part
            folder.Parent = current
            current = folder
        end
    end
    if #parts == 0 then
        return current
    end
    return current
end

function Storage:Has(path: string?): boolean
    local parts = splitPath(normalizePath(path))
    if #parts == 0 then
        local root = WorkspaceService:FindFirstChild(GDH_ROOT_NAME)
        return root ~= nil and root:IsA("Folder")
    end
    local current = ensureRoot()
    if current == nil then
        return false
    end
    for _, part in parts do
        local nextNode = current:FindFirstChild(part)
        if nextNode == nil then
            return false
        end
        current = nextNode
    end
    return true
end

function Storage:Children(path: string?): { Instance }
    local node = Storage:Folder(path)
    if node == nil then
        return {}
    end
    return node:GetChildren()
end

function Storage:Names(path: string?): { string }
    local names: { string } = {}
    for _, child in Storage:Children(path) do
        table.insert(names, child.Name)
    end
    return names
end

function Storage:Clear(path: string?): number
    local node = Storage:Folder(path)
    if node == nil then
        return 0
    end
    local count = 0
    for _, child in node:GetChildren() do
        child:Destroy()
        count += 1
    end
    return count
end

function Storage:Write(path: string?, name: string, data: string): Instance?
    local parent = Storage:Folder(path)
    if parent == nil or not validLeafName(tostring(name)) then
        return nil
    end
    local leafName = tostring(name)
    local existing = parent:FindFirstChild(leafName)
    if existing ~= nil and existing:IsA("StringValue") then
        existing.Value = data
        return existing
    end
    if existing ~= nil then
        existing:Destroy()
    end
    local value = Instance.new("StringValue")
    value.Name = leafName
    value.Value = data
    value.Parent = parent
    return value
end

function Storage:Read(path: string?, name: string): string?
    local parent = Storage:Folder(path)
    if parent == nil then
        return nil
    end
    local existing = parent:FindFirstChild(tostring(name))
    if existing ~= nil and existing:IsA("StringValue") then
        return existing.Value
    end
    return nil
end

function Storage:Delete(path: string?, name: string): boolean
    local parent = Storage:Folder(path)
    if parent == nil then
        return false
    end
    local existing = parent:FindFirstChild(tostring(name))
    if existing == nil then
        return false
    end
    existing:Destroy()
    return true
end

function Storage:Rename(path: string?, oldName: string, newName: string): Instance?
    local parent = Storage:Folder(path)
    if parent == nil then
        return nil
    end
    if not validLeafName(tostring(newName)) then
        return nil
    end
    local existing = parent:FindFirstChild(tostring(oldName))
    if existing == nil then
        return nil
    end
    local collision = parent:FindFirstChild(tostring(newName))
    if collision ~= nil then
        collision:Destroy()
    end
    existing.Name = tostring(newName)
    return existing
end

local function fsAvailable(): boolean
    return typeof(writefile) == "function"
        and typeof(readfile) == "function"
        and typeof(isfolder) == "function"
        and typeof(makefolder) == "function"
        and typeof(isfile) == "function"
end

local function ensureFsDirectory(folderPath: string)
    if typeof(makefolder) ~= "function" or typeof(isfolder) ~= "function" then
        return
    end
    local parts = splitPath(normalizePath(folderPath))
    local current = ""
    for _, part in parts do
        current = if current == "" then part else current .. "/" .. part
        if not isfolder(current) then
            pcall(makefolder, current)
        end
    end
end

local function normalizeMacroName(name: string): string
    local macroName = tostring(name)
    if macroName:sub(-#MACRO_EXTENSION) ~= MACRO_EXTENSION then
        macroName = macroName .. MACRO_EXTENSION
    end
    return macroName
end

local function macroIdFromFileName(fileName: string): string
    if fileName:sub(-#MACRO_EXTENSION) == MACRO_EXTENSION then
        return fileName:sub(1, #fileName - #MACRO_EXTENSION)
    end
    return fileName
end

function Storage:MacrosFolder(): Instance?
    return Storage:Folder(MACROS_SUBPATH)
end

function Storage:SaveMacro(name: string, data: string): boolean
    local macroId = tostring(name)
    if macroId == "" or not validSegment(macroId) then
        return false
    end
    local macroName = normalizeMacroName(macroId)
    local savedInstance = false
    local instanceError: string? = nil
    local okInstance, instanceResult = pcall(function(): Instance?
        return Storage:Write(MACROS_SUBPATH, macroName, data)
    end)
    if okInstance then
        savedInstance = instanceResult ~= nil
    else
        instanceError = tostring(instanceResult)
    end
    local savedFile = false
    if fsAvailable() then
        ensureFsDirectory(MACRO_FS_DIR)
        local okFile = pcall(function()
            writefile(MACRO_FS_DIR .. "/" .. macroName, data)
        end)
        savedFile = okFile
    end
    if not savedInstance and not savedFile then
        if instanceError ~= nil then
            pcall(warn, "[GDH Storage] macro write failed: " .. instanceError)
        end
        return false
    end
    return true
end

function Storage:LoadMacro(name: string): string?
    local macroId = tostring(name)
    if macroId == "" or not validSegment(macroId) then
        return nil
    end
    local macroName = normalizeMacroName(macroId)
    local data = Storage:Read(MACROS_SUBPATH, macroName)
    if data ~= nil then
        return data
    end
    if typeof(readfile) == "function" and typeof(isfile) == "function" then
        local filePath = MACRO_FS_DIR .. "/" .. macroName
        if isfile(filePath) then
            local ok, content = pcall(readfile, filePath)
            if ok and typeof(content) == "string" then
                return content
            end
        end
    end
    return nil
end

function Storage:HasMacro(name: string): boolean
    local macroId = tostring(name)
    if macroId == "" or not validSegment(macroId) then
        return false
    end
    local macroName = normalizeMacroName(macroId)
    local parent = Storage:Folder(MACROS_SUBPATH)
    if parent ~= nil and parent:FindFirstChild(macroName) ~= nil then
        return true
    end
    if typeof(isfile) == "function" then
        local ok, found = pcall(function()
            return isfile(MACRO_FS_DIR .. "/" .. macroName)
        end)
        if ok and found then
            return true
        end
    end
    return false
end

function Storage:ListMacros(): { string }
    local ids: { string } = {}
    local seen: { [string]: boolean } = {}
    local parent = Storage:Folder(MACROS_SUBPATH)
    if parent ~= nil then
        for _, child in parent:GetChildren() do
            if child:IsA("StringValue") then
                local id = macroIdFromFileName(child.Name)
                if id ~= "" and seen[id] ~= true then
                    seen[id] = true
                    table.insert(ids, id)
                end
            end
        end
    end
    local listFn = nil
    if typeof(listfolder) == "function" then
        listFn = listfolder
    elseif typeof(listfiles) == "function" then
        listFn = listfiles
    end
    if typeof(listFn) == "function" and typeof(isfolder) == "function" and typeof(isfile) == "function" then
        pcall(function()
            if (isfolder :: any)(MACRO_FS_DIR) then
                for _, entry in (listFn :: any)(MACRO_FS_DIR) do
                    if typeof(entry) == "string" then
                        local normalized = string.gsub(entry, "\\", "/")
                        local slashAt = string.find(normalized, "/[^/]*$")
                        local baseName = normalized
                        if slashAt ~= nil then
                            baseName = string.sub(normalized, slashAt + 1)
                        end
                        local fullPath = if string.find(normalized, "/", 1, true) ~= nil
                            then normalized
                            else MACRO_FS_DIR .. "/" .. baseName
                        local isFileOk = pcall(function()
                            return (isfile :: any)(fullPath)
                        end)
                        if isFileOk and baseName ~= "" then
                            local id = macroIdFromFileName(baseName)
                            if id ~= "" and seen[id] ~= true then
                                seen[id] = true
                                table.insert(ids, id)
                            end
                        end
                    end
                end
            end
        end)
    end
    table.sort(ids)
    return ids
end

function Storage:DeleteMacro(name: string): boolean
    local macroId = tostring(name)
    if macroId == "" or not validSegment(macroId) then
        return false
    end
    local macroName = normalizeMacroName(macroId)
    local removed = Storage:Delete(MACROS_SUBPATH, macroName)
    if typeof(delfile) == "function" and typeof(isfile) == "function" then
        local filePath = MACRO_FS_DIR .. "/" .. macroName
        pcall(function()
            if isfile(filePath) then
                (delfile :: any)(filePath)
            end
        end)
    end
    return removed
end

return Storage
