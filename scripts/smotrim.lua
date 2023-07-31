-- script for smotrim.ru (30/07/2023)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://smotrim.ru/channel/1
-- example: https://smotrim.ru/video/2393207
-- example: https://smotrim.ru/audio/2650807
-- example: https://smotrim.ru/podcast/45


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, '//smotrim%.ru/(.+)') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''    -- 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 10.0; rv:103.0) Gecko/20100101 Firefox/103.0', proxy, false)
if session == nil then return end

m_simpleTV.Http.SetTimeout(session, 10000)

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

local function _get_page(pattern, str1, str2)
    local id1, id2 = string.match(inAdr, pattern)
    local address = str1 .. id1 .. str2 .. (id2 or "")
    local answer = _send_request(session, address)

    return json.decode(answer)
end


local url, title

if string.match(inAdr, '//smotrim.ru/channel/') then
    local answer = _send_request(session, inAdr)
    inAdr = string.match(answer, '"embedUrl": "(.-)"')
    if string.match(inAdr, 'mediavitrina') then
        m_simpleTV.Control.PlayAddressT({address=inAdr})
        return
    end

    local tab = _get_page('/id/(.-)/.+/sid/(.-)/', 'https://player.smotrim.ru/iframe/datalive/id/', '/sid/')
    title = tab.data.playlist.medialist[1].title
    url = tab.data.playlist.medialist[1].sources.m3u8.auto

elseif string.match(inAdr, '//smotrim.ru/video/') then
    local tab = _get_page('video/(%d+)', 'https://player.smotrim.ru/iframe/datavideo/id/', '/sid/smotrim')
    title = tab.data.playlist.medialist[1].title
    url = tab.data.playlist.medialist[1].sources.m3u8.auto

elseif string.match(inAdr, '//smotrim.ru/audio/') then
    local tab = _get_page('audio/(%d+)', 'https://player.smotrim.ru/iframe/dataaudio/id/', '/sid/smotrim')
    title = tab.data.playlist.medialist[1].title
    url = tab.data.playlist.medialist[1].audio_url

elseif string.match(inAdr, '//smotrim.ru/podcast/') then
    local tab = _get_page('/podcast/(%d+)', 'https://api.smotrim.ru/api/v1/audios?limit=1000&plan=free,free&sort=date&rubrics=', '')

    local podcast = {}
    for i=1, #tab.data, 1 do
        podcast[i] = {}
        podcast[i].Id = i
        podcast[i].Name = tab.data[i].episodeTitle
        podcast[i].Address = 'https://smotrim.ru/audio/' .. tab.data[i].id
    end

    local _, id = m_simpleTV.OSD.ShowSelect_UTF8("podcast", 0, podcast, 10000, 1)
    m_simpleTV.Control.PlayAddressT({address=podcast[id or 1].Address})
    return

end

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentTitle_UTF8 = title
m_simpleTV.Control.CurrentAddress = url
