-- script for sber-zvuk.com (24/12/2022)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://sber-zvuk.com/track/66985389
-- example: https://sber-zvuk.com/release/10264599
-- example: https://sber-zvuk.com/artist/521621
-- example: https://sber-zvuk.com/playlist/7222566


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, '//sber%-zvuk%.com/(.+)') and
   not string.match(inAdr, '//zvuk%.com/(.+)') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''    -- 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML,like Gecko) Chrome/79.0.2785.143 Safari/537.36', proxy, false)
if session == nil then return end

m_simpleTV.Http.SetTimeout(session, 30000)

---------------------------------------------------------------------------

json = require "rxijson"


local function _send_request(session, address)
    local rc, answer = m_simpleTV.Http.Request(session, {url=address})
    if rc ~= 200 then
        m_simpleTV.Http.Close(session)
        m_simpleTV.OSD.ShowMessage("Connection error: " .. rc, 255, 3)
        return
    end

    return answer
end

local function _get_track(track_id)
    local address = "https://sber-zvuk.com/api/tiny/track/stream?id=" .. track_id .. "&quality=high"
    local answer = _send_request(session, address)
    local track = json.decode(answer)

    return track.result.stream
end

local function _get_album(js_data)
    local album = {}
    for i=1, #js_data, 1 do
        album[i] = {}
        album[i].Id = i
        album[i].Name = js_data[i].artist_names[1] .. " - " .. js_data[i].title
        album[i].Address = _get_track(js_data[i].id) .. '$OPT:no-gnutls-system-trust'

        m_simpleTV.OSD.ShowMessage("Read " .. i .. " of " .. #js_data .. " tracks", 255, 2)
        i = i + 1

        m_simpleTV.Common.Sleep(5000)
    end

    return album
end

local function _get_discography(table_type)
    table.sort(table_type, function(a, b)   -- сортировка по типу и по году
        return (a.type < b.type) or (a.type == b.type and a.releaseYear < b.releaseYear) end)

    local _table = {}
    for i=1, #table_type, 1 do
        _table[i] = {}
        _table[i].Id = i
        _table[i].Name = table_type[i].type .. ": " .. table_type[i].title .. " (" .. table_type[i].releaseYear .. ")"
        _table[i].Address = table_type[i].id

        i = i + 1
    end

    return _table
end


local answer = _send_request(session, inAdr)
local title = string.match(answer, '"og:title" content="(.-)"/>')

if string.match(inAdr, 'track') or string.match(inAdr, 'release') or string.match(inAdr, 'playlist') then
    local data = string.match(answer, '<script id="__NEXT_DATA__".-({.-})</script>')
    local js_data = json.decode(data)

    if string.match(inAdr, 'track') then js_data = {js_data.props.pageProps.track}
    elseif string.match(inAdr, 'release') then js_data = js_data.props.pageProps.release.tracks
    elseif string.match(inAdr, 'playlist') then js_data = js_data.props.pageProps.playlist.tracks
    end

    local album = _get_album(js_data)

    local _, id = m_simpleTV.OSD.ShowSelect_UTF8(title, 0, album, 10000, 0)
    if not id then id = 1 end

    if m_simpleTV.Control.MainMode == 0 then
        local cover = string.gsub(js_data[1].image.src, "{size}", "200x200") or ""
        m_simpleTV.Control.ChangeChannelLogo(cover, m_simpleTV.Control.ChannelID)
    end

    url = album[id].Address
    title = album[id].Name

elseif string.match(inAdr, 'artist') then
    local data = string.match(answer, '<script id="__NEXT_DATA__".-({.-})</script>')
    local js_data = json.decode(data)

    if m_simpleTV.Control.MainMode == 0 then
        local poster = string.gsub(js_data.props.pageProps.data.image.src, "{size}", "200x200") or ""
        m_simpleTV.Control.ChangeChannelLogo(poster, m_simpleTV.Control.ChannelID, 'CHANGE_IF_NOT_EQUAL')
    end

    local discography = _get_discography(js_data.props.pageProps.data.additionalData.releases)

    local _, id = m_simpleTV.OSD.ShowSelect_UTF8(title, 0, discography, 10000, 1)
    if not id then id = 1 end

    m_simpleTV.Control.PlayAddressT({address="https://sber-zvuk.com/release/" .. discography[id].Address})

end

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentTitle_UTF8 = title
m_simpleTV.Control.CurrentAddress = url
