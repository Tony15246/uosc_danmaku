local msg = require('mp.msg')
local utils = require("mp.utils")
local options = require("options")
require("api")

local input_loaded, input = pcall(require, "mp.input")
local uosc_available = false

function get_animes(query)
    local encoded_query = url_encode(query)
    local url = options.api_server .. "/api/v2/search/episodes"
    local params = "anime=" .. encoded_query
    local full_url = url .. "?" .. params
    local items = {}

    local message = "加载数据中..."
    if uosc_available then
        update_menu(menu_item(message), query)
    else
        mp.osd_message(message, 30)
    end
    msg.verbose("尝试获取番剧数据：" .. full_url)

    local res = get_danmaku_contents(full_url)

    if res.status ~= 0 then
        local message = "获取数据失败"
        if uosc_available then
            update_menu(menu_item(message), query)
        else
            mp.osd_message(message, 3)
        end
        msg.error("HTTP 请求失败：" .. res.stderr)
    end

    local response = utils.parse_json(res.stdout)

    if not response or not response.animes then
        local message = "无结果"
        if uosc_available then
            update_menu(menu_item(message), query)
        else
            mp.osd_message(message, 3)
        end
        msg.verbose("无结果")
        return
    end

    for _, anime in ipairs(response.animes) do
        table.insert(items, {
            title = anime.animeTitle,
            hint = anime.typeDescription,
            value = {
                "script-message-to",
                mp.get_script_name(),
                "search-episodes-event",
                utils.format_json(anime.episodes),
            },
        })
    end

    if uosc_available then
        update_menu(items, query)
    elseif input_loaded then
        mp.osd_message("", 0)
        mp.add_timeout(0.1, function()
            open_menu_select(items)
        end)
    end
end

function get_episodes(episodes)
    local items = {}
    for _, episode in ipairs(episodes) do
        table.insert(items, {
            title = episode.episodeTitle,
            value = { "script-message-to", mp.get_script_name(), "load-danmaku", episode.episodeId },
            keep_open = false,
            selectable = true,
        })
    end

    local menu_props = {
        type = "menu_episodes",
        title = "剧集信息",
        search_style = "disabled",
        items = items,
    }

    local json_props = utils.format_json(menu_props)
    if uosc_available then
        mp.commandv("script-message-to", "uosc", "open-menu", json_props)
    elseif input_loaded then
        mp.add_timeout(0.1, function()
            open_menu_select(items)
        end)
    end
end

function menu_item(input)
    local items = {}
    table.insert(items, { title = input, value = "" })
    return items
end

function update_menu(items, query)
    local menu_props = {
        type = "menu_anime",
        title = "在此处输入番剧名称",
        search_style = "palette",
        search_debounce = "submit",
        on_search = { "script-message-to", mp.get_script_name(), "search-anime-event" },
        footnote = "使用enter或ctrl+enter进行搜索",
        search_suggestion = query,
        items = items,
    }
    local json_props = utils.format_json(menu_props)
    mp.commandv("script-message-to", "uosc", "open-menu", json_props)
end

function open_menu_select(menu_items)
    local item_titles, item_values = {}, {}
    for i, v in ipairs(menu_items) do
        item_titles[i] = v.hint and v.title .. " (" .. v.hint .. ")" or v.title
        item_values[i] = v.value
    end
    mp.commandv('script-message-to', 'console', 'disable')
    input.select({
        prompt = '筛选:',
        items = item_titles,
        submit = function(id)
            mp.commandv(unpack(item_values[id]))
        end,
    })
end

-- 打开输入菜单
function open_input_menu_get()
    mp.commandv('script-message-to', 'console', 'disable')
    local title = get_title(true)
    input.get({
        prompt = '番剧名称:',
        default_text = title,
        cursor_position = title and #title + 1,
        submit = function(text)
            input.terminate()
            mp.commandv("script-message-to", mp.get_script_name(), "search-anime-event", text)
        end
    })
end

function open_input_menu_uosc()
    local menu_props = {
        type = "menu_danmaku",
        title = "在此处输入番剧名称",
        search_style = "palette",
        search_debounce = "submit",
        search_suggestion = get_title(true),
        on_search = { "script-message-to", mp.get_script_name(), "search-anime-event" },
        footnote = "使用enter或ctrl+enter进行搜索",
        items = {
            {
                value = "",
                hint = "使用enter或ctrl+enter进行搜索",
                keep_open = true,
                selectable = false,
                align = "center",
            },
        },
    }
    local json_props = utils.format_json(menu_props)
    mp.commandv("script-message-to", "uosc", "open-menu", json_props)
end

function open_add_menu_get()
    mp.commandv('script-message-to', 'console', 'disable')
    input.get({
        prompt = 'Input url:',
        submit = function(text)
            input.terminate()
            mp.commandv("script-message-to", mp.get_script_name(), "add-source-event", text)
        end
    })
end

function open_add_menu_uosc()
    local menu_props = {
        type = "menu_source",
        title = "在此输入源地址url",
        search_style = "palette",
        search_debounce = "submit",
        on_search = { "script-message-to", mp.get_script_name(), "add-source-event" },
        footnote = "使用enter或ctrl+enter进行搜索",
        items = {
            {
                value = "",
                hint = "使用enter或ctrl+enter进行搜索",
                keep_open = true,
                selectable = false,
                align = "center",
            },
        },
    }
    local json_props = utils.format_json(menu_props)
    mp.commandv("script-message-to", "uosc", "open-menu", json_props)
end

function open_input_menu()
    if uosc_available then
        open_input_menu_uosc()
    elseif input_loaded then
        open_input_menu_get()
    end
end

function open_add_menu()
    if uosc_available then
        open_add_menu_uosc()
    elseif input_loaded then
        open_add_menu_get()
    end
end

mp.commandv(
    "script-message-to",
    "uosc",
    "set-button",
    "danmaku",
    utils.format_json({
        icon = "search",
        tooltip = "弹幕搜索",
        command = "script-message open_search_danmaku_menu",
    })
)

mp.commandv(
    "script-message-to",
    "uosc",
    "set-button",
    "danmaku_source",
    utils.format_json({
        icon = "add_box",
        tooltip = "从源添加弹幕",
        command = "script-message open_add_source_menu",
    })
)


mp.register_script_message('uosc-version', function()
    uosc_available = true
end)

-- 注册函数给 uosc 按钮使用
mp.register_script_message("open_search_danmaku_menu", open_input_menu)
mp.register_script_message("search-anime-event", function(query)
    if uosc_available then
        mp.commandv("script-message-to", "uosc", "close-menu", "menu_danmaku")
    end
    get_animes(query)
end)
mp.register_script_message("search-episodes-event", function(episodes)
    if uosc_available then
        mp.commandv("script-message-to", "uosc", "close-menu", "menu_anime")
    end
    get_episodes(utils.parse_json(episodes))
end)

-- Register script message to show the input menu
mp.register_script_message("load-danmaku", function(episodeId)
    set_episode_id(episodeId, true)
end)

mp.register_script_message("open_add_source_menu", open_add_menu)
mp.register_script_message("add-source-event", function(query)
    if uosc_available then
        mp.commandv("script-message-to", "uosc", "close-menu", "menu_source")
    end
    add_danmaku_source(query, true)
end)

mp.commandv("script-message-to", "uosc", "set", "show_danmaku", "off")
mp.register_script_message("set", function(prop, value)
    if prop ~= "show_danmaku" then
        return
    end

    if value == "on" then
        show_danmaku_func()
    else
        hide_danmaku_func()
    end

    mp.commandv("script-message-to", "uosc", "set", "show_danmaku", value)
end)
mp.register_script_message("show_danmaku_keyboard", function()
    local has_danmaku = false
    local sec_sid = mp.get_property("secondary-sid")
    local tracks = mp.get_property_native("track-list")
    for i = #tracks, 1, -1 do
        if tracks[i].type == "sub" and tracks[i].title == "danmaku" then
            has_danmaku = true
            break
        end
    end

    if sec_sid == "no" and has_danmaku == false then
        local path = mp.get_property("path")
        local dir = get_parent_directory(path)
        local filename = mp.get_property('filename/no-ext')
        if filename and dir then
            local danmaku_xml = utils.join_path(dir, filename .. ".xml")
            if file_exists(danmaku_xml) then
                load_local_danmaku(danmaku_xml)
            else
                get_danmaku_with_hash(filename, path)
            end
            addon_danmaku(path)
        end
        return
    end

    if sec_sid ~= "no" then
        hide_danmaku_func()
        mp.commandv("script-message-to", "uosc", "set", "show_danmaku", "off")
    else
        show_danmaku_func()
        mp.commandv("script-message-to", "uosc", "set", "show_danmaku", "on")
    end
end)
