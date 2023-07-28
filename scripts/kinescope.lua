-- script for kinescope.io (16/07/2023)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://kinescope.io/embed/201703038


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, '//kinescope%.io/embed/') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''   -- 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:109.0) Gecko/20100101 Firefox/115.0', proxy, false)
if session == nil then return end

m_simpleTV.Http.SetTimeout(session, 10000)

---------------------------------------------------------------------------


local rc, answer = m_simpleTV.Http.Request(session, {url=inAdr})
if rc ~= 200 then
    m_simpleTV.Http.Close(session)
    m_simpleTV.OSD.ShowMessage("Connection error: " .. rc, 255, 3)
    return
end

local url = string.match(answer, '"src":"(.-)"')

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentAddress = url
