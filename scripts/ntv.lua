-- script for ntv.ru (31/10/2023)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://www.ntv.ru/air/ntv
-- example: https://www.ntv.ru/air/ntvlaw
-- example: https://www.ntv.ru/air/ntvseries
-- example: https://www.ntv.ru/air/ntvstyle
-- example: https://www.ntv.ru/air/unknown_russia


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, '//www%.ntv%.ru/air/') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''    -- 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 10.0; rv:103.0) Gecko/20100101 Firefox/103.0', proxy, false)
if session == nil then return end

m_simpleTV.Http.SetTimeout(session, 10000)

---------------------------------------------------------------------------

local json = require "rxijson"

local err, answer = m_simpleTV.Http.Request(session, {url='https://www.ntv.ru/api/new/widgets/air/source/index.jsp'})
if err ~= 200 then
    m_simpleTV.Http.Close(session)
    m_simpleTV.OSD.ShowMessage("Connection error: " .. err, 255, 3)
    return
end

local tab = json.decode(answer)
local t = {['ntvstyle']=1, ['ntvseries']=2, ['ntvlaw']=3, ['ntv']=4, ['unknown_russia']=5}
local chn = string.match(inAdr, "air/(.-)$")

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentAddress = tab.data.channels[t[chn]].src
