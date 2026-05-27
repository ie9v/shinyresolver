local ok_gradient, gradient = pcall(require, "neverlose/gradient")

if ok_gradient and gradient then
    local logo = gradient.text("Shiny Resolver", false, {
        color(176, 208, 255),
        color(255, 182, 255)
    })
    ui.sidebar(logo, "moon")
else
    ui.sidebar("Shiny Resolver", "moon")
end

--------------------------------------------------------------------------------
-- Safe number coercion
--------------------------------------------------------------------------------
local function n(v, default)
    return tonumber(v) or default or 0
end

--------------------------------------------------------------------------------
-- Math helpers
--------------------------------------------------------------------------------
if not math.clamp then
    math.clamp = function(v, lo, hi)
        v = tonumber(v) or 0
        lo = tonumber(lo) or 0
        hi = tonumber(hi) or 0
        if lo > hi then lo, hi = hi, lo end
        return v < lo and lo or v > hi and hi or v
    end
end

if not math.angle_diff then
    math.angle_diff = function(dest, src)
        local d = (n(dest) - n(src)) % 360
        return d > 180 and d - 360 or d
    end
end

local function normalize_yaw(y)
    y = n(y) % 360
    return y > 180 and y - 360 or y
end

--------------------------------------------------------------------------------
-- Entity helpers
--------------------------------------------------------------------------------
local function safe_call(fn)
    local ok, r = pcall(fn)
    return ok and r or nil
end

local function as_entity(v)
    if v == nil then return nil end
    if type(v) == "userdata" then return v end
    if type(v) == "number" then
        return safe_call(function() return entity.get(v) end)
    end
    return nil
end

local function get_index(ent)
    if type(ent) == "number" then return ent end
    return safe_call(function() return ent:get_index() end)
end

local function is_valid_enemy(ent)
    if not ent then return false end
    if not safe_call(function() return ent:is_alive() end) then return false end
    if safe_call(function() return ent:is_dormant() end) then return false end
    return true
end

local function get_name(ent)
    return safe_call(function() return ent:get_name() end) or "unknown"
end

local function get_velocity(ent)
    local vel = safe_call(function() return ent.m_vecVelocity end)
    if not vel then return 0 end
    local len = safe_call(function() return vel:length() end)
    if len then return n(len) end
    return math.sqrt(n(vel.x)^2 + n(vel.y)^2)
end

local function get_flags(ent)
    return n(safe_call(function() return ent.m_fFlags end))
end

local function is_on_ground(ent)
    local f = get_flags(ent)
    if bit then return bit.band(f, 1) == 1 end
    return (f % 2) >= 1
end

local function get_animstate(ent)
    return safe_call(function() return ent:get_anim_state() end)
        or safe_call(function() return ent:get_animstate() end)
end

local function anim(state, ...)
    local keys = {...}
    for i = 1, #keys do
        local v = safe_call(function() return state[keys[i]] end)
        local num = tonumber(v)
        if num then return num end
    end
    return 0
end

local function for_each_enemy(cb)
    local ok, list = pcall(function() return entity.get_players(true) end)
    if ok and type(list) == "table" then
        for _, raw in ipairs(list) do
            local e = as_entity(raw)
            if is_valid_enemy(e) then cb(e) end
        end
        return
    end
    pcall(function()
        entity.get_players(true, false, function(raw)
            local e = as_entity(raw)
            if is_valid_enemy(e) then cb(e) end
        end)
    end)
end

--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------
-- Ícones nativos do Neverlose / FontAwesome. Sem emoji.
local function nl_icon(name)
    local ok, icon = pcall(function()
        return ui.get_icon(name)
    end)

    if ok and icon and tostring(icon) ~= "" then
        return tostring(icon)
    end

    return ""
end

-- Cores do menu:
-- Ícones internos: azul bebê bem clarinho.
-- Ícones das tabs: cinza quase branco.
MENU_ICON_COL = "\affdcecff"
TAB_ICON_COL  = "\affeef2f6"
MENU_TEXT_COL = "\affffffff"

local function icon_label(icon_name, text)
    local ic = nl_icon(icon_name)
    if ic ~= "" then
        return MENU_ICON_COL .. ic .. "  " .. MENU_TEXT_COL .. text
    end
    return text
end

PAGE_OVERVIEW_ICON = TAB_ICON_COL .. nl_icon("house")
PAGE_SOLVER_ICON   = TAB_ICON_COL .. nl_icon("crosshairs")
PAGE_MISC_ICON     = TAB_ICON_COL .. nl_icon("gear")

local function menu_group(icon, page, title, column)
    -- Top tabs ficam somente com o ícone, sem texto.
    -- Se algum ícone não existir na build, usa o nome da página como fallback pra não quebrar.
    local tab_name = (icon ~= "" and icon or page)
    return ui.create(tab_name, title, column or 1)
end

-- ── OVERVIEW TAB ────────────────────────────────────────────────────────────
-- Overview clean: labels + botões nativos de valor (clicáveis, sem ação).
local function noop_button() end

local function value_text(value)
    return tostring(value)
end

local function add_tip(ref, text)
    if ref and text and text ~= "" then
        pcall(function() ref:tooltip(text) end)
    end
    return ref
end

local function create_value_button(group, text, tip)
    local ok, ref = pcall(function()
        -- alt_style = true deixa o botão no estilo alternativo/outline do Neverlose.
        return group:button(text, noop_button, true)
    end)

    if ok and ref then
        return add_tip(ref, tip)
    end

    local ok2, ref2 = pcall(function()
        return group:button(text, noop_button)
    end)
    if ok2 and ref2 then
        return add_tip(ref2, tip)
    end

    return add_tip(group:label(text), tip)
end

local function info_label(group, icon_name, text, tip)
    return add_tip(group:label(icon_label(icon_name, text)), tip)
end

local function private_value_text()
    local private_col = "\ad4b0ffff" -- pastel moon purple (RRGGBBAA)
    local ic = nl_icon("lock")
    if ic ~= "" then
        return private_col .. ic .. "  Private"
    end
    return private_col .. "Private"
end

b_profile = menu_group(PAGE_OVERVIEW_ICON, "Overview", icon_label("id-card", "PROFILE"), 1)
info_label(b_profile, "user", "User", "Steam/local player name detected from the current session.")
profile_user_label = create_value_button(b_profile, value_text("loading"), "Shows your current Steam/local name.")

info_label(b_profile, "code-branch", "Build", "Current private script build.")
profile_version_label = create_value_button(b_profile, value_text("10.3b"), "Shiny Resolver build version. v103 = 10.3b.")
profile_private_label = create_value_button(b_profile, private_value_text(), "Private branch access status.")

info_label(b_profile, "key", "License", "Current license tier.")
profile_license_label = create_value_button(b_profile, value_text("Lifetime"), "Lifetime private access.")

b_stats = menu_group(PAGE_OVERVIEW_ICON, "Overview", icon_label("chart-simple", "STATISTICS"), 2)
resolved_shots = 0
missed_shots   = 0
resolved_kills = 0

info_label(b_stats, "percent", "Hit Rate", "Percentage of confirmed resolver hits this session.")
hit_rate_label = create_value_button(b_stats, value_text("N/A"), "Current session hit percentage.")

info_label(b_stats, "check", "Hits", "Confirmed shots that damaged enemies.")
resolved_label = create_value_button(b_stats, value_text("0"), "Total confirmed resolver hits this session.")

info_label(b_stats, "xmark", "Misses", "Shots counted as resolver misses after filtering invalid states.")
missed_label   = create_value_button(b_stats, value_text("0"), "Total filtered misses this session.")

info_label(b_stats, "skull", "Kills", "Kills credited to the local player.")
kills_label    = create_value_button(b_stats, value_text("0"), "Total kills this session.")

b_modules = menu_group(PAGE_OVERVIEW_ICON, "Overview", icon_label("layer-group", "ACTIVE MODULES"), 2)
info_label(b_modules, "microchip", "Core", "Main resolver mode currently used by the script.")
module_core_label = create_value_button(b_modules, value_text("Dynamic resolver"), "Dynamic mode switches resolver behavior depending on target state.")

info_label(b_modules, "radar", "Detection", "Side detection features used by the resolver.")
module_detection_label = create_value_button(b_modules, value_text("Detection Core"), "Master detection core with LBY, jitter, duck, movement and history modules.")

info_label(b_modules, "rotate", "Correction", "Miss correction and brute force modules.")
module_correction_label = create_value_button(b_modules, value_text("Bruteforce / Anti Prediction"), "Cycles resolver offsets after misses and adds optional anti-prediction offset.")

info_label(b_modules, "bullseye", "Hitbox", "Automatic hitbox preference logic.")
module_hitbox_label = create_value_button(b_modules, value_text("Smart head / lethal baim"), "Uses resolver stability and lethal body aim checks to pick hitbox.")

b_build = menu_group(PAGE_OVERVIEW_ICON, "Overview", icon_label("sparkles", "BUILD INFO"), 1)
info_label(b_build, "shield-halved", "Branch", "Private build channel.")
build_branch_label = create_value_button(b_build, value_text("Shiny Resolver Private"), "Private Shiny Resolver resolver branch.")
info_label(b_build, "gauge-high", "Preset", "Default configuration profile.")
build_preset_label = create_value_button(b_build, value_text("Balanced"), "Balanced visual and performance preset.")

b_update = menu_group(PAGE_OVERVIEW_ICON, "Overview", "UPDATE NOTES", 1)
add_tip(b_update:label("10.3b"), "Latest Shiny Resolver patch notes.")
b_update:label("• overview patch notes are now cleaner")
b_update:label("• removed value buttons from this block")
b_update:label("• kept notes in a simple changelog style")
b_update:label("• watermark defaults remain background + 100%")
b_update:label("• notifications keep centered compact sizing")

-- ── SOLVER TAB ──────────────────────────────────────────────────────────────
g_main = menu_group(PAGE_SOLVER_ICON, "Solver", icon_label("power-off", "MAIN"), 1)
enable = g_main:switch(icon_label("power-off", "Enabled"), true)
enable:tooltip("Master toggle for the resolver engine.")
core_gear = enable:create()
resolver_mode = core_gear:combo(icon_label("code-branch", "Version"), "Dynamic", "Default", "Advanced")
resolver_mode:tooltip("Default: delta mirror  |  Advanced: full pipeline  |  Dynamic: auto per state")
performance = core_gear:switch(icon_label("gauge-high", "Performance Mode"), true)
performance:tooltip("Resolve only the priority/threat target when possible.")

g_side = menu_group(PAGE_SOLVER_ICON, "Solver", icon_label("radar", "DETECTION"), 1)
-- Detection Core como LABEL com gear nativa.
-- Isso replica o estilo do Hysteria: texto + engrenagem, sem switch/trigger e sem dropdown.
detection_core = g_side:label(icon_label("ellipsis", "Detection Core"))
detection_core:tooltip("Open the gear to configure side detection helpers.")
detection_gear = detection_core:create()
lby_resolver = detection_gear:switch(icon_label("lock", "LBY Resolver"), true)
lby_resolver:tooltip("Tracks lower-body yaw snaps to lock onto the real desync side.")
adaptive = detection_gear:switch(icon_label("sliders", "Adaptive Resolve"), true)
adaptive:tooltip("Scales desync strength based on player movement state.")
jitter_fix = detection_gear:switch(icon_label("wave-square", "Jitter Correction"), true)
jitter_fix:tooltip("Detects flip-jitter over 8 ticks and reduces over-correction.")
air_resolver = detection_gear:switch(icon_label("wind", "Air Resolver"), true)
air_resolver:tooltip("Use reduced desync strength for airborne targets.")
duck_resolver = detection_gear:switch(icon_label("person-arrow-down-to-line", "Duck Resolver"), true)
duck_resolver:tooltip("Adjusts desync strength when target is crouching or standing up.")
move_resolver = detection_gear:switch(icon_label("person-running", "Move Direction Resolver"), true)
move_resolver:tooltip("Uses velocity direction to bias the real desync side (strafe L/R).")
desync_history_en = detection_gear:switch(icon_label("database", "Desync History"), true)
desync_history_en:tooltip("Averages last 6 deltas to smooth out noisy desync readings.")
consec_lock = detection_gear:switch(icon_label("link", "Consecutive Hit Lock"), true)
consec_lock:tooltip("Locks the resolved side after 2+ consecutive hits on the same side.")

function detection_enabled()
    -- Detection Core não tem mais on/off próprio.
    -- Se o resolver estiver ligado, os módulos de detection funcionam conforme seus próprios switches.
    return enable:get()
end

g_angles = menu_group(PAGE_SOLVER_ICON, "Solver", icon_label("sliders", "ANGLE TUNING"), 2)
body_yaw = g_angles:slider(icon_label("arrows-rotate", "Body Yaw Strength"), 0, 100, 60)
body_yaw:tooltip("Base yaw correction strength before adaptive modifiers.")
desync_limit = g_angles:slider(icon_label("ruler", "Desync Limit"), 0, 60, 60)
desync_limit:tooltip("Maximum resolver correction angle clamp.")

g_brute = menu_group(PAGE_SOLVER_ICON, "Solver", icon_label("rotate", "CORRECTION"), 2)
brute_force = g_brute:switch(icon_label("shuffle", "Bruteforce Misses"), true)
brute_force:tooltip("Cycles through 7 angle offsets on consecutive misses.")
brute_gear = brute_force:create()
anti_prediction = brute_gear:switch(icon_label("dice", "Anti Prediction"), true)
anti_prediction:tooltip("Adds small random offset to counter prediction-based AA.")
brute_after = brute_gear:slider(icon_label("repeat", "Bruteforce After Misses"), 1, 10, 1)
brute_after:tooltip("Number of filtered misses required before brute force starts cycling.")

g_hitbox = menu_group(PAGE_SOLVER_ICON, "Solver", icon_label("bullseye", "HITBOX LOGIC"), 2)
hitbox_select = g_hitbox:switch(icon_label("crosshairs", "Smart Hitbox Select"), true)
hitbox_select:tooltip("Automatically prefer head when target is resolved and stable.")
head_vel_limit = g_hitbox:slider(icon_label("gauge", "Head Max Velocity"), 0, 300, 120)
head_vel_limit:tooltip("Only target head when enemy velocity is below this value.")
head_conf_only = g_hitbox:switch(icon_label("shield-halved", "Head on Confidence Only"), false)
head_conf_only:tooltip("Only target head when LBY lock or hit history confirms the side.")
force_baim = g_hitbox:switch(icon_label("person-rifle", "Force Baim Lethal"), true)
force_baim:tooltip("Force body aim when estimated damage is enough to kill the target.")
force_baim_gear = force_baim:create()
baim_min_damage = force_baim_gear:slider(icon_label("heart-pulse", "Baim Min Damage"), 1, 120, 95)
baim_min_damage:tooltip("Force body aim when weapon damage vs current HP is >= this value.")
baim_armor_check = force_baim_gear:switch(icon_label("shield", "Check Armor"), true)
baim_armor_check:tooltip("Apply armor damage reduction when calculating lethal threshold.")

-- ── MISC TAB ────────────────────────────────────────────────────────────────
b_dbg_ctrl = menu_group(PAGE_MISC_ICON, "Misc", icon_label("bug", "SOLVER DEBUGGER"), 1)
debugger    = b_dbg_ctrl:switch(icon_label("terminal", "Enable Debugger"), false)
debugger:tooltip("Show the player inspector and live resolver data.")
player_list = b_dbg_ctrl:list(icon_label("users", "Players"), {})
player_list:tooltip("Select an enemy to inspect live resolver values.")

b_dbg_data = menu_group(PAGE_MISC_ICON, "Misc", icon_label("database", "LIVE DATA"), 2)
dbg_mode   = b_dbg_data:label(icon_label("code-branch", "Mode      →  —"))
dbg_side   = b_dbg_data:label(icon_label("left-right", "Side      →  —"))
dbg_desync = b_dbg_data:label(icon_label("sliders", "Desync    →  —"))
dbg_vel    = b_dbg_data:label(icon_label("gauge", "Velocity  →  —"))
dbg_jitter = b_dbg_data:label(icon_label("wave-square", "Jitter    →  —"))
dbg_lby    = b_dbg_data:label(icon_label("lock", "LBY Lock  →  —"))
dbg_ground = b_dbg_data:label(icon_label("layer-group", "Grounded  →  —"))
dbg_micro  = b_dbg_data:label(icon_label("magnifying-glass", "Micro-Ang →  —"))
dbg_hitbox = b_dbg_data:label(icon_label("bullseye", "Hitbox    →  —"))

g_extra = menu_group(PAGE_MISC_ICON, "Misc", icon_label("sparkles", "EXTRA"), 1)
silent_shot = g_extra:switch(icon_label("volume-xmark", "Silent Shot"), true)
silent_shot:tooltip("Fire without animating the shot clientside.")
esp_flag_enable = g_extra:switch(icon_label("flag", "ESP Resolver Flag"), true)
esp_flag_enable:tooltip("Show resolver status flag above each enemy.")
logs = g_extra:switch(icon_label("file-lines", "Console Logs"), false)
logs:tooltip("Print hit/miss/debug info to console.")

g_clantag = menu_group(PAGE_MISC_ICON, "Misc", icon_label("tags", "CLANTAG"), 1)
clantag_enable = g_clantag:switch(icon_label("signature", "Animated Clantag"), false)
clantag_enable:tooltip("Animate your clantag using the Shiny Resolver type/delete effect.")
clantag_gear = clantag_enable:create()
clantag_speed = clantag_gear:slider(icon_label("gauge-high", "Animation Speed"), 1, 20, 8)
clantag_speed:tooltip("Controls how fast the clantag types and deletes. Higher is faster.")
clantag_clear = clantag_gear:switch(icon_label("eraser", "Clear On Disable"), true)
clantag_clear:tooltip("Clear the clantag automatically when the animation is disabled.")

-- ── TRASHTALK ────────────────────────────────────────────────────────────────
g_trashtalk = menu_group(PAGE_MISC_ICON, "Misc", icon_label("comments", "TRASHTALK"), 1)
trashtalk_enable = g_trashtalk:switch(icon_label("comment-dots", "Trashtalk"), false)
trashtalk_enable:tooltip("Send a short Shiny Resolver message after selected combat events.")
trashtalk_gear = trashtalk_enable:create()
-- Multi event selector: replaces the old Mode combo.
-- Pick exactly what should trigger trashtalk. No "All" option anymore.
trashtalk_events = nil
local _tt_ok, _tt_ref = pcall(function()
    return trashtalk_gear:selectable(icon_label("list-check", "Events"), "Kill", "Hit", "Miss", "Resolve Only")
end)
if not _tt_ok or not _tt_ref then
    _tt_ok, _tt_ref = pcall(function()
        return trashtalk_gear:selectable(icon_label("list-check", "Events"), {"Kill", "Hit", "Miss", "Resolve Only"})
    end)
end
if _tt_ok and _tt_ref then
    trashtalk_events = _tt_ref
    trashtalk_events:tooltip("Select which events can send trashtalk. Resolve Only sends: target resolved. ~ shiny resolver")
    pcall(function() trashtalk_events:set({"Kill"}) end)
else
    -- Fallback for builds without selectable(): still works, just not as a compact list.
    trashtalk_kill = trashtalk_gear:switch(icon_label("skull", "Kill"), true)
    trashtalk_hit = trashtalk_gear:switch(icon_label("check", "Hit"), false)
    trashtalk_miss = trashtalk_gear:switch(icon_label("xmark", "Miss"), false)
    trashtalk_resolve_only = trashtalk_gear:switch(icon_label("wand-magic-sparkles", "Resolve Only"), false)
end
trashtalk_delay = trashtalk_gear:slider(icon_label("clock", "Delay"), 0, 3, 1)
trashtalk_delay:tooltip("Delay before sending the message, in seconds. Max: 3s.")

--------------------------------------------------------------------------------
-- Animated Clantag
--------------------------------------------------------------------------------
CLANTAG_FRAMES = CLANTAG_FRAMES or {
    "5",
    "s",
    "sI",
    "sI-",
    "sI-I",
    "sh",
    "sh1",
    "shi",
    "shiI",
    "shiI\\",
    "shin",
    "shiny",
    "shiny r3",
    "shiny re5",
    "shiny res",
    "shiny res0",
    "shiny reso",
    "shiny resol",
    "shiny resol\\",
    "shiny resol\\/",
    "shiny resolv",
    "shiny resolv3",
    "shiny resolve",
    "shiny resolver",
    "shiny resolver",
    "shiny resolver",
    "shiny resolver",
    "shiny resolve",
    "shiny resolv",
    "shiny resol",
    "shiny reso",
    "shiny res",
    "shiny re",
    "shiny r",
    "shiny ",
    "shiny",
    "shin",
    "shi",
    "sh",
    "s",
    "",
}
CLANTAG_STATE = CLANTAG_STATE or { index = 1, last_update = 0, last_text = nil, cleared = true }

function set_shiny_clantag(text)
    text = tostring(text or "")

    if common and common.set_clan_tag then
        local ok = pcall(function() common.set_clan_tag(text) end)
        if ok then return true end
    end

    if common and common.set_clantag then
        local ok = pcall(function() common.set_clantag(text) end)
        if ok then return true end
    end

    if utils and utils.set_clan_tag then
        local ok = pcall(function() utils.set_clan_tag(text) end)
        if ok then return true end
    end

    if utils and utils.set_clantag then
        local ok = pcall(function() utils.set_clantag(text) end)
        if ok then return true end
    end

    if client and client.set_clan_tag then
        local ok = pcall(function() client.set_clan_tag(text) end)
        if ok then return true end
    end

    if client and client.set_clantag then
        local ok = pcall(function() client.set_clantag(text) end)
        if ok then return true end
    end

    return false
end

function update_shiny_clantag()
    if not clantag_enable:get() then
        if clantag_clear:get() and not CLANTAG_STATE.cleared then
            set_shiny_clantag("")
            CLANTAG_STATE.last_text = nil
            CLANTAG_STATE.cleared = true
        end
        return
    end

    CLANTAG_STATE.cleared = false

    local rt = globals.realtime or 0
    local speed = n(clantag_speed:get(), 8)
    local delay = math.max(0.04, 0.34 - speed * 0.014)

    if (rt - (CLANTAG_STATE.last_update or 0)) < delay then
        return
    end

    CLANTAG_STATE.last_update = rt

    local frames = CLANTAG_FRAMES
    local idx = CLANTAG_STATE.index or 1
    local tag = frames[idx] or "shiny resolver"

    if tag ~= CLANTAG_STATE.last_text then
        set_shiny_clantag(tag)
        CLANTAG_STATE.last_text = tag
    end

    idx = idx + 1
    if idx > #frames then idx = 1 end
    CLANTAG_STATE.index = idx
end

--------------------------------------------------------------------------------
-- Trashtalk
--------------------------------------------------------------------------------
TRASHTALK_MESSAGES = TRASHTALK_MESSAGES or {
    kill = {
        "shiny resolver says gn",
        "hell nah",
        "moon checked.",
        "shiny",
        "shiny > you",
        "sit down lil bro",
        "w",
        "anti aim from temu",
        "subscription expired",
        "1",
        "your antiaim is decorative.",
        "private build moment.",
        "roblox anti aim ahh",
    },
    hit = {
        "tagged by shiny resolver",
        "that angle got shiny checked",
        "clean hit.",
        "resolver looking cute today",
    },
    miss = {
        "spread saved you",
        "lucky miss, still shiny",
        "resolver is warming up",
        "next one is clean",
    }
}
TRASHTALK_STATE = TRASHTALK_STATE or { queue = {}, last_sent = 0, cycle = { kill = 1, hit = 1, miss = 1 } }

function trashtalk_selection_has(name)
    name = tostring(name or "")

    -- Preferred compact selectable/list mode.
    if trashtalk_events then
        local ok, selected = pcall(function() return trashtalk_events:get() end)
        if ok and selected ~= nil then
            if type(selected) == "table" then
                for k, v in pairs(selected) do
                    if type(k) == "string" and k == name and v then return true end
                    if type(v) == "string" and v == name then return true end
                    if type(v) == "table" then
                        for _, vv in pairs(v) do
                            if tostring(vv) == name then return true end
                        end
                    end
                end
            elseif tostring(selected) == name then
                return true
            end
        end
        return false
    end

    -- Fallback switch mode.
    if name == "Kill" then return trashtalk_kill and trashtalk_kill:get() end
    if name == "Hit" then return trashtalk_hit and trashtalk_hit:get() end
    if name == "Miss" then return trashtalk_miss and trashtalk_miss:get() end
    if name == "Resolve Only" then return trashtalk_resolve_only and trashtalk_resolve_only:get() end
    return false
end

function trashtalk_should_send(event_name)
    if not trashtalk_enable:get() then return false end
    if event_name == "kill" then
        return trashtalk_selection_has("Kill") or trashtalk_selection_has("Resolve Only")
    end
    if event_name == "hit" then return trashtalk_selection_has("Hit") end
    if event_name == "miss" then return trashtalk_selection_has("Miss") end
    return false
end

function trashtalk_pick_message(event_name, target_name)
    target_name = tostring(target_name or "")
    if #target_name > 18 then target_name = target_name:sub(1, 16) .. ".." end

    local msg
    -- Resolve Only has priority over normal kill messages when selected.
    if event_name == "kill" and trashtalk_selection_has("Resolve Only") then
        msg = "{target} resolved. ~ shiny resolver"
    else
        local list = TRASHTALK_MESSAGES[event_name] or TRASHTALK_MESSAGES.kill
        if not list or #list == 0 then return "shiny resolver" end
        msg = list[math.random(1, #list)]
    end

    msg = tostring(msg or "shiny resolver")
    msg = msg:gsub("{target}", target_name)
    msg = msg:gsub('"', "'")
    msg = msg:gsub(";", ",")
    return msg
end

function trashtalk_send_chat(text)
    text = tostring(text or "")
    if text == "" then return false end

    local cmd = "say " .. '"' .. text .. '"'

    if utils and utils.console_exec then
        local ok = pcall(function() utils.console_exec(cmd) end)
        if ok then return true end
    end

    if common and common.execute then
        local ok = pcall(function() common.execute(cmd) end)
        if ok then return true end
    end

    if client and client.exec then
        local ok = pcall(function() client.exec(cmd) end)
        if ok then return true end
    end

    if engine and engine.execute_client_cmd then
        local ok = pcall(function() engine.execute_client_cmd(cmd) end)
        if ok then return true end
    end

    return false
end

function queue_trashtalk(event_name, target_name)
    if not trashtalk_should_send(event_name) then return end
    local rt = globals.realtime or 0
    local delay = math.min(3, math.max(0, n(trashtalk_delay:get(), 1)))
    table.insert(TRASHTALK_STATE.queue, {
        time = rt + delay,
        text = trashtalk_pick_message(event_name, target_name)
    })
end

function update_trashtalk()
    if not trashtalk_enable:get() then
        TRASHTALK_STATE.queue = {}
        return
    end

    local rt = globals.realtime or 0
    if #TRASHTALK_STATE.queue == 0 then return end
    if rt - (TRASHTALK_STATE.last_sent or 0) < 0.65 then return end

    local item = TRASHTALK_STATE.queue[1]
    if not item or rt < (item.time or 0) then return end

    trashtalk_send_chat(item.text or "shiny resolver")
    TRASHTALK_STATE.last_sent = rt
    table.remove(TRASHTALK_STATE.queue, 1)
end

--------------------------------------------------------------------------------
-- Per-player state
--------------------------------------------------------------------------------
local misses        = {}
local cache         = {}
local side_history  = {}
local lby_history   = {}
local jitter_buf    = {}
local brute_seq     = {}
local players_cache = {}
LAST_HIT_INFO = LAST_HIT_INFO or {}

-- FIX 1: pending_hit impede que aim_ack processe um tiro que player_hurt já confirmou
-- como acerto. Evita o brute avançar quando o hit chega fora de ordem.
local pending_hit   = {}
local last_tick_seen   = {}  -- último tick em que cada player teve update válido
local desync_history   = {}  -- últimos N deltas por player (smooth)
local consec_hits      = {}  -- {side, count} hits consecutivos no mesmo lado
local duck_state       = {}  -- {was_duck, changed_tick} estado de duck anterior

-- Se o gap de ticks desde o último update for maior que isso,
-- o cache está stale (fakelag/dormant) e não deve penalizar o brute.
local FAKELAG_TICK_THRESHOLD = 4
local DESYNC_HIST_SIZE       = 6   -- número de deltas a suavizar

local JITTER_BUF_SIZE    = 8
-- FIX 2: Micro-angle threshold reduzido de 2.0 para 0.35.
-- Com 2.0°, um delta de 0.05° (o que os logs mostram) caía no path de micro e usava
-- brute cego. Agora só deltas realmente insignificantes são tratados como micro.
local MICRO_ANGLE_MAX    = 0.35
local MIN_STRENGTH_RATIO = 0.5
local BRUTE_OFFSETS      = { 1.0, -1.0, 0.5, -0.5, 0.0, 0.75, -0.75 }

--------------------------------------------------------------------------------
-- Crosshair Indicator
--------------------------------------------------------------------------------
local _IND = {}

g_ind = menu_group(PAGE_MISC_ICON, "Misc", icon_label("palette", "VISUALS"), 2)
ind_enable = g_ind:switch(icon_label("crosshairs", "Crosshair Indicator"), false)
ind_enable:tooltip("Draw the resolver HUD below the crosshair.")
ind_gear = ind_enable:create()

ind_style  = ind_gear:combo(icon_label("palette", "Indicator Style"), "Full", "Compact", "Minimal")
ind_style:tooltip("Full shows all rows, Compact keeps title/confidence, Minimal shows dot and percentage only.")
ind_font_style = ind_gear:combo(icon_label("font", "Font Style"), "Bold", "Default", "Small", "Console")
ind_font_style:tooltip("Choose the crosshair indicator font style. Bold is the default Shiny Resolver style.")
ind_dpi_scale = ind_gear:combo(icon_label("text-height", "DPI Scale"), "75%", "100%", "125%")
ind_dpi_scale:tooltip("Scale the crosshair indicator size. 100% is the default Shiny Resolver layout.")
ind_target = ind_gear:switch(icon_label("user", "Show Target Name"), true)
ind_target:tooltip("Show the current target name under the indicator title.")
ind_conf   = ind_gear:switch(icon_label("chart-simple", "Show Confidence Bar"), true)
ind_conf:tooltip("Show the calculated visual confidence percentage and bar.")
ind_state  = ind_gear:switch(icon_label("signal", "Show Resolver State"), false)
ind_state:tooltip("Show side, hitbox and lock state below the confidence row.")

g_wm = menu_group(PAGE_MISC_ICON, "Misc", icon_label("palette", "VISUALS"), 2)
wm_enable = g_wm:switch(icon_label("signature", "Watermark"), true)
wm_enable:tooltip("Draw a small Shiny Resolver watermark on screen.")
wm_gear = wm_enable:create()
wm_show_fps = wm_gear:switch(icon_label("gauge-high", "Show FPS"), true)
wm_show_fps:tooltip("Show current FPS in the watermark.")
wm_show_user = wm_gear:switch(icon_label("user", "Show User"), false)
wm_show_user:tooltip("Show your local player name in the watermark.")
wm_show_ping = wm_gear:switch(icon_label("wifi", "Show Ping"), true)
wm_show_ping:tooltip("Show your current latency in the watermark.")
wm_show_time = wm_gear:switch(icon_label("clock", "Show Time"), false)
wm_show_time:tooltip("Show local time in the watermark.")
wm_show_tickrate = wm_gear:switch(icon_label("server", "Show Tickrate"), false)
wm_show_tickrate:tooltip("Show server tickrate calculated from tick interval.")
wm_background = wm_gear:switch(icon_label("square", "Show Background"), true)
wm_background:tooltip("Draw a subtle background behind the watermark text.")
wm_position = wm_gear:combo(icon_label("location-dot", "Position"), "Top Right", "Top Left")
wm_position:tooltip("Choose where the watermark is drawn.")
wm_font_size = wm_gear:combo(icon_label("text-height", "DPI Scale"), "75%", "100%", "125%")
wm_font_size:tooltip("Adjust the watermark DPI scale.")
wm_font_style = wm_gear:combo(icon_label("font", "Font Style"), "Bold", "Default", "Small", "Console")
wm_font_style:tooltip("Choose the watermark font style. Bold is the default Shiny Resolver style.")
wm_draggable = wm_gear:switch(icon_label("up-down-left-right", "Drag With Mouse"), true)
wm_draggable:tooltip("Watermark is always draggable while the Neverlose menu is open.")
pcall(function() wm_draggable:visibility(false) end)
wm_snap_grid = wm_gear:switch(icon_label("border-all", "Snap To Grid"), true)
wm_snap_grid:tooltip("Snap watermark movement to a small grid while dragging.")
wm_grid_size = wm_gear:slider(icon_label("table-cells", "Grid Size"), 2, 32, 8)
wm_grid_size:tooltip("Grid is locked to 8px for clean placement.")
pcall(function() wm_grid_size:visibility(false) end)
wm_x_offset = wm_gear:slider(icon_label("arrows-left-right", "X Offset"), -900, 900, 0)
wm_x_offset:tooltip("Hidden: moved directly by dragging the watermark.")
pcall(function() wm_x_offset:visibility(false) end)
wm_y_offset = wm_gear:slider(icon_label("arrows-up-down", "Y Offset"), -500, 500, 0)
wm_y_offset:tooltip("Hidden: moved directly by dragging the watermark.")
pcall(function() wm_y_offset:visibility(false) end)

wm_reset_button = wm_gear:button(nl_icon("rotate-left") ~= "" and (MENU_ICON_COL .. nl_icon("rotate-left")) or "Reset", function()
    pcall(function() wm_x_offset:set(0) end)
    pcall(function() wm_y_offset:set(0) end)
    pcall(function() wm_position:set("Top Right") end)
    pcall(function() wm_font_size:set("100%") end)
    pcall(function() wm_font_style:set("Bold") end)
    pcall(function() wm_show_fps:set(true) end)
    pcall(function() wm_show_user:set(false) end)
    pcall(function() wm_show_ping:set(true) end)
    pcall(function() wm_show_time:set(false) end)
    pcall(function() wm_show_tickrate:set(false) end)
    pcall(function() wm_background:set(true) end)
    pcall(function() wm_grid_size:set(8) end)
    pcall(function() wm_snap_grid:set(true) end)
    if _wm then
        _wm.drag = false
        _wm.drag_dx = 0
        _wm.drag_dy = 0
        _wm.input_blocked = false
        _wm.grid_alpha = 0
    end
end, true)
wm_reset_button:tooltip("Reset watermark position and visual settings to the default Shiny Resolver layout.")

notify_enable = g_wm:switch(icon_label("bell", "Hit/Miss Notifications"), true)
notify_enable:tooltip("Show small Shiny Resolver combat notifications on hit, miss, kill and damage taken.")
notify_gear = notify_enable:create()
-- Multi event selector, same idea as trashtalk: choose exactly which notifications you want.
notify_events = nil
local _nt_ok, _nt_ref = pcall(function()
    return notify_gear:selectable(icon_label("list-check", "Events"), "Hit", "Miss", "Kill", "Damage Taken")
end)
if not _nt_ok or not _nt_ref then
    _nt_ok, _nt_ref = pcall(function()
        return notify_gear:selectable(icon_label("list-check", "Events"), {"Hit", "Miss", "Kill", "Damage Taken"})
    end)
end
if _nt_ok and _nt_ref then
    notify_events = _nt_ref
    notify_events:tooltip("Select which combat notifications should appear on screen.")
    pcall(function() notify_events:set({"Hit", "Miss", "Kill", "Damage Taken"}) end)
else
    -- Fallback for builds without selectable(): keep the same functionality with switches.
    notify_hit = notify_gear:switch(icon_label("check", "Hit"), true)
    notify_hit:tooltip("Show a notification when you damage an enemy.")
    notify_miss = notify_gear:switch(icon_label("xmark", "Miss"), true)
    notify_miss:tooltip("Show a notification when the resolver registers a filtered miss.")
    notify_kill = notify_gear:switch(icon_label("skull", "Kill"), true)
    notify_kill:tooltip("Show a notification when you kill an enemy.")
    notify_damage_taken = notify_gear:switch(icon_label("heart-crack", "Damage Taken"), true)
    notify_damage_taken:tooltip("Show who damaged you and how much damage you took.")
end
notify_background = notify_gear:switch(icon_label("square", "Show Background"), true)
notify_background:tooltip("Draw a subtle background behind each notification.")
notify_position = notify_gear:combo(icon_label("location-dot", "Position"), "Bottom Mid", "Top Right", "Top Left", "Bottom Right", "Bottom Left")
notify_position:tooltip("Choose where notifications appear.")
notify_dpi = notify_gear:combo(icon_label("text-height", "DPI Scale"), "75%", "100%", "125%", "150%")
notify_dpi:tooltip("Scale the notification size. 75% is the compact default layout.")
notify_font_style = notify_gear:combo(icon_label("font", "Font Style"), "Bold", "Default", "Small", "Console")
notify_font_style:tooltip("Choose the notification font style.")
notify_duration = notify_gear:slider(icon_label("hourglass-half", "Duration"), 1, 6, 3)
notify_duration:tooltip("How long each notification stays on screen, in seconds.")
notify_animation = notify_gear:combo(icon_label("wand-magic-sparkles", "Animation"), "Rise", "Slide", "Fade", "Pop")
notify_animation:tooltip("Choose how notifications animate in and out.")
notify_draggable = notify_gear:switch(icon_label("up-down-left-right", "Drag With Mouse"), true)
notify_draggable:tooltip("Notifications are always draggable while the Neverlose menu is open.")
pcall(function() notify_draggable:visibility(false) end)
notify_snap_grid = notify_gear:switch(icon_label("border-all", "Snap To Grid"), true)
notify_snap_grid:tooltip("Snap notification movement to a small grid while dragging.")
notify_grid_size = notify_gear:slider(icon_label("table-cells", "Grid Size"), 2, 32, 8)
notify_grid_size:tooltip("Grid is locked to 8px for clean placement.")
pcall(function() notify_grid_size:visibility(false) end)
notify_x_offset = notify_gear:slider(icon_label("arrows-left-right", "X Offset"), -900, 900, 0)
notify_x_offset:tooltip("Hidden: moved directly by dragging the notification preview.")
pcall(function() notify_x_offset:visibility(false) end)
notify_y_offset = notify_gear:slider(icon_label("arrows-up-down", "Y Offset"), -500, 500, -112)
notify_y_offset:tooltip("Hidden: moved directly by dragging the notification preview.")
pcall(function() notify_y_offset:visibility(false) end)
notify_reset_button = notify_gear:button(nl_icon("rotate-left") ~= "" and (MENU_ICON_COL .. nl_icon("rotate-left")) or "Reset", function()
    pcall(function() notify_position:set("Bottom Mid") end)
    pcall(function() notify_dpi:set("75%") end)
    pcall(function() notify_font_style:set("Bold") end)
    pcall(function() notify_duration:set(3) end)
    pcall(function() notify_animation:set("Rise") end)
    if notify_events then
        pcall(function() notify_events:set({"Hit", "Miss", "Kill", "Damage Taken"}) end)
    else
        pcall(function() notify_hit:set(true) end)
        pcall(function() notify_miss:set(true) end)
        pcall(function() notify_kill:set(true) end)
        pcall(function() notify_damage_taken:set(true) end)
    end
    pcall(function() notify_background:set(true) end)
    pcall(function() notify_x_offset:set(0) end)
    pcall(function() notify_y_offset:set(-112) end)
    pcall(function() notify_grid_size:set(8) end)
    pcall(function() notify_snap_grid:set(true) end)
    if NOTIFY_STATE then
        NOTIFY_STATE.drag = false
        NOTIFY_STATE.drag_dx = 0
        NOTIFY_STATE.drag_dy = 0
        NOTIFY_STATE.input_blocked = false
        NOTIFY_STATE.grid_alpha = 0
    end
end, true)
notify_reset_button:tooltip("Reset notification position and visual settings to the default Shiny Resolver layout.")

function load_mini_font(size, preferred)
    local fonts = preferred or { "Verdana", "Tahoma", "Arial", "Small Fonts" }
    for i = 1, #fonts do
        local ok, font = pcall(function()
            return render.load_font(fonts[i], vector(size, size), "a")
        end)
        if ok and font then return font end
    end
    return nil
end

local FONT_TITLE = load_mini_font(11, {"Verdana", "Tahoma", "Arial", "Small Fonts"})
local FONT_LABEL = load_mini_font(10, {"Verdana", "Tahoma", "Arial", "Small Fonts"})
local FONT_SMALL = load_mini_font(9,  {"Tahoma", "Verdana", "Arial", "Small Fonts"})
local FONT_CONF  = load_mini_font(13, {"Verdana", "Tahoma", "Arial", "Small Fonts"})
local FONT_ICON  = load_mini_font(13, {"Verdana", "Tahoma", "Arial", "Small Fonts"})
FONT_WM_SMALL = load_mini_font(10, {"Verdana", "Tahoma", "Arial", "Small Fonts"})
FONT_WM_MED   = load_mini_font(12, {"Verdana", "Tahoma", "Arial", "Small Fonts"})
FONT_WM_LARGE = load_mini_font(14, {"Verdana", "Tahoma", "Arial", "Small Fonts"})

local INDICATOR_X_OFFSET = 0
local INDICATOR_Y_OFFSET = 10

local C = {
    blue     = color(176, 208, 255, 255),
    pink     = color(255, 176, 232, 255),
    purple   = color(212, 176, 255, 255),
    white    = color(248, 250, 255, 255),
    dim      = color(205, 218, 255, 210),
    shadow   = color(0, 0, 0, 185),
    high     = color(143, 223, 176, 255),
    med      = color(176, 208, 255, 255),
    low      = color(255, 176, 176, 255),
    warn     = color(255, 198, 145, 255),
    na       = color(180, 200, 240, 75),
    null     = color(0, 0, 0, 0),
}

local _anim = {
    alpha        = 0,
    bar_width    = 0,
    dot_pulse    = 0,
    scope_offset = 0,
    conf_value   = 0,
    breath       = 0,
    opacity      = 1,
    target_alpha = 0,
    target_slide = -4,
    last_data_update = 0,
}

local _target_name  = "—"
local _conf_pct     = -1
local _state_str    = "No Target"
local _state_side   = 0
local _state_hb     = "chest"
local _resolved     = false
local _has_target   = false
local _state_jitter = false
local _state_micro  = false
local _state_locked = false
local _state_misses = 0

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function clamp(v, lo, hi)
    v = tonumber(v) or 0
    return v < lo and lo or v > hi and hi or v
end

local function lerp_color(ca, cb, t)
    t = clamp(t, 0, 1)
    return color(
        math.floor(ca.r + (cb.r - ca.r) * t),
        math.floor(ca.g + (cb.g - ca.g) * t),
        math.floor(ca.b + (cb.b - ca.b) * t),
        math.floor(ca.a + (cb.a - ca.a) * t)
    )
end

local function alpha_mod(c, a)
    return color(c.r, c.g, c.b, math.floor(clamp(a, 0, 1) * c.a))
end

local function get_indicator_accent()
    if not _has_target then
        return lerp_color(C.na, C.purple, _anim.breath or 0)
    end
    if not _resolved then
        return lerp_color(C.pink, C.purple, _anim.breath or 0)
    end
    local pct = tonumber(_conf_pct) or -1
    local bad_state = _state_jitter or _state_micro or _state_misses >= 2 or (pct >= 0 and pct < 45)
    local good_state = _state_locked or (pct >= 72)
    if bad_state then
        return lerp_color(C.low, C.warn, (_anim.breath or 0) * 0.65)
    end
    if good_state then
        return lerp_color(C.high, C.blue, (_anim.breath or 0) * 0.45)
    end
    return lerp_color(C.blue, C.purple, _anim.breath or 0)
end

local function text_size(font, flags, text)
    local ok, size = pcall(function()
        return render.measure_text(font, flags or "", tostring(text or ""))
    end)
    if ok and size then return size end
    return vector(#tostring(text or "") * 6, 10)
end

local function draw_text(font, pos, col, flags, text)
    pcall(function()
        render.text(font, pos, col, flags or "", tostring(text or ""))
    end)
end

local function draw_shadow_text(font, pos, col, flags, text, shadow_alpha)
    local t = tostring(text or "")
    local a = shadow_alpha or 185
    draw_text(font, vector(pos.x + 1, pos.y + 1), color(0, 0, 0, a), flags, t)
    draw_text(font, pos, col, flags, t)
end

local function draw_soft_rect(a, b, col, round)
    pcall(function() render.rect(a, b, col, round or 1) end)
end

local function pick_indicator_target()
    local threat = safe_call(function() return entity.get_threat() end)
    threat = as_entity(threat)
    if is_valid_enemy(threat) then return threat end
    local best = nil
    for_each_enemy(function(ent)
        if best then return end
        local idx = get_index(ent)
        if idx and cache[idx] then best = ent end
    end)
    if best then return best end
    for_each_enemy(function(ent)
        if not best then best = ent end
    end)
    return best
end

local function calculate_confidence(idx, data, rt)
    if not data then return -1 end
    local sh     = side_history[idx]
    local hits   = sh and ((sh.hits_left or 0) + (sh.hits_right or 0)) or 0
    local m      = misses[idx] or 0
    local total  = hits + m
    local pct = 34
    if total > 0 then
        local hit_r = hits / total
        pct = 28 + hit_r * 46
    end
    local side_n = n(data.side)
    if side_n ~= 0 then pct = pct + 13 end
    if data.lby_locked then pct = pct + 20 end
    if sh then
        local diff = math.abs((sh.hits_right or 0) - (sh.hits_left or 0))
        if diff >= 3 then pct = pct + 12
        elseif diff == 2 then pct = pct + 8
        elseif diff == 1 then pct = pct + 4 end
    end
    if data.on_ground then pct = pct + 5 else pct = pct - 8 end
    if data.jitter then pct = pct - 17 end
    if data.micro then pct = pct - 13 end
    local vel = n(data.velocity)
    if vel > 220 then pct = pct - 10
    elseif vel > 150 then pct = pct - 6
    elseif vel < 10 and data.on_ground then pct = pct + 5 end
    if m > 0 then pct = pct - math.min(m * 6, 24) end
    if data.hitbox == 0 then pct = pct + 3 end
    local desync = n(data.desync)
    local live = math.sin((rt or 0) * 1.35 + idx * 0.61) * 2.0
               + math.sin((rt or 0) * 0.55 + desync * 0.11) * 1.2
    pct = pct + live
    return math.floor(clamp(pct, 18, 94))
end

local function update_indicator_data(need_target, need_conf, need_state, rt)
    _resolved     = false
    _has_target   = false
    _state_jitter = false
    _state_micro  = false
    _state_locked = false
    _state_misses = 0
    if not need_target and not need_conf and not need_state then
        _target_name = ""
        _conf_pct    = -1
        _state_str   = ""
        return
    end
    local lp = entity.get_local_player()
    if not lp then
        if need_target then _target_name = "No Local" end
        if need_conf then _conf_pct = -1 end
        if need_state then _state_str = "No Local" end
        return
    end
    local target = pick_indicator_target()
    if not target then
        if need_target then _target_name = "No Target" end
        if need_conf then _conf_pct = -1 end
        if need_state then _state_str = "No Target" end
        return
    end
    _has_target = true
    local idx  = get_index(target)
    local data = idx and cache[idx]
    if need_target then
        local raw_name = get_name(target)
        if #raw_name > 18 then raw_name = raw_name:sub(1, 16) .. ".." end
        _target_name = raw_name
    end
    if not data then
        if need_conf then _conf_pct = -1 end
        if need_state then _state_str = "Resolving..." end
        return
    end
    _resolved     = true
    _state_side   = data.side or 0
    _state_hb     = (data.hitbox == 0) and "head" or "chest"
    _state_jitter = data.jitter == true
    _state_micro  = data.micro == true
    _state_locked = data.lby_locked == true
    _state_misses = idx and (misses[idx] or 0) or 0
    if need_conf then
        _conf_pct = calculate_confidence(idx, data, rt)
    end
    if need_state then
        local side_s = _state_side > 0 and "R" or _state_side < 0 and "L" or "?"
        local mode_s = data.mode and (data.mode:sub(1,1):upper() .. data.mode:sub(2)) or "?"
        _state_str   = mode_s .. " · " .. side_s .. " · " .. _state_hb
    end
end

local function is_scoped_player()
    local lp = entity.get_local_player()
    if not lp then return false end
    local scoped = safe_call(function() return lp.m_bIsScoped end)
    if scoped == nil then
        scoped = safe_call(function() return lp["m_bIsScoped"] end)
    end
    return scoped == true or scoped == 1
end

local BAR_W = 48
local BAR_H = 3
local TITLE_TEXT = "shiny resolver"
local DOT_W = 3
local DOT_GAP = 8
local TARGET_GAP_Y = 12
local NORMAL_OPACITY = 0.88
local SCOPED_OPACITY = 0.58

local function render_crosshair_indicator()
    if not ind_enable:get() then
        _anim.alpha        = 0
        _anim.bar_width    = 0
        _anim.scope_offset = 0
        _anim.conf_value   = 0
        _anim.opacity      = 1
        _anim.target_alpha = 0
        _anim.target_slide = -4
        _anim.last_data_update = 0
        return
    end
    local ft = clamp(globals.frametime, 0, 0.05)
    local rt = globals.realtime
    local indicator_style = tostring(ind_style:get() or "Full")
    local style_full    = indicator_style == "Full"
    local style_compact = indicator_style == "Compact"
    local style_minimal = indicator_style == "Minimal"
    local show_target = style_full and ind_target:get() or false
    local show_conf   = style_minimal or ((style_full or style_compact) and ind_conf:get())
    local show_state  = style_full and ind_state:get() or false
    local DATA_UPDATE_INTERVAL = 0.035
    if (rt - (_anim.last_data_update or 0)) >= DATA_UPDATE_INTERVAL then
        update_indicator_data(show_target, show_conf, show_state, rt)
        _anim.last_data_update = rt
    end
    _anim.alpha = lerp(_anim.alpha, 1, ft * 8)
    _anim.dot_pulse = 0.5 + math.sin(rt * 2.15) * 0.5
    _anim.breath = 0.5 + math.sin(rt * 1.65) * 0.5
    local wanted_target_alpha = _has_target and 1 or 0
    _anim.target_alpha = lerp(_anim.target_alpha or 0, wanted_target_alpha, ft * 10)
    _anim.target_slide = lerp(_anim.target_slide or -4, _has_target and 0 or -4, ft * 10)
    local scoped = is_scoped_player()
    local wanted_scope_offset = 0
    if scoped then
        local dpi_name = tostring(ind_dpi_scale and ind_dpi_scale:get() or "100%")
        wanted_scope_offset = dpi_name == "75%" and -34 or dpi_name == "125%" and -58 or -46
    end
    _anim.scope_offset = lerp(_anim.scope_offset or 0, wanted_scope_offset, ft * 11)
    local wanted_opacity = scoped and SCOPED_OPACITY or NORMAL_OPACITY
    _anim.opacity = lerp(_anim.opacity or NORMAL_OPACITY, wanted_opacity, ft * 10)
    if _anim.alpha < 0.01 then return end
    local alpha = _anim.alpha * (_anim.opacity or NORMAL_OPACITY)

    local IND_FONT_TITLE = ind_get_font and ind_get_font("title") or FONT_TITLE
    local IND_FONT_LABEL = ind_get_font and ind_get_font("label") or FONT_LABEL
    local IND_FONT_SMALL = ind_get_font and ind_get_font("small") or FONT_SMALL
    local IND_FONT_CONF  = ind_get_font and ind_get_font("conf")  or FONT_CONF

    local ind_scale = ind_dpi_value and ind_dpi_value() or 1
    local BAR_W = math.floor(48 * ind_scale + 0.5)
    local BAR_H = math.max(2, math.floor(3 * ind_scale + 0.5))
    local DOT_W = math.max(2, math.floor(3 * ind_scale + 0.5))
    local DOT_GAP = math.floor(8 * ind_scale + 0.5)
    local TARGET_GAP_Y = math.floor(12 * ind_scale + 0.5)
    local ROW_GAP = math.floor(10 * ind_scale + 0.5)
    local CONF_ROW_GAP = math.floor(12 * ind_scale + 0.5)

    local sw, sh = render.screen_size():unpack()
    local cx = sw * 0.5 + INDICATOR_X_OFFSET + (_anim.scope_offset or 0)
    local cy = sh * 0.5
    local accent = get_indicator_accent()
    local row_alpha = alpha * clamp(_anim.target_alpha or 0, 0, 1)
    local row_y_add = _anim.target_slide or 0
    local white  = alpha_mod(C.white, row_alpha)
    local title_col = alpha_mod(accent, alpha)
    if style_minimal then
        local mini_alpha = _has_target and row_alpha or (alpha * 0.42)
        if mini_alpha > 0.02 then
            local raw_pct = _conf_pct
            if raw_pct < 0 then
                _anim.conf_value = lerp(_anim.conf_value or 0, 0, ft * 8)
            else
                _anim.conf_value = lerp(_anim.conf_value or raw_pct, raw_pct, ft * 5.5)
            end
            local shown_pct = raw_pct < 0 and "--" or tostring(math.floor((_anim.conf_value or raw_pct) + 0.5))
            local pct_str = shown_pct .. "%"
            local pct_col
            if raw_pct < 0 then pct_col = alpha_mod(C.na, mini_alpha)
            elseif raw_pct >= 70 then pct_col = alpha_mod(C.high, mini_alpha)
            elseif raw_pct >= 45 then pct_col = alpha_mod(C.med, mini_alpha)
            else pct_col = alpha_mod(C.low, mini_alpha) end
            local pct_w = text_size(IND_FONT_CONF, "", pct_str).x
            local gap = 7
            local total_w = DOT_W + gap + pct_w
            local x = cx - total_w * 0.5
            local y = cy + INDICATOR_Y_OFFSET + (style_minimal and (row_y_add * 0.55) or 0)
            local dot_y = y + 5
            draw_soft_rect(vector(x + 1, dot_y + 1), vector(x + DOT_W + 1, dot_y + DOT_W + 1), color(0, 0, 0, math.floor(145 * mini_alpha)), 1)
            draw_soft_rect(vector(x, dot_y), vector(x + DOT_W, dot_y + DOT_W), alpha_mod(accent, mini_alpha * (0.78 + _anim.dot_pulse * 0.18)), 1)
            draw_text(IND_FONT_CONF, vector(x + DOT_W + gap + 1, y + 1), color(0, 0, 0, math.floor(215 * clamp(mini_alpha, 0, 1))), "", pct_str)
            draw_text(IND_FONT_CONF, vector(x + DOT_W + gap, y), pct_col, "", pct_str)
        end
        return
    end
    local title_w = text_size(IND_FONT_TITLE, "", TITLE_TEXT).x
    local x = cx - title_w * 0.5
    local y = cy + INDICATOR_Y_OFFSET
    -- Title dot removed: title is centered directly on cx.
    draw_shadow_text(IND_FONT_TITLE, vector(x, y), title_col, "", TITLE_TEXT, 170)
    y = y + TARGET_GAP_Y
    if show_target and row_alpha > 0.02 then
        local tw = text_size(IND_FONT_LABEL, "", _target_name).x
        draw_shadow_text(IND_FONT_LABEL, vector(cx - tw * 0.5, y + row_y_add), white, "", _target_name, math.floor(170 * clamp(row_alpha, 0, 1)))
        y = y + ROW_GAP
    end
    if show_conf and row_alpha > 0.02 then
        local raw_pct = _conf_pct
        if raw_pct < 0 then
            _anim.conf_value = lerp(_anim.conf_value or 0, 0, ft * 8)
            _anim.bar_width = lerp(_anim.bar_width or 0, 0.08, ft * 8)
        else
            _anim.conf_value = lerp(_anim.conf_value or raw_pct, raw_pct, ft * 5.5)
            _anim.bar_width = lerp(_anim.bar_width or 0, clamp(_anim.conf_value / 100, 0, 1), ft * 7)
        end
        local shown_pct = raw_pct < 0 and "--" or tostring(math.floor(_anim.conf_value + 0.5))
        local pct_str = shown_pct .. "%"
        local pct_w = text_size(IND_FONT_CONF, "", pct_str).x
        local total_w = BAR_W + 6 + pct_w
        local bx = cx - total_w * 0.5
        local by = y + 6
        draw_soft_rect(vector(bx, by + row_y_add), vector(bx + BAR_W, by + row_y_add + BAR_H), alpha_mod(C.na, row_alpha * 0.42), 1)
        local bar_col
        if raw_pct < 0 then bar_col = alpha_mod(C.na, row_alpha)
        elseif raw_pct >= 70 then bar_col = alpha_mod(C.high, row_alpha)
        elseif raw_pct >= 45 then bar_col = alpha_mod(C.med, row_alpha)
        else bar_col = alpha_mod(C.low, row_alpha) end
        local fill_w = math.max((_anim.bar_width or 0) * BAR_W, 1)
        draw_soft_rect(vector(bx, by + row_y_add), vector(bx + fill_w, by + row_y_add + BAR_H), bar_col, 1)
        local px = bx + BAR_W + 6
        draw_text(IND_FONT_CONF, vector(px + 1, y + row_y_add + 1), color(0, 0, 0, math.floor(220 * clamp(row_alpha, 0, 1))), "", pct_str)
        draw_text(IND_FONT_CONF, vector(px, y + row_y_add), bar_col, "", pct_str)
        y = y + CONF_ROW_GAP
    else
        _anim.bar_width = 0
        _anim.conf_value = 0
    end
    if show_state and row_alpha > 0.02 then
        local side_s = _state_side > 0 and "R" or _state_side < 0 and "L" or "?"
        local state_short
        if not _resolved then state_short = "resolving"
        elseif _state_locked then state_short = "locked · " .. side_s .. " / " .. _state_hb
        elseif _state_jitter then state_short = "jitter · " .. side_s .. " / " .. _state_hb
        elseif _state_micro then state_short = "micro · " .. side_s .. " / " .. _state_hb
        else state_short = side_s .. " / " .. _state_hb end
        local dim = alpha_mod(accent, row_alpha * 0.82)
        local sw2 = text_size(IND_FONT_SMALL, "", state_short).x
        draw_shadow_text(IND_FONT_SMALL, vector(cx - sw2 * 0.5, y + row_y_add - 1), dim, "", state_short, math.floor(155 * clamp(row_alpha, 0, 1)))
    end
end


--------------------------------------------------------------------------------
-- Shiny Resolver Watermark
--------------------------------------------------------------------------------
local WM_VERSION_TEXT = "10.3b"
local WM_PAD_X = 8
local WM_PAD_Y = 5
local WM_ICON_TEXT = "✦"
local WM_ICON_GAP = 7
local WM_SCREEN_PAD = 10

local _wm = {
    alpha = 0,
    breath = 0,
    fps = 0,
    last_fps_update = 0,
    drag = false,
    drag_dx = 0,
    drag_dy = 0,
    base_x = 0,
    base_y = 0,
    rect_x = 0,
    rect_y = 0,
    rect_w = 0,
    rect_h = 0,
    input_blocked = false,
    grid_alpha = 0,
}

local function get_local_name_short()
    local lp = entity.get_local_player()
    local name = lp and get_name(lp) or "user"
    if #name > 14 then name = name:sub(1, 12) .. ".." end
    return name
end

function wm_ping_text()
    local latency = nil

    local ok, v = pcall(function() return network.get_latency() end)
    if ok and tonumber(v) then latency = tonumber(v) end

    if latency == nil then
        ok, v = pcall(function() return utils.get_latency() end)
        if ok and tonumber(v) then latency = tonumber(v) end
    end

    if latency == nil then
        ok, v = pcall(function() return engine.get_latency() end)
        if ok and tonumber(v) then latency = tonumber(v) end
    end

    if latency == nil then
        ok, v = pcall(function() return client.latency() end)
        if ok and tonumber(v) then latency = tonumber(v) end
    end

    if latency == nil then return "0ms" end
    if latency < 1 then latency = latency * 1000 end
    return tostring(math.floor(latency + 0.5)) .. "ms"
end

function wm_time_text()
    -- Robust local clock: different NL builds expose time differently, so try a few safe paths.
    local ok, value = pcall(function() return os and os.date and os.date("%H:%M") end)
    if ok and value and tostring(value) ~= "" then
        return tostring(value)
    end

    local h, m

    ok, value = pcall(function() return common and common.get_system_time and common.get_system_time() end)
    if ok and value then
        if type(value) == "table" then
            h = value.hour or value.hours or value.h
            m = value.min or value.minute or value.minutes or value.m
        elseif type(value) == "number" then
            -- Some APIs return seconds since midnight.
            h = math.floor(value / 3600) % 24
            m = math.floor(value / 60) % 60
        end
    end

    if not h or not m then
        local ok2, a, b = pcall(function()
            if client and client.system_time then return client.system_time() end
            if utils and utils.get_system_time then return utils.get_system_time() end
        end)
        if ok2 then
            h, m = a, b
        end
    end

    h, m = tonumber(h), tonumber(m)
    if h and m then
        return string.format("%02d:%02d", h % 24, m % 60)
    end

    return "--:--"
end

function wm_tickrate_text()
    local ti = tonumber(globals.tickinterval) or 0
    if ti <= 0 then return "0t" end
    return tostring(math.floor((1 / ti) + 0.5)) .. "t"
end

function wm_map_text()
    local map = nil

    local ok, v = pcall(function() return globals.mapname end)
    if ok and v and tostring(v) ~= "" then map = tostring(v) end

    if map == nil then
        ok, v = pcall(function() return engine.get_level_name() end)
        if ok and v and tostring(v) ~= "" then map = tostring(v) end
    end

    if map == nil then
        ok, v = pcall(function() return engine.get_map_name() end)
        if ok and v and tostring(v) ~= "" then map = tostring(v) end
    end

    if map == nil then return "map" end
    map = map:gsub("^maps/", ""):gsub("%.vpk$", ""):gsub("%.bsp$", "")
    if #map > 18 then map = map:sub(1, 16) .. ".." end
    return map
end

WM_FONT_CACHE = WM_FONT_CACHE or {}

function wm_load_style_font(style, size)
    style = tostring(style or "Bold")
    size = tonumber(size) or 12

    local key = style .. ":" .. tostring(size)
    if WM_FONT_CACHE[key] then
        return WM_FONT_CACHE[key]
    end

    local flags = "a"
    local fonts

    if style == "Console" then
        fonts = {"Consolas", "Lucida Console", "Courier New", "Tahoma", "Verdana"}
    elseif style == "Small" then
        fonts = {"Small Fonts", "Tahoma", "Verdana", "Arial"}
    elseif style == "Default" then
        fonts = {"Verdana", "Tahoma", "Arial", "Small Fonts"}
    else
        -- Bold: tenta fonte/flag em negrito primeiro, depois fallback normal.
        flags = "ab"
        fonts = {"Verdana", "Tahoma", "Arial", "Arial Bold", "Trebuchet MS"}
    end

    for i = 1, #fonts do
        local ok, font = pcall(function()
            return render.load_font(fonts[i], vector(size, size), flags)
        end)
        if ok and font then
            WM_FONT_CACHE[key] = font
            return font
        end
    end

    -- Se a build não aceitar flag bold, tenta a mesma lista com antialias normal.
    if flags ~= "a" then
        for i = 1, #fonts do
            local ok, font = pcall(function()
                return render.load_font(fonts[i], vector(size, size), "a")
            end)
            if ok and font then
                WM_FONT_CACHE[key] = font
                return font
            end
        end
    end

    WM_FONT_CACHE[key] = FONT_WM_MED or FONT_LABEL
    return WM_FONT_CACHE[key]
end

local function wm_font()
    local dpi = tostring(wm_font_size and wm_font_size:get() or "100%")
    local size = dpi == "75%" and 10 or dpi == "125%" and 14 or 12
    local style = tostring(wm_font_style and wm_font_style:get() or "Bold")
    return wm_load_style_font(style, size)
end

function ind_dpi_value()
    local dpi = tostring(ind_dpi_scale and ind_dpi_scale:get() or "100%")
    if dpi == "75%" then return 0.75 end
    if dpi == "125%" then return 1.25 end
    return 1.0
end

-- Indicator font selector: uses the same native-style font presets as the watermark.
function ind_get_font(kind)
    local style = tostring(ind_font_style and ind_font_style:get() or "Bold")
    local scale = ind_dpi_value and ind_dpi_value() or 1.0
    local function scaled(size)
        return math.max(7, math.floor(size * scale + 0.5))
    end

    if kind == "title" then
        return wm_load_style_font(style, scaled(11))
    elseif kind == "label" then
        return wm_load_style_font(style, scaled(10))
    elseif kind == "small" then
        return wm_load_style_font(style, scaled(9))
    elseif kind == "conf" then
        return wm_load_style_font(style, scaled(13))
    elseif kind == "icon" then
        return wm_load_style_font(style, scaled(13))
    end

    return wm_load_style_font(style, scaled(10))
end

local function wm_menu_open()
    local ok, a = pcall(function() return ui.get_alpha() end)
    if ok and tonumber(a) then return tonumber(a) > 0.05 end

    ok, a = pcall(function() return ui.get_menu_alpha() end)
    if ok and tonumber(a) then return tonumber(a) > 0.05 end

    ok, a = pcall(function() return ui.is_open() end)
    if ok and a ~= nil then return a == true end

    return false
end

local function wm_mouse_pos()
    local ok, p = pcall(function() return ui.get_mouse_position() end)
    if ok and p then return p end

    ok, p = pcall(function() return render.mouse_position() end)
    if ok and p then return p end

    ok, p = pcall(function() return input.get_mouse_pos() end)
    if ok and p then return p end

    return nil
end

local function wm_mouse_down()
    local ok, v = pcall(function() return input.is_key_down(1) end)
    if ok and v ~= nil then return v == true end

    ok, v = pcall(function() return input.is_key_pressed(1) end)
    if ok and v ~= nil then return v == true end

    ok, v = pcall(function() return common.is_button_down(1) end)
    if ok and v ~= nil then return v == true end

    ok, v = pcall(function() return utils.key_state(1) end)
    if ok and v ~= nil then return v == true end

    return false
end

local function wm_inside(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function wm_snap(v, step)
    step = math.max(tonumber(step) or 1, 1)
    return math.floor((v / step) + 0.5) * step
end

local function render_drag_grid(sw, sh, step, alpha)
    step = math.max(tonumber(step) or 8, 2)
    alpha = clamp(alpha or 1, 0, 1)

    local col = color(176, 208, 255, math.floor(18 * alpha))
    local cx = 0
    while cx <= sw do
        draw_soft_rect(vector(cx, 0), vector(cx + 1, sh), col, 0)
        cx = cx + step
    end

    local cy = 0
    while cy <= sh do
        draw_soft_rect(vector(0, cy), vector(sw, cy + 1), col, 0)
        cy = cy + step
    end
end

local function render_drag_dim(sw, sh, alpha)
    alpha = clamp(alpha or 0, 0, 1)
    if alpha <= 0.01 then return end
    draw_soft_rect(vector(0, 0), vector(sw, sh), color(0, 0, 0, math.floor(42 * alpha)), 0)
end

local function render_drag_outline(x, y, w, h, alpha)
    alpha = clamp(alpha or 0, 0, 1)
    if alpha <= 0.01 then return end
    local col = color(176, 208, 255, math.floor(150 * alpha))
    draw_soft_rect(vector(x - 1, y - 1), vector(x + w + 1, y), col, 0)
    draw_soft_rect(vector(x - 1, y + h), vector(x + w + 1, y + h + 1), col, 0)
    draw_soft_rect(vector(x - 1, y - 1), vector(x, y + h + 1), col, 0)
    draw_soft_rect(vector(x + w, y - 1), vector(x + w + 1, y + h + 1), col, 0)
end

local function render_wm_grid(sw, sh, step, alpha)
    local ft = clamp(globals.frametime or 0, 0, 0.05)
    local target = (_wm.drag == true) and 1 or 0
    _wm.grid_alpha = lerp(_wm.grid_alpha or 0, target, ft * 12)
    if (_wm.grid_alpha or 0) <= 0.01 then return end
    render_drag_grid(sw, sh, step, (alpha or 1) * (_wm.grid_alpha or 0))
end

local function render_shiny_resolver_watermark()
    local ft = clamp(globals.frametime, 0, 0.05)
    local rt = globals.realtime

    if not wm_enable:get() then
        _wm.alpha = lerp(_wm.alpha or 0, 0, ft * 10)
        if (_wm.alpha or 0) < 0.01 then return end
    else
        _wm.alpha = lerp(_wm.alpha or 0, 1, ft * 9)
    end

    local alpha = clamp(_wm.alpha or 0, 0, 1)
    _wm.breath = 0.5 + math.sin(rt * 1.45) * 0.5

    if wm_show_fps:get() and (rt - (_wm.last_fps_update or 0)) > 0.22 then
        local fps = globals.frametime > 0 and math.floor(1 / globals.frametime + 0.5) or 0
        _wm.fps = fps
        _wm.last_fps_update = rt
    end

    local font = wm_font()
    local accent = lerp_color(C.blue, C.purple, _wm.breath)
    local parts = {"shiny resolver", WM_VERSION_TEXT}

    if wm_show_fps:get() then
        table.insert(parts, tostring(_wm.fps or 0) .. " fps")
    end

    if wm_show_ping:get() then
        table.insert(parts, wm_ping_text())
    end

    if wm_show_tickrate:get() then
        table.insert(parts, wm_tickrate_text())
    end

    if wm_show_time:get() then
        table.insert(parts, wm_time_text())
    end


    if wm_show_user:get() then
        table.insert(parts, get_local_name_short())
    end

    local text = table.concat(parts, "  ·  ")
    local icon_text = WM_ICON_TEXT
    local text_size_v = text_size(font, "", text)
    local icon_size_v = text_size(font, "", icon_text)
    local text_w = text_size_v.x
    local text_h = math.max(text_size_v.y, 10)
    local icon_w = math.max(icon_size_v.x, 7)
    local total_w = WM_PAD_X * 2 + icon_w + WM_ICON_GAP + text_w
    local total_h = math.max(text_h + WM_PAD_Y * 2, 20)

    local sw, sh = render.screen_size():unpack()
    local pos = tostring(wm_position:get() or "Top Right")
    local base_x
    if pos == "Top Left" then
        base_x = WM_SCREEN_PAD
    else
        base_x = sw - total_w - WM_SCREEN_PAD
    end
    local base_y = WM_SCREEN_PAD + 1

    local x = base_x + (wm_x_offset:get() or 0)
    local y = base_y + (wm_y_offset:get() or 0)

    _wm.rect_x = x
    _wm.rect_y = y
    _wm.rect_w = total_w
    _wm.rect_h = total_h

    local menu_open = wm_menu_open()
    local mouse = wm_mouse_pos()
    local down = wm_mouse_down()
    local can_drag = menu_open and mouse ~= nil

    if can_drag then
        local mx, my = mouse.x or mouse[1] or 0, mouse.y or mouse[2] or 0
        local hovering_wm = wm_inside(mx, my, x, y, total_w, total_h)
        _wm.input_blocked = hovering_wm or (_wm.drag == true)

        if down and not _wm.drag and hovering_wm then
            _wm.drag = true
            _wm.drag_dx = mx - x
            _wm.drag_dy = my - y
        elseif not down then
            _wm.drag = false
        end

        if _wm.drag then
            local nx = mx - (_wm.drag_dx or 0)
            local ny = my - (_wm.drag_dy or 0)

            nx = clamp(nx, 0, sw - total_w)
            ny = clamp(ny, 0, sh - total_h)

            if true then
                local step = 8
                nx = wm_snap(nx, step)
                ny = wm_snap(ny, step)
            end

            wm_x_offset:set(math.floor(nx - base_x + 0.5))
            wm_y_offset:set(math.floor(ny - base_y + 0.5))

            x = nx
            y = ny
        end
    else
        _wm.drag = false
        _wm.input_blocked = false
    end

    render_wm_grid(sw, sh, 8, alpha)
    render_drag_dim(sw, sh, _wm.grid_alpha or 0)

    if wm_background:get() then
        -- Very soft glass line/pill, matching the crosshair indicator without a heavy black box.
        draw_soft_rect(vector(x + 1, y + 1), vector(x + total_w + 1, y + total_h + 1), color(0, 0, 0, math.floor(72 * alpha)), 5)
        draw_soft_rect(vector(x, y), vector(x + total_w, y + total_h), color(12, 16, 24, math.floor(48 * alpha)), 5)
    end

    if menu_open then
        draw_soft_rect(vector(x, y), vector(x + total_w, y + 1), alpha_mod(accent, alpha * 0.72), 1)
    end

    render_drag_outline(x, y, total_w, total_h, _wm.grid_alpha or 0)

    local icon_x = x + WM_PAD_X
    local icon_y = y + total_h * 0.5 - text_h * 0.5
    draw_shadow_text(font, vector(icon_x, icon_y), alpha_mod(accent, alpha * (0.84 + _wm.breath * 0.12)), "", icon_text, math.floor(145 * alpha))

    local tx = icon_x + icon_w + WM_ICON_GAP
    local ty = y + total_h * 0.5 - text_h * 0.5
    draw_shadow_text(font, vector(tx, ty), alpha_mod(accent, alpha * 0.96), "", text, math.floor(155 * alpha))
end

--------------------------------------------------------------------------------
-- Shiny Resolver Notifications
--------------------------------------------------------------------------------
NOTIFY_STATE = NOTIFY_STATE or { items = {}, drag = false, drag_dx = 0, drag_dy = 0, rect_x = 0, rect_y = 0, rect_w = 0, rect_h = 0, input_blocked = false, grid_alpha = 0 }

function notify_dpi_value()
    local dpi = tostring(notify_dpi and notify_dpi:get() or "75%")
    if dpi == "75%" then return 0.75 end
    if dpi == "125%" then return 1.25 end
    if dpi == "150%" then return 1.50 end
    return 1.0
end

function notify_font(kind)
    local style = tostring(notify_font_style and notify_font_style:get() or "Bold")
    local scale = notify_dpi_value()
    -- Compact single-line layout, closer to Neverlose/Hysteria notifications.
    local base = kind == "small" and 9 or kind == "title" and 13 or 11
    return wm_load_style_font(style, math.max(7, math.floor(base * scale + 0.5)))
end

function notify_event_selected(name)
    name = tostring(name or "")

    if notify_events then
        local ok, selected = pcall(function() return notify_events:get() end)
        if ok and selected ~= nil then
            if type(selected) == "table" then
                for k, v in pairs(selected) do
                    if type(k) == "string" and k == name and v then return true end
                    if type(v) == "string" and v == name then return true end
                    if type(v) == "table" then
                        for _, vv in pairs(v) do
                            if tostring(vv) == name then return true end
                        end
                    end
                end
            elseif tostring(selected) == name then
                return true
            end
        end
        return false
    end

    if name == "Hit" then return notify_hit and notify_hit:get() end
    if name == "Miss" then return notify_miss and notify_miss:get() end
    if name == "Kill" then return notify_kill and notify_kill:get() end
    if name == "Damage Taken" then return notify_damage_taken and notify_damage_taken:get() end
    return false
end

function notify_enabled_for(kind)
    if not notify_enable or not notify_enable:get() then return false end
    if kind == "hit" then return notify_event_selected("Hit") end
    if kind == "miss" then return notify_event_selected("Miss") end
    if kind == "kill" then return notify_event_selected("Kill") end
    if kind == "hurt" then return notify_event_selected("Damage Taken") end
    return false
end

function notify_push(kind, target_name, detail)
    if not notify_enabled_for(kind) then return end

    target_name = tostring(target_name or "unknown")
    if #target_name > 18 then target_name = target_name:sub(1, 16) .. ".." end

    local title
    if kind == "hit" then
        title = "hit " .. target_name
        detail = detail and tostring(detail) or "confirmed"
    elseif kind == "miss" then
        title = "miss " .. target_name
        detail = detail and tostring(detail) or "resolver"
    elseif kind == "kill" then
        title = "kill " .. target_name
        detail = detail and tostring(detail) or "resolved"
    elseif kind == "hurt" then
        title = "hurt by " .. target_name
        detail = detail and tostring(detail) or "damage taken"
    else
        title = target_name
        detail = tostring(detail or "")
    end

    table.insert(NOTIFY_STATE.items, 1, {
        kind = kind,
        title = title,
        detail = detail,
        time = globals.realtime or 0,
        life = math.max(1, math.min(6, n(notify_duration and notify_duration:get(), 3)))
    })

    while #NOTIFY_STATE.items > 6 do
        table.remove(NOTIFY_STATE.items)
    end
end

function notify_kind_color(kind, breath)
    if kind == "hit" then
        return lerp_color(C.high, C.blue, (breath or 0) * 0.45)
    elseif kind == "miss" then
        return lerp_color(C.low, C.warn, (breath or 0) * 0.55)
    elseif kind == "kill" then
        return lerp_color(C.purple, C.pink, (breath or 0) * 0.35)
    elseif kind == "hurt" then
        return lerp_color(C.warn, C.low, (breath or 0) * 0.45)
    end
    return lerp_color(C.blue, C.purple, breath or 0)
end

function notify_get_stack_rect(render_items, font_title, font_small, scale, sw, sh)
    -- Compact per-item pills: stack is used for positioning/drag only; each background follows its own text width.
    local pad_x = math.floor(9 * scale + 0.5)
    local pad_y = math.floor(3 * scale + 0.5)
    local row_h = math.max(15, math.floor(21 * scale + 0.5))
    local gap = math.max(3, math.floor(4 * scale + 0.5))
    local screen_pad = 14
    local min_w = math.floor(205 * scale + 0.5)
    local max_w = min_w

    for i = 1, #render_items do
        local item = render_items[i]
        local icon = item.kind == "hit" and "✓" or item.kind == "miss" and "×" or item.kind == "kill" and "✦" or item.kind == "hurt" and "!" or "•"
        local title = tostring(item.title or "")
        local detail = tostring(item.detail or "")
        local line = icon .. "  " .. title .. (detail ~= "" and ("  ·  " .. detail) or "")
        local tw = text_size(font_title, "", line).x
        local w = tw + pad_x * 2
        if w > max_w then max_w = w end
    end

    local stack_h = (#render_items * row_h) + math.max(#render_items - 1, 0) * gap
    local pos = tostring(notify_position and notify_position:get() or "Bottom Mid")
    local base_x
    if pos == "Bottom Mid" then
        base_x = (sw * 0.5) - (max_w * 0.5)
    elseif pos == "Top Left" or pos == "Bottom Left" then
        base_x = screen_pad
    else
        base_x = sw - screen_pad - max_w
    end
    local base_y = (pos == "Bottom Mid" or pos == "Bottom Left" or pos == "Bottom Right") and (sh - screen_pad - stack_h) or screen_pad
    local x = base_x + (notify_x_offset and notify_x_offset:get() or 0)
    local y = base_y + (notify_y_offset and notify_y_offset:get() or 0)
    return x, y, max_w, stack_h, base_x, base_y, row_h, gap, pad_x, pad_y
end

function render_shiny_notifications()
    if not notify_enable or not notify_enable:get() then
        NOTIFY_STATE.items = {}
        NOTIFY_STATE.drag = false
        NOTIFY_STATE.input_blocked = false
        return
    end

    local rt = globals.realtime or 0
    local menu_open = wm_menu_open and wm_menu_open() or false
    local ft = clamp(globals.frametime or 0, 0, 0.05)
    NOTIFY_STATE.preview_alpha = lerp(NOTIFY_STATE.preview_alpha or 0, menu_open and 1 or 0, ft * 8)
    local preview_alpha = NOTIFY_STATE.preview_alpha or 0
    local items = NOTIFY_STATE.items or {}

    for i = #items, 1, -1 do
        local item = items[i]
        local age = rt - (item.time or 0)
        local life = item.life or 3
        if age > life then
            table.remove(items, i)
        end
    end

    local render_items = items
    if (#render_items == 0) and preview_alpha > 0.02 then
        render_items = {}
        local base_t = rt - 0.18
        if notify_enabled_for("hit") then
            table.insert(render_items, { kind = "hit", title = "hit enemy", detail = "head · 72 dmg", time = base_t, life = 999, preview = true, preview_alpha = preview_alpha })
        end
        if notify_enabled_for("miss") then
            table.insert(render_items, { kind = "miss", title = "miss enemy", detail = "resolver", time = base_t, life = 999, preview = true, preview_alpha = preview_alpha })
        end
        if notify_enabled_for("kill") then
            table.insert(render_items, { kind = "kill", title = "kill enemy", detail = "head · 100 dmg", time = base_t, life = 999, preview = true, preview_alpha = preview_alpha })
        end
        if notify_enabled_for("hurt") then
            table.insert(render_items, { kind = "hurt", title = "hurt by enemy", detail = "chest · 32 dmg", time = base_t, life = 999, preview = true, preview_alpha = preview_alpha })
        end
    end

    if not render_items or #render_items == 0 then
        NOTIFY_STATE.input_blocked = false
        return
    end

    local scale = notify_dpi_value()
    local font_title = notify_font("title")
    local font_small = notify_font("small")
    local sw, sh = render.screen_size():unpack()
    local breath = 0.5 + math.sin(rt * 1.6) * 0.5
    local x, y, stack_w, stack_h, base_x, base_y, row_h, gap, pad_x, pad_y = notify_get_stack_rect(render_items, font_title, font_small, scale, sw, sh)

    local mouse = wm_mouse_pos and wm_mouse_pos() or nil
    local down = wm_mouse_down and wm_mouse_down() or false
    local can_drag = menu_open and mouse ~= nil

    if can_drag then
        local mx, my = mouse.x or mouse[1] or 0, mouse.y or mouse[2] or 0
        local hovering = wm_inside(mx, my, x, y, stack_w, stack_h)
        NOTIFY_STATE.input_blocked = hovering or (NOTIFY_STATE.drag == true)

        if down and not NOTIFY_STATE.drag and hovering then
            NOTIFY_STATE.drag = true
            NOTIFY_STATE.drag_dx = mx - x
            NOTIFY_STATE.drag_dy = my - y
        elseif not down then
            NOTIFY_STATE.drag = false
        end

        if NOTIFY_STATE.drag then
            local nx = mx - (NOTIFY_STATE.drag_dx or 0)
            local ny = my - (NOTIFY_STATE.drag_dy or 0)
            nx = clamp(nx, 0, sw - stack_w)
            ny = clamp(ny, 0, sh - stack_h)
            if true then
                local step = 8
                nx = wm_snap(nx, step)
                ny = wm_snap(ny, step)
            end
            notify_x_offset:set(math.floor(nx - base_x + 0.5))
            notify_y_offset:set(math.floor(ny - base_y + 0.5))
            x = nx
            y = ny
        end
    else
        NOTIFY_STATE.drag = false
        NOTIFY_STATE.input_blocked = false
    end

    NOTIFY_STATE.rect_x = x
    NOTIFY_STATE.rect_y = y
    NOTIFY_STATE.rect_w = stack_w
    NOTIFY_STATE.rect_h = stack_h

    local grid_target = (NOTIFY_STATE.drag == true) and 1 or 0
    NOTIFY_STATE.grid_alpha = lerp(NOTIFY_STATE.grid_alpha or 0, grid_target, clamp(globals.frametime or 0, 0, 0.05) * 12)
    if (NOTIFY_STATE.grid_alpha or 0) > 0.01 then
        render_drag_grid(sw, sh, 8, NOTIFY_STATE.grid_alpha or 0)
        render_drag_dim(sw, sh, NOTIFY_STATE.grid_alpha or 0)
        render_drag_outline(x, y, stack_w, stack_h, NOTIFY_STATE.grid_alpha or 0)
    end

    local anim = tostring(notify_animation and notify_animation:get() or "Rise")
    local pos = tostring(notify_position and notify_position:get() or "Bottom Mid")
    local from_right = (pos == "Top Right" or pos == "Bottom Right")

    for i = 1, #render_items do
        local item = render_items[i]
        local age = rt - (item.time or 0)
        local life = item.life or 3
        local in_a = math.min(age * 2.55, 1)
        local out_a = math.min((life - age) * 2.25, 1)
        local alpha = clamp(math.min(in_a, out_a), 0, 1)
        if item.preview then
            alpha = alpha * clamp(item.preview_alpha or preview_alpha or 1, 0, 1)
        end

        if alpha > 0.01 then
            local accent = notify_kind_color(item.kind, breath)
            local title = tostring(item.title or "")
            local detail = tostring(item.detail or "")
            local icon = item.kind == "hit" and "✓" or item.kind == "miss" and "×" or item.kind == "kill" and "✦" or item.kind == "hurt" and "!" or "•"
            local line = icon .. "  " .. title .. (detail ~= "" and ("  ·  " .. detail) or "")
            local tw_v = text_size(font_title, "", line)
            local tw = tw_v.x
            local w = tw + pad_x * 2
            local h = row_h
            local idx_offset = (i - 1) * (h + gap)
            local center_x = x + stack_w * 0.5
            local ix = center_x - w * 0.5
            local iy = y + idx_offset
            local slide = (1 - alpha) * 13 * scale

            if anim == "Slide" then
                ix = ix + (from_right and slide or -slide)
            elseif anim == "Rise" then
                iy = iy + slide
            elseif anim == "Pop" then
                local pop = (1 - alpha) * 5 * scale
                ix = ix + pop
                iy = iy + pop * 0.4
            end

            -- Background follows the current text width instead of forcing every row
            -- to share the largest notification width. This keeps short messages compact
            -- while long nicknames still expand cleanly around centered text.
            if notify_background and notify_background:get() then
                draw_soft_rect(vector(ix + 1, iy + 1), vector(ix + w + 1, iy + h + 1), color(0, 0, 0, math.floor(65 * alpha)), 5)
                draw_soft_rect(vector(ix, iy), vector(ix + w, iy + h), color(12, 16, 24, math.floor(45 * alpha)), 5)
            end

            if menu_open and i == 1 then
                draw_soft_rect(vector(ix, iy), vector(ix + w, iy + 1), alpha_mod(accent, alpha * 0.60), 1)
            end

            local line_h = tw_v.y
            local text_x = ix + (w - tw) * 0.5
            local text_y = iy + h * 0.5 - line_h * 0.5
            draw_shadow_text(font_title, vector(text_x, text_y), alpha_mod(accent, alpha * 0.96), "", line, math.floor(145 * alpha))
        end
    end
end

local HITBOX_HEAD  = 0
local HITBOX_CHEST = 3

local function ensure_state(idx)
    if not misses[idx]        then misses[idx]        = 0 end
    if not brute_seq[idx]     then brute_seq[idx]     = 1 end
    if not side_history[idx]  then
        side_history[idx] = { hits_left = 0, hits_right = 0, last_side = 0 }
    end
    if not lby_history[idx]   then
        lby_history[idx] = { last_lby = 0, locked_side = 0 }
    end
    if not jitter_buf[idx]    then jitter_buf[idx]    = {} end
    if not desync_history[idx] then desync_history[idx] = {} end
    if not consec_hits[idx]   then consec_hits[idx]   = { side = 0, count = 0 } end
    if not duck_state[idx]    then duck_state[idx]    = { was_duck = false, changed_tick = 0 } end
end

local function push_jitter(idx, yaw)
    local buf = jitter_buf[idx]
    table.insert(buf, n(yaw))
    if #buf > JITTER_BUF_SIZE then table.remove(buf, 1) end
end

local function detect_jitter(idx)
    local buf = jitter_buf[idx]
    if #buf < 4 then return false end
    local flips = 0
    for i = 2, #buf do
        if math.abs(math.angle_diff(buf[i], buf[i-1])) > 20 then
            flips = flips + 1
        end
    end
    return flips >= 2
end

local function history_side(idx)
    local h = side_history[idx]
    if not h then return 0 end
    if h.hits_right > h.hits_left + 1 then return  1 end
    if h.hits_left  > h.hits_right + 1 then return -1 end
    return 0
end

local function lby_side(idx, animstate)
    if not detection_enabled() or not lby_resolver:get() then return 0 end
    local lby = anim(animstate,
        "m_flLowerBodyYawTarget", "lby", "flGoalFeetYaw", "goal_feet_yaw")
    if lby == 0 then return 0 end
    local h    = lby_history[idx]
    local diff = math.abs(math.angle_diff(lby, h.last_lby))
    if diff > 35 then
        local eye = anim(animstate, "eye_yaw", "flEyeYaw")
        local d   = math.angle_diff(eye, lby)
        h.locked_side = d > 0 and -1 or 1
    end
    h.last_lby = lby
    return h.locked_side
end

-- Desync History: suaviza o delta fazendo média dos últimos N frames.
-- Evita que um spike de 1 tick mude o strength bruscamente.
local function push_desync_history(idx, delta_val)
    local h = desync_history[idx]
    table.insert(h, n(delta_val))
    if #h > DESYNC_HIST_SIZE then table.remove(h, 1) end
end

local function smooth_delta(idx, raw_delta)
    if not detection_enabled() or not desync_history_en:get() then return raw_delta end
    local h = desync_history[idx]
    if #h == 0 then return raw_delta end
    local sum = 0
    for i = 1, #h do sum = sum + h[i] end
    -- Média ponderada: frames mais recentes têm peso maior
    local weighted = 0
    local total_w  = 0
    for i = 1, #h do
        local w = i  -- peso crescente
        weighted = weighted + h[i] * w
        total_w  = total_w  + w
    end
    return total_w > 0 and (weighted / total_w) or raw_delta
end

-- Duck Resolver: detecta mudança de crouch e ajusta strength.
-- Quando o alvo levanta do duck o animstate reseta o LBY — o desync muda.
local function get_duck_factor(ent, idx)
    if not detection_enabled() or not duck_resolver:get() then return 1.0 end

    local duck_amt = n(safe_call(function() return ent.m_flDuckAmount end))
    local is_duck  = duck_amt > 0.5
    local ds       = duck_state[idx]
    local cur_tick = globals.tickcount or 0

    if is_duck ~= ds.was_duck then
        ds.was_duck    = is_duck
        ds.changed_tick = cur_tick
    end

    local ticks_since = cur_tick - (ds.changed_tick or 0)

    if is_duck then
        -- Agachado: desync é menor porque o corpo fica mais alinhado
        return 0.75
    elseif ticks_since < 8 then
        -- Acabou de levantar: LBY reseta, desync instável por ~8 ticks
        -- Reduz strength pra não over-corrigir durante a transição
        return 0.55 + (ticks_since / 8) * 0.45
    end

    return 1.0
end

-- Move Direction Resolver: quando o alvo está strafe para um lado,
-- o desync tende a ir para o lado oposto ao movimento.
-- Usa a direção do velocity em relação ao eye_yaw para inferir o lado.
local function move_direction_side(ent, eye_yaw)
    if not detection_enabled() or not move_resolver:get() then return 0 end

    local vel = safe_call(function() return ent.m_vecVelocity end)
    if not vel then return 0 end

    local vx = n(safe_call(function() return vel.x end))
    local vy = n(safe_call(function() return vel.y end))
    local speed = math.sqrt(vx*vx + vy*vy)
    if speed < 20 then return 0 end  -- parado/quase parado, sem info útil

    -- Ângulo do velocity no mundo
    local move_yaw = math.deg(math.atan2(vy, vx))
    -- Diferença entre direção do movimento e onde o player está olhando
    local rel = math.angle_diff(move_yaw, n(eye_yaw))

    -- Se movendo para a direita relativa ao eye → desync tende à esquerda
    -- Se movendo para a esquerda relativa ao eye → desync tende à direita
    if rel > 20 and rel < 160 then
        return -1  -- strafing right → desync left
    elseif rel < -20 and rel > -160 then
        return 1   -- strafing left  → desync right
    end

    return 0  -- movimento frontal/traseiro, sem info de lado
end

-- Consecutive Hit Lock: quando acerta o mesmo lado 2x seguidas, trava.
local function update_consec_hits(idx, side)
    local ch = consec_hits[idx]
    if side == 0 then return end
    if side == ch.side then
        ch.count = ch.count + 1
    else
        ch.side  = side
        ch.count = 1
    end
end

local function consec_locked_side(idx)
    if not detection_enabled() or not consec_lock:get() then return 0 end
    local ch = consec_hits[idx]
    if ch and ch.count >= 2 then return ch.side end
    return 0
end

--------------------------------------------------------------------------------
-- Hitbox selection
--------------------------------------------------------------------------------

-- Retorna o HP atual do inimigo de forma segura.
local function get_hp(ent)
    return n(safe_call(function() return ent.m_iHealth end))
end

-- Retorna o armor do inimigo (0 se sem armor).
local function get_armor(ent)
    return n(safe_call(function() return ent.m_ArmorValue end))
end

-- Calcula o dano estimado que a arma atual do local player faz no chest/body.
-- Usa os valores reais de damage + falloff quando disponível,
-- e aplica redução de armor se o alvo tiver (CS2: 0.5 penetration no body sem kevlar).
local ARMOR_REDUCTION = 0.5   -- body sem helmet, armor normal
local function estimate_body_damage(ent)
    local lp = safe_call(function() return entity.get_local_player() end)
    if not lp then return 0 end

    local wpn = safe_call(function() return lp:get_player_weapon() end)
    if not wpn then return 0 end

    -- Tenta pegar damage da arma diretamente
    local dmg = n(safe_call(function() return wpn.m_flDamage end))
              or n(safe_call(function() return wpn["m_flDamage"] end))

    -- Fallback: tabela de dano aproximado por weapon classname para as armas mais comuns.
    -- Esse fallback é melhor que 0 quando a propriedade não está exposta.
    if dmg <= 0 then
        local wname = tostring(safe_call(function() return wpn:get_name() end) or "")
        local dmg_table = {
            ["weapon_awp"]       = 115,
            ["weapon_ak47"]      = 36,
            ["weapon_m4a1"]      = 33,
            ["weapon_m4a1_silencer"] = 33,
            ["weapon_deagle"]    = 53,
            ["weapon_ssg08"]     = 88,
            ["weapon_sg553"]     = 30,
            ["weapon_famas"]     = 30,
            ["weapon_galil"]     = 30,
            ["weapon_aug"]       = 28,
            ["weapon_glock"]     = 28,
            ["weapon_usp_silencer"] = 35,
            ["weapon_p250"]      = 38,
            ["weapon_five_seven"] = 32,
            ["weapon_tec9"]      = 33,
        }
        dmg = dmg_table[wname] or 30
    end

    -- Aplica redução de armor se o alvo tiver e a opção estiver ligada
    if baim_armor_check:get() then
        local armor = get_armor(ent)
        if armor > 0 then
            dmg = dmg * ARMOR_REDUCTION
        end
    end

    return math.floor(dmg)
end

local function should_force_baim(ent, idx)
    if not force_baim:get() then return false end

    local hp = get_hp(ent)
    if hp <= 0 then return false end

    local threshold = n(baim_min_damage:get(), 95)
    local estimated = estimate_body_damage(ent)

    -- Se o dano estimado no body >= HP do alvo, o chest/body já mata: força baim.
    return estimated >= hp and hp <= threshold
end

local function get_preferred_hitbox(idx, ent)
    -- Force Baim Lethal tem prioridade sobre qualquer outra lógica de hitbox.
    if ent and should_force_baim(ent, idx) then
        return HITBOX_CHEST
    end

    if not hitbox_select:get() then return HITBOX_CHEST end
    local data = cache[idx]
    if not data then return HITBOX_CHEST end
    local vel_ok    = n(data.velocity) < n(head_vel_limit:get(), 120)
    local grnd_ok   = data.on_ground
    local jitter_ok = not data.jitter
    local micro_ok  = not data.micro
    if head_conf_only:get() then
        local confident = data.lby_locked or history_side(idx) ~= 0
        if not confident then return HITBOX_CHEST end
    end
    if vel_ok and grnd_ok and jitter_ok and micro_ok then
        return HITBOX_HEAD
    end
    return HITBOX_CHEST
end

--------------------------------------------------------------------------------
-- Core resolve
--------------------------------------------------------------------------------
-- Thresholds de delta:
--   MICRO  (0°  – 0.35°): sem desync real → aplica eye_yaw direto (zero offset)
--                          exceto se tiver misses acumulados, aí brute com step suave
--   SMALL  (0.35° – 8°):  desync pequeno → strength proporcional ao delta
--   NORMAL (> 8°):        desync completo → pipeline normal adaptive/LBY/history
local MICRO_MAX = MICRO_ANGLE_MAX   -- 0.35
local SMALL_MAX = 8.0

local function resolve_entity(ent, mode_override)
    local idx = get_index(ent)
    if not idx then return "Invalid" end

    ensure_state(idx)

    local animstate = get_animstate(ent)
    if not animstate then return "No Animstate" end

    local eye_yaw   = anim(animstate, "eye_yaw",       "flEyeYaw")
    local feet_yaw  = anim(animstate, "goal_feet_yaw", "flGoalFeetYaw")
    local velocity  = get_velocity(ent)
    local on_ground = is_on_ground(ent)

    push_jitter(idx, eye_yaw)

    local raw_delta  = math.angle_diff(eye_yaw, feet_yaw)
    push_desync_history(idx, math.abs(raw_delta))
    -- Usa o delta suavizado para calcular strength, mas o raw para determinar side
    local delta      = raw_delta
    local abs_delta  = math.abs(smooth_delta(idx, math.abs(raw_delta)))
    local mode       = mode_override or "advanced"
    local limit      = n(desync_limit:get(), 60)
    local base_str   = n(body_yaw:get(),     60)
    local brute_thresh = n(brute_after:get(), 1)
    local miss_count = misses[idx]
    local locked     = lby_side(idx, animstate)
    local hist       = history_side(idx)
    local is_jitter  = detection_enabled() and jitter_fix:get() and detect_jitter(idx)
    local duck_factor = get_duck_factor(ent, idx)
    local move_side   = move_direction_side(ent, eye_yaw)
    local consec_side = consec_locked_side(idx)

    -- ── Classificação do delta ──────────────────────────────────────────────
    local is_micro = abs_delta <= MICRO_MAX
    local is_small = (not is_micro) and abs_delta < SMALL_MAX

    -- ── MICRO path ──────────────────────────────────────────────────────────
    -- Delta quase zero = não há desync para corrigir.
    -- Sem misses: aplica eye_yaw puro (qualquer offset piora).
    -- Com misses: houve algo errado — brute com step conservador sobre eye_yaw.
    if is_micro then
        local final_yaw
        local applied_strength = 0
        local applied_side     = 0

        if miss_count == 0 then
            -- Nenhum miss anterior: alvo sem desync real, vai direto.
            final_yaw = normalize_yaw(eye_yaw)
        else
            -- Misses acumulados em micro: provavelmente fakelag/slowwalk com
            -- micro-desync real. Brute com step pequeno baseado em miss_count.
            -- Usa no máximo 35% do limit para não over-corrigir.
            local brute_mult = BRUTE_OFFSETS[brute_seq[idx]] or 1.0
            local step = math.clamp(miss_count * 3.5, 2.0, limit * 0.35)
            applied_side = brute_seq[idx] % 2 == 0 and 1 or -1
            if locked ~= 0 then applied_side = locked
            elseif hist ~= 0 then applied_side = hist end
            applied_strength = step * math.abs(brute_mult)
            if brute_mult < 0 then applied_side = -applied_side end
            final_yaw = normalize_yaw(eye_yaw + applied_strength * applied_side)
        end

        pcall(function() animstate.goal_feet_yaw = final_yaw end)
        pcall(function() animstate.flGoalFeetYaw = final_yaw end)
        side_history[idx].last_side = applied_side
        cache[idx] = {
            mode       = mode,
            eye        = eye_yaw,
            feet       = final_yaw,
            desync     = applied_strength,
            side       = applied_side,
            velocity   = velocity,
            jitter     = is_jitter,
            on_ground  = on_ground,
            lby_locked = locked ~= 0,
            micro      = true,
            hitbox     = HITBOX_CHEST,
        }
        cache[idx].hitbox = get_preferred_hitbox(idx, ent)
        return miss_count == 0 and "Micro-Zero" or "Micro-Brute"
    end

    -- ── SMALL path ──────────────────────────────────────────────────────────
    -- Delta entre 0.35° e 8°: desync existe mas é pequeno.
    -- Curva QUADRÁTICA: ratio = (delta/SMALL_MAX)^2 em vez de linear.
    -- Ex linear: 0.92/8 = 0.115 → strength 6.9° (over-corrige)
    -- Ex quad:   0.115^2 = 0.013 → strength ~0.8° (preciso)
    -- Com misses: interpola quadrático → linear → full conforme miss_count.
    local strength
    if is_small then
        local ratio      = abs_delta / SMALL_MAX          -- 0..1 linear
        local ratio_quad = ratio * ratio                  -- 0..1 quadrático
        local base_prop  = ratio_quad * limit             -- strength quadrático
        if miss_count == 0 then
            strength = math.clamp(base_prop, 0.5, limit * 0.45)
        else
            -- 1 miss → interpola quad→linear (ratio * limit)
            -- 2+ misses → full pipeline (limit)
            local linear_prop = ratio * limit
            local miss_factor = math.clamp(miss_count / 2.0, 0, 1)
            local target_str  = base_prop + (linear_prop - base_prop) * math.min(miss_factor, 1)
                              + (limit - linear_prop) * math.max(miss_factor - 0.5, 0) * 2
            strength = math.clamp(target_str, 0.5, limit)
        end
    else
        -- ── NORMAL path ─────────────────────────────────────────────────────
        -- Delta ≥ 8°: desync completo, pipeline normal.
        strength = base_str
        if mode ~= "default" and detection_enabled() and adaptive:get() then
            if not on_ground and air_resolver:get() then
                strength = strength * 0.60
            elseif velocity < 5 then
                strength = strength * 1.00
            elseif velocity < 80 then
                strength = strength * 0.82
            elseif velocity > 200 then
                strength = strength * 1.05
            end
        end
        strength = math.clamp(strength, 0, limit)
        if is_jitter then strength = strength * 0.72 end
        -- Duck factor: reduz strength quando agachado ou na transição
        strength = strength * duck_factor
        strength = math.clamp(strength, 0, limit)
    end

    -- ── Side detection ──────────────────────────────────────────────────────
    -- Prioridade: consec lock > LBY lock > hit history > move dir > delta sign
    local side
    if consec_side ~= 0 then
        side = consec_side         -- 2+ hits consecutivos: lado confirmado
    elseif locked ~= 0 then
        side = locked              -- LBY snap detectado
    elseif hist ~= 0 then
        side = hist                -- histórico de hits
    elseif move_side ~= 0 then
        side = move_side           -- direção do strafe inferida
    else
        side = delta > 0 and -1 or 1
    end

    -- ── Brute cycle ─────────────────────────────────────────────────────────
    -- Só ativa após brute_thresh misses. Não ativa em small/micro sem misses.
    if brute_force:get() and miss_count >= brute_thresh then
        local mult = BRUTE_OFFSETS[brute_seq[idx]] or 1.0
        if mult < 0 then
            side     = -side
            strength = strength * math.abs(mult)
        else
            strength = strength * mult
        end
        strength = math.clamp(strength, 1.5, limit)
    end

    -- Anti-prediction: offset aleatório pequeno para AA baseado em prediction.
    if anti_prediction:get() then
        strength = strength + math.random(-2, 2)
        strength = math.clamp(strength, 0, limit)
    end

    local final_yaw = normalize_yaw(eye_yaw + strength * side)

    pcall(function() animstate.goal_feet_yaw = final_yaw end)
    pcall(function() animstate.flGoalFeetYaw = final_yaw end)

    side_history[idx].last_side = side

    cache[idx] = {
        mode       = mode,
        eye        = eye_yaw,
        feet       = final_yaw,
        desync     = strength,
        side       = side,
        velocity   = velocity,
        jitter     = is_jitter,
        on_ground  = on_ground,
        lby_locked = locked ~= 0,
        micro      = false,
        hitbox     = HITBOX_CHEST,
    }

    cache[idx].hitbox = get_preferred_hitbox(idx, ent)
    return "Resolved"
end

--------------------------------------------------------------------------------
-- resolver public API
--------------------------------------------------------------------------------
local resolver = {}

resolver.run = function(ent)
    if not enable:get() then return "Disabled" end
    local m = resolver_mode:get()
    if m == "Default"  then return resolve_entity(ent, "default")  end
    if m == "Advanced" then return resolve_entity(ent, "advanced") end
    if m == "Dynamic" then
        if not is_on_ground(ent) or get_velocity(ent) > 120 then
            return resolve_entity(ent, "advanced")
        else
            return resolve_entity(ent, "default")
        end
    end
    return "Unknown"
end

resolver.get_hitbox = function(ent)
    local idx = get_index(ent)
    if not idx then return HITBOX_CHEST end
    ensure_state(idx)
    local data = cache[idx]
    if not data then return HITBOX_CHEST end
    return data.hitbox or HITBOX_CHEST
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------
local function update_label(ref, text)
    pcall(function() ref:update(text) end)
    pcall(function() ref:name(text) end)
    pcall(function() ref:set(text) end)
end

local function update_stats_labels()
    local total = resolved_shots + missed_shots
    local rate  = total > 0 and math.floor((resolved_shots / total) * 100) or 0
    update_label(hit_rate_label, value_text(rate .. "%"))
    update_label(resolved_label, value_text(resolved_shots))
    update_label(missed_label,   value_text(missed_shots))
    update_label(kills_label,    value_text(resolved_kills))
end

local function event_entity(userid)
    if userid == nil or userid == 0 then return nil end
    return safe_call(function() return entity.get(userid, true) end)
        or safe_call(function() return entity.get(userid) end)
end

local function same_entity(a, b)
    if not a or not b then return false end
    if a == b then return true end
    local ai = get_index(a)
    local bi = get_index(b)
    return ai ~= nil and bi ~= nil and ai == bi
end

function event_damage_amount(e)
    return n(e and (e.dmg_health or e.damage or e.dmg or e.health_damage), 0)
end

function event_hitgroup_id(e)
    return n(e and (e.hitgroup or e.hit_group or e.hitbox or e.hitbox_id), 0)
end

function event_hitgroup_name(e)
    local hg = event_hitgroup_id(e)
    if hg == 1 then return "head" end
    if hg == 2 then return "chest" end
    if hg == 3 then return "stomach" end
    if hg == 4 then return "left arm" end
    if hg == 5 then return "right arm" end
    if hg == 6 then return "left leg" end
    if hg == 7 then return "right leg" end
    if hg == 8 then return "neck" end
    return "body"
end

function format_damage_detail(e)
    local dmg = event_damage_amount(e)
    local hitgroup = event_hitgroup_name(e)
    if dmg > 0 then
        return hitgroup .. " · " .. tostring(dmg) .. " dmg", dmg, hitgroup
    end
    return hitgroup, dmg, hitgroup
end

if events.player_hurt then
    events.player_hurt:set(function(e)
        local lp = entity.get_local_player()
        if not lp then return end

        local attacker = event_entity(e.attacker)
        local victim   = event_entity(e.userid)
        if not attacker or not victim then return end

        if same_entity(attacker, lp) and not same_entity(victim, lp) then
            local idx = get_index(victim)
            if idx then
                ensure_state(idx)

                -- FIX 3: marca hit pendente ANTES de resetar, para que aim_ack
                -- que ainda vai chegar neste tick não incremente miss nem avance brute.
                pending_hit[idx] = (globals.tickcount or 0)

                misses[idx]    = 0
                brute_seq[idx] = 1

                local c    = cache[idx]
                local side = c and n(c.side) or 0
                if side > 0 then
                    side_history[idx].hits_right = side_history[idx].hits_right + 1
                elseif side < 0 then
                    side_history[idx].hits_left  = side_history[idx].hits_left  + 1
                end
                -- Consecutive hit lock: registra o lado acertado
                update_consec_hits(idx, side)
            end

            resolved_shots = resolved_shots + 1
            update_stats_labels()

            queue_trashtalk("hit", get_name(victim))
            local _hit_detail, _hit_dmg, _hitgroup = format_damage_detail(e)
            if idx then
                LAST_HIT_INFO[idx] = { damage = _hit_dmg, hitgroup = _hitgroup, time = globals.realtime or 0 }
            end
            notify_push("hit", get_name(victim), _hit_detail)

            if logs:get() then
                print("[shiny resolver] HIT " .. get_name(victim))
            end
        elseif same_entity(victim, lp) and not same_entity(attacker, lp) then
            local _hurt_detail = format_damage_detail(e)
            notify_push("hurt", get_name(attacker), _hurt_detail)
        end
    end)
end

events.aim_ack:set(function(shot)
    if not shot or not shot.target then return end

    local state = tostring(shot.state or "")

    -- FIX 4: "correction" é o engine corrigindo trajetória (spread, movimento),
    -- não um erro de lado do resolver. Não deve incrementar miss nem avançar brute.
    -- Outros estados que indicam acerto real também são ignorados.
    if state == "hit"
    or state == "hurt"
    or state == "damage"
    or state == "correction" then  -- <-- FIX principal dos logs
        return
    end

    local ent = as_entity(shot.target)
    if not ent then return end

    local idx = get_index(ent)
    if not idx then return end

    ensure_state(idx)

    -- FIX 3 cont.: se player_hurt já processou hit neste tick ou no tick anterior,
    -- não conta como miss (aim_ack pode chegar depois do player_hurt no mesmo tick).
    local tick = globals.tickcount or 0
    local hit_tick = pending_hit[idx]
    if hit_tick and (tick - hit_tick) <= 1 then
        pending_hit[idx] = nil
        return
    end
    pending_hit[idx] = nil

    -- FIX 5: só conta miss e avança brute em estados que realmente indicam
    -- que o resolver enviou o ângulo errado.
    if state == "missed"
    or state == "spread"
    or state == "prediction error"
    or state == "occlusion"
    or state == "unpredicted occasion" then
        -- Se o gap de ticks for alto, o alvo estava em fakelag/dormant.
        -- O cache estava stale — não é erro do resolver, não penaliza brute.
        local cur_tick  = globals.tickcount or 0
        local last_tick = last_tick_seen[idx] or cur_tick
        local tick_gap  = cur_tick - last_tick
        if tick_gap >= FAKELAG_TICK_THRESHOLD then
            -- Cache stale: invalida pra forçar resolve limpo no próximo update.
            cache[idx] = nil
            if logs:get() then
                print("[shiny resolver] STALE-SKIP " .. get_name(ent)
                    .. " | gap=" .. tick_gap .. "t | state=" .. state)
            end
            return
        end

        missed_shots   = missed_shots + 1
        misses[idx]    = misses[idx] + 1
        brute_seq[idx] = (brute_seq[idx] % #BRUTE_OFFSETS) + 1

        update_stats_labels()

        queue_trashtalk("miss", get_name(ent))
        notify_push("miss", get_name(ent), state ~= "" and state or "resolver")

        if logs:get() then
            local hb  = resolver.get_hitbox(ent)
            local hbs = hb == HITBOX_HEAD and "head" or "chest"
            print("[shiny resolver] MISS " .. get_name(ent)
                .. " | state=" .. state
                .. " | hitbox=" .. hbs)
        end
    end
    -- estados desconhecidos/vazios são silenciosamente ignorados
    -- para não punir o ciclo de brute por eventos que não são do resolver.
end)

events.player_death:set(function(e)
    local lp = entity.get_local_player()
    if not lp then return end

    local attacker = event_entity(e.attacker)
    local victim   = event_entity(e.userid)

    if attacker and same_entity(attacker, lp) then
        resolved_kills = resolved_kills + 1
        update_stats_labels()
        queue_trashtalk("kill", victim and get_name(victim) or "unknown")

        local kill_detail = "resolved"
        local victim_idx = victim and get_index(victim)
        local last_hit = victim_idx and LAST_HIT_INFO[victim_idx]
        if last_hit and ((globals.realtime or 0) - (last_hit.time or 0)) < 2.5 then
            kill_detail = tostring(last_hit.hitgroup or "body")
            if n(last_hit.damage, 0) > 0 then
                kill_detail = kill_detail .. " · " .. tostring(last_hit.damage) .. " dmg"
            end
        end
        notify_push("kill", victim and get_name(victim) or "unknown", kill_detail)

        if logs:get() then
            print("[shiny resolver] KILL " .. (victim and get_name(victim) or "unknown"))
        end
    end

    if victim then
        local idx = get_index(victim)
        if idx then
            misses[idx]       = nil
            cache[idx]        = nil
            side_history[idx] = nil
            lby_history[idx]  = nil
            jitter_buf[idx]   = nil
            brute_seq[idx]    = nil
            pending_hit[idx]    = nil
            last_tick_seen[idx]  = nil
            desync_history[idx]  = nil
            consec_hits[idx]     = nil
            duck_state[idx]      = nil
            LAST_HIT_INFO[idx]    = nil
        end
    end
end)

update_stats_labels()

events.net_update_end:set(function()
    if not enable:get() then return end
    local cur_tick = globals.tickcount or 0
    for_each_enemy(function(ent)
        local idx = get_index(ent)
        if idx then last_tick_seen[idx] = cur_tick end
        resolver.run(ent)
    end)
end)

function wm_should_block_game_input()
    if not wm_menu_open() then return false end

    local mouse = wm_mouse_pos()
    if not mouse then return false end

    local mx, my = mouse.x or mouse[1] or 0, mouse.y or mouse[2] or 0

    local wm_block = false
    if wm_enable:get() then
        local rx, ry = _wm.rect_x or 0, _wm.rect_y or 0
        local rw, rh = _wm.rect_w or 0, _wm.rect_h or 0
        wm_block = (_wm.drag == true) or (_wm.input_blocked == true) or wm_inside(mx, my, rx, ry, rw, rh)
    end

    local nt_block = false
    if notify_enable and notify_enable:get() and NOTIFY_STATE then
        local rx, ry = NOTIFY_STATE.rect_x or 0, NOTIFY_STATE.rect_y or 0
        local rw, rh = NOTIFY_STATE.rect_w or 0, NOTIFY_STATE.rect_h or 0
        nt_block = (NOTIFY_STATE.drag == true) or (NOTIFY_STATE.input_blocked == true) or wm_inside(mx, my, rx, ry, rw, rh)
    end

    return wm_block or nt_block
end

function wm_block_attack_buttons(cmd)
    if not wm_should_block_game_input() then return end

    -- Prevent the click used to drag the watermark from being passed to the game.
    -- Multiple field names are used as compatibility fallbacks between NL builds.
    pcall(function() cmd.in_attack = false end)
    pcall(function() cmd.in_attack2 = false end)
    pcall(function() cmd.attack = false end)
    pcall(function() cmd.attack2 = false end)

    if cmd.buttons ~= nil and bit then
        pcall(function()
            -- IN_ATTACK = 1, IN_ATTACK2 = 2048
            cmd.buttons = bit.band(cmd.buttons, bit.bnot(1))
            cmd.buttons = bit.band(cmd.buttons, bit.bnot(2048))
        end)
    end
end

events.createmove:set(function(cmd)
    wm_block_attack_buttons(cmd)

    local lp = entity.get_local_player()
    if not lp then return end
    if not silent_shot:get() then return end
    local wpn = lp:get_player_weapon()
    if wpn then
        local since_shot = globals.curtime - wpn["m_fLastShotTime"]
        if since_shot <= 0.025 then
            cmd.no_choke = true
        end
    end
end)

events.render:set(function()
    local on = enable:get()

    -- Overview profile: mostra o nome Steam/local do jogador no menu
    do
        local lp = entity.get_local_player()
        local steam_name = lp and get_name(lp) or "unknown"
        update_label(profile_user_label, steam_name)
    end
    local ind_menu_style = tostring(ind_style:get() or "Full")
    ind_target:visibility(ind_menu_style == "Full")
    ind_state:visibility(ind_menu_style == "Full")
    ind_conf:visibility(ind_menu_style == "Full" or ind_menu_style == "Compact")

    resolver_mode:visibility(on)
    performance:visibility(on)
    detection_core:visibility(on)
    local det_on = on
    adaptive:visibility(det_on)
    jitter_fix:visibility(det_on)
    lby_resolver:visibility(det_on)
    air_resolver:visibility(det_on)
    duck_resolver:visibility(det_on)
    move_resolver:visibility(det_on)
    desync_history_en:visibility(det_on)
    consec_lock:visibility(det_on)
    brute_force:visibility(on)
    local brute_on = on and brute_force:get()
    anti_prediction:visibility(brute_on)
    brute_after:visibility(brute_on)
    body_yaw:visibility(on)
    desync_limit:visibility(on)
    local hs = on and hitbox_select:get()
    hitbox_select:visibility(on)
    head_vel_limit:visibility(on and hs)
    head_conf_only:visibility(on and hs)
    force_baim:visibility(on)
    local fb = on and force_baim:get()
    baim_min_damage:visibility(fb)
    baim_armor_check:visibility(fb)

    local dbg = debugger:get()
    local names = {"None"}
    if dbg then
        players_cache = {}
        for_each_enemy(function(ent)
            table.insert(players_cache, ent)
            table.insert(names, get_name(ent))
        end)
    end

    player_list:visibility(dbg)
    dbg_mode:visibility(dbg)
    dbg_side:visibility(dbg)
    dbg_desync:visibility(dbg)
    dbg_vel:visibility(dbg)
    dbg_jitter:visibility(dbg)
    dbg_lby:visibility(dbg)
    dbg_ground:visibility(dbg)
    dbg_micro:visibility(dbg)
    dbg_hitbox:visibility(dbg)

    render_crosshair_indicator()
    render_shiny_resolver_watermark()
    render_shiny_notifications()
    update_shiny_clantag()
    update_trashtalk()

    if dbg then
        player_list:update(names)
        local selected = player_list:get()
        if selected and selected > 1 then
            local ent = players_cache[selected - 1]
            if ent then
                local idx  = get_index(ent)
                local data = idx and cache[idx]
                if data then
                    local side_n   = n(data.side)
                    local desync_n = n(data.desync)
                    local vel_n    = n(data.velocity)
                    local side_col = side_n > 0 and "\aff2ecc71" or side_n < 0 and "\affe74c3c" or "\affa0a0a0"
                    local side_str = side_n > 0 and "Right" or side_n < 0 and "Left" or "Unknown"
                    local mode_str = tostring(data.mode or "?")
                    mode_str = mode_str:sub(1,1):upper() .. mode_str:sub(2)
                    local hb_str   = (data.hitbox == HITBOX_HEAD) and "\aff2ecc71Head" or "\affff9b2eChest"
                    dbg_mode:update(  "\affa0a0a0  Mode      \affffffff→  \aff9b59b6" .. mode_str)
                    dbg_side:update(  "\affa0a0a0  Side      \affffffff→  " .. side_col .. side_str)
                    dbg_desync:update("\affa0a0a0  Desync    \affffffff→  \affff9b2e" .. string.format("%.1f°", desync_n))
                    dbg_vel:update(   "\affa0a0a0  Velocity  \affffffff→  \affff9b2e" .. string.format("%.0f u/s", vel_n))
                    dbg_jitter:update("\affa0a0a0  Jitter    \affffffff→  " .. (data.jitter     and "\affe74c3cDetected" or "\aff2ecc71Clean"))
                    dbg_lby:update(   "\affa0a0a0  LBY Lock  \affffffff→  " .. (data.lby_locked and "\aff2ecc71Locked"   or "\affa0a0a0Free"))
                    dbg_ground:update("\affa0a0a0  Grounded  \affffffff→  " .. (data.on_ground  and "\aff2ecc71Yes"      or "\affe74c3cNo"))
                    dbg_micro:update( "\affa0a0a0  Micro-Ang \affffffff→  " .. (data.micro      and "\affff9b2eActive"   or "\aff2ecc71Normal"))
                    dbg_hitbox:update("\affa0a0a0  Hitbox    \affffffff→  " .. hb_str)
                    if logs:get() then
                        print(string.format(
                            "[shiny resolver] %s | %s | side:%s desync:%.1f vel:%.0f jitter:%s lby:%s grnd:%s micro:%s hitbox:%s",
                            get_name(ent), mode_str,
                            side_n > 0 and "R" or side_n < 0 and "L" or "?",
                            desync_n, vel_n,
                            data.jitter     and "yes" or "no",
                            data.lby_locked and "locked" or "free",
                            data.on_ground  and "yes" or "no",
                            data.micro      and "yes" or "no",
                            (data.hitbox == HITBOX_HEAD) and "head" or "chest"
                        ))
                    end
                else
                    dbg_mode:update(  "\affa0a0a0  Mode      →  —")
                    dbg_side:update(  "\affa0a0a0  Side      →  —")
                    dbg_desync:update("\affa0a0a0  Desync    →  —")
                    dbg_vel:update(   "\affa0a0a0  Velocity  →  —")
                    dbg_jitter:update("\affa0a0a0  Jitter    →  —")
                    dbg_lby:update(   "\affa0a0a0  LBY Lock  →  —")
                    dbg_ground:update("\affa0a0a0  Grounded  →  —")
                    dbg_micro:update( "\affa0a0a0  Micro-Ang →  —")
                    dbg_hitbox:update("\affa0a0a0  Hitbox    →  —")
                end
            end
        end
    end
end)

esp.enemy:new_text("Resolver State", "Resolved", function(ent)
    if not esp_flag_enable:get() then return end
    if not enable:get() then return end
    local idx = get_index(ent)
    if not idx then return end
    local data = cache[idx]
    if not data then return "Resolving..." end
    local side_n = n(data.side)
    local side_s = side_n > 0 and "R" or side_n < 0 and "L" or "?"
    local hb_s   = (data.hitbox == HITBOX_HEAD) and "Head" or "Chest"
    return string.format("Resolved [%s | %s]", side_s, hb_s)
end)
