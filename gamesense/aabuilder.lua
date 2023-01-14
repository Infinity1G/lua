-- This software is licensed with GNU GPL 2.0.
-- Read more here: https://github.com/Infinity1G/lua/blob/main/gamesense/LICENSE
local LICENSE = "GNU GPL 2.0"

-- Replace 'true' with 'false' if you want to prevent this lua from connecting to the internet
local ENABLE_AUTOUPDATER = true

-- Current lua version
local VERSION = "1.7"

-- Cache globals for that $ performance boost $
local ui_get, ui_set, ui_update, ui_new_color_picker, ui_new_string, ui_reference, ui_set_visible, ui_new_listbox, ui_new_button, ui_new_checkbox, ui_new_label, ui_new_combobox, ui_new_multiselect, ui_new_slider, ui_new_hotkey, ui_set_callback, ui_new_textbox = ui.get, ui.set, ui.update, ui.new_color_picker, ui.new_string, ui.reference, ui.set_visible, ui.new_listbox, ui.new_button, ui.new_checkbox, ui.new_label, ui.new_combobox, ui.new_multiselect, ui.new_slider, ui.new_hotkey, ui.set_callback, ui.new_textbox
local globals_realtime, globals_curtime, globals_tickcount, globals_maxplayers = globals.realtime, globals.curtime, globals.tickcount, globals.maxplayers
local json_stringify, json_parse = json.stringify, json.parse
local table_remove, table_insert = table.remove, table.insert
local string_format, string_rep = string.format, string.rep
local math_abs, math_sqrt = math.abs, math.sqrt
local bit_band, bit_lshift = bit.band, bit.lshift
local entity_get_local_player, entity_get_player_weapon, entity_get_classname, entity_get_prop, entity_get_player_resource, entity_get_origin, entity_get_players, entity_get_esp_data, entity_get_game_rules, entity_is_enemy, entity_is_alive = entity.get_local_player, entity.get_player_weapon, entity.get_classname, entity.get_prop, entity.get_player_resource, entity.get_origin, entity.get_players, entity.get_esp_data, entity.get_game_rules, entity.is_enemy, entity.is_alive
local client_timestamp, error_log, client_reload_active_scripts, client_set_event_callback, client_latency, client_current_threat, client_userid_to_entindex = client.timestamp, client.error_log, client.reload_active_scripts, client.set_event_callback, client.latency, client.current_threat, client.userid_to_entindex
local database_read, database_write = database.read, database.write
local renderer_indicator = renderer.indicator
local select, setmetatable, toticks, require, tostring, ipairs, pairs, type, pcall, writefile, assert, print, printf = select, setmetatable, toticks, require, tostring, ipairs, pairs, type, pcall, writefile, assert, print, printf

-- Libraries
local vector = require("vector")
local http = nil

-- If the auto updater is disabled, then dont bother checking for the http library
if ENABLE_AUTOUPDATER then
    if not pcall(require, "gamesense/http") then
        error_log("The HTTP library is needed for the autoupdater to work.")
    else
        http = require("gamesense/http")
    end
end

-- Menu color hex codes. '\aRRGGBBAA'
local WHITE, LIGHTGRAY, GRAY, GREEN, YELLOW, LIGHTRED, RED = "\aFFFFFFE1", "\aAFAFAFE1", "\a646464E1", "\aAFFFAFE1", "\aFFFF96E1", "\aFFAFAFE1", "\aFF8080E1"

-- All of the current conditions and their descriptions
local CONDITIONS = {"Always", "Not moving", "Moving", "Slow motion", "On ground", "In air", "On peek", "Breaking LC", "Vulnerable", "Crouching", "Not crouching",  "Height advantage", "Height disadvantage", "Knifeable", "Zeusable", "Doubletapping", "Defensive", "Terrorist", "Counter terrorist", "Dormant", "Warm up", "Pre-round", "Round end"}
local DESCRIPTIONS = {
    ["Always"] = "Always true.",
    ["Not moving"] = "True when your horizontal velocity < 2.",
    ["Moving"] = "True when your horizontal velocity >= 2.",
    ["Slow motion"] = "True when you are moving and holding your slow walk key.",
    ["On ground"] = "True when you are touching the ground.",
    ["In air"] = "True when you are not touching the ground.",
    ["On peek"] = "True for the first 18 ticks you are vulnerable.",
    ["Breaking LC"] = "True when you are breaking lagcomp with fakelag.",
    ["Vulnerable"] = "True when enemies can shoot you.",
    ["Crouching"] = "True when you are crouching and not fake ducking.",
    ["Not crouching"] = "True when you are not crouching.",
    ["Height advantage"] = "True when you are 25 HMU above your anti-aim target.",
    ["Height disadvantage"] = "True when you are 25 HMU below your anti-aim target.",
    ["Knifeable"] = "True when you are able to be knifed by an enemy.",
    ["Zeusable"] = "True when you can be zeused by an enemy.",
    ["Doubletapping"] = "True when you are holding your doubletap key and not choking.",
    ["Defensive"] = "True hen you break lagcomp with defensive.",
    ["Terrorist"] = "True when you are on the terrorist team.",
    ["Counter terrorist"] = "True when you are on the counter-terrorist team.",
    ["Dormant"] = "True when all enemies are dormant for you.",
    ["Warm up"] = "True when the game is in a warm up period.",
    ["Pre-round"] = "True ~0.5 seconds before a round starts.",
    ["Round end"] = "True when a round is over and there are no enemies."
}

-- Will be set to true if an update is availablle on github
local update_available = false

-- Storage for custom conditions
local custom_conditions = {}
local custom_descriptions = {}
local custom_funcs = {}

-- Block data
local blocks = {}
local new_block = false
local current_block = nil
local active_block = nil
local fatal_block = nil

-- Current visible menu screen
local screen = 0

-- Condition data
local vulnerable_ticks = 0
local last_sim_time = 0
local defensive_until = 0
local last_origin = vector(0, 0, 0)
local on_ground_ticks = 0

-- A list of needed menu references
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

-- A list of created menu elements
-- (x) is the page that it appears on
local menu = {
    -- Main screen (0)
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
    delete = ui_new_button("AA", "Anti-aimbot angles", LIGHTRED.. "Delete", function() end),
    delete_inactive = ui_new_button("AA", "Anti-aimbot angles", GRAY.. "Delete", function() end),
    updater_label = ui_new_label("AA", "Anti-aimbot angles", "Version x.x is available."),
    download = ui_new_button("AA", "Anti-aimbot angles", "Download update", function() end),
    ignore = ui_new_button("AA", "Anti-aimbot angles", "Ignore", function() end),

    -- Conditions editing screen (1)
    cond_type = ui_new_combobox("AA", "Anti-aimbot angles", "Conditions type", {"AND", "OR"}),
    cond_browser = ui_new_listbox("AA", "Anti-aimbot angles", "Conditions browser", DEFAULT_CONDITIONS),
    cond_toggle = ui_new_button("AA", "Anti-aimbot angles", "Toggle", function() end),
    save = ui_new_button("AA", "Anti-aimbot angles", GREEN.. "Finish", function() end),
    back_saved = ui_new_button("AA", "Anti-aimbot angles", GREEN.. "Back", function() end),
    back_unsaved = ui_new_button("AA", "Anti-aimbot angles", LIGHTRED.. "Back", function() end),
    descriptions = {},

    -- Preset editing screen (2)
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
    force_defensive = ui_new_checkbox("AA", "Anti-aimbot angles", "Force defensive"),
    next = ui_new_button("AA", "Anti-aimbot angles", GREEN.. "Next", function() end),
    back2_saved = ui_new_button("AA", "Anti-aimbot angles", GREEN.. "Back", function() end),
    back2_unsaved = ui_new_button("AA", "Anti-aimbot angles", LIGHTRED.. "Back", function() end),

    -- Other (either always visible or never visible)
    show_active_block = ui_new_checkbox("AA", "Other", "Display active block"),
    show_active_block_color = ui_new_color_picker("AA", "Other", "Display active block color", 255, 255, 255, 200),
    config = ui_new_string("new_aa_config", "{}"), -- if this is a blank string the config system breaks ????
}

-- Tests the run speed of a function and prints the run speed to console
-- Use this when trying to optimize different functions
--- @param func_name string Identifier to use when printing the speed of a function
--- @param func function The function you want to test the speed of
--- @param ... any The arguements for the passed function
local function test_performance(func_name, func, ...)
    local start_time = client_timestamp()

    for i = 1, 1000000 do -- 1,000,000
        func(...)
    end

    local end_time = client_timestamp()
    local elapsed = end_time - start_time -- timestamps are given in milliseconds

    printf("%s finished in %.3f milliseconds.", func_name, elapsed)
end

-- Returns true if a table contains a certain value
-- Does not work with key:pair tables
--- @param tab table The table we want to search
--- @param val any The value we want to search for
--- @return boolean boolean Returns true if the table contains the given value
local function includes(tab, val)
    for i,v in ipairs(tab) do
        if v == val then
            return true
        end
    end

    return false
end

--- @class Block
--- @field name string The name of the block that appears in the menu
--- @field enabled boolean False if the block should be ignored when running anti-aim
--- @field conditions table A table of conditions that are checked before the anti-aim is activated
--- @field cond_type string AND when all conditions must be true, OR when only 1 condition must be true
--- @field force_defensive bool True when cmd.force_defensive should be set to 1 when the block is active
--- @field settings table A table of settings that should have corresponding anti-aim references
local Block = {}
do
    Block.__index = Block
    local Block_mt = {}

    --- @param name string The name of the block that appears in the menu
    --- @param import_from_menu boolean Should the block be initialized with menu references instead of default values
    --- @return Block self Returns a Block object
    function Block.new(name, import_from_menu)
        local self = setmetatable({}, Block)

        self.name = name or "unknown"
        self.enabled = true
        self.conditions = {}
        self.cond_type = "AND"
        self.force_defensive = false
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

        -- If we import settings from the menu, change the name to 'Gamesense'
        if import_from_menu then
            self.name = "Gamesense"
            for k in pairs(self.settings) do
                self.settings[k] = ui_get(references[k])
            end
        end

        return self
    end

    -- Copies a 'deblockified' block object into a block object
    -- Ill eventually update this to suck less
    --- @param tab table A block object that is not a block. Sounds confusing cuz it is.
    --- @return Block self Returns a Block object
    function Block.to_block(tab)
        -- Create a block object to use as a base
        local base = Block.new(tab.name or "Default")

        for k,v in pairs(base) do
            -- If there is a matching field in the tab table and they are of the same type
            -- set the base blocks value to the tabs value
            -- If the value is another table, do the same process on that table
            if tab[k] ~= nil and type(tab[k]) == type(v) then
                base[k] = tab[k]
            end
        end

        return base
    end

    -- Adds/Removes a condition from a blocks list of conditions
    --- @param cond string The condition that should be toggled.
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

    --- @param local_conditions table A list of the local players active conditions
    --- @return boolean boolean Returns true if a Blocks conditions have been met
    function Block:conditions_met(local_conditions)
        local conditions = self.conditions
        local logic = self.cond_type

        -- If there are no conditions, don't bother checking
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

    -- Updates a blocks values
    -- Does not update conditions or enabled. These are done in different functions.
    function Block:update()
        self.name = ui_get(menu.name)
        self.cond_type = ui_get(menu.cond_type)
        self.force_defensive = ui_get(menu.force_defensive)

        for k in pairs(self.settings) do
            self.settings[k] = ui_get(menu[k])
        end
    end

    -- Sets the menus anti-aim settings to the blocks settings
    --- @param cmd userdata setup_commands arguement table
    function Block:set_antiaim(cmd)
        for k,v in pairs(self.settings) do
            local ref = references[k]

            -- Freestanding is special because we have a seperate hotkey to activate it.
            if ref and k ~= "freestanding" then
                ui_set(ref, v)
            elseif k == "freestanding" then
                ui_set(ref, #v == 1 and ui_get(menu.freestanding_key) and "Default" or "")
            end
        end

        if self.force_defensive then
            cmd.force_defensive = 1
        end

        -- For statistical use
        active_block = self
    end

    --- @param _ nil ignore this
    --- @param ... any The arguements used in Block.new
    --- @return Block Block a block object
    function Block_mt.__call(_, ...)
        return Block.new(...)
    end

    -- Set Block_mt as a metatable for Block
    setmetatable(Block, Block_mt)
end

-- Sets all of the given menu references to a certain visibility
--- @param b boolean The visibility of each reference in the table
--- @param ... number Every arg except the last one should be a menu reference.
local function set_table_visibility(b, ...)
    local args = {...}

    for i,v in ipairs(args) do
        ui_set_visible(v, b)
    end
end

-- Sets all of the anti-aim settings to a given visibility
--- @param b boolean Menu reference visibility
local function set_references_visibility(b)
    set_table_visibility(b, references.pitch, references.yaw_base, references.yaw, 
        references.yaw_val, references.jitter, references.jitter_val, 
        references.body, references.body_val, references.freestand_body, 
        references.fake_limit, references.roll, references.edge_yaw, 
        references.freestanding, references.freestanding_key
    )
end

-- Displays all of the current blocks in the main listbox
-- Disabled blocks will appear grayed out
local function update_browser()
    local display = {}
    local num = 1
    for i,v in ipairs(blocks) do
        display[#display+1] = v.enabled and string_format("%s[%i] %s%s", fatal_block == v and RED or LIGHTGRAY, num, WHITE, v.name) or string_format("%s[  ] %s%s", LIGHTGRAY, GRAY, v.name)
        num = v.enabled and num+1 or num
    end

    ui_update(menu.browser, display)
end

-- Displays all of the conditions. 
-- Custom conditions will have a [c] prefix.
-- Disabled conditions will appear grayed out.
local function update_cond_browser()
    -- We can't check the conditions of a block if there isnt a block
    if not current_block then
        return
    end

    local display = {}

    for _,v in ipairs(CONDITIONS) do
        display[#display+1] = string_format("%s%s", includes(current_block.conditions, v) and WHITE or GRAY, v)
    end

    -- Give custom conditions a prefix so users know they are custom
    for _,v in ipairs(custom_conditions) do
        display[#display+1] = string_format("%s[c] %s%s", YELLOW, includes(current_block.conditions, v) and WHITE or GRAY, v)
    end

    ui_update(menu.cond_browser, display)
end

-- Sets the 2 description labels according to the given conditions description
--- @param condition string The condition that we want the description of
local function update_cond_description(condition)
    if not condition then
        return
    end

    local description = condition.. ": ".. (DESCRIPTIONS[condition] or custom_descriptions[condition] or "Unknown.")
    local lines = {}
    local len = 0
    
    -- If the description is longer than 30 characters, split it into multiple lines to help with readability
    local idx = 1
    for s in description:gmatch("%S+") do
        local s_ = s.. " "
        if len + #s_ <= 30 then
            lines[idx] = (lines[idx] or "").. s_
            len = len + #s_
        else
            idx = idx + 1
            lines[idx] = s_
            len = 0
        end
    end

    -- Go through our description. If there is not label available to set, create one
    for i,v in ipairs(lines) do
        if menu.descriptions[i] then
            ui_set_visible(menu.descriptions[i], screen == 2)
        else
            menu.descriptions[#menu.descriptions+1] = ui_new_label("AA", "Anti-aimbot angles", " ")
        end

        ui_set(menu.descriptions[i], LIGHTGRAY.. v)
    end

    -- Hide the labels not already in use
    if #menu.descriptions > #lines then
        for i = #lines+1, #menu.descriptions do
            ui_set_visible(menu.descriptions[i], false)
        end
    end
end

-- Sets all of the menu settings to the current blocks settings
local function update_values()
    if not current_block then
        return
    end

    ui_set(menu.name, current_block.name)
    ui_set(menu.force_defensive, current_block.force_defensive or false)
    ui_set(menu.cond_type, current_block.cond_type)

    for k,v in pairs(current_block.settings) do
        ui_set(menu[k], v)
    end

    update_cond_browser()
end

-- Updates the visibility of the created menu references
--- @param s number The screen that we want to show. [0-2]
local function update_visibility(s)
    local browser = ui_get(menu.browser)

    if type(s) == "number" then
        screen = s
    end

    set_table_visibility(screen == 0, menu.browser, menu.new)
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
    ui_set_visible(menu.updater_label, screen == 0 and update_available)
    ui_set_visible(menu.download, screen == 0 and update_available)
    ui_set_visible(menu.ignore, screen == 0 and update_available)

    set_table_visibility(screen == 2, menu.cond_type, menu.cond_browser, menu.cond_toggle, menu.save, unpack(menu.descriptions))
    ui_set_visible(menu.back_saved, screen == 2 and not new_block)
    ui_set_visible(menu.back_unsaved, screen == 2 and new_block)

    set_table_visibility(screen == 1, menu.name_label, menu.name, menu.pitch, menu.yaw_base, menu.yaw, menu.body, menu.fake_limit, 
        menu.edge_yaw, menu.freestanding, menu.freestanding_key, menu.roll, menu.force_defensive, menu.next
    )
    ui_set_visible(menu.yaw_val, screen == 1 and ui_get(menu.yaw) ~= "Off")
    ui_set_visible(menu.jitter, screen == 1 and ui_get(menu.yaw) ~= "Off")
    ui_set_visible(menu.jitter_val, screen == 1 and ui_get(menu.yaw) ~= "Off" and ui_get(menu.jitter) ~= "Off")
    ui_set_visible(menu.body_val, screen == 1 and ui_get(menu.body) ~= "Off" and ui_get(menu.body) ~= "Opposite")
    ui_set_visible(menu.freestand_body, screen == 1 and ui_get(menu.body) ~= "Off")
    ui_set_visible(menu.fake_limit, screen == 1 and ui_get(menu.body) ~= "Off")
    ui_set_visible(menu.back2_saved, screen == 1 and not new_block)
    ui_set_visible(menu.back2_unsaved, screen == 1 and new_block)

    update_browser()
end

--- @return boolean boolean Returns true if the player can be hit by an enemy
local function is_vulnerable()
    for _, v in ipairs(entity_get_players(true)) do
        local flags = (entity_get_esp_data(v)).flags

        if bit_band(flags, bit_lshift(1, 11)) ~= 0 then
            vulnerable_ticks = vulnerable_ticks + 1
            return true
        end
    end

    -- If we aren't vulnerable then we have been vulnerable for 0 ticks
    vulnerable_ticks = 0
    return false
end

--- @return number count The number of alive enemies
local function get_total_enemies()
    local count = 0

    for e = 1, globals_maxplayers() do
        if entity_get_prop(entity_get_player_resource(), "m_bConnected", e) and entity_is_enemy(e) and entity_is_alive(e) then
            count = count + 1
        end
    end

    return count
end

-- I got help from JustiNN?id=1984 with this function. All credit goes to him
--- @param local_player number The entindex of the local player
--- @return boolean boolean Returns true if defensive dt is currently active
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

--- @param origin vector A vector of the local players origin
--- @param enemies table A list of entindexes
--- @return boolean boolean Returns true if the local player is under the threat of being knifed
local function is_knifeable(origin, enemies)
    local knife_range = 128 -- Its actually 64 but thats too small of a range

    for _,v in ipairs(enemies) do
        local weapon = entity_get_player_weapon(v)
        local weapon_class = entity_get_classname(weapon)

        if weapon_class == "CKnife" then
            local enemy_origin = vector(entity_get_origin(v))
            local dist = origin:dist(enemy_origin)

            if dist <= knife_range then
                return true
            end
        end
    end

    return false
end

--- @param origin vector A vector of the local players origin
--- @param enemies table A list of entindexes
--- @return boolean boolean Returns true if the local player is under the threat of being zeused
local function is_zeusable(origin, enemies)
    local taser_range = 230 -- 193 is the largest needed to one shot you
    
    for _,v in ipairs(enemies) do
        local weapon = entity_get_player_weapon(v)
        local weapon_class = entity_get_classname(weapon)

        if weapon_class == "CWeaponTaser" then
            local enemy_origin = vector(entity_get_origin(v))
            local dist = origin:dist(enemy_origin)

            if dist <= taser_range then
                return true
            end
        end
    end

    return false
end

-- Gets all of the possible conditions and calculated whether or not they are active
--- @param cmd userdata setup_commands arguement table
--- @param local_player number the entindex of the local player
--- @return table conditions a key:value table of conditions and whether or not they are active
local function get_conditions(cmd, local_player)
    local game_rules = entity_get_game_rules()
    local velocity = {entity_get_prop(local_player, "m_vecVelocity")}
    local speed = math_sqrt(velocity[1] * velocity[1] + velocity[2] * velocity[2])
    local flags = entity_get_prop(local_player, "m_fFlags")
    local on_ground = bit_band(flags, 1) == 1
    local duck_amount = entity_get_prop(local_player, "m_flDuckAmount")
    local team_num = entity_get_prop(entity_get_player_resource(), "m_iTeam", local_player)
    local origin = vector(entity_get_origin(local_player))
    local breaking_lc = (last_origin - origin):length2dsqr() > 4096
    local threat = client_current_threat()
    local height_to_threat = 0
    local vulnerable = is_vulnerable()
    local enemies = entity_get_players(true)
    local curtime = globals_curtime()
    local doubletapping = ui_get(references.double_tap) and ui_get(references.double_tap_key)
    local slowwalking =  ui_get(references.slow_motion) and ui_get(references.slow_motion_key)

    on_ground_ticks = on_ground and on_ground_ticks + 1 or 0
    
    if cmd.chokedcommands == 0 then
        last_origin = origin
    end

    if threat then
        local threat_origin = vector(entity_get_origin(threat))
        height_to_threat = origin.z-threat_origin.z
    end

    local conds = {
        ["Always"] = true,
        ["Not moving"] = speed < 2,
        ["Slow motion"] = slowwalking and speed >= 2,
        ["Moving"] = speed >= 2,
        ["On ground"] = on_ground_ticks > 1,
        ["In air"] = on_ground_ticks <= 1,
        ["On peek"] = vulnerable and vulnerable_ticks <= 18,
        ["Breaking LC"] = breaking_lc,
        ["Height advantage"] = threat and height_to_threat > 25,
        ["Height disadvantage"] = threat and height_to_threat < -25,
        ["Vulnerable"] = vulnerable,
        ["Not crouching"] = duck_amount < 0.9,
        ["Crouching"] = duck_amount >= 0.9,
        ["Knifeable"] = is_knifeable(origin, enemies),
        ["Zeusable"] = is_zeusable(origin, enemies),
        ["Doubletapping"] = doubletapping and cmd.chokedcommands <= ui_get(references.double_tap_lag),
        ["Defensive"] = is_defensive_active(local_player),
        ["Terrorist"] = team_num == 2,
        ["Counter terrorist"] = team_num == 3,
        ["Dormant"] = #enemies == 0,
        ["Warm up"] = entity_get_prop(game_rules, "m_bWarmupPeriod") == 1,
        ["Pre-round"] = entity_get_prop(game_rules, "m_fRoundStartTime") > curtime + toticks(client_latency()),
        ["Round end"] = entity_get_prop(game_rules, "m_iRoundWinStatus") ~= 0 and get_total_enemies() == 0
    }

    for _,v in ipairs(custom_conditions) do
        conds[v] = custom_funcs[v](local_player)
    end

    return conds
end

-- Searches through all of the blocks to find one where its conditions are met, then sets the anti-aim settings to the blocks settings
--- @param cmd userdata setup_commands arguement table
--- @param local_conditions table a key:value table of local player conditions
local function run_antiaim(cmd, local_conditions)
    if screen == 1 then
        current_block:update()
        current_block:set_antiaim(cmd)
    else
        for i,block in ipairs(blocks) do
            if (block:conditions_met(local_conditions) or i == #blocks) and block.enabled then
                block:set_antiaim(cmd)
                break -- bad coding practice but it works so Im not changing it
            end
        end
    end

    set_references_visibility(false)
end

-- Runs every game tick
--- @param cmd userdata setup_commands arguement table
local function on_setup_command(cmd)
    -- Prevent unneeded calculations for that $ performance boost $
    if not ui_get(references.enabled) then
        return
    end

    local local_player = entity_get_local_player()
    local local_conditions = get_conditions(cmd, local_player)

    run_antiaim(cmd, local_conditions)
end

-- Checks which block we had enabled if we died to a headshot
--- @param e userdata player_death event data
local function on_player_death(e)
    if not ui_get(references.enabled) then
        return
    end

    local local_player = entity_get_local_player()
    if client_userid_to_entindex(e.userid) == local_player then
        fatal_block = active_block
        update_browser()
    end
end

-- Calls once every frame
-- Displays the active anti-aim block if there is one
local function on_paint()
    if not ui_get(references.enabled) or not ui_get(menu.show_active_block) then
        return
    end

    local local_player = entity_get_local_player()

    if not entity_is_alive(local_player) or not active_block then
        return
    end

    local r, g, b, a = ui_get(menu.show_active_block_color)
    renderer_indicator(r, g, b, a, active_block.name)
end

-- Adds a custom condition to the menu
--- @param name string The name of the condition
--- @param desc string A short description of the condition
--- @param func function A function that determines whether or not the condition is active. Should return a boolean.
local function add_condition(name, desc, func)
    -- make sure that the name becomes a key instead of an index
    name = tostring(name)
    
    -- Make sure the condition is set up correctly
    assert(#name > 0 and name ~= "nil", "The condition must have a name.")
    assert(type(desc) == "string" and #desc > 0, "The condition must have a description.")
    assert(type(func) == "function", "You must add a function to the condition.")
    assert(not includes(CONDITIONS, name) and not includes(custom_conditions, name), "That condition already exists.")

    custom_conditions[#custom_conditions+1] = name
    custom_descriptions[name] = desc
    custom_funcs[name] = func
end

-- Saves the current block table to a menu reference
local function save_config()
    ui_set(menu.config, tostring(json_stringify(blocks)))
end

-- Loads a config from the config menu reference
-- If there is no config, then create a config with a default block
local function load_config()
    local json_cfg = ui_get(menu.config)
    current_block = nil
    blocks = {}
    
    -- '{}' is the default and the cfg should only be {} when the lua is first loaded
    if json_cfg == "{}" then
        blocks[#blocks+1] = Block("Default", true)
        save_config()
    else
        local cfg = json_parse(ui_get(menu.config)) or {}

        for i,v in ipairs(cfg) do
            blocks[#blocks+1] = Block.to_block(v)
        end
    end

    update_visibility(0)
    set_references_visibility(false)
end

-- Calls when the lua is first loaded
local function on_init()
    client_set_event_callback("setup_command", on_setup_command)
    client_set_event_callback("paint", on_paint)
    client_set_event_callback("pre_config_save", save_config)
    client_set_event_callback("post_config_load", load_config)

    client_set_event_callback("player_death", on_player_death)

    client_set_event_callback("shutdown", function()
        set_references_visibility(true)
        database_write("new_aa_cache", {globals_realtime(), blocks})
    end)

    -- Minimized because less lines of code = better
    ui_set_callback(menu.new, function() new_block = true; current_block = Block(); update_values(); update_visibility(1) end)
    ui_set_callback(menu.edit, function() new_block = false; current_block = blocks[ui_get(menu.browser)+1]; update_values(); update_visibility(1) end)
    ui_set_callback(menu.toggle, function() blocks[ui_get(menu.browser)+1].enabled = not blocks[ui_get(menu.browser)+1].enabled; update_browser() end)
    ui_set_callback(menu.delete, function() table_remove(blocks, ui_get(menu.browser)+1); update_browser(); if #blocks > 0 then ui_set(menu.browser, ui_get(menu.browser)-1) end; update_visibility(0) end)
    ui_set_callback(menu.next, function() update_visibility(2) end)
    ui_set_callback(menu.back_saved, function() update_visibility(1) end)
    ui_set_callback(menu.back_unsaved, function() update_visibility(1) end)
    ui_set_callback(menu.yaw, function() if screen == 1 then update_visibility(1) end end)
    ui_set_callback(menu.jitter, function() if screen == 1 then update_visibility(1) end end)
    ui_set_callback(menu.body, function() if screen == 1 then update_visibility(1) end end)
    ui_set_callback(menu.save, function() current_block:update(); if new_block then blocks[#blocks+1] = current_block end; current_block = nil; update_visibility(0) end)
    ui_set_callback(menu.back2_saved, function() update_visibility(0) end)
    ui_set_callback(menu.back2_unsaved, function() update_visibility(0) end)


    ui_set_callback(menu.cond_toggle, function() 
        if not current_block then
            return
        end

        local idx = ui_get(menu.cond_browser) + 1

        local all_conditions = {}
        for _,v in ipairs(CONDITIONS) do all_conditions[#all_conditions+1] = v end
        for _,v in ipairs(custom_conditions) do all_conditions[#all_conditions+1] = v end 

        current_block:toggle_condition(all_conditions[idx]);
        
        update_cond_browser() 
    end)

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
        if not ui_get(self) then
            return
        end

        local idx = ui_get(self) + 1
        local realtime = globals_realtime()

        if idx == prev_cond_browser[1] and realtime - prev_cond_browser[2] <= 0.25 then
            ui_set(menu.cond_toggle, true)
        end

        local all_conditions = {}
        for _,v in ipairs(CONDITIONS) do all_conditions[#all_conditions+1] = v end
        for _,v in ipairs(custom_conditions) do all_conditions[#all_conditions+1] = v end 

        update_cond_description(all_conditions[idx])
        prev_cond_browser = {idx, realtime}
    end)

    -- Read from the luas cache
    local cache = database_read("new_aa_cache")

    -- If the lua was reloaded, it will have been unloaded for 0 seconds
    -- We can use this to cache the block table between lua loads because tables are deleted on unload
    -- If the lua wasnt reloaded, call the load_config function to load blocks to the menu
    if cache and globals_realtime() - cache[1] == 0 then
        for i,v in ipairs(cache[2]) do
            blocks[#blocks+1] = Block.to_block(v)
        end
    else
        load_config()
    end
    
    set_references_visibility(false)
    update_visibility(0)

    -- If the auto updater is off, the build is a dev build, or the user is not subscribed to the http library, do not run the autoupdater
    -- I could be using coroutines for this as its async but I don't really feel like it
    if ENABLE_AUTOUPDATER and http and not VERSION:find("d") then
        -- Checks for an update on the github and sets the download button visible if there is one
        http.get("https://raw.githubusercontent.com/Infinity1G/lua/main/gamesense/aabuilder_version.txt", function(success, response)
            if success and response.status == 200 then
                local cloud_version = response.body
                cloud_version = cloud_version:gsub("\n$", "")

                if cloud_version ~= VERSION then
                    -- Ignore the update until the lua is loaded next
                    ui_set_callback(menu.ignore, function()
                        update_available = false
                        update_visibility()
                    end)

                    -- Overwrite the current lua with the new lua from github
                    -- Breaks if the lua is loaded as a module from a folder :(
                    ui_set_callback(menu.download, function()
                        http.get("https://raw.githubusercontent.com/Infinity1G/lua/main/gamesense/aabuilder.lua", function(success, response)
                            if success and response.status == 200 then
                                local body = response.body
                                local name = _NAME

                                writefile(_NAME..".lua", body)
                                client_reload_active_scripts()
                            end
                        end)
                    end)

                    -- An update is available so set the update label, download button and ignore button to visible
                    update_available = true
                    ui_set(menu.updater_label, string_format("%sVersion %s%s%s is available to download.", LIGHTGRAY, GREEN, cloud_version, LIGHTGRAY))
                    update_visibility()
                end
            end
        end)
    end

    -- Create a global variable for other scripts to use
    _G.condition = {}
    condition.add = add_condition
end

-- Initiate the lua
on_init()