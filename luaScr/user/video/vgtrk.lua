-- script for vgtrk.com (28/06/2022)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://player.vgtrk.com/iframe/video/id/2433592/start_zoom/true/showZoomBtn/false/sid/smotrim/isPlay/false/mute/true/?acc_video_id=2589919


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, '//player%.vgtrk%.com/(.+)') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''    -- proxy: 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML,like Gecko) Chrome/79.0.2785.143 Safari/537.36', proxy, false)
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

local answer = _send_request(session, inAdr)
local dataUrl = string.match(answer, "window%.pl%.data%.dataUrl = '(.-)'")

local answer = _send_request(session, 'https:' .. dataUrl)
local jsdata = json.decode(answer)

local title = jsdata.data.playlist.medialist[1].title
local url = jsdata.data.playlist.medialist[1].sources.m3u8.auto

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentTitle_UTF8 = title
m_simpleTV.Control.CurrentAddress = url
