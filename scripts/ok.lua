-- script for ok.ru (26/06/2022)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://ok.ru/video/23276948199
-- example: https://ok.ru/live/3574052691599


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, '//ok%.ru/(.+)') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''    -- 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML,like Gecko) Chrome/79.0.2785.143 Safari/537.36', proxy, false)
if session == nil then return end

m_simpleTV.Http.SetTimeout(session, 10000)

---------------------------------------------------------------------------

json = require "rxijson"
htmlEntities = require 'htmlEntities'

local rc, answer = m_simpleTV.Http.Request(session, {url=inAdr})
if rc ~= 200 then
    m_simpleTV.Http.Close(session)
    m_simpleTV.OSD.ShowMessage("Connection error: " .. rc, 255, 3)
    return
end

local str = string.match(answer, 'data%-options%="(.-)" data%-player%-container%-id')
str = htmlEntities.decode(str)

local data = json.decode(str)
local metadata = json.decode(data.flashvars.metadata)

local title = metadata.movie.title
local url = metadata.hlsManifestUrl or metadata.hlsMasterPlaylistUrl

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentTitle_UTF8 = title
m_simpleTV.Control.CurrentAddress = url
