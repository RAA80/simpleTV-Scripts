-- script for vk.com (26/07/2023)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://vk.com/video68015256_456239307
-- example: https://vk.com/video-24136539_456239830


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, '//vk%.ru/(.+)') and
   not string.match(inAdr, '//m%.vk%.ru/(.+)') and
   not string.match(inAdr, '//vk%.com/(.+)') and
   not string.match(inAdr, '//m%.vk%.com/(.+)') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''    -- 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML,like Gecko) Chrome/79.0.2785.143 Safari/537.36', proxy, false)
if session == nil then return end

m_simpleTV.Http.SetTimeout(session, 10000)

---------------------------------------------------------------------------

local json = require "rxijson"
local htmlEntities = require 'htmlEntities'

inAdr = string.gsub(inAdr, '&id=', '_')
local video_id = string.match(inAdr, '[%a=](%-?%d+_%d+)') or ''
local list_id = string.match(inAdr, 'list=([^&]+)') or ''
local playlist_id = string.match(inAdr, '/playlist/(%-?%d+_%d+)') or ''

local body = 'act=show&al=1&claim=&dmcah=&hd=&list=' .. list_id ..
             '&load_playlist=1&module=direct&playlist_id=' .. playlist_id ..
             '&show_original=&t=&video=' .. video_id
local headers = 'X-Requested-With: XMLHttpRequest\nReferer: ' .. inAdr
local inAdr = 'https://vk.com/al_video.php'

local rc, answer = m_simpleTV.Http.Request(session, {url=inAdr, method='post', body=body, headers=headers})
if rc ~= 200 then
    m_simpleTV.Http.Close(session)
    m_simpleTV.OSD.ShowMessage("Connection error: " .. rc, 255, 3)
    return
end

local data = json.decode(answer)
local url = data.payload[2][5].player.params[1].hls or
            data.payload[2][5].player.params[1].hls_ondemand
local title = data.payload[2][5].player.params[1].md_title

title = m_simpleTV.Common.multiByteToUTF8(title)
title = htmlEntities.decode(title)

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentTitle_UTF8 = title
m_simpleTV.Control.CurrentAddress = url
