local ui_reference, ui_new_checkbox, ui_new_slider, ui_new_combobox, ui_new_multiselect, ui_new_listbox, ui_new_label, ui_new_hotkey, ui_new_textbox, ui_new_button, ui_new_string, ui_get, ui_set, ui_set_visible, ui_set_callback, ui_update, ui_is_menu_open = ui.reference, ui.new_checkbox, ui.new_slider, ui.new_combobox, ui.new_multiselect, ui.new_listbox, ui.new_label, ui.new_hotkey, ui.new_textbox, ui.new_button, ui.new_string, ui.get, ui.set, ui.set_visible, ui.set_callback, ui.update, ui.is_menu_open
local client_set_event_callback, client_unset_event_callback, client_screen_size, client_userid_to_entindex,  client_current_threat, client_random_int = client.set_event_callback, client_unset_event_callback, client.screen_size, client.userid_to_entindex, client.current_threat, client.random_int
local entity_get_players, entity_get_esp_data, entity_is_alive, entity_get_prop, entity_get_player_resource, entity_is_enemy, entity_get_game_rules, entity_get_local_player, entity_get_origin = entity.get_players, entity.get_esp_data, entity.is_alive, entity.get_prop, entity.get_player_resource, entity.is_enemy, entity.get_game_rules, entity.get_local_player, entity.get_origin
local globals_maxplayers, globals_realtime, globals_curtime = globals.maxplayers, globals.realtime, globals.curtime
local database_read, database_write  = database.read, database.write
local json_parse, json_stringify = json.parse, json.stringify
local bit_band, bit_lshift = bit.band, bit.lshift
local table_insert, table_remove = table.insert, table.remove
local math_sqrt, math_cos, math_abs = math.sqrt, math.cos, math.abs
local select, pairs, ipairs, tostring, setmetatable = select, pairs, ipairs, tostring, setmetatable
local string_find, string_format = string.find, string.format

local bit = require("bit")
local vector = require("vector")

local references = {
    { -- visible
        fake_lag_limit = ui_reference("AA", "Fake lag", "Limit"),
        slow_motion = ui_reference("AA", "Other", "Slow motion"),
        slow_motion_key = select(2, ui_reference("AA", "Other", "Slow motion")),
        onshot_aa = ui_reference("AA", "Other", "On shot anti-aim"),
        onshot_aa_key = select(2, ui_reference("AA", "Other", "On shot anti-aim")),
        double_tap = ui_reference("RAGE", "Other", "Double tap"),
        double_tap_key = select(2, ui_reference("RAGE", "Other", "Double tap")),
        double_tap_lag = ui_reference("RAGE", "Other", "Double tap fake lag limit"),
        enabled = ui_reference("AA", "Anti-aimbot angles", "Enabled"),
    },
    { -- hidden
        pitch = ui_reference("AA", "Anti-aimbot angles", "Pitch"),
        yaw_base = ui_reference("AA", "Anti-aimbot angles", "Yaw base"),
        yaw = ui_reference("AA", "Anti-aimbot angles", "Yaw"),
        yaw_val = select(2, ui_reference("AA", "Anti-aimbot angles", "Yaw")),
        jitter = ui_reference("AA", "Anti-aimbot angles", "Yaw jitter"),
        jitter_val = select(2, ui_reference("AA", "Anti-aimbot angles", "Yaw jitter")),
        body = ui_reference("AA", "Anti-aimbot angles", "Body yaw"),
        body_val = select(2, ui_reference("AA", "Anti-aimbot angles", "Body yaw")),
        freestand_body = ui_reference("AA", "Anti-aimbot angles", "Freestanding body yaw"),
        fake_limit = ui_reference("AA", "Anti-aimbot angles", "Fake yaw limit"),
        roll = ui_reference("AA", "Anti-aimbot angles", "Roll"),
        edge_yaw = ui_reference("AA", "Anti-aimbot angles", "Edge yaw"),
        freestanding = ui_reference("AA", "Anti-aimbot angles", "Freestanding"),
        freestanding_key = select(2, ui_reference("AA", "Anti-aimbot angles", "Freestanding")),
    }
}

local menu = {
    browser = ui_new_listbox("AA", "Anti-aimbot angles", "Menu browser", {}),

    conditions = ui_new_multiselect("AA", "Anti-aimbot angles", "Activation conditions", {"Always", "Not moving", "Moving", "Slow motion", "On ground", "In air", "Breaking LC", "Vulnerable", "Crouching", "Not crouching",  "Height advantage", "Height disadvantage", "Doubletapping", "Defensive", "Terrorist", "Counter terrorist", "Dormant", "Round end"}),
    conditions_logic = ui_new_combobox("AA", "Anti-aimbot angles", "\nConditions logic", "And", "Or"),
    pitch = ui_new_combobox("AA", "Anti-aimbot angles", "Pitch", {"Off", "Default", "Down", "Up", "Random", "Minimal"}),
    yaw_base = ui_new_combobox("AA", "Anti-aimbot angles", "Yaw base", {"Local view", "At targets"}),
    yaw = ui_new_combobox("AA", "Anti-aimbot angles", "Yaw", {"Off", "180", "Spin", "Static", "180 Z", "Crosshair"}),
    yaw_val = ui_new_slider("AA", "Anti-aimbot angles", "\nYaw value", -180, 180, 8, true, "°"),
    jitter = ui_new_combobox("AA", "Anti-aimbot angles", "Yaw jitter", {"Off", "Offset", "Center", "Random"}),
    jitter_val = ui_new_slider("AA", "Anti-aimbot angles", "\nYaw jitter value", -180, 180, 8, true, "°"),
    body = ui_new_combobox("AA", "Anti-aimbot angles", "Body yaw", {"Off", "Opposite", "Jitter", "Static"}),
    body_val = ui_new_slider("AA", "Anti-aimbot angles", "\nBody yaw value", -180, 180, 60, true, "°"),
    freestand_body = ui_new_checkbox("AA", "Anti-aimbot angles", "Freestanding body yaw"),
    fake_limit = ui_new_slider("AA", "Anti-aimbot angles", "Fake yaw limit", 0, 60, 60, true, "°"),
    edge_yaw = ui_new_checkbox("AA", "Anti-aimbot angles", "Edge yaw"),
    freestanding = ui_new_checkbox("AA", "Anti-aimbot angles", "Freestanding"),
    freestanding_key = ui_new_hotkey("AA", "Anti-aimbot angles", "Freestanding key", true),
    roll = ui_new_slider("AA", "Anti-aimbot angles", "Roll", -50, 50, 0, true, "°"),

    blank_label = ui_new_label("AA", "Anti-aimbot angles", " "),
    block_name_label = ui_new_label("AA", "Anti-aimbot angles", "Block name"),
    block_name = ui_new_textbox("AA", "Anti-aimbot angles", "Block name textbox"),
    add_block = ui_new_button("AA", "Anti-aimbot angles", "Add new", function() end),
    add_block_save = ui_new_button("AA", "Anti-aimbot angles", "Save new", function() end),
    edit_block = ui_new_button("AA", "Anti-aimbot angles", "Edit", function() end),
    edit_block_save = ui_new_button("AA", "Anti-aimbot angles", "Save edits", function() end),
    disable_block = ui_new_button("AA", "Anti-aimbot angles", "Toggle", function() end),
    delete_block = ui_new_button("AA", "Anti-aimbot angles", "Delete", function() end),
    move_up = ui_new_button("AA", "Anti-aimbot angles", "Move up", function() end),
    move_down = ui_new_button("AA", "Anti-aimbot angles", "Move down", function() end),
    go_back = ui_new_button("AA", "Anti-aimbot angles", "Go back (unsaved)", function() end),

    force_choke = ui_new_checkbox("AA", "Fake lag", "Force choke"),
    disable_on_round_end = ui_new_checkbox("AA", "Fake lag", "Disable on round end"),

    config = ui_new_string("Config save string", ""),
}

local status = "Browsing menu"
local last_browser = {nil, 0}
local blocks = {}

local function includes(tab, val)
    for i,v in ipairs(tab) do
        if v == val then
            return true
        end
    end

    return false
end

local function set_table_visibility(tab, b)
    for k,v in pairs(tab) do
        ui_set_visible(v, b)
    end
end

local function update_browser()
    local display_table = {}
    local num_disabled = 0

    for i,v in ipairs(blocks) do
        local disabled = v.disabled or false
        local start = disabled and string_format("\a%02x%02x%02x%02x[-] ", 100, 100, 100, 225) or "["..(i - num_disabled).."] "
        display_table[#display_table+1] = start.. v.name
        if disabled then
            num_disabled = num_disabled + 1
        end
    end

    ui_update(menu.browser, display_table)
end

local function update_menu_settings(block)
    if not block then block = {} end

    ui_set(menu.conditions, block.conditions or {})
    ui_set(menu.conditions_logic, block.conditions_logic or "And")
    ui_set(menu.pitch, block.pitch or "Off")
    ui_set(menu.yaw_base, block.yaw_base or "Local view")
    ui_set(menu.yaw, block.yaw or "Off")
    ui_set(menu.yaw_val, block.yaw_val or 8)
    ui_set(menu.jitter, block.jitter or "Off")
    ui_set(menu.jitter_val, block.jitter_val or 8)
    ui_set(menu.body, block.body or "Off")
    ui_set(menu.body_val, block.body_val or 60)
    ui_set(menu.freestand_body, block.freestand_body or false)
    ui_set(menu.fake_limit, block.fake_limit or 60)
    ui_set(menu.edge_yaw, block.edge_yaw or false)
    ui_set(menu.freestanding, block.freestanding or false)
    ui_set(menu.roll, block.roll or 0)
end

local function update_menu()
    local browsing_menu = status == "Browsing menu"
    local browser = ui_get(menu.browser)
    local has_block = status:find("block")

    set_table_visibility({menu.browser, menu.add_block}, browsing_menu)
    set_table_visibility({menu.block_name_label, menu.block_name, menu.conditions, menu.conditions_logic, menu.pitch, menu.yaw_base, menu.yaw, menu.body, menu.edge_yaw, menu.freestanding, menu.freestanding_key, menu.roll}, has_block)

    ui_set_visible(menu.add_block_save, status == "Adding block")
    ui_set_visible(menu.edit_block, browsing_menu and browser)
    ui_set_visible(menu.edit_block_save, status == "Editing block")
    ui_set_visible(menu.delete_block, browsing_menu and browser and #blocks > 1)
    ui_set_visible(menu.disable_block, browsing_menu and browser)
    ui_set_visible(menu.move_up, browsing_menu and browser and browser > 0)
    ui_set_visible(menu.move_down, browsing_menu and browser and browser < #blocks - 1)
    ui_set_visible(menu.go_back, not browsing_menu and status ~= "Tutorial")
    ui_set_visible(menu.blank_label, not browsing_menu)

    ui_set_visible(menu.yaw_val, has_block and ui_get(menu.yaw) ~= "Off")
    ui_set_visible(menu.jitter, has_block and ui_get(menu.yaw) ~= "Off")
    ui_set_visible(menu.jitter_val, has_block and ui_get(menu.yaw) ~= "Off" and ui_get(menu.jitter) ~= "Off")
    ui_set_visible(menu.body_val, has_block and ui_get(menu.body) ~= "Off" and ui_get(menu.body) ~= "Opposite")
    ui_set_visible(menu.freestand_body, has_block and ui_get(menu.body) ~= "Off")
    ui_set_visible(menu.fake_limit, has_block and ui_get(menu.body) ~= "Off")
end

local function is_vulnerable()
    for _, v in ipairs(entity_get_players(true)) do
        local flags = (entity_get_esp_data(v)).flags

        if bit_band(flags, bit_lshift(1, 11)) ~= 0 then
            return true
        end
    end

    return false
end

local function get_total_enemies()
    local count = 0
    for e = 1, globals_maxplayers() do
        if entity_get_prop(entity_get_player_resource(), "m_bConnected", e) and entity_is_enemy(e) and entity_is_alive(e) then
            count = count + 1
        end
    end
    return count
end

local last_origin, last_sim_time, on_ground_ticks = vector(0,0,0), 0, 0
local function get_conditions(cmd, local_player)
    local velocity = {entity_get_prop(local_player, "m_vecVelocity")}
    local speed = math_sqrt(velocity[1] * velocity[1] + velocity[2] * velocity[2])
    local flags = entity_get_prop(local_player, "m_fFlags")
    local on_ground = bit_band(flags, 1) == 1
    local duck_amount = entity_get_prop(local_player, "m_flDuckAmount")
    local team_num = entity_get_prop(entity_get_player_resource(), "m_iTeam", local_player)
    local sim_time = toticks(entity_get_prop(local_player, "m_flSimulationTime"))
    local sim_diff = sim_time - last_sim_time
    last_sim_time = sim_time
    local origin = vector(entity_get_origin(local_player))
    local breaking_lc = (last_origin - origin):length2dsqr() > 4096
    local threat = client_current_threat()
    local pitch_to_threat = 0
    local height_to_threat = 0

    on_ground_ticks = on_ground and on_ground_ticks + 1 or 0
    
    if cmd.chokedcommands == 0 then
        last_origin = origin
    end

    if threat then
        local threat_origin = vector(entity_get_origin(threat))
        pitch_to_threat = origin:to(threat_origin):angles()
        height_to_threat = origin.z-threat_origin.z
    end

    local conditions = {
        ["Always"] = true,
        ["Not moving"] = speed < 2,
        ["Slow motion"] = ui_get(references[1].slow_motion) and ui_get(references[1].slow_motion_key) and speed >= 2,
        ["Moving"] = speed >= 2,
        ["On ground"] = on_ground_ticks > 1,
        ["In air"] = on_ground_ticks <= 1,
        ["Breaking LC"] = breaking_lc,
        ["Height advantage"] = threat and height_to_threat > 25,
        ["Height disadvantage"] = threat and height_to_threat < -25,
        ["Vulnerable"] = is_vulnerable(),
        ["Not crouching"] = duck_amount < 0.9,
        ["Crouching"] = duck_amount >= 0.9,
        ["Doubletapping"] = ui_get(references[1].double_tap) and ui_get(references[1].double_tap_key) and cmd.chokedcommands <= ui_get(references[1].double_tap_lag),
        ["Defensive"] = sim_diff < 0,
        ["Terrorist"] = team_num == 2,
        ["Counter terrorist"] = team_num == 3,
        ["Dormant"] = #entity_get_players(true) == 0,
        ["Round end"] = entity_get_prop(entity_get_game_rules(), "m_iRoundWinStatus") ~= 0 and get_total_enemies() == 0
    }

    return conditions
end

local Block = {}
do
    Block.__index = Block

    function Block.defaults()
        return {
            disabled = false,
            conditions = {"Always"},
            conditions_logic = "And",
            pitch = ui_get(references[2].pitch),
            yaw_base = ui_get(references[2].yaw_base),
            yaw = ui_get(references[2].yaw),
            yaw_val = ui_get(references[2].yaw_val),
            jitter = ui_get(references[2].jitter),
            jitter_val = ui_get(references[2].jitter_val),
            body = ui_get(references[2].body),
            body_val = ui_get(references[2].body_val),
            freestand_body = ui_get(references[2].freestand_body),
            fake_limit = ui_get(references[2].fake_limit),
            roll = ui_get(references[2].roll),
            freestanding = #ui_get(references[2].freestanding) == 1 and ui_get(references[2].freestanding_key),
            edge_yaw = ui_get(references[2].edge_yaw)
        }
    end

    function Block.new(name)
        local self = setmetatable({}, Block)

        self:update_settings(name)

        blocks[#blocks+1] = self
    end

    function Block.new_from_table(name, tab)
        local self = setmetatable({}, Block)
        local settings = Block.defaults()

        for k,v in pairs(tab) do
            if settings[k] then -- compatability between versions
                settings[k] = v
            end
        end

        settings.name = name

        for k,v in pairs(settings) do
            self[k] = v
        end

        blocks[#blocks+1] = self
    end

    function Block:update_settings(name)
        self.name = name or self.name or "Default"
        self.disabled = self.disabled ~= nil and self.disabled or false
        self.conditions = ui_get(menu.conditions)
        self.conditions_logic = ui_get(menu.conditions_logic)
        self.pitch = ui_get(menu.pitch)
        self.yaw_base = ui_get(menu.yaw_base)
        self.yaw = ui_get(menu.yaw)
        self.yaw_val = ui_get(menu.yaw_val)
        self.jitter = ui_get(menu.jitter)
        self.jitter_val = ui_get(menu.jitter_val)
        self.body = ui_get(menu.body)
        self.body_val = ui_get(menu.body_val)
        self.freestand_body = ui_get(menu.freestand_body)
        self.fake_limit = ui_get(menu.fake_limit)
        self.roll = ui_get(menu.roll)
        self.freestanding = ui_get(menu.freestanding)
        self.edge_yaw = ui_get(menu.edge_yaw)
    end

    function Block:set_antiaim(cmd)
        if cmd.chokedcommands > 0 then
            return
        end

        for k,v in pairs(self) do
            local ref = references[2][k]
            if ref and k ~= "freestanding" then
                ui_set(ref, v)
            elseif k == "freestanding" then
                ui_set(ref, v and ui_get(menu.freestanding_key) and "Default" or "-")
            end
        end

        ui_set(references[2].freestanding_key, "Always on")
    end

    function Block:conditions_met(cmd, local_player, local_conditions)
        local conditions = self.conditions
        local num_conditions = #conditions
        local logic = self.conditions_logic

        if logic == "And" then
            for i,condition in ipairs(conditions) do
                if not local_conditions[condition] then
                    return false
                end
            end

            return true
        elseif logic == "Or" then
            for i,condition in ipairs(conditions) do
                if local_conditions[condition] then
                    return true
                end
            end

            return false
        end

        return false
    end
end

local function set_defaults()
    Block.new_from_table("Default", Block.defaults())
    update_browser()
end

local function run_antiaim(cmd, local_player, local_conditions)
    local browser = ui_get(menu.browser)
    if ui_is_menu_open() and browser and status == "Editing block" then
        local block = blocks[browser+1]
        block:update_settings()
        block:set_antiaim(cmd)
        ui_set(references[2].yaw_base, "Local view")
    else
        for i,block in ipairs(blocks) do
            if (block:conditions_met(cmd, local_player, local_conditions) or i == #blocks) and not block.disabled then
                block:set_antiaim(cmd)
                break
            end
        end
    end

    set_table_visibility(references[2], false)
end

local function run_fakelag(cmd, local_player, local_conditions)
    local flags = entity_get_prop(local_player, "m_fFlags")
    local on_ground = bit_band(flags, 1) == 1
    local no_choke = false

    if local_conditions["Round end"] and ui_get(menu.disable_on_round_end) then
        cmd.no_choke = 1
        no_choke = true
    end

    if ui_get(menu.force_choke) and not no_choke then
        cmd.allow_send_packet = false
    end
end

local function load_config(tab)
    blocks = {}

    for i,v in ipairs(tab) do
        Block.new_from_table(v.name, v)
    end

    ui_set(menu.browser, 0)
    update_browser()
    set_table_visibility(references[2], false)
end

local function save_config()
    ui_set(menu.config, tostring(json_stringify(blocks)))
end

local function set_button_callbacks()
    ui_set_callback(menu.browser, function(self)
        local idx = ui_get(self) + 1
        local realtime = globals_realtime()
        
        if realtime - last_browser[2] < 0.5 and idx == last_browser[1] then
            ui_set(menu.edit_block, true)
        end

        last_browser = {idx, globals_realtime()}
        update_menu()
    end)

    ui_set_callback(menu.add_block_save, function()
        Block.new(ui_get(menu.block_name))
        update_browser()
        ui_set(menu.go_back, true)
    end)

    ui_set_callback(menu.edit_block_save, function()
        local idx = ui_get(menu.browser) + 1
        local current_block = blocks[idx]
        current_block:update_settings(ui_get(menu.block_name))
        ui_set(menu.go_back, true)
        update_browser()
    end)

    ui_set_callback(menu.add_block, function() 
        status = "Adding block"
        ui_set(menu.block_name, "") 
        update_menu_settings() 
        update_menu() 
    end)

    ui_set_callback(menu.edit_block, function() 
        if not ui_get(menu.browser) then
            return
        end

        local idx = ui_get(menu.browser) + 1
        ui_set(menu.block_name, blocks[idx].name)
        status = "Editing block"
        update_menu_settings(blocks[ui_get(menu.browser)+1]) 
        update_menu() 
    end)

    ui_set_callback(menu.delete_block, function()
        if #blocks == 1 then
            return
        end
        local idx = ui_get(menu.browser) + 1
        table_remove(blocks, idx)
        update_browser()
        update_menu()
        if ui_get(menu.browser) and ui_get(menu.browser) >= #blocks then
            ui_set(menu.browser, #blocks-1)
        end
    end)

    ui_set_callback(menu.disable_block, function()
        local idx = ui_get(menu.browser) + 1
        blocks[idx].disabled = not blocks[idx].disabled
        update_browser()
    end)
    
    ui_set_callback(menu.move_up, function()
        local idx = ui_get(menu.browser) + 1
        local temp = table_remove(blocks, idx)
        table_insert(blocks, idx-1, temp)
        update_browser()
        ui_set(menu.browser, idx - 2)
    end)

    ui_set_callback(menu.move_down, function()
        local idx = ui_get(menu.browser) + 1
        local temp = table_remove(blocks, idx)
        table_insert(blocks, idx+1, temp)
        update_browser()
        ui_set(menu.browser, idx)
    end)
    
    ui_set_callback(menu.go_back, function() 
        status = "Browsing menu"
        update_menu() 
    end)

    ui_set_callback(menu.yaw, update_menu)
    ui_set_callback(menu.jitter, update_menu)
    ui_set_callback(menu.body, update_menu)
end

client_set_event_callback("setup_command", function(cmd)
    if not ui_get(references[1].enabled) then
        return
    end

    local local_player = entity_get_local_player()
    local local_conditions = get_conditions(cmd, local_player)
    run_antiaim(cmd, local_player, local_conditions)
    run_fakelag(cmd, local_player, local_conditions)
end)

client_set_event_callback("pre_config_save", save_config)

client_set_event_callback("post_config_load", function()
    local cfg = ui_get(menu.config)

    load_config(json_parse(cfg))

    status = "Browsing menu"
    update_menu()
end)

client_set_event_callback("shutdown", function()
    set_table_visibility(references[2], true)
    database_write("block_aa_cache", {globals_realtime(), blocks})
end)

local function init()
    local cache = database_read("block_aa_cache") or nil
    if cache and globals_realtime() - cache[1] < 0.1 and globals_realtime() - cache[1] >= 0 then
        load_config(cache[2])
    else
        set_defaults()
        save_config()
    end

    set_table_visibility(references[2], false)
    set_button_callbacks()
    update_menu()
end 

init()
