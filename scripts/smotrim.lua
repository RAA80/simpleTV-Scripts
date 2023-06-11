-- script for smotrim.ru (11/06/2023)
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

json = require "rxijson"


local function _send_request(session, address)
    local rc, answer = m_simpleTV.Http.Request(session, {url=address})
    if rc ~= 200 then
        m_simpleTV.Http.Close(session)
        m_simpleTV.OSD.ShowMessage("Connection error: " .. rc, 255, 3)
        return
    end

    return answer
end


local url, title

if string.match(inAdr, '//smotrim.ru/channel/') then
    local answer = _send_request(session, inAdr)
    local embedUrl = string.match(answer, '"embedUrl": "(.-)"')
    if string.match(embedUrl, 'mediavitrina') then
        m_simpleTV.Control.PlayAddressT({address=embedUrl})
        return
    end

    local id, sid = string.match(embedUrl, '/id/(.-)/.+/sid/(.-)/')
    embedUrl = "https://player2.smotrim.ru/iframe/datalive/id/" .. id .. "/sid/" .. sid

    local answer = _send_request(session, embedUrl)
    local tab = json.decode(answer)
    title = tab.data.playlist.medialist[1].title
    url = tab.data.playlist.medialist[1].sources.m3u8.auto

elseif string.match(inAdr, '//smotrim.ru/video/') then
    local answer = _send_request(session, inAdr)
    local embedUrl = string.match(answer, '"embedUrl": "(.-)"')

    local id, sid = string.match(embedUrl, '/id/(.-)/sid/(.-)/')
    embedUrl = "https://player2.smotrim.ru/iframe/datavideo/id/" .. id .. "/sid/" .. sid

    local answer = _send_request(session, embedUrl)
    local tab = json.decode(answer)
    title = tab.data.playlist.medialist[1].title
    url = tab.data.playlist.medialist[1].sources.m3u8.auto

elseif string.match(inAdr, '//smotrim.ru/audio/') then
    local id = string.match(inAdr, 'audio/(%d+)')
    local embedUrl = 'https://player.smotrim.ru/iframe/audio/id/' .. id .. '/sid/smotrim'

    local answer = _send_request(session, embedUrl)
    title = string.match(answer, '<title>(.-)</title>')
    url = string.match(answer, "window%.pl%.audio_url .-= '(.-)'")

elseif string.match(inAdr, '//smotrim.ru/podcast/') then
    local podcast_id = string.match(inAdr, '/podcast/(%d+)')
    local embedUrl = 'https://api.smotrim.ru/api/v1/audios/?includes=anons:datePub:duration:episodeTitle:rubrics:title&limit=1000&plan=free,free&sort=date&rubrics=' .. podcast_id

    local answer = _send_request(session, embedUrl)
    local tab = json.decode(answer)

    local podcast = {}
    for i=1, #tab.data, 1 do
        podcast[i] = {}
        podcast[i].Id = i
        podcast[i].Name = tab.data[i].episodeTitle
        podcast[i].Address = 'https://smotrim.ru/audio/' .. tab.data[i].id
    end

    local _, id = m_simpleTV.OSD.ShowSelect_UTF8("podcast", 0, podcast, 10000, 1)
    if not id then id = 1 end

    m_simpleTV.Control.PlayAddressT({address=podcast[id].Address})

end

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentTitle_UTF8 = title
m_simpleTV.Control.CurrentAddress = url
