-- script for cdntvpotok.com (07/09/2025)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: http://ovego.tv/publ/live_tv/razvlekatelnye/paramount_comedy/7-1-0-1188
-- example: https://telik.live/fox.html
-- example: https://telik.live/trash-tv.html
-- example: http://sweet-tv.net/discovery-channel.html
-- example: https://smotret-tv.live/kinopokaz.html
-- example: https://smotru.tv/eurosport-1.html


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, 'ovego%.tv/(.+)') and
   not string.match(inAdr, 'smotret%-tv%.live/(.+)') and
   not string.match(inAdr, 'sweet%-tv%.net/(.+)') and
   not string.match(inAdr, 'smotru%.tv/(.+)') and
   not string.match(inAdr, 'telik%.live/(.+)') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''    -- 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 10.0; rv:103.0) Gecko/20100101 Firefox/103.0', proxy, false)
if session == nil then return end

m_simpleTV.Http.SetTimeout(session, 20000)

---------------------------------------------------------------------------

local function _send_request(session, address, header)
    local err, answer = m_simpleTV.Http.Request(session, {url=address, headers=header})
    if err ~= 200 then
        m_simpleTV.Http.Close(session)
        m_simpleTV.OSD.ShowMessage("Connection error: " .. err, 255, 3)
        return
    end

    return answer
end


local answer = _send_request(session, inAdr, "")
local src = string.match(answer, '<iframe.-src="(.-php)"')

local referer = string.match(inAdr, "(https?://.-)/")
local host = string.match(src, "(https?://.-)/")
local header = "Host: " .. host .. "\n" ..
               "Referer: " .. referer .. "\n" ..
               "Upgrade-Insecure-Requests: 1"
local answer = _send_request(session, src, header)

local signature = string.match(answer, 'signature = "(.-)"') or ""
local url = string.match(answer, 'file:"(.-)[ "]') or
            string.match(answer, 'file=(.-)"')
url = string.match(url, "([^%s+]+)")
url = unescape(url)

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentAddress = url .. signature
