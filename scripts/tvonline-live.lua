-- script for tvonline.live (20/10/2024)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://tvonline.live/paramount-comedy-online.php
-- example: https://tvonline.live/fox-online.php


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, 'tvonline%.live/(.+)') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''    -- 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 10.0; rv:103.0) Gecko/20100101 Firefox/103.0', proxy, false)
if session == nil then return end

m_simpleTV.Http.SetTimeout(session, 20000)

---------------------------------------------------------------------------

local function _send_request(session, method, address, body, header)
    local rc, answer = m_simpleTV.Http.Request(session, {method=method, url=address, body=body, headers=header})
    if rc ~= 200 then
        m_simpleTV.Http.Close(session)
        m_simpleTV.OSD.ShowMessage("Connection error: " .. rc, 255, 3)
        return
    end

    return answer
end


local answer = _send_request(session, 'get', inAdr, nil, nil)

local header = 'Host: tvonline.live\n' ..
               'Referer: ' .. inAdr .. '\n' ..
               'Upgrade-Insecure-Requests: 1'
local src = "https://tvonline.live" .. string.match(answer, '<iframe id="tv" src="(.-)"')
local answer = _send_request(session, 'get', src, nil, header)

local url = string.match(answer, 'file:"%[.-%](.-)[ "]')
if string.match(url, "https") == nil then
    url = "https://tvonline.live" .. url
end

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentTitle_UTF8 = title
m_simpleTV.Control.CurrentAddress = url
