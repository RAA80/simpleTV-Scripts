-- script for 360tv.ru (26/07/2023)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://360tv.ru/air/
-- example: https://360tv.ru/air/news/


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, '360tv%.ru/(.+)') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''    -- 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:104.0) Gecko/20100101 Firefox/104.0', proxy, false)
if session == nil then return end

m_simpleTV.Http.SetTimeout(session, 10000)

---------------------------------------------------------------------------

local json = require "rxijson"


local function _get_url(tab, id1, id2)
    local url1 = tab[id1].m3u8
    local host = string.match(url1, "https://(.-)/")

    local url2 = tab[id2].m3u8
    local param = string.match(url2, "https://.-/(.+)")

    return "https://" .. host .. "/" .. param
end


local rc, answer = m_simpleTV.Http.Request(session, {url=inAdr})
if rc ~= 200 then
    m_simpleTV.Http.Close(session)
    m_simpleTV.OSD.ShowMessage("Connection error: " .. rc, 255, 3)
    return
end

local data = string.match(answer, 'type="application/json">(.-)</script>')
local tab = json.decode(data)

local url = ""
if string.match(inAdr, '/news') then
    url = _get_url(tab.props.pageProps.live.airtabs, 2, 1)
else
    url = _get_url(tab.props.pageProps.live.airtabs, 1, 2)
end

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentAddress = url
