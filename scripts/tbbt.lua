-- script for tbbt.live (19/09/2025)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://tbbt.live


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, '//tbbt%.live') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''    -- 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 10.0; rv:103.0) Gecko/20100101 Firefox/103.0', proxy, false)
if session == nil then return end

m_simpleTV.Http.SetTimeout(session, 20000)

---------------------------------------------------------------------------

local rc, answer = m_simpleTV.Http.Request(session, {url=inAdr})
if rc ~= 200 then
    m_simpleTV.Http.Close(session)
    m_simpleTV.OSD.ShowMessage("Connection error: " .. rc, 255, 3)
    return
end

local title = string.match(answer, "<title>(.-)</title>")
local url = string.match(answer, "player%.src.-src: '(.-)'")

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentTitle_UTF8 = title
m_simpleTV.Control.CurrentAddress = url
