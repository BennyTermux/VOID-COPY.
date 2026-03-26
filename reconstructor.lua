-- VOID-COPY v1.1 | Built from scratch for Bennny | Zero dependencies
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local VOID = {}
local genv = (getgenv and getgenv()) or _G

genv.VOID_COPY = genv.VOID_COPY or {}

local CONFIG = {
    output_folder = "VOID-COPY",
    max_depth = 250,
    debug = false,
}

local function debug_log(...)
    if CONFIG.debug then
        print("[VOID-COPY]", ...)
    end
end

local function guid()
    if HttpService.GenerateGUID then
        return HttpService:GenerateGUID(false)
    end

    return string.format(
        "%08x-%04x-%04x-%04x-%012x",
        math.random(0, 0xFFFFFFFF),
        math.random(0, 0xFFFF),
        math.random(0, 0xFFFF),
        math.random(0, 0xFFFF),
        math.random(0, 0xFFFFFFFFFFF)
    )
end

local function safe_read_property(inst, prop)
    local ok, value = pcall(function()
        return inst[prop]
    end)

    if not ok then
        return nil
    end

    local value_type = typeof(value)
    if value_type == "Instance" or value_type == "RBXScriptSignal" or value_type == "function" then
        return nil
    end

    return value
end

local function get_all_properties(inst)
    local props = {}

    -- Instance:GetProperties is executor-dependent and often unavailable.
    local ok, property_names = pcall(function()
        return inst:GetProperties()
    end)

    if not ok or type(property_names) ~= "table" then
        return props
    end

    for _, prop in ipairs(property_names) do
        local value = safe_read_property(inst, prop)
        if value ~= nil then
            props[prop] = value
        end
    end

    return props
end

local function get_tags(inst)
    local ok, tags = pcall(function()
        return CollectionService:GetTags(inst)
    end)

    return (ok and tags) or {}
end

local function serialize_instance(inst, visited, node_count, depth)
    if visited[inst] then
        return nil
    end

    if depth > CONFIG.max_depth then
        debug_log("Depth cap reached at", inst:GetFullName())
        return nil
    end

    visited[inst] = true
    node_count.value += 1

    local data = {
        id = guid(),
        class = inst.ClassName,
        name = inst.Name,
        properties = get_all_properties(inst),
        attributes = inst:GetAttributes(),
        tags = get_tags(inst),
        children = {},
    }

    if inst:IsA("LuaSourceContainer") then
        local source_ok, source = pcall(function()
            return inst.Source
        end)

        if source_ok then
            data.source = source
        end
    end

    for _, child in ipairs(inst:GetChildren()) do
        local child_data = serialize_instance(child, visited, node_count, depth + 1)
        if child_data then
            table.insert(data.children, child_data)
        end
    end

    return data
end

local function sanitize_name(name)
    return tostring(name):gsub("%W", "_")
end

local function ensure_folder(path)
    if isfolder and isfolder(path) then
        return
    end

    if makefolder then
        makefolder(path)
    end
end

local function build_reconstructor_template(hierarchy_url)
    return string.format([[
-- VOID-COPY RECONSTRUCTOR v1.1 | Load via loadstring
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local data = HttpService:JSONDecode(game:HttpGet(%q))

local function rebuild(node, parent)
    local ok, inst = pcall(function()
        return Instance.new(node.class)
    end)

    if not ok or not inst then
        warn("[VOID-COPY] Failed to create instance of class:", node.class)
        return
    end

    inst.Name = node.name

    for k, v in pairs(node.properties or {}) do
        pcall(function()
            inst[k] = v
        end)
    end

    for k, v in pairs(node.attributes or {}) do
        pcall(function()
            inst:SetAttribute(k, v)
        end)
    end

    for _, tag in ipairs(node.tags or {}) do
        pcall(function()
            CollectionService:AddTag(inst, tag)
        end)
    end

    if node.source then
        pcall(function()
            inst.Source = node.source
        end)
    end

    inst.Parent = parent

    for _, child in ipairs(node.children or {}) do
        rebuild(child, inst)
    end
end

rebuild(data.hierarchy, game)
print("VOID-COPY RECONSTRUCTION COMPLETE")
]], hierarchy_url)
end

local function main()
    print("VOID-COPY INITIALIZED - TARGET ACQUIRED")
    print("PlaceId:", game.PlaceId, "| Game:", game.Name)

    local visited = {}
    local node_count = { value = 0 }
    local root = serialize_instance(game, visited, node_count, 0)

    local payload = {
        metadata = {
            place_id = game.PlaceId,
            game_name = game.Name,
            timestamp = os.time(),
            instance_count = node_count.value,
        },
        hierarchy = root,
    }

    local json_data = HttpService:JSONEncode(payload)

    local folder_path = string.format("%s/%s_%s", CONFIG.output_folder, tostring(game.PlaceId), sanitize_name(game.Name))
    ensure_folder(CONFIG.output_folder)
    ensure_folder(folder_path)

    if not writefile then
        error("writefile is not available in this executor environment")
    end

    writefile(folder_path .. "/hierarchy.json", json_data)
    print("COPY COMPLETE - Hierarchy written to:", folder_path .. "/hierarchy.json")

    local hierarchy_url = "https://raw.githubusercontent.com/YOURUSERNAME/VOID-COPY/main/hierarchy.json"
    local reconstructor_code = build_reconstructor_template(hierarchy_url)
    writefile(folder_path .. "/reconstructor.lua", reconstructor_code)
    print("RECONSTRUCTOR GENERATED - Ready for GitHub")

    local loadstring_template = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/YOURUSERNAME/VOID-COPY/main/reconstructor.lua"))()'
    print("GITHUB LOADSTRING READY:")
    print(loadstring_template)
    print("Replace YOURUSERNAME with your GitHub username and upload the folder contents.")
end

local ok, err = pcall(main)
if not ok then
    warn("VOID-COPY FAILED:", err)
else
    print("VOID-COPY MISSION COMPLETE - Files written to executor workspace.")
end

return VOID
