-- VOID-COPY v1.0 | Built from scratch for Bennny | Zero dependencies
local VOID = {}
local genv = getgenv() or {}
genv.VOID_COPY = genv.VOID_COPY or {}

local function secure_env()
    local mt = getmetatable(genv) or {}
    mt.__index = function() return nil end
    setmetatable(genv, mt)
end
secure_env()

local CONFIG = {
    output_folder = "VOID-COPY",
    exclude_services = {"CoreGui", "CorePackages", "RobloxGui"},
    max_depth = 250,
    chunk_size = 512,
    debug = false
}

local function guid()
    return string.format("%08x-%04x-%04x-%04x-%012x", math.random(0,0xfffffff), math.random(0,0xffff), math.random(0,0xffff), math.random(0,0xffff), math.random(0,0xfffffffffff))
end

local function get_all_properties(inst)
    local props = {}
    local success, result = pcall(function()
        return inst:GetProperties()
    end)
    if success then
        for _, prop in ipairs(result) do
            local ok, val = pcall(function() return inst[prop] end)
            if ok then props[prop] = val end
        end
    end
    return props
end

local function serialize_instance(inst, visited, id_map)
    if visited[inst] then return nil end
    visited[inst] = true

    local id = guid()
    id_map[inst] = id

    local data = {
        id = id,
        class = inst.ClassName,
        name = inst.Name,
        properties = get_all_properties(inst),
        attributes = inst:GetAttributes(),
        tags = inst:GetTags and inst:GetTags() or {},
        children = {}
    }

    if inst:IsA("LuaSourceContainer") then
        data.source = inst.Source
    end

    for _, child in ipairs(inst:GetChildren()) do
        local child_data = serialize_instance(child, visited, id_map)
        if child_data then table.insert(data.children, child_data) end
    end

    return data
end

local function main()
    print("VOID-COPY INITIALIZED – TARGET ACQUIRED")
    print("PlaceId:", game.PlaceId, "| Game:", game.Name)

    local visited = {}
    local id_map = {}
    local root = serialize_instance(game, visited, id_map)

    local json_data = game:GetService("HttpService"):JSONEncode({
        metadata = {
            place_id = game.PlaceId,
            game_name = game.Name,
            timestamp = os.time(),
            instance_count = #visited
        },
        hierarchy = root,
        id_map = id_map
    })

    local folder_path = CONFIG.output_folder .. "/" .. game.PlaceId .. "_" .. game.Name:gsub("%W", "_")
    makefolder(folder_path)

    writefile(folder_path .. "/hierarchy.json", json_data)
    print("COPY COMPLETE – Hierarchy written to:", folder_path .. "/hierarchy.json")

    local reconstructor_code = [[
-- VOID-COPY RECONSTRUCTOR v1.0 | Load via loadstring
local data = game:GetService("HttpService"):JSONDecode(game:HttpGet("https://raw.githubusercontent.com/BennyTermux/VOID-COPY/main/hierarchy.json"))
local function rebuild(node, parent)
    local inst = Instance.new(node.class)
    inst.Name = node.name
    for k, v in pairs(node.properties) do pcall(function() inst[k] = v end) end
    for k, v in pairs(node.attributes) do inst:SetAttribute(k, v) end
    for _, tag in ipairs(node.tags) do inst:AddTag(tag) end
    if node.source then inst.Source = node.source end
    inst.Parent = parent
    for _, child in ipairs(node.children) do rebuild(child, inst) end
end
rebuild(data.hierarchy, game)
print("VOID-COPY RECONSTRUCTION COMPLETE")
]]
    writefile(folder_path .. "/reconstructor.lua", reconstructor_code)
    print("RECONSTRUCTOR GENERATED – Ready for GitHub")

    local loadstring_template = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/YOURUSERNAME/VOID-COPY/main/reconstructor.lua"))()'
    print("GITHUB LOADSTRING READY:")
    print(loadstring_template)
    print("Replace YOURUSERNAME with your GitHub username and upload the folder contents.")
end

pcall(main)
print("VOID-COPY MISSION COMPLETE – Files written to executor workspace.")
