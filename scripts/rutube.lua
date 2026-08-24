-- script for rutube.ru (24/08/2026)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://rutube.ru/video/a88448f3a273028b52f6d66bf5cc68fd/
--          https://rutube.ru/video/c58f502c7bb34a8fcdd976b221fca292/
--          https://rutube.ru/live/video/c37cd74192c6bc3d6cd6077c0c4fd686/
--          https://rutube.ru/shorts/2b920289347334ee93e63873bc444212/
--          https://rutube.ru/play/embed/da912cee19d409d5b5cdf504499383a0/
--          https://rutube.ru/plst/1673828/
--          https://rutube.ru/channel/1765289/


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, '//rutube%.ru/(.+)') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''    -- 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0', proxy, false)
if session == nil then return end

m_simpleTV.Http.SetTimeout(session, 10000)

---------------------------------------------------------------------------

local json = require "rxijson"

local function _send_request(session, address)
    local err, answer = m_simpleTV.Http.Request(session, {url=address})
    if err ~= 200 then
        m_simpleTV.Http.Close(session)
        m_simpleTV.OSD.ShowMessage("Connection error: " .. err, 255, 3)
        return
    end

    return json.decode(answer)
end

local function _show_playlist(id)
    local url = string.format("https://rutube.ru/api/metainfo/tv/%s/?format=json", id)
    local tab = _send_request(session, url)
    local name = tab.name

    local list = {}
    local i = 0
    local page = 1

    repeat
        url = string.format("https://rutube.ru/api/playlist/custom/%s/videos?page=%s&format=json&limit=40", id, page)
        tab = _send_request(session, url)

        for k=1, #tab.results, 1 do
            list[i+k] = {}
            list[i+k].Id = i+k
            list[i+k].Name = tab.results[k].title
            list[i+k].Address = tab.results[k].video_url
        end

        i = i + #tab.results
        page = page + 1
    until not tab.has_next

    local _, id = m_simpleTV.OSD.ShowSelect_UTF8(name, -1, list, 10000, 2)

    m_simpleTV.Control.ChangeAddress = 'Yes'
    m_simpleTV.Control.CurrentAddress = "wait"
end

local function _show_single_video(id)
    local link = "http://rutube.ru/api/play/options/" .. id
    local tab = _send_request(session, link)

    m_simpleTV.Control.CurrentTitle_UTF8 = tab.title
    m_simpleTV.Control.CurrentAddress = tab.video_balancer.m3u8 or tab.live_streams.hls[1].url
end

local function _show_channel_items(id, pattern, host)
    local list = {}
    local i = 0
    local page = 1

    repeat
        m_simpleTV.OSD.ShowMessage("Read page " .. page)

        url = string.format(pattern, id, page)
        tab = _send_request(session, url)

        for k=1, #tab.results, 1 do
            list[i+k] = {}
            list[i+k].Id = i+k
            list[i+k].Name = tab.results[k].title
            list[i+k].Address = host .. tab.results[k].id
        end

        i = i + #tab.results
        page = page + 1
    until not tab.has_next

    local _, id = m_simpleTV.OSD.ShowSelect_UTF8("Playlists", -1, list, 10000, 2)

    m_simpleTV.Control.ChangeAddress = 'Yes'
    m_simpleTV.Control.CurrentAddress = "wait"
end

local function _show_channel(uid)
    local handle = {{name = "Videos",    args = {uid, "https://rutube.ru/api/video/person/%s/?page=%s", "https://rutube.ru/video/"}},
                    {name = "Shorts",    args = {uid, "https://rutube.ru/api/video/person/%s/?origin__type=rshorts&page=%s", "https://rutube.ru/shorts/"}},
                    {name = "Playlists", args = {uid, "https://rutube.ru/api/playlist/user/%s/?page=%s", "https://rutube.ru/plst/"}}}
    local list = {}

    for i=1, #handle, 1 do
        list[i] = {}
        list[i].Id = i
        list[i].Name = handle[i].name
    end

    local _, id = m_simpleTV.OSD.ShowSelect_UTF8("Channel", 0, list, 10000, 3)
    return _show_channel_items(unpack(handle[id or 1].args))
end


local handlers = {['video']=_show_single_video,
                  ['shorts']=_show_single_video,
                  ['live/video']=_show_single_video,
                  ['play/embed']=_show_single_video,
                  ['plst']=_show_playlist,
                  ['channel']=_show_channel,
                  ['video/person']=_show_channel}
local frmt, id = string.match(inAdr, "https?://rutube%.ru/([%w/]+)/([%da-z]+)")
handlers[frmt](id)

m_simpleTV.Http.Close(session)
