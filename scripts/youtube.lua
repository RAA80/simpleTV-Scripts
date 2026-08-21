-- script for youtube.com (21/08/2026)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://www.youtube.com/watch?v=l_BM6j5DGPA
--          https://www.youtube.com/playlist?list=PL4dWJMOQ_a1Q1H-quhclayMFleCdjn0_Y
--          https://www.youtube.com/shorts/-YSFdHE0-tg
--          https://www.youtube.com/watch?v=Dx5qFachd3A
--          https://www.youtube.com/@schillermusik

-- Important !!!
-- if youtube is blocked, download nodpi (https://github.com/GVCoder09/nodpi) and run it
-- download yt-dlp (https://github.com/yt-dlp/yt-dlp) and write path to exe in YTDLP_PATH

if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, '//www%.youtube%.com/(.+)') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

---------------------------- Settings -------------------------------------

local YTDLP_PATH = "D:/Programs/SimpleTV/luaScr/user/video/core/yt-dlp.exe"
local NET_PROXY = "127.0.0.1:8881"      --"" - if proxy not needed

---------------------------------------------------------------------------

local io = require "io"
local os = require "os"
local json = require "rxijson"


local function _run_popen(command)
    local handle = io.popen(command)
    local text = handle:read("*a")
    handle:close()

    return json.decode(text)
end

local function _show_playlist(link)
    local command = string.format('cmd /c %s --proxy %s -J --flat-playlist %s', YTDLP_PATH, NET_PROXY, link)
    local tab = _run_popen(command)

    local list = {}
    for i=1, #tab.entries, 1 do
        list[i] = {}
        list[i].Id = i
        list[i].Name = tab.entries[i].title
        list[i].Address = tab.entries[i].webpage_url or tab.entries[i].url
    end

    local mode = not string.match(list[1].Address, "/watch%?v=(.+)") and
                 not string.match(list[1].Address, "/shorts/(.+)") and 3 or 2
    local _, id = m_simpleTV.OSD.ShowSelect_UTF8(tab.title, -1, list, 30000, mode)

    if mode == 3 then
        return _show_playlist(tab.entries[id or 1].url or tab.entries[id or 1].webpage_url)
    end

    m_simpleTV.Control.ChangeAddress = 'Yes'
    m_simpleTV.Control.CurrentAddress = "wait"
end

local function _show_single_video(link)
    local stderr = os.tmpname()

    local command = string.format('cmd /c %s --proxy %s -J %s 2>%s', YTDLP_PATH, NET_PROXY, link, stderr)
    local tab = _run_popen(command)

    local handle = io.open(stderr, "r")
    local text = handle:read("*a")
    handle:close()

    local is_err = string.match(text, "ERROR:(.+)")
    if is_err then
        m_simpleTV.OSD.ShowMessage(is_err, 255, 10)
        os.remove(stderr)
        return nil
    end

    os.remove(stderr)

    m_simpleTV.Control.CurrentTitle_UTF8 = tab.title
    m_simpleTV.Control.CurrentAddress = tab.requested_formats[1].url ..
                                        "$OPT:input-slave=" .. tab.requested_formats[2].url ..
                                        "$OPT:http-proxy=" .. (NET_PROXY ~= "" and "http://" .. NET_PROXY or "") ..
                                        '$OPT:demux=avdemux,avformat,adaptive,any' ..
                                        "$OPT:no-gnutls-system-trust" ..
                                        "$OPT:http-referrer=https://www.youtube.com/"
end


if not string.match(inAdr, "/watch%?v=(.+)") and
   not string.match(inAdr, "/shorts/(.+)") then
    _show_playlist(inAdr)
else
    _show_single_video(inAdr)
end
