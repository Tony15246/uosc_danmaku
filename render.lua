-- modified from https://github.com/rkscv/danmaku/blob/main/danmaku.lua

local msg = require('mp.msg')
local utils = require("mp.utils")

local INTERVAL = 0.001
local osd_width, osd_height, delay, pause = 0, 0, 0, true
enabled, comments = false, nil

-- 从时间字符串转换为秒数
local function time_to_seconds(time_str)
    local h, m, s = time_str:match("(%d+):(%d+):([%d%.]+)")
    return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
end

-- 提取 \move 参数 (x1, y1, x2, y2) 并返回
local function parse_move_tag(text)
    -- 匹配包括小数和负数在内的坐标值
    local x1, y1, x2, y2 = text:match("\\move%((%-?[%d%.]+),%s*(%-?[%d%.]+),%s*(%-?[%d%.]+),%s*(%-?[%d%.]+)%)")
    if x1 and y1 and x2 and y2 then
        return tonumber(x1), tonumber(y1), tonumber(x2), tonumber(y2)
    end
    return nil
end

local function apply_moving_text(event, pos)
    local x1, y1, x2, y2 = parse_move_tag(event.text)
    if not x1 then
        return string.format("{\\an8}%s", event.text)
    end

    -- 计算移动的时间范围
    local duration = options.scrolltime
    local progress = (pos - event.start_time - delay) / duration  -- 移动进度 [0, 1]

    -- 计算当前坐标
    local current_x = x1 + (x2 - x1) * progress
    local current_y = y1 + (y2 - y1) * progress

    -- 移除 \move 标签并应用当前坐标
    local clean_text = event.text:gsub("\\move%(.-%)", "")
    return string.format("{\\pos(%d,%d)\\an8}%s", current_x, current_y, clean_text)
end

-- 从 ASS 文件中解析样式和事件
local function parse_ass(ass_path)
    local ass_file = io.open(ass_path, "r")
    if not ass_file then
        return nil
    end

    local events = {}

    for line in ass_file:lines() do
        if line:match("^Dialogue:") then
            local start_time, end_time, style, text = line:match("Dialogue:%s*[^,]*,%s*([^,]*),%s*([^,]*),%s*([^,]*),[^,]*,[^,]*,[^,]*,[^,]*,[^,]*,(.*)")
            if start_time and end_time and text then
                table.insert(events, {
                    start_time = time_to_seconds(start_time),
                    end_time = time_to_seconds(end_time),
                    text = text:gsub("%s+$", ""),
                })
            end
        end
    end

    ass_file:close()
    return events
end

local overlay = mp.create_osd_overlay('ass-events')

local function render()
    if comments == nil then return end

    local pos, err = mp.get_property_number('time-pos')
    if err ~= nil then
        return msg.error(err)
    end

    local fontname = options.fontname
    local fontsize = options.fontsize

    local width, height = 1920, 1080
    local ratio = osd_width / osd_height
    if width / height < ratio then
        height = width / ratio
        fontsize = options.fontsize - ratio * 2
    end

    local ass_events = {}

    for _, event in ipairs(comments) do
        if pos >= event.start_time + delay and pos <= event.end_time + delay then
            local text = apply_moving_text(event, pos)

            -- 构建 ASS 字符串
            local ass_text = string.format("{\\fn%s\\fs%d\\c&HFFFFFF&\\alpha&H%x\\bord%s\\shad%s\\b%s\\q2}%s",
                fontname, fontsize, options.transparency, options.outline, options.shadow, options.bold == "true" and "1" or "0", text)

            table.insert(ass_events, ass_text)
        end
    end

    overlay.res_x = width
    overlay.res_y = height
    overlay.data = table.concat(ass_events, '\n')
    overlay:update()
end

local function show_loaded()
    if danmaku.anime and danmaku.episode then
        mp.osd_message("匹配内容：" .. danmaku.anime .. "-" .. danmaku.episode .. "\n弹幕加载成功，共计" .. #comments .. "条弹幕", 3)
        msg.info(danmaku.anime .. "-" .. danmaku.episode .. " 弹幕加载成功，共计" .. #comments .. "条弹幕")
    else
        mp.osd_message("弹幕加载成功，共计" .. #comments .. "条弹幕", 3)
    end
end

function parse_danmaku(ass_file_path, from_menu)
    comments, err = parse_ass(ass_file_path)
    if not comments then
        msg.error("ASS 解析错误:", err)
        return
    end

    if enabled and (from_menu or get_danmaku_visibility()) then
        show_danmaku_func()
        mp.commandv("script-message-to", "uosc", "set", "show_danmaku", "on")
        show_loaded()
    else
        enabled = false
        mp.osd_message("")
    end
end

function show_danmaku_func()
    render()
    if not pause then
        timer:resume()
    end
    enabled = true
    set_danmaku_visibility(true)
end

function hide_danmaku_func()
    timer:kill()
    overlay:remove()
    enabled = false
    set_danmaku_visibility(false)
end

mp.observe_property('osd-width', 'number', function(_, value) osd_width = value or osd_width end)
mp.observe_property('osd-height', 'number', function(_, value) osd_height = value or osd_height end)
mp.observe_property('display-fps', 'number', function(_, value)
    if value ~= nil then
        local interval = 1 / value / 10
        if interval > INTERVAL then
            timer = mp.add_periodic_timer(interval, render, true)
        else
            timer = mp.add_periodic_timer(INTERVAL, render, true)
        end
    else
        timer = mp.add_periodic_timer(INTERVAL, render, true)
    end
end)
mp.observe_property('pause', 'bool', function(_, value)
    if value ~= nil then
        pause = value
    end
    if enabled then
        if pause then
            timer:kill()
        elseif comments ~= nil then
            timer:resume()
        end
    end
end)

mp.add_hook("on_unload", 50, function()
    mp.unobserve_property('pause')
    comments, delay = nil, 0
    timer:kill()
    overlay:remove()

    local danmaku_path = os.getenv("TEMP") or "/tmp/"
    local rm1 = utils.join_path(danmaku_path, "danmaku.json")
    local rm2 = utils.join_path(danmaku_path, "danmaku.ass")
    local rm3 = utils.join_path(danmaku_path, "danmaku.xml")
    local rm4 = utils.join_path(danmaku_path, "temp.mp4")
    local rm5 = utils.join_path(danmaku_path, "bahamut.json")
    if file_exists(rm1) then os.remove(rm1) end
    if file_exists(rm2) then os.remove(rm2) end
    if file_exists(rm3) then os.remove(rm3) end
    if file_exists(rm4) then os.remove(rm4) end
    if file_exists(rm5) then os.remove(rm5) end
end)

mp.register_event('playback-restart', function(event)
    if event.error then
        return msg.error(event.error)
    end
    if enabled and comments ~= nil then
        render()
    end
end)

mp.register_script_message("danmaku-delay", function(number)
    local value = tonumber(number)
    if value == nil then
        return msg.error('command danmaku-delay: invalid time')
    end
    delay = delay + value
    if enabled and comments ~= nil then
        render()
    end
    mp.osd_message('设置弹幕延迟: ' .. (delay * 1000) .. ' ms')
end)

