local ui_get, ui_set, ui_update, ui_new_string, ui_reference, ui_set_visible, ui_new_listbox, ui_new_button, ui_new_checkbox, ui_new_label, ui_new_combobox, ui_new_multiselect, ui_new_slider, ui_new_hotkey, ui_set_callback, ui_new_textbox = ui.get, ui.set, ui.update, ui.new_string, ui.reference, ui.set_visible, ui.new_listbox, ui.new_button, ui.new_checkbox, ui.new_label, ui.new_combobox, ui.new_multiselect, ui.new_slider, ui.new_hotkey, ui.set_callback, ui.new_textbox
local globals_realtime, globals_tickcount, globals_maxplayers = globals.realtime, globals.tickcount, globals.maxplayers
local json_stringify, json_parse = json.stringify, json.parse
local table_remove, table_insert = table.remove, table.insert
local string_format, string_rep = string.format, string.rep
local math_abs, math_sqrt = math.abs, math.sqrt
local bit_band, bit_lshift = bit.band, bit.lshift
local entity_get_local_player, entity_get_prop, entity_get_player_resource, entity_get_origin, entity_get_players, entity_get_esp_data, entity_get_game_rules, entity_is_enemy, entity_is_alive = entity.get_local_player, entity.get_prop, entity.get_player_resource, entity.get_origin, entity.get_players, entity.get_esp_data, entity.get_game_rules, entity.is_enemy, entity.is_alive
local client_set_event_callback, client_latency, client_current_threat = client.set_event_callback, client.latency, client.current_threat
local database_read, database_write = database.read, database.write
local select, setmetatable, toticks, require, tostring, ipairs, pairs, type = select, setmetatable, toticks, require, tostring, ipairs, pairs, type

local vector = require("vector")

local WHITE = string_format("\a%02x%02x%02x%02x", 255, 255, 255, 225)
local LIGHTGRAY = string_format("\a%02x%02x%02x%02x", 175, 175, 175, 225)
local GRAY = string_format("\a%02x%02x%02x%02x", 100, 100, 100, 225)
local GREEN = string_format("\a%02x%02x%02x%02x", 175, 255, 175, 225)
local RED = string_format("\a%02x%02x%02x%02x", 255, 175, 175, 225)
local CONDITIONS = {"Always", "Not moving", "Moving", "Slow motion", "On ground", "In air", "On peek", "Breaking LC", "Vulnerable", "Crouching", "Not crouching",  "Height advantage", "Height disadvantage", "Doubletapping", "Defensive", "Terrorist", "Counter terrorist", "Dormant", "Round end"}
local DESCRIPTIONS = {
    ["Always"] = "Always true.",
    ["Not moving"] = "Horizontal velocity < 2.",
    ["Moving"] = "Horizontal velocity >= 2.",
    ["Slow motion"] = "Slow walking and moving.",
    ["On ground"] = "Touching the ground.",
    ["In air"] = "Not touching the ground.",
    ["On peek"] = "First 14 vulnerable ticks.",
    ["Breaking LC"] = "Breaking lagcomp with fake lag.",
    ["Vulnerable"] = "Can be shot by enemies.",
    ["Crouching"] = "Crouching (Not fakeducking).",
    ["Not crouching"] = "Not crouching.",
    ["Height advantage"] = "25 HMU above your target.",
    ["Height disadvantage"] = "25 HMU below your target.",
    ["Doubletapping"] = "Holding doubletap key and not choking.",
    ["Defensive"] = "When you break lagcomp with defensive doubletap.",
    ["Terrorist"] = "You are on the terrorist team.",
    ["Counter terrorist"] = "You are on the counter-terrorist team.",
    ["Dormant"] = "All enemies are dormant for you.",
    ["Round end"] = "The round is over and there are no enemies."
}

local screen = 0
local blocks = {}
local new_block = false
local current_block = nil

local references = {
    fake_lag_limit = ui_reference("AA", "Fake lag", "Limit"),
    slow_motion = ui_reference("AA", "Other", "Slow motion"),
    slow_motion_key = select(2, ui_reference("AA", "Other", "Slow motion")),
    onshot_aa = ui_reference("AA", "Other", "On shot anti-aim"),
    onshot_aa_key = select(2, ui_reference("AA", "Other", "On shot anti-aim")),
    double_tap = ui_reference("RAGE", "Other", "Double tap"),
    double_tap_key = select(2, ui_reference("RAGE", "Other", "Double tap")),
    double_tap_lag = ui_reference("RAGE", "Other", "Double tap fake lag limit"),
    enabled = ui_reference("AA", "Anti-aimbot angles", "Enabled"),
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

local menu = {
    -- main screen (0)
    browser = ui_new_listbox("AA", "Anti-aimbot angles", "browser", blocks),
    new = ui_new_button("AA", "Anti-aimbot angles", GREEN.. "New", function() end),
    edit = ui_new_button("AA", "Anti-aimbot angles", "Edit", function() end),
    edit_inactive = ui_new_button("AA", "Anti-aimbot angles", GRAY.. "Edit", function() end),
    toggle = ui_new_button("AA", "Anti-aimbot angles", "Toggle", function() end),
    toggle_inactive = ui_new_button("AA", "Anti-aimbot angles", GRAY.. "Toggle", function() end),
    move_up = ui_new_button("AA", "Anti-aimbot angles", "Move up", function() end),
    move_up_inactive = ui_new_button("AA", "Anti-aimbot angles", GRAY.. "Move up", function() end),
    move_down = ui_new_button("AA", "Anti-aimbot angles", "Move down", function() end),
    move_down_inactive = ui_new_button("AA", "Anti-aimbot angles", GRAY.. "Move down", function() end),
    delete = ui_new_button("AA", "Anti-aimbot angles", RED.. "Delete", function() end),
    delete_inactive = ui_new_button("AA", "Anti-aimbot angles", GRAY.. "Delete", function() end),

    -- conditions editing screen (1)
    cond_type = ui_new_combobox("AA", "Anti-aimbot angles", "Conditions type", {"AND", "OR"}),
    cond_browser = ui_new_listbox("AA", "Anti-aimbot angles", "Conditions browser", CONDITIONS),
    cond_toggle = ui_new_button("AA", "Anti-aimbot angles", "Toggle", function() end),
    save = ui_new_button("AA", "Anti-aimbot angles", GREEN.. "Finish", function() end),
    back = ui_new_button("AA", "Anti-aimbot angles", RED.. "Back", function() end),
    desc1 = ui_new_label("AA", "Anti-aimbot angles", "[DESCRIPTION]"),
    desc2 = ui_new_label("AA", "Anti-aimbot angles", "[DESCRIPTION]"),

    -- preset editing screen (2)
    name_label = ui_new_label("AA", "Anti-aimbot angles", "Block name"),
    name = ui_new_textbox("AA", "Anti-aimbot angles", "\nBlock name"),
    pitch = ui_new_combobox("AA", "Anti-aimbot angles", "Pitch", {"Off", "Default", "Up", "Down", "Minimal", "Random"}),
    yaw_base = ui_new_combobox("AA", "Anti-aimbot angles", "Yaw base", {"Local view", "At targets"}),
    yaw = ui_new_combobox("AA", "Anti-aimbot angles", "Yaw", {"Off", "180", "Spin", "Static", "180 Z", "Crosshair"}),
    yaw_val = ui_new_slider("AA", "Anti-aimbot angles", "\nYaw slider", -180, 180, 8, true, "°"),
    jitter = ui_new_combobox("AA", "Anti-aimbot angles", "Yaw jitter", {"Off", "Offset", "Center", "Random"}),
    jitter_val = ui_new_slider("AA", "Anti-aimbot angles", "\nYaw jitter slider", -180, 180, 8, true, "°"),
    body = ui_new_combobox("AA", "Anti-aimbot angles", "Body yaw", {"Off", "Static", "Jitter", "Opposite"}),
    body_val = ui_new_slider("AA", "Anti-aimbot angles", "\nBody yaw slider", -180, 180, 60, true, "°"),
    freestand_body = ui_new_checkbox("AA", "Anti-aimbot angles", "Freestanding body yaw"),
    fake_limit = ui_new_slider("AA", "Anti-aimbot angles", "Fake yaw limit", 0, 60, 60, true, "°"),
    edge_yaw = ui_new_checkbox("AA", "Anti-aimbot angles", "Edge yaw"),
    freestanding = ui_new_multiselect("AA", "Anti-aimbot angles", "Freestanding", {"Default"}),
    freestanding_key = ui_new_hotkey("AA", "Anti-aimbot angles", "\nFreestanding hotkey", true),
    roll = ui_new_slider("AA", "Anti-aimbot angles", "Roll", -50, 50, 0, true, "°"),
    next = ui_new_button("AA", "Anti-aimbot angles", GREEN.. "Next", function() end),
    back2 = ui_new_button("AA", "Anti-aimbot angles", RED.. "Back", function() end),

    -- other
    config = ui_new_string("new_aa_config", "")
}

local function includes(tab, val)
    for i,v in ipairs(tab) do
        if v == val then
            return true
        end
    end

    return false
end

local Block = {}
do
    Block.__index = Block
    local Block_mt = {}

    function Block.new(name, import_from_menu)
        local self = setmetatable({}, Block)

        self.name = name or ""
        self.enabled = true
        self.conditions = {}
        self.cond_type = "AND"
        self.settings = {
            pitch = "Off",
            yaw_base = "Local view",
            yaw = "Off",
            yaw_val = 8,
            jitter = "Off",
            jitter_val = 8,
            body = "Off",
            body_val = 60,
            freestand_body = false,
            fake_limit = 60,
            edge_yaw = false,
            freestanding = {},
            roll = 0
        }

        if import_from_menu then
            self.name = "Gamesense"
            for k in pairs(self.settings) do
                self.settings[k] = ui_get(references[k])
            end
        end

        return self
    end

    function Block.to_block(tab)
        local self = setmetatable(tab, Block)
        return self
    end

    function Block:toggle_condition(cond)
        if includes(self.conditions, cond) then
            for i,v in ipairs(self.conditions) do
                if v == cond then
                    table_remove(self.conditions, i)
                end
            end
        else
            self.conditions[#self.conditions+1] = cond
        end
    end

    function Block:conditions_met(local_conditions)
        local conditions = self.conditions
        local logic = self.cond_type

        if #conditions == 0 then
            return false
        end

        if logic == "AND" then
            for _,cond in ipairs(conditions) do
                if not local_conditions[cond] then
                    return false
                end
            end

            return true
        elseif logic == "OR" then
            for _,cond in ipairs(conditions) do
                if local_conditions[cond] then
                    return true
                end
            end

            return false
        end

        return false
    end

    function Block:update()
        self.name = ui_get(menu.name)
        self.cond_type = ui_get(menu.cond_type)

        for k in pairs(self.settings) do
            self.settings[k] = ui_get(menu[k])
        end
    end

    function Block:set_antiaim()
        for k,v in pairs(self.settings) do
            local ref = references[k]
            if ref and k ~= "freestanding" then
                ui_set(ref, v)
            elseif k == "freestanding" then
                ui_set(ref, v == {"Default"} and ui_get(menu.freestanding_key) and {"Default"} or {"-"})
            end
        end
    end

    function Block_mt.__call(_, ...)
        return Block.new(...)
    end

    setmetatable(Block, Block_mt)
end

local function set_table_visibility(...)
    local args = {...}
    local bool = args[#args]

    for i = 1, #args-1 do
        ui_set_visible(args[i], bool)
    end
end

local function set_references_visibility(b)
    set_table_visibility(references.pitch, references.yaw_base, references.yaw, references.yaw_val, references.jitter, references.jitter_val, references.body, references.body_val, references.freestand_body, references.fake_limit, references.roll, references.edge_yaw, references.freestanding, references.freestanding_key, b)
end

local function update_browser()
    local display = {}
    local num = 1
    for i,v in ipairs(blocks) do
        display[#display+1] = v.enabled and string_format("%s[%i] %s%s", LIGHTGRAY, num, WHITE, v.name) or string_format("%s[  ] %s%s", LIGHTGRAY, GRAY, v.name)
        num = v.enabled and num+1 or num
    end

    ui_update(menu.browser, display)
end

local function update_cond_browser()
    if not current_block then
        return
    end

    local display = {}

    for _,v in ipairs(CONDITIONS) do
        display[#display+1] = string_format("%s%s", includes(current_block.conditions, v) and WHITE or GRAY, v)
    end

    ui_update(menu.cond_browser, display)
end

local function update_cond_description(condition)
    local description = condition.. ": ".. DESCRIPTIONS[condition] or "Unknown."
    local desc1, desc2 = "", ""
    local len = 0
    
    for s in description:gmatch("%S+") do
        local s_ = s.. " "
        if len + #s_ <= 30 then
            desc1 = desc1.. s_
        else
            desc2 = desc2.. s_
        end
        len = len + #s_
    end

    ui_set(menu.desc1, LIGHTGRAY.. desc1)
    ui_set(menu.desc2, LIGHTGRAY.. desc2)
end

local function update_values()
    if not current_block then
        return
    end

    ui_set(menu.name, current_block.name)
    ui_set(menu.cond_type, current_block.cond_type)

    for k,v in pairs(current_block.settings) do
        ui_set(menu[k], v)
    end

    update_cond_browser()
end

local function update_visibility(s)
    local browser = ui_get(menu.browser)

    if type(s) == "number" then
        screen = s
    end

    set_table_visibility(menu.browser, menu.new, screen == 0)
    ui_set_visible(menu.edit, screen == 0 and browser)
    ui_set_visible(menu.edit_inactive, screen == 0 and not browser)
    ui_set_visible(menu.toggle, screen == 0 and browser)
    ui_set_visible(menu.toggle_inactive, screen == 0 and not browser)
    ui_set_visible(menu.move_up, screen == 0 and browser and browser > 0)
    ui_set_visible(menu.move_up_inactive, screen == 0 and not (browser and browser > 0))
    ui_set_visible(menu.move_down, screen == 0 and browser and browser < #blocks-1)
    ui_set_visible(menu.move_down_inactive, screen == 0 and not (browser and browser < #blocks-1))
    ui_set_visible(menu.delete, screen == 0 and browser and #blocks > 1)
    ui_set_visible(menu.delete_inactive, screen == 0 and not (browser and #blocks > 1))

    set_table_visibility(menu.cond_type, menu.cond_browser, menu.cond_toggle, menu.save, menu.back, menu.desc1, menu.desc2, screen == 2)

    set_table_visibility(menu.name_label, menu.name, menu.pitch, menu.yaw_base, menu.yaw, menu.body, menu.fake_limit, menu.edge_yaw, menu.freestanding, menu.freestanding_key, menu.roll, menu.next, menu.back2, screen == 1)
    ui_set_visible(menu.yaw_val, screen == 1 and ui_get(menu.yaw) ~= "Off")
    ui_set_visible(menu.jitter, screen == 1 and ui_get(menu.yaw) ~= "Off")
    ui_set_visible(menu.jitter_val, screen == 1 and ui_get(menu.yaw) ~= "Off" and ui_get(menu.jitter) ~= "Off")
    ui_set_visible(menu.body_val, screen == 1 and ui_get(menu.body) ~= "Off" and ui_get(menu.body) ~= "Opposite")
    ui_set_visible(menu.freestand_body, screen == 1 and ui_get(menu.body) ~= "Off")
    ui_set_visible(menu.fake_limit, screen == 1 and ui_get(menu.body) ~= "Off")

    update_browser()
end

local vulnerable_ticks = 0
local function is_vulnerable()
    for _, v in ipairs(entity_get_players(true)) do
        local flags = (entity_get_esp_data(v)).flags

        if bit_band(flags, bit_lshift(1, 11)) ~= 0 then
            vulnerable_ticks = vulnerable_ticks + 1
            return true
        end
    end

    vulnerable_ticks = 0
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

local last_sim_time, defensive_until = 0, 0
local function is_defensive_active(local_player)
    local tickcount = globals_tickcount()
    local sim_time = toticks(entity_get_prop(local_player, "m_flSimulationTime"))
    local sim_diff = sim_time - last_sim_time

    if sim_diff < 0 then
        defensive_until = tickcount + math_abs(sim_diff) - toticks(client_latency())
    end
    
    last_sim_time = sim_time

    return defensive_until > tickcount
end

local last_origin, on_ground_ticks = vector(0,0,0), 0
local function get_conditions(cmd, local_player)
    local velocity = {entity_get_prop(local_player, "m_vecVelocity")}
    local speed = math_sqrt(velocity[1] * velocity[1] + velocity[2] * velocity[2])
    local flags = entity_get_prop(local_player, "m_fFlags")
    local on_ground = bit_band(flags, 1) == 1
    local duck_amount = entity_get_prop(local_player, "m_flDuckAmount")
    local team_num = entity_get_prop(entity_get_player_resource(), "m_iTeam", local_player)
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
        ["Slow motion"] = ui_get(references.slow_motion) and ui_get(references.slow_motion_key) and speed >= 2,
        ["Moving"] = speed >= 2,
        ["On ground"] = on_ground_ticks > 1,
        ["In air"] = on_ground_ticks <= 1,
        ["On peek"] = vulnerable_ticks > 0 and vulnerable_ticks <= 14,
        ["Breaking LC"] = breaking_lc,
        ["Height advantage"] = threat and height_to_threat > 25,
        ["Height disadvantage"] = threat and height_to_threat < -25,
        ["Vulnerable"] = is_vulnerable(),
        ["Not crouching"] = duck_amount < 0.9,
        ["Crouching"] = duck_amount >= 0.9,
        ["Doubletapping"] = ui_get(references.double_tap) and ui_get(references.double_tap_key) and cmd.chokedcommands <= ui_get(references.double_tap_lag),
        ["Defensive"] = is_defensive_active(local_player),
        ["Terrorist"] = team_num == 2,
        ["Counter terrorist"] = team_num == 3,
        ["Dormant"] = #entity_get_players(true) == 0,
        ["Round end"] = entity_get_prop(entity_get_game_rules(), "m_iRoundWinStatus") ~= 0 and get_total_enemies() == 0
    }

    return conditions
end

local function run_antiaim(local_conditions)
    if screen == 1 then
        current_block:update()
        current_block:set_antiaim()
    else
        for i,block in ipairs(blocks) do
            if (block:conditions_met(local_conditions) or i == #blocks) and block.enabled then
                block:set_antiaim()
                break
            end
        end
    end

    set_references_visibility(false)
end

local function on_setup_command(cmd)
    if not ui_get(references.enabled) then
        return
    end

    local local_player = entity_get_local_player()
    local local_conditions = get_conditions(cmd, local_player)

    run_antiaim(local_conditions)
end

local function load_config()
    local cfg = json_parse(ui_get(menu.config))
    current_block = nil
    blocks = {}

    for i,v in ipairs(cfg) do
        blocks[#blocks+1] = Block.to_block(v)
    end

    update_visibility(0)
    set_references_visibility(false)
    ui_set(menu.browser, 0)
end

local function save_config()
    ui_set(menu.config, tostring(json_stringify(blocks)))
end

local function on_init()
    client_set_event_callback("setup_command", on_setup_command)
    client_set_event_callback("pre_config_save", save_config)
    client_set_event_callback("post_config_load", load_config)

    client_set_event_callback("shutdown", function()
        set_references_visibility(true)
        database_write("new_aa_cache", {globals_realtime(), blocks})
    end)

    ui_set_callback(menu.new, function() new_block = true; current_block = Block(); update_values(); update_visibility(1) end)
    ui_set_callback(menu.edit, function() new_block = false; current_block = blocks[ui_get(menu.browser)+1]; update_values(); update_visibility(1) end)
    ui_set_callback(menu.toggle, function() blocks[ui_get(menu.browser)+1].enabled = not blocks[ui_get(menu.browser)+1].enabled; update_browser() end)
    ui_set_callback(menu.delete, function() table_remove(blocks, ui_get(menu.browser)+1); update_browser(); if #blocks > 0 then ui_set(menu.browser, ui_get(menu.browser)-1) end; update_visibility(0) end)
    ui_set_callback(menu.next, function() update_visibility(2) end)
    ui_set_callback(menu.back, function() update_visibility(1) end)
    ui_set_callback(menu.yaw, function() if screen == 1 then update_visibility(1) end end)
    ui_set_callback(menu.jitter, function() if screen == 1 then update_visibility(1) end end)
    ui_set_callback(menu.body, function() if screen == 1 then update_visibility(1) end end)
    ui_set_callback(menu.save, function() current_block:update(); if new_block then blocks[#blocks+1] = current_block end; current_block = nil; update_visibility(0) end)
    ui_set_callback(menu.back2, function() update_visibility(0) end)
    ui_set_callback(menu.cond_toggle, function() current_block:toggle_condition(CONDITIONS[ui_get(menu.cond_browser)+1]); update_cond_browser() end)

    ui_set_callback(menu.move_up, function()
        local idx = ui_get(menu.browser) + 1
        local temp = table_remove(blocks, idx)
        table_insert(blocks, idx-1, temp)
        update_browser()
        ui_set(menu.browser, idx-2)
    end)

    ui_set_callback(menu.move_down, function()
        local idx = ui_get(menu.browser) + 1
        local temp = table_remove(blocks, idx)
        table_insert(blocks, idx+1, temp)
        update_browser()
        ui_set(menu.browser, idx)
    end)

    local prev_browser = {nil, nil}
    ui_set_callback(menu.browser, function(self)
        if not ui_get(self) then
            return
        end

        local idx = ui_get(self) + 1
        local realtime = globals_realtime()

        if idx == prev_browser[1] and realtime - prev_browser[2] <= 0.25 then
            ui_set(menu.edit, true)
        end

        prev_browser = {idx, realtime}
        update_visibility(false)
    end)

    local prev_cond_browser = {nil, nil}
    ui_set_callback(menu.cond_browser, function(self)
        local idx = ui_get(self) + 1
        local realtime = globals_realtime()

        if idx == prev_cond_browser[1] and realtime - prev_cond_browser[2] <= 0.25 then
            ui_set(menu.cond_toggle, true)
        end

        update_cond_description(CONDITIONS[idx])
        prev_cond_browser = {idx, realtime}
    end)
    
    local cache = database_read("new_aa_cache")

    if cache and globals_realtime() - cache[1] < 0.1 then
        for i,v in ipairs(cache[2]) do
            blocks[#blocks+1] = Block.to_block(v)
        end
    else
        blocks[#blocks+1] = Block("Default", true)
    end

    set_references_visibility(false)
    update_visibility(0)
end

on_init()
