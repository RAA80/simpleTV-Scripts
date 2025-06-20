-- script for ovego.tv (20/06/2025)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: http://ovego.tv/publ/live_tv/razvlekatelnye/paramount_comedy/7-1-0-1188
-- example: http://telik.live/fox.html
-- example: http://telik.live/trash-tv.html
-- example: http://smotret-tv.live/kinopokaz.html


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, 'ovego%.tv/(.+)') and
   not string.match(inAdr, 'smotret%-tv%.live/(.+)') and
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

local function src_url_extractor(text)
    for result in string.gmatch(text, 'src="(.-)"') do
        if string.match(result, 'php') then
            return result
        end
    end
end


local answer = _send_request(session, inAdr, "")
local src = src_url_extractor(answer)

local referer = string.match(inAdr, "(http://.-)/") or
                string.match(inAdr, "(https://.-)/")
local host = string.match(src, "(http://.-)/") or
             string.match(src, "(https://.-)/")
local header = "Host: " .. host .. "\n" ..
               "Referer: " .. referer .. "\n" ..
               "Upgrade-Insecure-Requests: 1"
local answer = _send_request(session, src, header)

local signature = string.match(answer, 'signature = "(.-)"') or ""
local url = string.match(answer, 'file:"(.-)[ "]') or
            string.match(answer, 'file=(.-)"')

url = string.gsub(url, " or ", " ")
for part in string.gmatch(url, "([^" .. "%s+" .. "]+)") do
    url = part
    break
end

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentAddress = url .. signature
