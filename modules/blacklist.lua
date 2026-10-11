local msg = require('mp.msg')
local utils = require("mp.utils")
local unpack = unpack or table.unpack

local blacklist_patterns   -- 规则缓存
local blacklist_state      -- 编辑器状态缓存

local function blacklist_template(ext)
    if ext == "xml" then return '<?xml version="1.0" encoding="utf-8"?>\n<filters>\n</filters>\n' end
    if ext == "json" then return "[]\n" end
    return ""
end

-- 从磁盘解析编辑状态；force=true 强制重建（菜单打开时调用）
function blacklist_get_state(force)
    if blacklist_state and not force then return blacklist_state end
    local path = get_blacklist_path()
    local state = { path = path, exists = false, parse_failed = false, entries = {}, nodes = {} }
    local ext = tostring(path or ""):lower():match("%.([a-z]+)$")
    if (ext == "txt" or ext == "xml" or ext == "json") then
        state.ext = ext
        local content = file_exists(path) and read_file(path)
        if content then
            state.exists = true
            if ext == "txt" then
                for _, line in ipairs(split_lines(content)) do
                    local pattern = line:match("^%s*(.-)%s*$")
                    if pattern ~= "" then
                        local entry = { pattern = pattern, enabled = true }
                        state.entries[#state.entries + 1] = entry
                        state.nodes[#state.nodes + 1] = { entry = entry }
                    end
                end
            elseif ext == "xml" then
                for _, line in ipairs(split_lines(content)) do
                    local enabled, pattern = line:match('<item%s+enabled="([^"]*)"%s*>t=(.-)</item>')
                    if (enabled == "true" or enabled == "false") and pattern then
                        local entry = { pattern = pattern, enabled = enabled == "true" }
                        state.entries[#state.entries + 1] = entry
                        state.nodes[#state.nodes + 1] = { entry = entry }
                    else
                        state.nodes[#state.nodes + 1] = { raw_text = line }  -- 其余行原样保留
                    end
                end
            elseif ext == "json" then
                if content:sub(1, 3) == "\239\187\191" then content = content:sub(4) end
                local data = utils.parse_json(content)
                if type(data) ~= "table" then
                    state.parse_failed = true
                else
                    for _, raw in ipairs(data) do
                        if type(raw) == "table" and raw.type == 0 and type(raw.filter) == "string" then
                            local entry = { pattern = raw.filter, enabled = raw.opened == true, meta = raw }
                            state.entries[#state.entries + 1] = entry
                            state.nodes[#state.nodes + 1] = { entry = entry }
                        else
                            state.nodes[#state.nodes + 1] = { raw = raw }  -- 未知条目原样保留
                        end
                    end
                end
            end
        end
    end
    blacklist_state = state
    return state
end

-- 按格式序列化编辑状态（字符原样，不做任何转义）
local function blacklist_serialize(state)
    local fmt_item = function(e)
        return string.format('<item enabled="%s">t=%s</item>', e.enabled and "true" or "false", e.pattern)
    end
    if state.ext == "txt" then
        local out = {}
        for _, e in ipairs(state.entries) do
            if not e.deleted then out[#out + 1] = e.pattern end
        end
        return #out > 0 and table.concat(out, "\n") .. "\n" or ""
    elseif state.ext == "xml" then
        local out, pending = {}, {}
        for _, e in ipairs(state.entries) do
            if e.is_new and not e.deleted then pending[#pending + 1] = fmt_item(e) end
        end
        for _, n in ipairs(state.nodes) do
            if n.entry then
                if not n.entry.deleted then out[#out + 1] = fmt_item(n.entry) end
            else
                if #pending > 0 and n.raw_text:find("</filters>", 1, true) then
                    for _, line in ipairs(pending) do out[#out + 1] = line end
                    pending = {}
                end
                out[#out + 1] = n.raw_text
            end
        end
        for _, line in ipairs(pending) do out[#out + 1] = line end
        return table.concat(out, "\n") .. "\n"
    elseif state.ext == "json" then
        local out = {}
        for _, n in ipairs(state.nodes) do
            if n.entry then
                if not n.entry.deleted then
                    n.entry.meta.filter, n.entry.meta.opened = n.entry.pattern, n.entry.enabled
                    out[#out + 1] = n.entry.meta
                end
            else
                out[#out + 1] = n.raw
            end
        end
        for _, e in ipairs(state.entries) do
            if e.is_new and not e.deleted then out[#out + 1] = e.meta end
        end
        return (#out > 0 and utils.format_json(out) or "[]") .. "\n"
    end
end

local function blacklist_write(state, content)
    if not get_blacklist_path() then return false, "未配置 blacklist_path" end
    if not write_file(state.path, content) then
        return false, "无法写入黑名单文件（目录不存在或无权限）"
    end
    return true
end

-- 热重载规则 + 当前有可用弹幕源时按新规则重载刷新
local function blacklist_apply()
    get_blacklist_patterns(true)
    if type(DANMAKU) == "table" and type(DANMAKU.sources) == "table" then
        for _, s in pairs(DANMAKU.sources) do
            if type(s) == "table" and s.data and not s.blocked then
                pcall(load_danmaku, true)
                break
            end
        end
    end
end

-- 落盘当前编辑状态；失败时执行 undo 回滚内存态
local function blacklist_commit(undo)
    local content = blacklist_serialize(blacklist_state)
    if not content then return false, "不支持的格式" end
    local ok, err = blacklist_write(blacklist_state, content)
    if not ok then
        if undo then undo() end
        return false, err
    end
    blacklist_apply()
    return true
end

-- ---------- CRUD（返回 ok, 提示文本；OSD 与菜单刷新由 menu.lua 负责） ----------

-- 添加。text 原样入库，仅做行首尾 trim；文件不存在时自动创建
function blacklist_add_entry(text)
    local pattern = tostring(text or ""):match("^%s*(.-)%s*$")
    if pattern == "" then return false end
    if not get_blacklist_path() then return false, "未配置 blacklist_path，无法添加" end
    local state = blacklist_get_state()
    if not state.ext then return false, "blacklist_path 的扩展名不受支持（需 .txt/.xml/.json）" end
    if state.exists and state.parse_failed then return false, "文件解析失败，请先在菜单中重置" end
    if state.ext == "xml" and pattern:find("</item>", 1, true) then
        return false, "xml 格式不支持包含 </item> 的屏蔽词，请改用 txt/json"
    end
    if not state.exists then
        local ok, err = blacklist_write(state, blacklist_template(state.ext))
        if not ok then return false, err end
        state = blacklist_get_state(true)
    end
    local entry
    if state.ext == "json" then
        local max_id = 0
        for _, n in ipairs(state.nodes) do
            local raw = n.raw or (n.entry and n.entry.meta)
            if type(raw) == "table" and type(raw.id) == "number" and raw.id > max_id then max_id = raw.id end
        end
        entry = { pattern = pattern, enabled = true, is_new = true,
                  meta = { type = 0, filter = pattern, opened = true, id = max_id + 1 } }
    else
        entry = { pattern = pattern, enabled = true, is_new = true }
    end
    table.insert(state.entries, entry)
    local ok, err = blacklist_commit(function() table.remove(state.entries) end)
    if not ok then return false, err end
    return true, "已添加：" .. abbr_str(pattern, 30)
end

function blacklist_toggle_entry(index)
    local state = blacklist_get_state()
    local entry = state.entries[index]
    if not entry then return false, "条目不存在" end
    if state.ext == "txt" then return false, "txt 格式每行始终生效，无启用状态" end
    entry.enabled = not entry.enabled
    local ok, err = blacklist_commit(function() entry.enabled = not entry.enabled end)
    if not ok then return false, err end
    return true, entry.enabled and "已启用" or "已停用"
end

function blacklist_edit_entry(index, text)
    local state = blacklist_get_state()
    local entry = state.entries[index]
    if not entry then return false, "条目不存在" end
    if state.ext == "txt" then return false, "txt 格式请删除后重新添加" end
    local pattern = tostring(text or ""):match("^%s*(.-)%s*$")
    if pattern == "" or pattern == entry.pattern then return false end
    if state.ext == "xml" and pattern:find("</item>", 1, true) then
        return false, "xml 格式不支持包含 </item> 的规则"
    end
    local old = entry.pattern
    entry.pattern = pattern
    local ok, err = blacklist_commit(function() entry.pattern = old end)
    if not ok then return false, err end
    return true, "已修改"
end

function blacklist_delete_entry(index)
    local entry = blacklist_get_state().entries[index]
    if not entry then return false, "条目不存在" end
    entry.deleted = true
    local ok, err = blacklist_commit(function() entry.deleted = false end)
    if not ok then return false, err end
    return true, "已删除"
end

-- 新建 / 重置（两者同为写入标准模板，共用此函数）
function blacklist_create_file()
    local state = blacklist_get_state()
    if not state.ext then return false, "blacklist_path 的扩展名不受支持（需 .txt/.xml/.json）" end
    local ok, err = blacklist_write(state, blacklist_template(state.ext))
    if not ok then return false, err end
    blacklist_apply()
    return true, "已写入 ." .. state.ext .. " 黑名单文件"
end
