local msg = require('mp.msg')
local utils = require("mp.utils")

require("options")
require("api")
require('render')

local input_loaded, input = pcall(require, "mp.input")
local uosc_available = false


function updata_menu_items_config()
	return {
		bold = { title = "粗体", query = "bold", hint = options.bold },
		fontsize = { title = "大小", query = "fontsize", hint = options.fontsize, scope = { min = "0", max = "inf"} },
		shadow = { title = "阴影", query = "shadow", hint = options.shadow, scope = { min = "0", max = "inf"} },
		outline = { title = "描边", query = "outline", hint = options.outline, scope = { min = "0.0", max = "4.0"} },
		density = { title = "弹幕密度", query = "density", hint = options.density, scope = { min = "-1", max = "inf"} },
		scrolltime = { title = "弹幕速度", query = "scrolltime", hint = options.scrolltime, scope = { min = "1", max = "inf"} },
		transparency = { title = "透明度", query = "transparency", hint = options.transparency, scope = { min = "0", max = "255"} },
		displayarea = { title = "弹幕显示范围", query = "displayarea", hint = options.displayarea, scope = { min = "0.0", max = "1.0"} },
	}
end
local menu_items_config = updata_menu_items_config()
local footnote_table = {
	bold = "true / false",
	fontsize = "请输入整数(>=0)",
	shadow = "请输入整数(>=0)",
	outline = "输入范围：(0.0-4.0)",
	transparency = "  输入范围：0(不透明)到255(完全透明)",
	scrolltime = "请输入整数(>=1)，数字越大速度越慢",
	density = "  请输入整数(>=-1) -1：表示不重叠 0：表示无限制 其他表示限定条数",
	displayarea = "显示范围(0.0-1.0)",
}
-- 创建一个包含键顺序的表，这是样式菜单的排布顺序
local ordered_keys = {"bold", "fontsize", "shadow", "outline", "transparency", "scrolltime", "density", "displayarea"}


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
        show_message(message, 30)
    end
    msg.verbose("尝试获取番剧数据：" .. full_url)

    local res = get_danmaku_contents(full_url)

    if res.status ~= 0 then
        local message = "获取数据失败"
        if uosc_available then
            update_menu(menu_item(message), query)
        else
            show_message(message, 3)
        end
        msg.error("HTTP 请求失败：" .. res.stderr)
    end

    local response = utils.parse_json(res.stdout)

    if not response or not response.animes then
        local message = "无结果"
        if uosc_available then
            update_menu(menu_item(message), query)
        else
            show_message(message, 3)
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
                anime.animeTitle, utils.format_json(anime.episodes),
            },
        })
    end

    if uosc_available then
        update_menu(items, query)
    elseif input_loaded then
        show_message("", 0)
        mp.add_timeout(0.1, function()
            open_menu_select(items)
        end)
    end
end

function get_episodes(animeTitle, episodes)
    local items = {}
    for _, episode in ipairs(episodes) do
        table.insert(items, {
            title = episode.episodeTitle,
            value = { "script-message-to", mp.get_script_name(), "load-danmaku", animeTitle, episode.episodeTitle, episode.episodeId },
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


-- 设置弹幕样式菜单
function add_danmaku_setup(active)
	local items = {}
	for _, key in ipairs(ordered_keys) do
		local config = menu_items_config[key]
		table.insert(items, {
			title = config.title,
			hint = "目前：" .. tostring(config.hint),
			value = { "script-message-to", mp.get_script_name(), "setup-danmaku-style", config.query },
			active = key == active,
			keep_open = true,
			selectable = true,
		})
	end

    local menu_props = {
        type = "menu_style",
        title = "弹幕样式",
        footnote = "样式更改仅在本次播放生效",
        items = items,
    }
    local json_props = utils.format_json(menu_props)
    mp.commandv("script-message-to", "uosc", "open-menu", json_props)
end

-- 更新弹幕样式设置菜单
function updata_danmaku_setup(active, status)
	local items = {}
	for _, key in ipairs(ordered_keys) do
		local config = menu_items_config[key]
		table.insert(items, {
			title = config.title,
			hint = "目前：" .. tostring(config.hint),
--            icon = 'history',
			value = { "script-message-to", mp.get_script_name(), "setup-danmaku-style", config.query },
			active = key == active,
			keep_open = true,
			selectable = true,
		})
	end

    local menu_props = {
        type = "menu_style",
        title = footnote_table[active],
        search_style = "palette",
        search_debounce = "submit",
        footnote = footnote_table[active] or "",
		on_search = { "script-message-to", mp.get_script_name(), "update-danmaku-style", active },
        items = items,
    }
	local actions = "update-menu"
    if status and status == "error" then
        menu_props.title = "输入非数字字符或范围出错"
		-- 创建一个定时器，在2秒后触发回调函数，删除搜索栏错误信息
		mp.add_timeout(2.0, function() updata_danmaku_setup(active) end)
		actions = "open-menu"
    elseif status and status == "updata" then
        menu_props.title = footnote_table[active]
		actions = "open-menu"
	end
    local json_props = utils.format_json(menu_props)
    mp.commandv("script-message-to", "uosc", actions, json_props)
end

-- 总集合弹幕菜单
function open_add_total_menu_uosc()
	local items = {}
	local menu_items_config = {
		{ title = "弹幕搜索", action = "open_search_danmaku_menu" },
		{ title = "从源添加弹幕", action = "open_add_source_menu" },
		{ title = "弹幕设置", action = "open_setup_danmaku_menu" },
	}
	for _, config in ipairs(menu_items_config) do
		table.insert(items, {
			title = config.title,
			value = { "script-message-to", mp.get_script_name(), config.action },
			keep_open = false,
			selectable = true,
		})
	end

    local menu_props = {
        type = "menu_total",
        title = "弹幕设置",
        search_style = "disabled",
        items = items,
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

mp.commandv(
    "script-message-to",
    "uosc",
    "set-button",
    "danmaku_menu",
    utils.format_json({
        icon = "grid_view",
        tooltip = "弹幕设置",
        command = "script-message open_add_total_menu",
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
mp.register_script_message("search-episodes-event", function(animeTitle, episodes)
    if uosc_available then
        mp.commandv("script-message-to", "uosc", "close-menu", "menu_anime")
    end
    get_episodes(animeTitle, utils.parse_json(episodes))
end)

-- Register script message to show the input menu
mp.register_script_message("load-danmaku", function(animeTitle, episodeTitle, episodeId)
    danmaku.anime = animeTitle
    danmaku.episode = episodeTitle:match("(第%d+[话回集]+)") or episodeTitle
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
        if comments == nil then
            local path = mp.get_property("path")
            if is_protocol(path) and (path:find('bilibili.com') or path:find('bilivideo.c[nom]+')) then
                load_danmaku_for_bilibili(path)
                return
            end
            if is_protocol(path) and (path:find('bahamut.akamaized.net')) then
                load_danmaku_for_bahamut(path)
                return
            end
            init(path)
        else
            if danmaku.anime and danmaku.episode then
                show_message("加载弹幕：" .. danmaku.anime .. "-" .. danmaku.episode.. "\\N共计" .. #comments .. "条弹幕", 3)
            else
                show_message("弹幕加载成功，共计" .. #comments .. "条弹幕", 3)
            end
            show_danmaku_func()
        end
    else
        show_message("关闭弹幕", 2)
        hide_danmaku_func()
    end

    mp.commandv("script-message-to", "uosc", "set", "show_danmaku", value)
end)

mp.register_script_message("show_danmaku_keyboard", function()
    if not enabled then
        if comments == nil then
            local path = mp.get_property("path")
            if is_protocol(path) and (path:find('bilibili.com') or path:find('bilivideo.c[nom]+')) then
                load_danmaku_for_bilibili(path)
                return
            end
            if is_protocol(path) and (path:find('bahamut.akamaized.net')) then
                load_danmaku_for_bahamut(path)
                return
            end
            init(path)
        else
            if danmaku.anime and danmaku.episode then
                show_message("加载弹幕：" .. danmaku.anime .. "-" .. danmaku.episode.. "\\N共计" .. #comments .. "条弹幕", 3)
            else
                show_message("弹幕加载成功，共计" .. #comments .. "条弹幕", 3)
            end
            show_danmaku_func()
            mp.commandv("script-message-to", "uosc", "set", "show_danmaku", "on")
        end
    else
        show_message("关闭弹幕", 2)
        hide_danmaku_func()
        mp.commandv("script-message-to", "uosc", "set", "show_danmaku", "off")
    end
end)

mp.register_script_message("open_add_total_menu", open_add_total_menu_uosc)
mp.register_script_message("open_setup_danmaku_menu", function()
    if uosc_available then
        mp.commandv("script-message-to", "uosc", "close-menu", "menu_total")
    end
    add_danmaku_setup()
end)


mp.register_script_message("setup-danmaku-style", function(query)
    if type(query) == "string" and menu_items_config[query] then
		if query == "bold" then
			options["bold"] = not options["bold"]
			menu_items_config = updata_menu_items_config()
		end
		updata_danmaku_setup(query)
	else
		add_danmaku_setup()
    end
end)

mp.register_script_message("update-danmaku-style", function(query, text)
	-- mp.commandv("script-message-to", "uosc", "close-menu", "menu_style")
	if text == nil or text == "" then
		return
	elseif query == "bold" then
		options["bold"] = not options["bold"]
		menu_items_config = updata_menu_items_config()
		updata_danmaku_setup(query, "updata")
	elseif is_strict_number(text) then
		local num = tonumber(text)
		local status = "error"
		local min_num = tonumber(menu_items_config[query]["scope"]["min"]) or 0
		local max_num = tonumber(menu_items_config[query]["scope"]["max"]) or math.huge
		if num and min_num <= num and num <= max_num then
			options[query] = tonumber(text)
			status = "updata"
		end
		menu_items_config = updata_menu_items_config()
		updata_danmaku_setup(query, status)
	else
		updata_danmaku_setup(query, "error")
	end
end)
