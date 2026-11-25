local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local UI = genv.GDH_UI
if typeof(UI) ~= "table" then
    return
end

local Theme = UI.Theme
local Widget = UI.Widget
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Util = nil
do
    local okUtil, moduleValue = pcall(function()
        return genv.Import("Geometry Dash 2.2/Features/Level/Util")
    end)
    if okUtil and typeof(moduleValue) == "table" then
        Util = moduleValue
    end
end

local runtime: any = nil
local checkpointHook = Util ~= nil and Util.NewHook() or nil
local simulationHook = Util ~= nil and Util.NewHook() or nil
local lastCheckpointFrame: number? = nil
local pendingPlayback: string? = nil
local playbackFinished = false
local handleRecordDeath: (() -> ())? = nil

local function S(n: number): number
    return math.floor(n * (Theme.ScreenScale or 1) + 0.5)
end

local function isTypingForCapture(): boolean
    local keyboard = genv.GDH_Keyboard
    if typeof(keyboard) == "table" and typeof(keyboard.IsTyping) == "function" then
        local ok, result = pcall(keyboard.IsTyping)
        if ok then
            return result == true
        end
    end
    return UserInputService:GetFocusedTextBox() ~= nil
end

local function logDiag(message: string)
    local log = getgenv().GDH_POPUP_LOG
    if log == nil then
        log = {}
        getgenv().GDH_POPUP_LOG = log
    end
    table.insert(log, string.format("%.2f %s", os.clock(), message))
    if #log > 240 then
        table.remove(log, 1)
    end
end

local Storage = nil
do
    local Import = genv.Import
    if Import ~= nil then
        local ok, moduleValue = pcall(function()
            return Import("Function/Storage")
        end)
        if ok and typeof(moduleValue) == "table" then
            Storage = moduleValue
        else
            if not ok then
                logDiag("ReplayEngine Storage import error: " .. tostring(moduleValue))
            end
        end
    end
end
if Storage == nil then
    warn("[GDH] Replay Engine: Function/Storage unavailable, saving disabled")
else
    pcall(function()
        local storageModule = Storage :: any
        storageModule.Root()
        storageModule:MacrosFolder()
    end)
end

local ModalListWidget = nil
do
    local Import = genv.Import
    if Import ~= nil then
        local ok, moduleValue = pcall(function()
            return Import("interface/Pc/Widgets/ModalList")
        end)
        if ok and typeof(moduleValue) == "table" then
            ModalListWidget = moduleValue
        end
    end
end
if ModalListWidget == nil then
    warn("[GDH] Replay Engine: interface/Pc/Widgets/ModalList unavailable")
end

local TPS_DEFAULT = 120
local bufferTps: number = TPS_DEFAULT

local engine = {
    mode = "disable",
    replay_name = "",
    tps = TPS_DEFAULT,
    m_currentFrame = 0,
    m_physicIndex = 0,
    m_inputIndex = 0,
    m_physicFrames = {},
    m_inputFrames = {},
    m_animFrames = {},
    m_animIndex = 0,
    accuracy_fix = true,
    velocity_fix = true,
    ignore_inputs = true,
}

local tickAccumulator = 0
local playbackPrevPos: Vector3? = nil
local playbackYOffset = 90
local lastDeadState: boolean? = nil
local savedCharacterStates: {
    root: any?,
    anchored: boolean,
    humanoid: Humanoid?,
    autoRotate: boolean,
    jumpPower: number?,
    walkSpeed: number?,
    runtimeX: number?,
    runtimeY: number?,
    runtimeVy: number?,
    runtimeRotation: number?,
    runtimeGameplayRotation: number?,
    fx: any?,
    fxX: number?,
    fxY: number?,
} = {
    root = nil,
    anchored = false,
    humanoid = nil,
    autoRotate = true,
    jumpPower = nil,
    walkSpeed = nil,
    runtimeX = nil,
    runtimeY = nil,
    runtimeVy = nil,
    runtimeRotation = nil,
    runtimeGameplayRotation = nil,
    fx = nil,
    fxX = nil,
    fxY = nil,
}

local syncModeRadios: (() -> ())? = nil
local makeWarningModal: ((any) -> any)? = nil
local findTextBox: ((Instance?) -> TextBox?)? = nil
local recordOverwriteModal: any = nil
local saveOverwriteModal: any = nil
local loadOverwriteModal: any = nil
local clearModal: any = nil
local proSettingsModal: any = nil
local replayNameRow: any = nil
local selectReplayWidget: any = nil
local proSettingsButton: any = nil
local replaySizeLabel: any = nil
local frameLabel: any = nil
local inputBeganConn: RBXScriptConnection? = nil
local inputEndedConn: RBXScriptConnection? = nil
local characterAddedConn: RBXScriptConnection? = nil
local heartbeatConn: RBXScriptConnection? = nil
local diedConnections: { [Humanoid]: RBXScriptConnection } = setmetatable({}, { __mode = "k" })

local RADIO_FOR_MODE: { [string]: string } = {
    disable = "Disable",
    record = "Record",
    play = "Play",
    continue_mode = "Continue",
}
local modeRadioFrames: { [string]: Instance } = {}

local function getRuntime(): any
    if runtime ~= nil then
        return runtime
    end
    local ok, moduleValue = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local node = port and port:FindFirstChild("ClientRuntime")
        return node and require(node) or nil
    end)
    if ok and typeof(moduleValue) == "table" then
        runtime = moduleValue
    end
    return runtime
end

local function isPlaying(): boolean
    local rt = getRuntime()
    local layer = rt ~= nil and rt.layer or nil
    return typeof(layer) == "table" and typeof(layer.state) == "table"
end

local function getRuntimeState(): any?
    local rt = getRuntime()
    local state = rt ~= nil and rt.layer ~= nil and rt.layer.state or nil
    if typeof(state) == "table" then
        return state
    end
    return nil
end

local function isRuntimeRoot(value: any): boolean
    return typeof(value) == "table" and type(value.x) == "number" and type(value.y) == "number"
end

local function getRuntimeFx(): any?
    local rt = getRuntime()
    local fx = rt ~= nil and rt.layer ~= nil
        and rt.layer.presentation ~= nil
        and rt.layer.presentation.fx
        or nil
    if type(fx) == "table" and type(fx[1]) == "table" then
        return fx[1]
    end
    return nil
end

local function isGameplayActive(): boolean
    local state = getRuntimeState()
    return isPlaying() and state ~= nil and state.dead ~= true
end

local function resetRuntimeToStart(): boolean
    local state = getRuntimeState()
    if state == nil or type(state.reset) ~= "function" then
        return false
    end
    local ok = pcall(function()
        state.reset(state, nil)
    end)
    if ok then
        lastDeadState = false
    end
    return ok
end

local function levelName(): string?
    local name = game.Name
    if typeof(name) ~= "string" or name == "" then
        return nil
    end
    return name
end

if #engine.m_inputFrames == 0 and engine.replay_name == "" then
    local name = levelName()
    if name ~= nil then
        engine.replay_name = name
    end
end

local function currentCharacter(): (any?, Humanoid?, any?)
    local player = Players.LocalPlayer
    if player ~= nil then
        local character = player.Character
        if character ~= nil then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid ~= nil and humanoid.Health > 0 then
                local root = character:FindFirstChild("HumanoidRootPart")
                if root == nil or not root:IsA("BasePart") then
                    root = character:FindFirstChildWhichIsA("BasePart")
                end
                if root ~= nil then
                    return character, humanoid, root :: BasePart
                end
            end
        end
    end
    local state = getRuntimeState()
    if isRuntimeRoot(state) then
        return state, nil, state
    end
    return nil, nil, nil
end

local function get_frame(): number
    return engine.m_currentFrame
end

local function get_actions_size(): number
    return #engine.m_inputFrames
end

local function get_current_index(): number
    return engine.m_inputIndex
end

local function clear()
    engine.m_physicFrames = {}
    engine.m_inputFrames = {}
    engine.m_animFrames = {}
    engine.m_physicIndex = 0
    engine.m_inputIndex = 0
end

local function erasePhysicAtOrAfter(currentFrame: number)
    local kept: { any } = {}
    for _, entry in engine.m_physicFrames do
        if entry.frame < currentFrame then
            table.insert(kept, entry)
        end
    end
    engine.m_physicFrames = kept
    local keptAnims: { any } = {}
    for _, entry in engine.m_animFrames do
        if entry.frame < currentFrame then
            table.insert(keptAnims, entry)
        end
    end
    engine.m_animFrames = keptAnims
end

local function truncateRecording(targetFrame: number): ()
    local function keep(frame: any): boolean
        return type(frame) == "number" and frame <= targetFrame
    end
    local physic: { any } = {}
    for _, entry in engine.m_physicFrames do
        if keep(entry.frame) then
            physic[#physic + 1] = entry
        end
    end
    engine.m_physicFrames = physic
    local anims: { any } = {}
    for _, entry in engine.m_animFrames do
        if keep(entry.frame) then
            anims[#anims + 1] = entry
        end
    end
    engine.m_animFrames = anims
    local inputs: { any } = {}
    for _, entry in engine.m_inputFrames do
        if keep(entry.frame) then
            inputs[#inputs + 1] = entry
        end
    end
    engine.m_inputFrames = inputs
    engine.m_currentFrame = targetFrame
    engine.m_physicIndex = 0
    engine.m_inputIndex = 0
    engine.m_animIndex = 0
    tickAccumulator = 0
    playbackPrevPos = nil
end

local function serialize(): string
    local parts: { string } = {
        "RE4",
        string.format("%.6g", engine.tps),
        tostring(#engine.m_physicFrames),
    }
    for _, physicFrame in engine.m_physicFrames do
        table.insert(parts, string.format(
            "%d %.6g %.6g %.6g %.6g %.6g %.6g %.6g %d",
            physicFrame.frame,
            physicFrame.x,
            physicFrame.y,
            physicFrame.z,
            physicFrame.ox,
            physicFrame.oy,
            physicFrame.oz,
            physicFrame.vy,
            physicFrame.isPlayer2 and 1 or 0))
    end
    table.insert(parts, tostring(#engine.m_inputFrames))
    for _, inputFrame in engine.m_inputFrames do
        table.insert(parts, string.format(
            "%d %d %d %d",
            inputFrame.frame,
            inputFrame.down and 1 or 0,
            inputFrame.button,
            inputFrame.isPlayer2 and 1 or 0))
    end
    if #engine.m_animFrames > 0 then
        table.insert(parts, tostring(#engine.m_animFrames))
        for _, animFrame in engine.m_animFrames do
            local line = string.format("%d %d", animFrame.frame, #animFrame.tracks)
            for _, trackEntry in animFrame.tracks do
                line = line .. string.format(" %s %.6g %.6g %.6g",
                    trackEntry.id, trackEntry.weight, trackEntry.speed, trackEntry.timePos)
            end
            table.insert(parts, line)
        end
    end
    return table.concat(parts, "\n")
end

local function deserialize(raw: string?): boolean
    if typeof(raw) ~= "string" or raw == "" then
        return false
    end
    raw = string.gsub(raw, "\r", "")
    local lines = string.split(raw, "\n")
    if #lines < 3 then
        return false
    end
    local header = ""
    for _, piece in string.split(lines[1], " ") do
        if piece ~= "" then
            header = piece
            break
        end
    end
    if header ~= "RE4" then
        logDiag("deserialize: bad header " .. tostring(lines[1]))
        return false
    end
    local tps = tonumber(lines[2])
    if tps == nil or tps < 1 then
        logDiag("deserialize: bad tps " .. tostring(lines[2]))
        return false
    end
    local physicCount = tonumber(lines[3])
    if physicCount == nil or physicCount < 0 then
        logDiag("deserialize: bad physic count " .. tostring(lines[3]))
        return false
    end
    local cursor = 4
    local physicFrames: { any } = {}
    for _ = 1, physicCount do
        local line = lines[cursor]
        cursor += 1
        if line == nil then
            logDiag("deserialize: missing physic frame at line " .. tostring(cursor))
            return false
        end
        local frame, x, y, z, ox, oy, oz, vy, p2 = line:match(
            "^%s*(%d+)%s+([%-%+%.%deE]+)%s+([%-%+%.%deE]+)%s+([%-%+%.%deE]+)%s+([%-%+%.%deE]+)%s+([%-%+%.%deE]+)%s+([%-%+%.%deE]+)%s+([%-%+%.%deE]+)%s+([%-%+%.%deE]+)%s*$")
        if frame == nil then
            logDiag("deserialize: bad physic frame at line " .. tostring(cursor) .. ": " .. tostring(line))
            return false
        end
        table.insert(physicFrames, {
            frame = tonumber(frame),
            x = tonumber(x),
            y = tonumber(y),
            z = tonumber(z),
            ox = tonumber(ox),
            oy = tonumber(oy),
            oz = tonumber(oz),
            vy = tonumber(vy),
            isPlayer2 = (tonumber(p2) or 0) ~= 0,
        })
    end
    local inputLine = lines[cursor]
    cursor += 1
    if inputLine == nil then
        logDiag("deserialize: missing input count line")
        return false
    end
    local inputCount = tonumber(inputLine)
    if inputCount == nil or inputCount < 0 then
        logDiag("deserialize: bad input count " .. tostring(inputLine))
        return false
    end
    local inputFrames: { any } = {}
    for _ = 1, inputCount do
        local line = lines[cursor]
        cursor += 1
        if line == nil then
            logDiag("deserialize: missing input frame at line " .. tostring(cursor))
            return false
        end
        local frame, down, button, p2 = line:match(
            "^%s*(%d+)%s+([%-%+%.%deE]+)%s+([%-%+%.%deE]+)%s+([%-%+%.%deE]+)%s*$")
        if frame == nil then
            logDiag("deserialize: bad input frame at line " .. tostring(cursor) .. ": " .. tostring(line))
            return false
        end
        table.insert(inputFrames, {
            frame = tonumber(frame),
            down = (tonumber(down) or 0) ~= 0,
            button = tonumber(button) or 0,
            isPlayer2 = (tonumber(p2) or 0) ~= 0,
        })
    end
    local animFrames: { any } = {}
    local animCountLine = lines[cursor]
    cursor += 1
    if animCountLine ~= nil and string.gsub(animCountLine, "%s", "") ~= "" then
        local animCount = tonumber(animCountLine)
        if animCount == nil or animCount < 0 then
            logDiag("deserialize: bad anim count " .. tostring(animCountLine))
            return false
        end
        for _ = 1, animCount do
            local line = lines[cursor]
            cursor += 1
            if line == nil then
                logDiag("deserialize: missing anim frame at line " .. tostring(cursor))
                return false
            end
            local tokens = string.split(line, " ")
            local frameNumber = tonumber(tokens[1])
            local trackCount = tonumber(tokens[2])
            if frameNumber == nil or trackCount == nil or trackCount < 0 then
                logDiag("deserialize: bad anim frame at line " .. tostring(cursor) .. ": " .. tostring(line))
                return false
            end
            local trackList: { any } = {}
            local at = 3
            local okParse = true
            for _ = 1, trackCount do
                local id = tokens[at]
                local weight = tonumber(tokens[at + 1])
                local speed = tonumber(tokens[at + 2])
                local timePos = tonumber(tokens[at + 3])
                at += 4
                if id == nil or id == "" or weight == nil or speed == nil or timePos == nil then
                    okParse = false
                    break
                end
                table.insert(trackList, {
                    id = id,
                    weight = weight,
                    speed = speed,
                    timePos = timePos,
                })
            end
            if not okParse then
                logDiag("deserialize: bad anim track at line " .. tostring(cursor) .. ": " .. tostring(line))
                return false
            end
            table.insert(animFrames, {
                frame = frameNumber,
                tracks = trackList,
            })
        end
    end
    if #animFrames > 0 and #physicFrames > 0 and animFrames[1].frame ~= physicFrames[1].frame then
        animFrames = {}
    end
    engine.m_physicFrames = physicFrames
    engine.m_inputFrames = inputFrames
    engine.m_animFrames = animFrames
    engine.tps = tps
    bufferTps = tps
    return true
end

local function save(name: string): string
    if Storage == nil then
        return "Failed to save Replay (Storage unavailable)"
    end
    if name == nil or name == "" then
        return "Empty macro name is not allowed"
    end
    if get_actions_size() == 0 then
        return "Replay doesn't have actions"
    end
    local serialized = serialize()
    local okCall, saved = pcall(function()
        return (Storage :: any):SaveMacro(name, serialized)
    end)
    if not okCall then
        logDiag("save error: " .. tostring(saved))
        return "Failed to save Replay (error)"
    end
    if not saved then
        logDiag("save refused: name=" .. tostring(name) .. " bytes=" .. tostring(#serialized))
        return "Failed to save Replay (Storage refused)"
    end
    logDiag("saved: " .. tostring(name) .. " inputs=" .. tostring(get_actions_size()) .. " bytes=" .. tostring(#serialized))
    return "Replay Saved"
end

local function load(name: string): string
    if Storage == nil then
        return "Failed to open Replay (Storage unavailable)"
    end
    if name == nil or name == "" then
        return "Failed to open Replay"
    end
    local okRead, data = pcall(function()
        return (Storage :: any):LoadMacro(name)
    end)
    if not okRead then
        logDiag("load error: " .. tostring(data))
        return "Failed to open Replay (error)"
    end
    if data == nil then
        return "Failed to open Replay"
    end
    if not deserialize(data) then
        return "Invalid Replay format"
    end
    engine.m_currentFrame = 0
    engine.m_physicIndex = 0
    engine.m_inputIndex = 0
    engine.m_animIndex = 0
    tickAccumulator = 0
    playbackPrevPos = nil
    logDiag("loaded: " .. tostring(name) .. " frames=" .. tostring(#engine.m_physicFrames))
    return "Replay Loaded"
end

local MOVE_ANIM_BASE_SPEED = 16
local VERTICAL_ANIM_THRESHOLD = 25
local ANIM_FADE_TIME = 0.15

local playbackAnim = {
    active = false,
    humanoid = nil :: Humanoid?,
    animator = nil :: any,
    animateScript = nil :: Instance?,
    animateDisabledByUs = false,
    tracks = {} :: { [string]: AnimationTrack },
    current = "",
    handoverConn = nil :: RBXScriptConnection?,
    pending = "",
    pendingCount = 0,
    moveSpeed = 1,
    lastClock = 0,
    sweepCount = 0,
    airLatch = 0,
    landedDisabled = false,
    recordedTracks = {} :: { [string]: AnimationTrack },
    recordedLooped = {} :: { [string]: boolean },
}

local function stopAllTracksExcept(animator: any, keep: any)
    if animator == nil or animator.Parent == nil then
        return
    end
    local ok, playing = pcall(function()
        return animator:GetPlayingAnimationTracks()
    end)
    if not ok or typeof(playing) ~= "table" then
        return
    end
    for _, track in (playing :: { AnimationTrack }) do
        if track ~= keep then
            pcall(function()
                track:Stop(0.1)
            end)
        end
    end
end

local function stopForeignTracks(animator: any, tracks: { [string]: AnimationTrack })
    if animator == nil or animator.Parent == nil then
        return
    end
    local ok, playing = pcall(function()
        return animator:GetPlayingAnimationTracks()
    end)
    if not ok or typeof(playing) ~= "table" then
        return
    end
    for _, track in (playing :: { AnimationTrack }) do
        if track ~= tracks.idle and track ~= tracks.move and track ~= tracks.jump and track ~= tracks.fall then
            pcall(function()
                track:Stop(0.25)
            end)
        end
    end
end

local function playbackAnimator(humanoid: Humanoid): Instance?
    local animator: Instance? = nil
    pcall(function()
        animator = humanoid:FindFirstChildOfClass("Animator")
    end)
    if animator == nil then
        pcall(function()
            local created = Instance.new("Animator")
            created.Parent = humanoid
            animator = created
        end)
    end
    if typeof(animator) ~= "Instance" then
        return nil
    end
    return animator
end

local function containerNameKind(name: string): string?
    local lowered = string.lower(name)
    if lowered == "run" or lowered == "walk" then
        return lowered
    end
    if lowered == "idle" or lowered == "jump" or lowered == "fall" then
        return lowered
    end
    return nil
end

local function collectPlayerAnimations(animateScript: Instance?): { [string]: Instance }
    local sources: { [string]: Instance } = {}
    if animateScript == nil then
        return sources
    end
    pcall(function()
        for _, descendant in animateScript:GetDescendants() do
            if descendant:IsA("Animation") then
                local kind = nil
                local parent = descendant.Parent
                if parent ~= nil then
                    kind = containerNameKind(parent.Name)
                end
                if kind == nil then
                    kind = containerNameKind(descendant.Name)
                end
                if kind ~= nil and sources[kind] == nil then
                    sources[kind] = descendant
                end
            end
        end
    end)
    return sources
end

local function loadAnimTrack(animator: any, source: Instance?): AnimationTrack?
    if animator == nil or source == nil then
        return nil
    end
    local ok, track = pcall(function()
        return animator:LoadAnimation(source)
    end)
    if ok and typeof(track) == "Instance" then
        return track :: AnimationTrack
    end
    return nil
end

local recordedAnimInstances: { [string]: Animation } = {}

local function roundAnimValue(value: number?): number
    if value == nil or value ~= value then
        return 0
    end
    return math.floor(value * 1000 + 0.5) / 1000
end

local function loadRecordedTrack(animator: any, id: string, loopedById: { [string]: boolean }): AnimationTrack?
    local anim = recordedAnimInstances[id]
    if anim == nil then
        local created = Instance.new("Animation")
        created.AnimationId = id
        recordedAnimInstances[id] = created
        anim = created
    end
    local looped = loopedById[id]
    if looped ~= nil then
        pcall(function()
            (anim :: Animation).Looped = looped
        end)
    end
    local ok, track = pcall(function()
        return (animator :: any):LoadAnimation(anim)
    end)
    if ok and typeof(track) == "Instance" then
        return track :: AnimationTrack
    end
    return nil
end

local function applyRecordedAnimations(humanoid: Humanoid?)
    local state = playbackAnim
    if not state.active or humanoid == nil or state.humanoid ~= humanoid then
        return
    end
    local animator = state.animator
    if animator == nil or animator.Parent == nil then
        return
    end
    local animFrames = engine.m_animFrames
    if engine.m_animIndex >= #animFrames then
        return
    end
    local snapshot = animFrames[engine.m_animIndex + 1]
    if snapshot.frame > engine.m_currentFrame then
        return
    end
    engine.m_animIndex += 1
    local wantedIds: { [string]: boolean } = {}
    for _, trackEntry in snapshot.tracks do
        wantedIds[tostring(trackEntry.id)] = true
    end
    for id, track in state.recordedTracks do
        if not wantedIds[id] then
            pcall(function()
                (track :: AnimationTrack):Stop(0.15)
            end)
            state.recordedTracks[id] = nil
        end
    end
    for _, trackEntry in snapshot.tracks do
        local id = tostring(trackEntry.id)
        if id ~= "" then
            local track: AnimationTrack? = state.recordedTracks[id]
            if track == nil then
                track = loadRecordedTrack(animator, id, state.recordedLooped)
                state.recordedTracks[id] = track
            end
            if track ~= nil then
                local weight = if trackEntry.weight ~= nil then trackEntry.weight else 1
                local speed = if trackEntry.speed ~= nil then trackEntry.speed else 1
                local timePos = if trackEntry.timePos ~= nil then trackEntry.timePos else 0
                pcall(function()
                    local animTrack = track :: AnimationTrack
                    if not animTrack.IsPlaying then
                        animTrack:Play(0.05, weight, speed)
                    end
                    animTrack.TimePosition = timePos
                    animTrack:AdjustSpeed(speed)
                    if math.abs(animTrack.WeightCurrent - weight) > 0.12 then
                        animTrack:AdjustWeight(weight, 0.1)
                    end
                end)
            end
        end
    end
end

local function resetPlaybackAnimState(handoverConn: RBXScriptConnection?)
    playbackAnim.active = false
    playbackAnim.humanoid = nil
    playbackAnim.animator = nil
    playbackAnim.animateScript = nil
    playbackAnim.animateDisabledByUs = false
    playbackAnim.tracks = {}
    playbackAnim.current = ""
    playbackAnim.handoverConn = handoverConn
    playbackAnim.pending = ""
    playbackAnim.pendingCount = 0
    playbackAnim.moveSpeed = 1
    playbackAnim.lastClock = 0
    playbackAnim.sweepCount = 0
    playbackAnim.airLatch = 0
    playbackAnim.landedDisabled = false
    playbackAnim.recordedTracks = {}
    playbackAnim.recordedLooped = {}
end

local function stopPlaybackAnimation(handOver: boolean)
    local state = playbackAnim
    if state.handoverConn ~= nil then
        pcall(function()
            (state.handoverConn :: RBXScriptConnection):Disconnect()
        end)
        state.handoverConn = nil
    end
    if state.active and state.animator ~= nil then
        local animator = state.animator
        if handOver and state.tracks.idle ~= nil then
            local idleTrack = state.tracks.idle :: AnimationTrack
            stopAllTracksExcept(animator, idleTrack)
            pcall(function()
                idleTrack:Play(0.1, 1, 1)
            end)
            pcall(function()
                state.handoverConn = animator.AnimationPlayed:Connect(function(track)
                    if track ~= idleTrack then
                        local conn = playbackAnim.handoverConn
                        if conn ~= nil then
                            conn:Disconnect()
                            playbackAnim.handoverConn = nil
                        end
                        pcall(function()
                            idleTrack:Stop(0.2)
                        end)
                    end
                end)
            end)
        else
            stopAllTracksExcept(animator, nil)
        end
    end
    if state.animateScript ~= nil and state.animateDisabledByUs then
        pcall(function()
            (state.animateScript :: any).Disabled = false
        end)
    end
    if state.landedDisabled and state.humanoid ~= nil then
        pcall(function()
            (state.humanoid :: Humanoid):SetStateEnabled(Enum.HumanoidStateType.Landed, true)
        end)
    end
    resetPlaybackAnimState(state.handoverConn)
end

local function setupPlaybackAnimation(humanoid: Humanoid?)
    if humanoid == nil or (humanoid :: Humanoid).Parent == nil then
        return
    end
    stopPlaybackAnimation(false)
    local animator = playbackAnimator(humanoid :: Humanoid)
    if animator == nil then
        return
    end
    local animateScript: Instance? = nil
    local character = (humanoid :: Humanoid).Parent
    pcall(function()
        animateScript = (character :: Instance):FindFirstChild("Animate")
    end)
    local sources = collectPlayerAnimations(animateScript)
    local moveSource = sources.run or sources.walk
    local tracks: { [string]: AnimationTrack } = {}
    tracks.idle = loadAnimTrack(animator, sources.idle)
    tracks.move = loadAnimTrack(animator, moveSource)
    tracks.jump = loadAnimTrack(animator, sources.jump)
    tracks.fall = loadAnimTrack(animator, sources.fall)
    local resolvedList: { string } = {}
    for _, kind in { "idle", "move", "jump", "fall" } do
        if tracks[kind] ~= nil then
            table.insert(resolvedList, kind)
        end
    end
    local recordedLooped: { [string]: boolean } = {}
    pcall(function()
        local character = (humanoid :: Humanoid).Parent
        for _, descendant in (character :: Instance):GetDescendants() do
            if descendant:IsA("Animation") and descendant.AnimationId ~= "" then
                recordedLooped[string.gsub(descendant.AnimationId, "%s+", "")] = descendant.Looped
            end
        end
    end)
    local hasRecordedAnims = #engine.m_animFrames > 0
    if #resolvedList == 0 and not hasRecordedAnims then
        logDiag("playback animation: no animation instances in player Animate script, game animations untouched")
        return
    end
    local animateDisabledByUs = false
    if animateScript ~= nil then
        pcall(function()
            if (animateScript :: any).Disabled ~= true then
                (animateScript :: any).Disabled = true
                animateDisabledByUs = true
            end
        end)
    end
    stopAllTracksExcept(animator, nil)
    for _, kind in { "idle", "move", "jump", "fall" } do
        local track = tracks[kind]
        if track ~= nil then
            pcall(function()
                (track :: AnimationTrack).Looped = true
            end)
        end
    end
    local landedDisabled = false
    pcall(function()
        (humanoid :: Humanoid):SetStateEnabled(Enum.HumanoidStateType.Landed, false)
        landedDisabled = true
    end)
    playbackAnim.active = true
    playbackAnim.humanoid = humanoid
    playbackAnim.animator = animator
    playbackAnim.animateScript = animateScript
    playbackAnim.animateDisabledByUs = animateDisabledByUs
    playbackAnim.tracks = tracks
    playbackAnim.current = ""
    playbackAnim.landedDisabled = landedDisabled
    playbackAnim.recordedTracks = {}
    playbackAnim.recordedLooped = recordedLooped
    logDiag("playback animation using player Animate script: tracks=" .. table.concat(resolvedList, ",")
        .. " animate=" .. tostring(animateScript ~= nil)
        .. " recorded=" .. tostring(#engine.m_animFrames))
end

local function updatePlaybackAnimation(humanoid: Humanoid?, horizontalSpeed: number, verticalVelocity: number)
    local state = playbackAnim
    if not state.active or humanoid == nil or state.humanoid ~= humanoid then
        return
    end
    local animator = state.animator
    if animator == nil or animator.Parent == nil then
        return
    end
    local now = os.clock()
    local dt = now - state.lastClock
    state.lastClock = now
    if dt <= 0 or dt > 0.25 then
        dt = 0.016
    end
    local wanted = state.current
    if wanted == "" then
        wanted = "idle"
    end
    if state.airLatch > 0 then
        state.airLatch -= 1
    end
    if verticalVelocity > VERTICAL_ANIM_THRESHOLD or verticalVelocity < -VERTICAL_ANIM_THRESHOLD then
        state.airLatch = math.max(state.airLatch, 6)
    end
    local latchAir = state.airLatch > 0
    local airborne = latchAir
    if not airborne then
        pcall(function()
            airborne = (humanoid :: Humanoid).FloorMaterial == Enum.Air
        end)
    end
    if verticalVelocity > VERTICAL_ANIM_THRESHOLD then
        wanted = "jump"
    elseif verticalVelocity < -VERTICAL_ANIM_THRESHOLD then
        wanted = "fall"
    elseif airborne then
        if state.current == "jump" or state.current == "fall" then
            wanted = state.current
        elseif latchAir and verticalVelocity >= 0 then
            wanted = "jump"
        elseif state.current == "" then
            wanted = if verticalVelocity >= 0 then "jump" else "fall"
        elseif verticalVelocity < 0 then
            wanted = "fall"
        end
    elseif horizontalSpeed > 0.5 then
        wanted = "move"
    elseif state.current == "move" and horizontalSpeed < 0.2 then
        wanted = "idle"
    elseif state.current == "jump" or state.current == "fall" then
        wanted = "idle"
    end
    local desired = wanted
    if state.current ~= "" and wanted ~= state.current then
        if wanted == state.pending then
            state.pendingCount += 1
        else
            state.pending = wanted
            state.pendingCount = 1
        end
        if state.pendingCount < 2 then
            desired = state.current
        else
            state.pendingCount = 0
        end
    else
        state.pending = ""
        state.pendingCount = 0
    end
    local track = state.tracks[desired]
    if track == nil and desired ~= "idle" then
        desired = "idle"
        track = state.tracks.idle
    end
    if track == nil then
        return
    end
    if state.current ~= desired then
        stopAllTracksExcept(animator, track)
        pcall(function()
            (track :: AnimationTrack):Play(ANIM_FADE_TIME, 1, 1)
        end)
        state.current = desired
    elseif desired == "jump" then
        pcall(function()
            if not (track :: AnimationTrack).IsPlaying then
                (track :: AnimationTrack):Play(0, 1, 1)
            end
        end)
    end
    if desired == "move" then
        local targetSpeed = math.clamp(horizontalSpeed / MOVE_ANIM_BASE_SPEED, 0.05, 4)
        state.moveSpeed += (targetSpeed - state.moveSpeed) * math.min(1, dt * 8)
        pcall(function()
            (track :: AnimationTrack):AdjustSpeed(state.moveSpeed)
        end)
    end
    state.sweepCount += 1
    if state.sweepCount >= 15 then
        state.sweepCount = 0
        stopForeignTracks(animator, state.tracks)
    end
end

local function releasePlaybackStates(restorePosition: boolean?)
    if restorePosition == nil then
        restorePosition = true
    end
    stopPlaybackAnimation(true)
    local saved = savedCharacterStates
    local root = saved.root
    if isRuntimeRoot(root) then
        if restorePosition then
            pcall(function()
                if saved.runtimeX ~= nil then root.x = saved.runtimeX end
                if saved.runtimeY ~= nil then root.y = saved.runtimeY end
                if saved.runtimeVy ~= nil then root.vy = saved.runtimeVy end
                if saved.runtimeRotation ~= nil then root.rotation = saved.runtimeRotation end
                if saved.runtimeGameplayRotation ~= nil then
                    root.gameplayRotation = saved.runtimeGameplayRotation
                end
                local fx = saved.fx
                if fx ~= nil then
                    if saved.fxX ~= nil then fx.x = saved.fxX end
                    if saved.fxY ~= nil then fx.y = saved.fxY end
                end
            end)
        end
    elseif typeof(root) == "Instance" and root.Parent ~= nil and root:IsA("BasePart") then
        pcall(function()
            root.Anchored = saved.anchored
        end)
    end
    local humanoid = saved.humanoid
    if humanoid ~= nil and humanoid.Parent ~= nil then
        pcall(function()
            humanoid.AutoRotate = saved.autoRotate
            if saved.jumpPower ~= nil then
                humanoid.JumpPower = saved.jumpPower
            end
            if saved.walkSpeed ~= nil then
                humanoid.WalkSpeed = saved.walkSpeed
            end
        end)
    end
    savedCharacterStates = {
        root = nil,
        anchored = false,
        humanoid = nil,
        autoRotate = true,
        jumpPower = nil,
        walkSpeed = nil,
        runtimeX = nil,
        runtimeY = nil,
        runtimeVy = nil,
        runtimeRotation = nil,
        runtimeGameplayRotation = nil,
        fx = nil,
        fxX = nil,
        fxY = nil,
    }
end

local function capturePlaybackStates(): boolean
    local _, humanoid, root = currentCharacter()
    if root == nil then
        return false
    end
    if isRuntimeRoot(root) then
        local fx = getRuntimeFx()
        savedCharacterStates = {
            root = root,
            anchored = false,
            humanoid = nil,
            autoRotate = true,
            jumpPower = nil,
            walkSpeed = nil,
            runtimeX = root.x,
            runtimeY = root.y,
            runtimeVy = root.vy,
            runtimeRotation = root.rotation,
            runtimeGameplayRotation = root.gameplayRotation,
            fx = fx,
            fxX = fx and fx.x or nil,
            fxY = fx and fx.y or nil,
        }
        if fx ~= nil then
            playbackYOffset = (fx.y or 0) - (root.y or 0)
        end
        return true
    end
    savedCharacterStates = {
        root = root,
        anchored = root.Anchored,
        humanoid = humanoid,
        autoRotate = humanoid ~= nil and humanoid.AutoRotate or true,
        jumpPower = humanoid ~= nil and humanoid.JumpPower or nil,
        walkSpeed = humanoid ~= nil and humanoid.WalkSpeed or nil,
        runtimeX = nil,
        runtimeY = nil,
        runtimeVy = nil,
        runtimeRotation = nil,
        runtimeGameplayRotation = nil,
        fx = nil,
        fxX = nil,
        fxY = nil,
    }
    if humanoid ~= nil then
        humanoid.AutoRotate = false
        if engine.ignore_inputs then
            humanoid.JumpPower = 0
        end
    end
    return true
end

local function enterDisable()
    pendingPlayback = nil
    playbackFinished = false
    releasePlaybackStates()
    engine.mode = "disable"
    if typeof(syncModeRadios) == "function" then
        syncModeRadios()
    end
end

local function startRecording()
    pendingPlayback = nil
    playbackFinished = false
    engine.tps = TPS_DEFAULT
    bufferTps = engine.tps
    clear()
    lastCheckpointFrame = nil
    engine.m_currentFrame = 0
    tickAccumulator = 0
    playbackPrevPos = nil
    engine.mode = "record"
    if typeof(syncModeRadios) == "function" then
        syncModeRadios()
    end
end

local function setRecordMode()
    if engine.mode == "record" then
        return
    end
    pendingPlayback = if isPlaying() then nil else "record"
    playbackFinished = false
    releasePlaybackStates()
    lastCheckpointFrame = nil
    engine.mode = "record"
    if typeof(syncModeRadios) == "function" then
        syncModeRadios()
    end
end

local function beginPlayback(targetMode: string): boolean
    if not isPlaying() then
        pendingPlayback = targetMode
        playbackFinished = false
        engine.mode = targetMode
        if typeof(syncModeRadios) == "function" then
            syncModeRadios()
        end
        return true
    end
    playbackFinished = false
    if bufferTps > 0 then
        engine.tps = bufferTps
    end
    if #engine.m_physicFrames == 0 then
        return false
    end
    local _, humanoid, root = currentCharacter()
    if root == nil then
        UI:Notify("Can't start playback: no active player", 5)
        if typeof(syncModeRadios) == "function" then
            syncModeRadios()
        end
        return false
    end
    releasePlaybackStates()
    resetRuntimeToStart()
    _, humanoid, root = currentCharacter()
    engine.m_physicIndex = 0
    engine.m_inputIndex = 0
    engine.m_animIndex = 0
    engine.m_currentFrame = 0
    tickAccumulator = 0
    playbackPrevPos = nil
    if not capturePlaybackStates() then
        UI:Notify("Can't start playback: no alive character", 5)
        if typeof(syncModeRadios) == "function" then
            syncModeRadios()
        end
        return false
    end
    local first = engine.m_physicFrames[1]
    if first ~= nil then
        if isRuntimeRoot(root) then
            root.x = first.x
            root.y = first.y
            if first.vy ~= nil then root.vy = first.vy end
            if first.ox ~= nil then root.rotation = first.ox end
            if first.oz ~= nil then root.gameplayRotation = first.oz end
            local fx = getRuntimeFx()
            if fx ~= nil then
                fx.x = first.x
                fx.y = first.y + playbackYOffset
            end
            playbackPrevPos = Vector3.new(first.x, first.y, 0)
        else
            root.CFrame = CFrame.new(first.x, first.y, first.z)
                * CFrame.fromOrientation(first.ox, first.oy, first.oz)
            playbackPrevPos = Vector3.new(first.x, first.y, first.z)
        end
    end
    setupPlaybackAnimation(humanoid)
    pendingPlayback = nil
    engine.mode = targetMode
    if typeof(syncModeRadios) == "function" then
        syncModeRadios()
    end
    return true
end

local function applyPhysic(entry: any, humanoid: Humanoid?, root: any)
    if isRuntimeRoot(root) then
        pcall(function()
            root.x = entry.x
            root.y = entry.y
            if entry.vy ~= nil then root.vy = entry.vy end
            if entry.ox ~= nil then root.rotation = entry.ox end
            if entry.oz ~= nil then root.gameplayRotation = entry.oz end
            local fx = getRuntimeFx()
            if fx ~= nil then
                fx.x = entry.x
                fx.y = entry.y + playbackYOffset
            end
        end)
        playbackPrevPos = Vector3.new(entry.x, entry.y, 0)
        return
    end
    local nextCFrame = CFrame.new(entry.x, entry.y, entry.z)
        * CFrame.fromOrientation(entry.ox, entry.oy, entry.oz)
    root.CFrame = nextCFrame
    local entryVy = if entry.vy ~= nil then entry.vy else 0
    if engine.velocity_fix then
        local velocity = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(velocity.X, entryVy, velocity.Z)
    end
    local currentPosition = Vector3.new(entry.x, entry.y, entry.z)
    if humanoid ~= nil and humanoid.Parent ~= nil then
        local previous = playbackPrevPos
        local horizontal = if previous ~= nil
            then Vector3.new(
                currentPosition.X - previous.X,
                0,
                currentPosition.Z - previous.Z)
            else Vector3.zero
        local horizontalDistance = horizontal.Magnitude
        local horizontalSpeed = horizontalDistance * engine.tps
        pcall(function()
            humanoid.WalkSpeed = math.clamp(horizontalSpeed, 0, 1000)
            if previous ~= nil then
                if horizontalSpeed < 0.5 then
                    humanoid:Move(Vector3.zero, false)
                else
                    humanoid:Move(horizontal.Unit, false)
                end
            end
        end)
        if #engine.m_animFrames > 0 then
            applyRecordedAnimations(humanoid)
        else
            updatePlaybackAnimation(humanoid, horizontalSpeed, entryVy)
        end
    end
    playbackPrevPos = currentPosition
end

local function applyInterpolated(a: any, b: any, mix: number, root: any)
    local function lerpField(field: string, fallback: number): number
        local av = if type(a[field]) == "number" then a[field] else fallback
        local bv = if type(b[field]) == "number" then b[field] else av
        return av + (bv - av) * mix
    end
    local x = lerpField("x", 0)
    local y = lerpField("y", 0)
    local z = lerpField("z", 0)
    local ox = lerpField("ox", 0)
    local oy = lerpField("oy", 0)
    local oz = lerpField("oz", 0)
    local vy = lerpField("vy", 0)
    if isRuntimeRoot(root) then
        pcall(function()
            root.x = x
            root.y = y
            root.vy = vy
            root.rotation = ox
            root.gameplayRotation = oz
            local fx = getRuntimeFx()
            if fx ~= nil then
                fx.x = x
                fx.y = y + playbackYOffset
            end
        end)
    else
        pcall(function()
            root.CFrame = CFrame.new(x, y, z)
                * CFrame.fromOrientation(ox, oy, oz)
        end)
    end
end

local function fireInput(entry: any, humanoid: Humanoid?)
    if humanoid == nil then
        return
    end
    if entry.button ~= Enum.KeyCode.Space.Value then
        return
    end
    if not entry.down then
        return
    end
    pcall(function()
        if humanoid:GetState() == Enum.HumanoidStateType.Jumping then
            return
        end
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end)
    local tps = engine.tps
    if tps == nil or tps < 1 then
        tps = 60
    end
    playbackAnim.airLatch = math.ceil(tps * 0.5)
end

local function handleCommands(humanoid: Humanoid?)
    local inputFrames = engine.m_inputFrames
    local size = #inputFrames
    if engine.mode == "continue_mode" then
        local reachedEnd = engine.m_inputIndex >= size
        if reachedEnd or (size > 0 and engine.m_currentFrame > inputFrames[size].frame) then
            erasePhysicAtOrAfter(engine.m_currentFrame)
            releasePlaybackStates(false)
            engine.mode = "record"
            if typeof(syncModeRadios) == "function" then
                syncModeRadios()
            end
            UI:Notify("Switched to Record mode. Continue recording!")
            return
        end
    end
    if engine.mode ~= "play" and engine.mode ~= "continue_mode" then
        return
    end
    while engine.m_inputIndex < size and engine.m_currentFrame >= inputFrames[engine.m_inputIndex + 1].frame do
        engine.m_inputIndex += 1
        fireInput(inputFrames[engine.m_inputIndex], humanoid)
    end
end

local function finishPlayback()
    if engine.mode ~= "play" then
        return
    end
    playbackFinished = true
    releasePlaybackStates(false)
    engine.mode = "disable"
    if typeof(syncModeRadios) == "function" then
        syncModeRadios()
    end
end

local function captureRecordedAnims(humanoid: Humanoid?)
    if humanoid == nil or (humanoid :: Humanoid).Parent == nil then
        return
    end
    local animator: Instance? = nil
    pcall(function()
        animator = (humanoid :: Humanoid):FindFirstChildOfClass("Animator")
    end)
    if animator == nil then
        return
    end
    local ok, playing = pcall(function()
        return (animator :: any):GetPlayingAnimationTracks()
    end)
    local snapshot: { any } = {}
    if ok and typeof(playing) == "table" then
        for _, track in (playing :: { AnimationTrack }) do
            pcall(function()
                local anim = (track :: AnimationTrack).Animation
                if anim ~= nil and anim:IsA("Animation") and anim.AnimationId ~= "" then
                    local id = string.gsub(anim.AnimationId, "%s+", "")
                    if id ~= "" then
                        table.insert(snapshot, {
                            id = id,
                            weight = roundAnimValue((track :: AnimationTrack).WeightCurrent),
                            speed = roundAnimValue((track :: AnimationTrack).Speed),
                            timePos = roundAnimValue((track :: AnimationTrack).TimePosition),
                        })
                    end
                end
            end)
        end
    end
    table.insert(engine.m_animFrames, {
        frame = engine.m_currentFrame,
        tracks = snapshot,
    })
end

local function tick(humanoid: Humanoid?, root: any, alpha: number)
    if playbackFinished and engine.mode == "play" then
        return
    end
    engine.m_currentFrame += 1
    if engine.mode == "record" then
        if engine.accuracy_fix then
            local physicFrames = engine.m_physicFrames
            local last = physicFrames[#physicFrames]
            if last == nil or last.frame ~= engine.m_currentFrame then
                if root ~= nil then
                    if isRuntimeRoot(root) then
                        table.insert(physicFrames, {
                            frame = engine.m_currentFrame,
                            x = root.x,
                            y = root.y,
                            z = 0,
                            ox = root.rotation or 0,
                            oy = root.gravityMod or 0,
                            oz = root.gameplayRotation or 0,
                            vy = root.vy or 0,
                            isPlayer2 = root.dual == true,
                        })
                    else
                        local rootCFrame = root.CFrame
                        local ox, oy, oz = rootCFrame:ToOrientation()
                        table.insert(physicFrames, {
                            frame = engine.m_currentFrame,
                            x = rootCFrame.Position.X,
                            y = rootCFrame.Position.Y,
                            z = rootCFrame.Position.Z,
                            ox = ox,
                            oy = oy,
                            oz = oz,
                            vy = root.AssemblyLinearVelocity.Y,
                            isPlayer2 = false,
                        })
                    end
                    captureRecordedAnims(humanoid)
                end
            end
        end
    elseif engine.mode == "play" or engine.mode == "continue_mode" then
        local physicFrames = engine.m_physicFrames
        if #physicFrames == 0 then
            if engine.mode == "play" then
                finishPlayback()
            end
            return
        end
        while engine.m_physicIndex < #physicFrames
            and engine.m_currentFrame >= physicFrames[engine.m_physicIndex + 1].frame
        do
            engine.m_physicIndex += 1
            applyPhysic(physicFrames[engine.m_physicIndex], humanoid, root)
        end
        if engine.mode == "play"
            and #physicFrames > 0
            and engine.m_physicIndex >= #physicFrames
            and engine.m_currentFrame >= physicFrames[#physicFrames].frame
        then
            finishPlayback()
            return
        end
        if alpha > 0 and engine.mode ~= "disable" then
            local previous = physicFrames[engine.m_physicIndex]
            local nextFrame = physicFrames[engine.m_physicIndex + 1]
            if previous ~= nil and nextFrame ~= nil then
                local span = nextFrame.frame - previous.frame
                if span > 0 then
                    local progress = (engine.m_currentFrame - previous.frame + alpha) / span
                    applyInterpolated(previous, nextFrame, math.clamp(progress, 0, 1), root)
                end
            end
        end
        handleCommands(humanoid)
    end
end

local MOUSE_BUTTON_CODES: { [Enum.UserInputType]: number } = {
    [Enum.UserInputType.MouseButton1] = -1,
    [Enum.UserInputType.MouseButton2] = -2,
}

local function captureRawInput(input: InputObject, down: boolean)
    if engine.mode ~= "record" or not isGameplayActive() then
        return
    end
    local button: number? = nil
    if input.UserInputType == Enum.UserInputType.Keyboard then
        button = input.KeyCode.Value
    else
        button = MOUSE_BUTTON_CODES[input.UserInputType]
    end
    if button == nil then
        return
    end
    table.insert(engine.m_inputFrames, {
        frame = engine.m_currentFrame + 1,
        down = down,
        button = button :: number,
        isPlayer2 = false,
    })
end

local function attachDeathHook(humanoid: Humanoid?)
    if humanoid == nil then
        return
    end
    if diedConnections[humanoid] ~= nil then
        return
    end
    diedConnections[humanoid] = humanoid.Died:Connect(function()
        if engine.mode == "record" then
            if handleRecordDeath ~= nil then
                handleRecordDeath()
            end
            return
        end
        if engine.mode == "play" or engine.mode == "continue_mode" then
            task.spawn(function()
                local deadline = os.clock() + 10
                while os.clock() < deadline do
                    task.wait(0.25)
                    if engine.mode ~= "play" and engine.mode ~= "continue_mode" then
                        return
                    end
                    local character, humanoidAlive, root = currentCharacter()
                    if character ~= nil and humanoidAlive ~= nil and root ~= nil then
                        beginPlayback(engine.mode)
                        return
                    end
                end
            end)
        end
    end)
end

handleRecordDeath = function(): ()
    if engine.mode ~= "record" or not isPlaying() then
        return
    end
    local target = lastCheckpointFrame or 0
    truncateRecording(target)
end

if checkpointHook ~= nil then
    checkpointHook:Wrap("Checkpoints", "push", function(original, ...)
        local args = table.pack(...)
        local result = original(...)
        if engine.mode == "record" and isPlaying() then
            local useCheckpoint = false
            local checkpointTable: any = nil
            for index = 1, args.n do
                local value = args[index]
                if value == true then
                    useCheckpoint = true
                end
                if type(value) == "table" and type(value.practice) == "table" and checkpointTable == nil then
                    checkpointTable = value
                end
            end
            if checkpointTable ~= nil and #checkpointTable.practice > 0 then
                useCheckpoint = true
            end
            if useCheckpoint then
                lastCheckpointFrame = engine.m_currentFrame
            end
        end
        return result
    end)
end

if simulationHook ~= nil then
    simulationHook:Wrap("Simulation", "reset", function(original, ...)
        local result = original(...)
        if engine.mode == "record" and handleRecordDeath ~= nil then
            handleRecordDeath()
        end
        return result
    end)
end

findTextBox = function(root: Instance?): TextBox?
    if root == nil then
        return nil
    end
    if root:IsA("TextBox") then
        return root :: TextBox
    end
    return root:FindFirstChildWhichIsA("TextBox", true)
end

local function mouseAnchor(): Vector2
    local ok, location = pcall(function()
        local inset = GuiService:GetGuiInset()
        local mouse = UserInputService:GetMouseLocation()
        return Vector2.new(mouse.X - inset.X, mouse.Y - inset.Y)
    end)
    if ok and typeof(location) == "Vector2" then
        return location
    end
    return Vector2.new(90, 90)
end

local replayWindow = UI:CreateWindow({
    Title = "Replay Engine",
    Order = 9995,
    AutoHeight = true,
    Keybindable = false,
    Searchable = false,
    Size = UDim2.fromOffset(S(270), S(165)),
})

local function showAtMouse(modal: any, trigger: Instance?)
    if modal == nil then
        return
    end
    if trigger ~= nil then
        pcall(function()
            modal:SetOutsideIgnore(trigger)
        end)
    end
    pcall(function()
        modal:ShowAt(mouseAnchor(), Vector2.new(10, 8))
    end)
end

makeWarningModal = function(config: { any }): any
    if ModalListWidget == nil then
        return nil
    end
    local widget: any = nil
    widget = ModalListWidget.create({
        Title = config.Title,
        Body = config.Body,
        BodyWidth = 330,
        FooterLayout = "Row",
        FooterButtons = { config.Yes, "Cancel" },
        GlowSpread = 500,
        OnButton = function(buttonName: string)
            widget.Close()
            if buttonName == config.Yes and typeof(config.OnYes) == "function" then
                config.OnYes()
            end
        end,
        Parent = (replayWindow :: any)._screenGui,
    })
    return widget
end

proSettingsModal = UI:CreateWindow({
    Title = "Pro Settings",
    Popup = true,
    Visible = false,
    Size = UDim2.fromOffset(S(300), 0),
    FitWidth = true,
})

proSettingsModal:AddToggle({
    Name = "Accuracy Fix",
    Default = engine.accuracy_fix,
    Callback = function(state: boolean)
        engine.accuracy_fix = state
    end,
})

proSettingsModal:AddToggle({
    Name = "Y Velocity Fix",
    Default = engine.velocity_fix,
    Callback = function(state: boolean)
        engine.velocity_fix = state
    end,
})

proSettingsModal:AddToggle({
    Name = "Ignore Inputs on Playback",
    Default = engine.ignore_inputs,
    Callback = function(state: boolean)
        engine.ignore_inputs = state
    end,
})

local function chooseReplayMacro(macroId: string)
    macroId = macroId:gsub("%.re4$", "")
    engine.replay_name = macroId
    local field = if findTextBox ~= nil then findTextBox(replayNameRow) else nil
    if field ~= nil then
        field.Text = macroId
    end
end

if ModalListWidget ~= nil then
    selectReplayWidget = ModalListWidget.create({
        Title = "Select Replay",
        ListWidth = 400,
        ListHeight = 500,
        FooterButtons = { "Open Folder", "Close" },
        OnButton = function(buttonName: string)
            if buttonName == "Open Folder" then
                if Storage ~= nil then
                    UI:Notify("Macros folder: Workspace/GDH/Macros", 5)
                else
                    UI:Notify("Macros folder: Workspace/GDH/Macros (Storage unavailable)", 5)
                end
            end
        end,
        Parent = (replayWindow :: any)._screenGui,
    })
end

local function refreshLabels()
    local replaySizeText = string.format("Replay Size: %d/%d", get_current_index(), get_actions_size())
    if replaySizeText ~= lastReplaySizeLabel and replaySizeLabel ~= nil then
        lastReplaySizeLabel = replaySizeText
        replaySizeLabel.Text = replaySizeText
    end
    local frameText = string.format("Frame: %d", get_frame())
    if frameText ~= lastFrameLabel and frameLabel ~= nil then
        lastFrameLabel = frameText
        frameLabel.Text = frameText
    end
end

replayWindow:AddRadioRow({
    {
        Name = "Disable",
        Group = "ReplayEngineMode",
        Default = true,
        Callback = function()
            enterDisable()
        end,
    },
    {
        Name = "Record",
        Group = "ReplayEngineMode",
        Callback = function()
            if engine.mode == "record" then
                return
            end
            if not isPlaying() then
                setRecordMode()
                return
            end
            if get_actions_size() > 0 then
                if recordOverwriteModal ~= nil then
                    recordOverwriteModal.ShowCentered()
                end
                if typeof(syncModeRadios) == "function" then
                    syncModeRadios()
                end
            else
                startRecording()
            end
        end,
    },
    {
        Name = "Play",
        Group = "ReplayEngineMode",
        Callback = function()
            if engine.mode == "play" then
                return
            end
            beginPlayback("play")
        end,
    },
})

replayWindow:AddRadioRow({
    {
        Name = "Continue",
        Group = "ReplayEngineMode",
        Callback = function()
            if engine.mode == "continue_mode" then
                return
            end
            if beginPlayback("continue_mode") then
                UI:Notify("Don't forget to load the replay to continue the recording. It'll play what you recorded and then switch back to recording mode", 15)
            end
        end,
    },
}, 2)

do
    local content = replayWindow:GetContentFrame()
    for _, child in content:GetChildren() do
        if child:IsA("Frame") and child.Name == "RadioRow" then
            for _, radioFrame in child:GetChildren() do
                if radioFrame:IsA("Frame") then
                    local title = radioFrame:FindFirstChild("Title")
                    if title ~= nil and title:IsA("TextButton") then
                        modeRadioFrames[title.Text] = radioFrame
                    end
                end
            end
        end
    end
end

syncModeRadios = function()
    local apis = genv.GDH_RadioButtonApis
    if typeof(apis) ~= "table" then
        return
    end
    local target = RADIO_FOR_MODE[engine.mode]
    for name, frame in modeRadioFrames do
        local api = apis[frame]
        if api ~= nil then
            pcall(function()
                api.SetActive(name == target)
            end)
        end
    end
end

replayWindow:AddSeparator()

local function applyReplayNameFromField()
    local field = if findTextBox ~= nil then findTextBox(replayNameRow) else nil
    if field ~= nil then
        engine.replay_name = field.Text
    end
end

local function popupLog(message: string)
    logDiag(message)
end

local function openSelectReplay()
    if selectReplayWidget == nil then
        return
    end
    local items: { string } = {}
    if Storage ~= nil then
        pcall(function()
            items = (Storage :: any):ListMacros()
        end)
    end
    popupLog("openSelectReplay items=" .. #items)
    local list = selectReplayWidget.List
    if typeof(list) == "Instance" and list:IsA("ScrollingFrame") then
        for _, child in list:GetChildren() do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
        for i, macroId in items do
            local pill = Widget.Button({
                Text = macroId .. ".re4",
                LayoutOrder = i,
                Callback = function()
                    chooseReplayMacro(macroId)
                    pcall(function()
                        (selectReplayWidget :: any).Close()
                    end)
                end,
            })
            pill.LayoutOrder = i
            pill.Parent = list
        end
        popupLog("openSelectReplay pills=" .. #items)
    end
    local okShow, errShow = pcall(function()
        (selectReplayWidget :: any).ShowCentered()
    end)
    popupLog("openSelectReplay show ok=" .. tostring(okShow) .. " err=" .. tostring(errShow))
end

replayNameRow = replayWindow:AddInputRow({
    Hint = "Enter the macro name",
    Arrow = true,
    ArrowDirection = "Down",
    OnArrow = openSelectReplay,
})

local function onBeginSave()
    applyReplayNameFromField()
    local name = engine.replay_name
    local exists = false
    if Storage ~= nil then
        pcall(function()
            exists = (Storage :: any):HasMacro(name)
        end)
    end
    if exists and get_actions_size() > 0 and saveOverwriteModal ~= nil then
        if typeof(saveOverwriteModal.SetBody) == "function" then
            saveOverwriteModal.SetBody(string.format(
                "A macro named \"%s.re4\" already exists.\nAre you sure you want to overwrite it?",
                tostring(name)))
        end
        saveOverwriteModal.ShowCentered()
    else
        UI:Notify(save(name), 5)
    end
end

local function onBeginLoad()
    applyReplayNameFromField()
    if get_actions_size() > 0 and loadOverwriteModal ~= nil then
        loadOverwriteModal.ShowCentered()
    else
        UI:Notify(load(engine.replay_name), 5)
    end
end

local function onBeginClear()
    if get_actions_size() > 0 and clearModal ~= nil then
        clearModal.ShowCentered()
    else
        clear()
        UI:Notify("Replay has been cleared", 5)
    end
end

replayWindow:AddButtonRow({
    {
        Text = "Save",
        Callback = onBeginSave,
    },
    {
        Text = "Load",
        Callback = onBeginLoad,
    },
    {
        Text = "Clear",
        Callback = onBeginClear,
    },
})

replaySizeLabel = replayWindow:AddLabel({ Text = "Replay Size: 0/0" })
frameLabel = replayWindow:AddLabel({ Text = "Frame: 0" })

replayWindow:AddSeparator()

proSettingsButton = replayWindow:AddButton({
    Text = "Pro Settings",
    Callback = function()
        showAtMouse(proSettingsModal, proSettingsButton)
    end,
})

recordOverwriteModal = makeWarningModal({
    Title = "Record Overwrite Warning",
    Body = "You currently have actions stored in the buffer.\nStarting a new recording will clear your current unsaved active macro.\n\nAre you sure you want to proceed?",
    Yes = "Yes, Overwrite",
    OnYes = function()
        startRecording()
    end,
})

saveOverwriteModal = makeWarningModal({
    Title = "Save Overwrite Warning",
    Body = "Are you sure you want to overwrite it?",
    Yes = "Yes, Overwrite",
    OnYes = function()
        UI:Notify(save(engine.replay_name), 5)
    end,
})

loadOverwriteModal = makeWarningModal({
    Title = "Load Overwrite Warning",
    Body = "You currently have recorded actions actively loaded.\nLoading this macro will clear your unsaved working progress.\n\nAre you sure you want to proceed?",
    Yes = "Yes, Load",
    OnYes = function()
        UI:Notify(load(engine.replay_name), 5)
    end,
})

clearModal = makeWarningModal({
    Title = "Clear Warning",
    Body = "Are you sure you want to completely clear the current macro?\nThis action cannot be undone.",
    Yes = "Yes, Clear",
    OnYes = function()
        clear()
        UI:Notify("Replay has been cleared", 5)
    end,
})

inputBeganConn = UserInputService.InputBegan:Connect(function(input)
    if isTypingForCapture() then
        return
    end
    captureRawInput(input, true)
end)

inputEndedConn = UserInputService.InputEnded:Connect(function(input)
    captureRawInput(input, false)
end)

heartbeatConn = RunService.Heartbeat:Connect(function(dtValue: number)
    if not isPlaying() then
        return
    end
    local state = getRuntimeState()
    local deadNow = state ~= nil and state.dead == true
    if deadNow and lastDeadState ~= true then
        if engine.mode == "record" and handleRecordDeath ~= nil then
            handleRecordDeath()
        end
    end
    lastDeadState = deadNow
    if pendingPlayback ~= nil then
        local target = pendingPlayback
        pendingPlayback = nil
        if target == "record" then
            startRecording()
        else
            beginPlayback(target)
        end
    end
    if engine.mode == "disable" then
        return
    end
    if not isGameplayActive() then
        tickAccumulator = 0
        return
    end
    if dtValue <= 0 then
        return
    end
    local _, humanoid, root = currentCharacter()
    if root == nil then
        tickAccumulator = 0
        return
    end
    if humanoid ~= nil then
        attachDeathHook(humanoid)
    end
    local tps = engine.tps
    if tps == nil or tps < 1 or tps ~= tps then
        tps = TPS_DEFAULT
        engine.tps = tps
    end
    tickAccumulator += dtValue * tps
    local ticks = math.floor(tickAccumulator)
    tickAccumulator -= ticks
    if ticks > tps then
        ticks = tps
        tickAccumulator = 0
    end
    for _ = 1, ticks do
        if engine.mode == "disable" then
            break
        end
        tick(humanoid, root, tickAccumulator)
    end
end)

do
    local actions = genv.GDH_KeybindActions
    if typeof(actions) ~= "table" then
        actions = {}
        genv.GDH_KeybindActions = actions
    end

    table.insert(actions, {
        Id = "ReplayEngine::Record",
        Module = "Replay Engine",
        Name = "Record",
        Default = nil,
        Callback = function()
            if engine.mode == "record" then
                enterDisable()
                UI:Notify("Replay Engine: Disable")
            else
                setRecordMode()
                UI:Notify("Replay Engine: Record")
            end
        end,
    })

    table.insert(actions, {
        Id = "ReplayEngine::Playback",
        Module = "Replay Engine",
        Name = "Playback",
        Default = nil,
        Callback = function()
            if engine.mode == "play" then
                enterDisable()
                UI:Notify("Replay Engine: Disable")
            else
                if beginPlayback("play") then
                    UI:Notify("Replay Engine: Play")
                end
            end
        end,
    })

    table.insert(actions, {
        Id = "ReplayEngine::Save Macro By Level Name",
        Module = "Replay Engine",
        Name = "Save Macro By Level Name",
        Default = nil,
        Callback = function()
            local name = levelName()
            if name == nil then
                UI:Notify("Can't get a level name to save a macro", 5)
                return
            end
            UI:Notify(save(name), 5)
        end,
    })

    table.insert(actions, {
        Id = "ReplayEngine::Load Macro By Level Name",
        Module = "Replay Engine",
        Name = "Load Macro By Level Name",
        Default = nil,
        Callback = function()
            local name = levelName()
            if name == nil then
                UI:Notify("Can't get a level name to load a macro", 5)
                return
            end
            UI:Notify(load(name), 5)
        end,
    })

    local sync = genv.GDH_KeybindActionsSync
    if typeof(sync) == "function" then
        pcall(sync)
    end
end

local windowRootConn = replayWindow.Root.Destroying:Connect(function()
    for _, conn in { inputBeganConn, inputEndedConn, characterAddedConn, heartbeatConn } do
        pcall(function()
            conn:Disconnect()
        end)
    end
    for _, conn in diedConnections do
        pcall(function()
            conn:Disconnect()
        end)
    end
    table.clear(diedConnections)
    releasePlaybackStates()
    if checkpointHook ~= nil then checkpointHook:Restore() end
    if simulationHook ~= nil then simulationHook:Restore() end
    engine.mode = "disable"
end)

characterAddedConn = Players.LocalPlayer.CharacterAdded:Connect(function(character: Model)
    local humanoid = character:WaitForChild("Humanoid", 10)
    if humanoid ~= nil and humanoid:IsA("Humanoid") then
        attachDeathHook(humanoid :: Humanoid)
    end
    if engine.mode == "record" then
        tickAccumulator = 0
    end
end)

do
    local player = Players.LocalPlayer
    local character = if player ~= nil then player.Character else nil
    if character ~= nil then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid ~= nil then
            attachDeathHook(humanoid)
        end
    end
end

task.spawn(function()
    task.wait(0.3)
    while windowRootConn.Connected do
        refreshLabels()
        task.wait(0.2)
    end
end)

genv.GDH_REPLAY_STATE = function()
    return {
        mode = engine.mode,
        playing = isPlaying(),
        checkpoint = lastCheckpointFrame,
        frames = #engine.m_physicFrames,
    }
end

logDiag("Replay Engine: loaded - macros in Workspace/GDH/Macros (.re4), mode " .. tostring(engine.mode))
