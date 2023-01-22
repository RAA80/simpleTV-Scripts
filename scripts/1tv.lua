-- script for 1tv.ru (21/01/2023)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://www.1tv.ru/live


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, '1tv%.ru/live') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''    -- 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML,like Gecko) Chrome/79.0.2785.143 Safari/537.36', proxy, false)
if session == nil then return end

m_simpleTV.Http.SetTimeout(session, 10000)

---------------------------------------------------------------------------

json = require "rxijson"

local function _send_request(session, address)
    local err, answer = m_simpleTV.Http.Request(session, {url=address})
    if err ~= 200 then
        m_simpleTV.Http.Close(session)
        m_simpleTV.OSD.ShowMessage("Connection error: " .. err, 255, 3)
        return
    end

    return json.decode(answer)
end

local data = _send_request(session, "http://stream.1tv.ru/api/playlist/1tvch_as_array.json")
local tab = _send_request(session, "http://stream.1tv.ru/get_hls_session")
local url = data.hls[1] .. '&s=' .. tab.s or data.mpd[1]

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentAddress = url
