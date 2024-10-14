local utils = require("mp.utils")
local msg = require 'mp.msg'
require("api")

function get_animes(query)
    local encoded_query = url_encode(query)

    local url = "https://api.dandanplay.net/api/v2/search/episodes"
    local params = "anime=" .. encoded_query
    local full_url = url .. "?" .. params

    local cmd = {
        name = 'subprocess',
        capture_stdout = true,
        capture_stderr = true,
        playback_only = true,
        args = {
            "curl",
            "-L",
            "-X",
            "GET",
            "--header",
            "Accept: application/json",
            "--header",
            "User-Agent: MyCustomUserAgent/1.0",
            full_url,
        },
    }

    local items = {}

    local message = "加载数据中..."
    update_menu(menu_item(message), query)

    local res = mp.command_native(cmd)

    if res.status ~= 0 then
        local message = "获取数据失败"
        update_menu(menu_item(message), query)
        msg.error("HTTP Request failed: " .. res.stderr)
    end

    local response = utils.parse_json(res.stdout)

    if not response or not response.animes then
        local message = "无结果"
        update_menu(menu_item(message), query)
        msg.verbose("无结果")
        return
    end

    for _, anime in ipairs(response.animes) do
        table.insert(items, {
            title = anime.animeTitle,
            value = {
                "script-message-to",
                mp.get_script_name(),
                "search-episodes-event",
                utils.format_json(anime.episodes),
            },
        })
    end

    update_menu(items, query)

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
    mp.commandv("script-message-to", "uosc", "open-menu", json_props)
end

function menu_item(input)
    local items = {}
    table.insert(items, { title = input, value = "" })
    return items
end

function update_menu(items, query)
    local menu_props = {
        type = "menu_anime",
        title = "在此处输入动画名称",
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

-- 打开输入菜单
function open_input_menu()
    local menu_props = {
        type = "menu_danmaku",
        title = "在此处输入动画名称",
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

function open_add_menu()
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

-- 注册函数给 uosc 按钮使用
mp.register_script_message("open_search_danmaku_menu", open_input_menu)
mp.register_script_message("search-anime-event", function(query)
    mp.commandv("script-message-to", "uosc", "update-menu", "menu_danmaku")
    get_animes(query)
end)
mp.register_script_message("search-episodes-event", function(episodes)
    mp.commandv("script-message-to", "uosc", "close-menu", "menu_anime")
    get_episodes(utils.parse_json(episodes))
end)

-- Register script message to show the input menu
mp.register_script_message("load-danmaku", function(episodeId)
    set_episode_id(episodeId, true)
end)

mp.register_script_message("open_add_source_menu", open_add_menu)
mp.register_script_message("add-source-event", function(query)
    mp.commandv("script-message-to", "uosc", "close-menu", "menu_source")
    add_danmaku_source(query)
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
