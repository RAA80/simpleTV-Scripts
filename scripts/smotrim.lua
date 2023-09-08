-- script for smotrim.ru (11/08/2023)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://smotrim.ru/brand/20305
-- example: https://smotrim.ru/video/158543
-- example: https://smotrim.ru/podcast/9741
-- example: https://smotrim.ru/audio/2714934
-- example: https://smotrim.ru/live/53520
-- example: https://smotrim.ru/channel/270
-- example: https://smotrim.ru/channel/248


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, '//smotrim%.ru/(.+)') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''    -- 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 10.0; rv:103.0) Gecko/20100101 Firefox/103.0', proxy, false)
if session == nil then return end

m_simpleTV.Http.SetTimeout(session, 20000)

---------------------------------------------------------------------------

local json = require "rxijson"


local function _send_request(session, address)
    local rc, answer = m_simpleTV.Http.Request(session, {url=address})
    if rc ~= 200 then
        m_simpleTV.Http.Close(session)
        m_simpleTV.OSD.ShowMessage("Connection error: " .. rc, 255, 3)
        return
    end

    return answer
end

local function _get_page(pattern, link, ext)
    local id = string.match(inAdr, pattern)
    local address = link .. id .. ext
    local answer = _send_request(session, address)

    return json.decode(answer)
end

local function _redirect_url(link, _table)
    local list = {}
    for i=1, #_table.data, 1 do
        list[i] = {}
        list[i].Id = i
        list[i].Name = _table.data[i].episodeTitle ~= "" and _table.data[i].episodeTitle or _table.data[i].combinedTitle
        list[i].Address = link .. _table.data[i].id
    end

    local name = _table.data[1].brandTitle
    local _, id = m_simpleTV.OSD.ShowSelect_UTF8(name, 0, list, 10000, 1)
    m_simpleTV.Control.PlayAddressT({address=list[id or 1].Address})
end


local url, title

if string.match(inAdr, 'live/(%d+)') then
    local tab = _get_page('live/(%d+)', 'https://player.smotrim.ru/iframe/datalive/id/', '')
    url = tab.data.playlist.medialist[1].sources.m3u8.auto .. '$OPT:no-spu'
    title = tab.data.playlist.medialist[1].title

elseif string.match(inAdr, 'channel/(%d+)') then
    local answer = _send_request(session, inAdr)
    local address = string.match(answer, '"embedUrl": "(.-)"')

    if string.match(address, 'mediavitrina') then
        m_simpleTV.Control.PlayAddressT({address=address})
        return
    elseif string.match(address, 'audio%-live') then
        local tab = _get_page('channel/(%d+)', 'https://player.smotrim.ru/iframe/dataaudiolive/id/', '')
        url = tab.data.playlist.medialist[1].source.auto
        title = tab.data.playlist.medialist[1].title
    end

elseif string.match(inAdr, 'video/(%d+)') then
    local tab = _get_page('video/(%d+)', 'https://api.smotrim.ru/api/v1/videos/', '')
    url = tab.data.sources.m3u8.auto
    title = tab.data.combinedTitle

elseif string.match(inAdr, 'audio/(%d+)') then
    local tab = _get_page('audio/(%d+)', 'https://api.smotrim.ru/api/v1/audios/', '')
    url = tab.data.sources.listen
    title = tab.data.episodeTitle

elseif string.match(inAdr, 'podcast/(%d+)') then
    local tab = _get_page('podcast/(%d+)', 'https://api.smotrim.ru/api/v1/audios/rubrics/', '?limit=1000')
    return _redirect_url('https://smotrim.ru/audio/', tab)

elseif string.match(inAdr, 'brand/(%d+)') then
    local tab = _get_page('brand/(%d+)', 'https://api.smotrim.ru/api/v1/videos/brands/', '?limit=1000')
    return _redirect_url('https://smotrim.ru/video/', tab)

end

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentTitle_UTF8 = title
m_simpleTV.Control.CurrentAddress = url
