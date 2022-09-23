-- script for music.yandex.com (23/09/2022)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://music.yandex.com/track/36213788
-- example: https://music.yandex.com/album/7571288
-- example: https://music.yandex.com/artist/189688
-- example: https://music.yandex.com/users/music-blog/playlists/2131


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, 'music%.yandex%.com/(.+)') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''    -- 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:104.0) Gecko/20100101 Firefox/104.0', proxy, false)
if session == nil then return end

m_simpleTV.Http.SetTimeout(session, 10000)

---------------------------------------------------------------------------

json = require "rxijson"


local function _get_year(_table)
    return _table.year ~= nil and " (" .. _table.year .. ") " or ""     -- аналог a==b ? true : false
end

local function _get_artist(_table)
    local artists = ""
    for i=1, #_table.artists, 1 do
        artists = artists .. _table.artists[i].name
        if i>=1 and i<#_table.artists then
            artists = artists .. ", "
        end
    end

    return artists
end

local function _get_title(_table)
    local version = _table.version ~= nil and " (" .. _table.version .. ")" or ""
    return _table.title .. version
end

local function _get_cover(_table)
    local cover = ""
    if _table.coverUri ~= nil then cover = _table.coverUri or ""
    elseif _table.cover ~= nil then cover = _table.cover.uri or ""
    end

    return string.gsub('http://' .. cover, "[%%]+", "200x200") or ""
end

local function _send_request(session, address, header)
    local err, answer = m_simpleTV.Http.Request(session, {url=address, headers=header})
    if err ~= 200 then
        m_simpleTV.Http.Close(session)
        m_simpleTV.OSD.ShowMessage("Connection error: " .. err, 255, 3)
        return
    end

    return answer
end

local function _get_track(track_id)
    local header = 'Authorization: OAuth ' .. 'AgAAAAAYLxRXAAG8XicUsn4Rw0Cyu29SHjX1ACQ'

    local address = 'https://api.music.yandex.net/tracks/' .. track_id .. '/download-info'
    local answer = _send_request(session, address, header)
    local track = json.decode(answer)

    local address = track.result[1].downloadInfoUrl .. '&format=json'
    local answer = _send_request(session, address, header)
    local track = json.decode(answer)

    local str = 'XGRlBW9FXlekgbPrRHuSiA' .. string.sub(track.path, 2) .. track.s
    local hash = m_simpleTV.Common.CryptographicHash(str, "Md5", true)

    return 'https://' .. track.host .. '/get-mp3/' .. hash .. '/' .. track.ts .. track.path
end

local function _get_album(_table)
    local album = {}
    for i=1, #_table, 1 do
        album[i] = {}
        album[i].Id = i
        album[i].Name = _get_artist(_table[i]) .. " - " .. _get_title(_table[i])
        album[i].Address = _get_track(_table[i].id)

        i = i + 1
    end

    return album
end

local function _get_discography(_table)
    table.sort(_table, function(a, b) if a.year and b.year then return a.year < b.year end
               end)
    local discography = {}
    for i=1, #_table, 1 do
        discography[i] = {}
        discography[i].Id = i
        discography[i].Name = _get_year(_table[i]) .. _get_artist(_table[i]) .. " - " .. _get_title(_table[i])
        discography[i].Address = _table[i].id

        i = i + 1
    end

    return discography
end

local function _get_playlist(_table)
    local playlist = {}
    for i=1, #_table, 1 do
        playlist[i] = {}
        playlist[i].Id = i
        playlist[i].Name = _get_artist(_table[i].track) .. ' - ' .. _get_title(_table[i].track)
        playlist[i].Address = _get_track(_table[i].track.id)

        i = i + 1
    end

    return playlist
end


local url = ""
local title = ""

if string.match(inAdr, '/track/%d+$') then
    local track_id = string.match(inAdr, 'track/(%d+)')
    url = _get_track(track_id)

elseif string.match(inAdr, '/album/%d+$') then
    local album_id = string.match(inAdr, 'album/(%d+)')
    local address = "https://api.music.yandex.net/albums/" .. album_id .. "/with-tracks"
    local answer = _send_request(session, address, "")
    local js_data = json.decode(answer)

    local name = _get_artist(js_data.result) .. " - " .. _get_title(js_data.result) .. _get_year(js_data.result)
    local album = _get_album(js_data.result.volumes[1])

    local _, id = m_simpleTV.OSD.ShowSelect_UTF8(name, 0, album, 10000, 0)
    if not id then id = 1 end

    if m_simpleTV.Control.MainMode == 0 then
        m_simpleTV.Control.ChangeChannelLogo(_get_cover(js_data.result), m_simpleTV.Control.ChannelID)
    end

    title = album[id].Name
    url = album[id].Address

elseif string.match(inAdr, '/artist/%d+$') or string.match(inAdr, '/artist/%d+/albums$') then
    local artist_id = string.match(inAdr, 'artist/(%d+)')
    local address = "https://api.music.yandex.net/artists/" .. artist_id .. "/direct-albums?page=0&page-size=100"
    local answer = _send_request(session, address, "")
    local js_data = json.decode(answer)

    if m_simpleTV.Control.MainMode == 0 then
        m_simpleTV.Control.ChangeChannelLogo(_get_cover(js_data.result.albums[1].artists[1]),
                                             m_simpleTV.Control.ChannelID, 'CHANGE_IF_NOT_EQUAL')
    end

    local discography = _get_discography(js_data.result.albums)

    local _, id = m_simpleTV.OSD.ShowSelect_UTF8("Discography", 0, discography, 10000, 1)
    if not id then id = 1 end

    m_simpleTV.Control.PlayAddressT({address="https://music.yandex.com/album/" .. discography[id].Address})

elseif string.match(inAdr, '/users/.-/playlists/%d+$') then
    local user_id = string.match(inAdr, '/users/(.-)/')
    local playlist_id = string.match(inAdr, '/playlists/(%d+)')
    local address = 'https://api.music.yandex.net/users/' .. user_id .. '/playlists/' .. playlist_id
    local answer = _send_request(session, address, "")
    local js_data = json.decode(answer)

    local name = js_data.result.title
    local playlist = _get_playlist(js_data.result.tracks)

    local _, id = m_simpleTV.OSD.ShowSelect_UTF8(name, 0, playlist, 10000, 0)
    if not id then id = 1 end

    if m_simpleTV.Control.MainMode == 0 then
        m_simpleTV.Control.ChangeChannelLogo(_get_cover(js_data.result), m_simpleTV.Control.ChannelID)
    end

    title = playlist[id].Name
    url = playlist[id].Address

end

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentTitle_UTF8 = title
m_simpleTV.Control.CurrentAddress = url
