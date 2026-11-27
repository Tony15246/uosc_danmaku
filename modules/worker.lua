-- hash_worker.lua —— 由 apis/dandanplay.lua 按需 load-script 的哈希工人
-- 独立脚本线程：本文件的同步 I/O 只阻塞自己，不影响播放与其他脚本
local mp = require 'mp'
local utils = require 'mp.utils'
local msg = require 'mp.msg'

local HASH_LIMIT = 16 * 1024 * 1024
-- nil=未加载 / table=可用 / false=不可用
local MD5_LIB = nil
local cancelled = {}

-- md5 库加载（三级，最终都指向 modules/md5.lua）：
local function load_md5_lib(md5_lib)
    if MD5_LIB ~= nil then return end
    -- 1) require：mpv 把脚本自身目录加入 package.path，worker 位于 modules/，
    --    与 main.lua 的 require("modules/md5") 依赖同一机制
    local ok, lib = pcall(require, 'md5')
    if ok and type(lib) == 'table' and lib.new then
        MD5_LIB = lib
    end
    -- 2) 回退：主脚本传入的路径 dofile（apis/dandanplay.lua 计算）
    if MD5_LIB == nil and md5_lib and md5_lib ~= '' then
        local ok2, lib2 = pcall(dofile, md5_lib)
        if ok2 and type(lib2) == 'table' and lib2.new then
            MD5_LIB = lib2
        end
    end
    -- 3) 回退：本文件自身同目录 dofile 兜底
    if MD5_LIB == nil then
        local src = (debug.getinfo(1, 'S') or {}).source or ''
        local dir = src:match('^@(.+)[/\\][^/\\]+$')
        if dir then
            local ok3, lib3 = pcall(dofile, utils.join_path(dir, 'md5.lua'))
            if ok3 and type(lib3) == 'table' and lib3.new then
                MD5_LIB = lib3
            end
        end
    end
    if MD5_LIB == nil then
        MD5_LIB = false
        msg.warn('worker: md5 库不可用')
    end
end

mp.register_script_message('uosc_danmaku_hash_cancel', function(id)
    -- FIFO：正在阻塞读时先排队，读完后处理
    if id then cancelled[id] = true end
end)

mp.register_script_message('uosc_danmaku_hash_request', function(id, path, md5_lib, reply_to)
    if not id or not path or not reply_to then return end

    -- 排队期间被取消的请求：跳过，不白读 16MB
    if cancelled[id] then
        cancelled[id] = nil
        msg.verbose('worker: skipped cancelled request ' .. id)
        return
    end

    local hash = ''
    local t0 = mp.get_time()
    local ok, err = pcall(function()
        local info = utils.file_info(path)
        if info and info.size >= HASH_LIMIT then
            load_md5_lib(md5_lib)
            if type(MD5_LIB) == 'table' and MD5_LIB.new then
                -- 阻塞只发生在本线程
                local file, err = io.open(path, 'rb')
                if file then
                    local m = MD5_LIB.new()
                    for _ = 1, 16 do
                        local content = file:read(1024 * 1024)
                        if not content then break end
                        m:update(content)
                    end
                    file:close()
                    hash = m:finish() or ''
                else
                    msg.warn('worker open failed: ' .. tostring(err))
                end
            end
        end
    end)
    if not ok then
        msg.warn('worker hash error: ' .. tostring(err))
        hash = ''
    end

    mp.commandv('script-message-to', reply_to, 'uosc_danmaku_hash_result', id, hash, t0)
end)

-- 就绪广播（固定消息名）：main 由此得知本 worker 的实际脚本名
mp.commandv('script-message', 'uosc_danmaku_hash_ready', mp.get_script_name())
