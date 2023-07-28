-- script for mediavitrina.ru (26/07/2023)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://player.mediavitrina.ru/rentv/rentv_web/player.html


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, '//player%.mediavitrina%.ru/(.+)') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''    -- 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML,like Gecko) Chrome/79.0.2785.143 Safari/537.36', proxy, false)
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

    return answer
end

local answer = _send_request(session, inAdr)
local url = string.match(answer, "api: {.-sources: {.-url: '(.-)'")
url = string.gsub(url, '{{APPLICATION_ID}}', "")
url = string.gsub(url, '{{PLAYER_REFERER_HOSTNAME}}', "mediavitrina.ru")
url = string.gsub(url, '{{CONFIG_CHECKSUM_SHA256}}', "")
url = string.gsub(url, '/v3/', "/v1/")

local answer = _send_request(session, url)
local data = json.decode(answer)
url = data.hls[1] or data.mpd[1]

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentAddress = url
