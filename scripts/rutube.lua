-- script for rutube.ru (09/08/2025)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://rutube.ru/video/a88448f3a273028b52f6d66bf5cc68fd/
-- example: https://rutube.ru/video/c58f502c7bb34a8fcdd976b221fca292/
-- example: https://rutube.ru/shorts/2b920289347334ee93e63873bc444212/


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, '//rutube%.ru/(.+)') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''    -- 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML,like Gecko) Chrome/79.0.2785.143 Safari/537.36', proxy, false)
if session == nil then return end

m_simpleTV.Http.SetTimeout(session, 10000)

---------------------------------------------------------------------------

local json = require "rxijson"

local id = string.match(inAdr, '/video/(%w+)') or string.match(inAdr, '/shorts/(%w+)')
inAdr = "http://rutube.ru/api/play/options/" .. id

local rc, answer = m_simpleTV.Http.Request(session, {url=inAdr})
if rc ~= 200 then
    m_simpleTV.Http.Close(session)
    m_simpleTV.OSD.ShowMessage("Connection error: " .. rc, 255, 3)
    return
end

local data = json.decode(answer)
local title = data.title
local url = data.video_balancer.m3u8 or data.live_streams.hls[1].url

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentTitle_UTF8 = title
m_simpleTV.Control.CurrentAddress = url
