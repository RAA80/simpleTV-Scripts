-- script for music.yandex.com (22/04/2023)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://music.yandex.com/track/36213788
-- example: https://music.yandex.com/album/7571288
-- example: https://music.yandex.com/artist/189688
-- example: https://music.yandex.com/users/music-blog/playlists/2131
-- example: https://music.yandex.com/label/2399


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, '//music%.yandex%.com/(.+)') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''    -- 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 10.0; rv:103.0) Gecko/20100101 Firefox/103.0', proxy, false)
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
    local cover = _table.coverUri ~= nil and _table.coverUri or
                  _table.cover ~= nil and _table.cover.uri or ""

    return string.gsub('http://' .. cover, "[%%]+", "200x200") or ""
end

local function _send_request(session, address, header)
    local err, answer = m_simpleTV.Http.Request(session, {url=address, headers=header})
    if err ~= 200 then
        m_simpleTV.Http.Close(session)
        m_simpleTV.OSD.ShowMessage("Connection error: " .. err, 255, 3)
        return
    end

    return json.decode(answer)
end

local function _get_track(track_id)
    local header = 'Authorization: OAuth AgAAAAAYLxRXAAG8XicUsn4Rw0Cyu29SHjX1ACQ'

    local address = 'https://api.music.yandex.net/tracks/' .. track_id .. '/download-info'
    local track = _send_request(session, address, header)

    local address = track.result[1].downloadInfoUrl .. '&format=json'
    local track = _send_request(session, address, header)

    local str = 'XGRlBW9FXlekgbPrRHuSiA' .. string.sub(track.path, 2) .. track.s
    local hash = m_simpleTV.Common.CryptographicHash(str, "Md5", true)

    return 'https://' .. track.host .. '/get-mp3/' .. hash .. '/' .. track.ts .. track.path
end

local function _get_album(_table)
    local album = {}
    local index = 1
    for cd=1, #_table, 1 do
        for i=1, #_table[cd], 1 do
            album[index] = {}
            album[index].Id = index
            album[index].Name = _get_artist(_table[cd][i]) .. " - " .. _get_title(_table[cd][i])
            album[index].Address = _get_track(_table[cd][i].id)
            index = index + 1
        end
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
    end

    return playlist
end

local function _set_panel_logo(url)
    if m_simpleTV.Control.MainMode == 0 then
        m_simpleTV.Control.ChangeChannelLogo(_get_cover(url), m_simpleTV.Control.ChannelID, 'CHANGE_IF_NOT_EQUAL')
    end
end

local function _show_select(name, list, mode)
    local _, id = m_simpleTV.OSD.ShowSelect_UTF8(name, 0, list, 10000, mode)
    if not id then id = 1 end

    return list[id].Name, list[id].Address
end


local url = ""
local title = ""

if string.match(inAdr, '/track/%d+$') then
    local id = string.match(inAdr, 'track/(%d+)')
    url = _get_track(id)

elseif string.match(inAdr, '/album/%d+$') then
    local id = string.match(inAdr, 'album/(%d+)')
    local address = "https://api.music.yandex.net/albums/" .. id .. "/with-tracks"
    local tab = _send_request(session, address, "")
    local name = _get_artist(tab.result) .. " - " .. _get_title(tab.result) .. _get_year(tab.result)
    local list = _get_album(tab.result.volumes)

    _set_panel_logo(tab.result)
    title, url = _show_select(name, list, 0)

elseif string.match(inAdr, '/artist/%d+$') or string.match(inAdr, '/artist/%d+/albums$') then
    local id = string.match(inAdr, 'artist/(%d+)')
    local address = "https://api.music.yandex.net/artists/" .. id .. "/direct-albums?page=0&page-size=100"
    local tab = _send_request(session, address, "")
    local name = "Discography"
    local list = _get_discography(tab.result.albums)

    _set_panel_logo(tab.result.albums[1].artists[1])
    local _, album_id = _show_select(name, list, 1)

    m_simpleTV.Control.PlayAddressT({address="https://music.yandex.com/album/" .. album_id})

elseif string.match(inAdr, '/users/.-/playlists/%d+$') then
    local playlist_id = string.match(inAdr, '/playlists/(%d+)')
    local id = string.match(inAdr, '/users/(.-)/')
    local address = 'https://api.music.yandex.net/users/' .. id .. '/playlists/' .. playlist_id
    local tab = _send_request(session, address, "")
    local name = tab.result.title
    local list = _get_playlist(tab.result.tracks)

    _set_panel_logo(tab.result)
    title, url = _show_select(name, list, 0)

elseif string.match(inAdr, '/label/%d+$') then
    local id = string.match(inAdr, 'label/(%d+)')
    local address = "https://api.music.yandex.net/labels/" .. id .."/albums"
    local tab = _send_request(session, address, "")
    local name = "Label"
    local list = _get_discography(tab.result.albums)

    _set_panel_logo(tab.result.albums[1].artists[1])
    local _, album_id = _show_select(name, list, 1)

    m_simpleTV.Control.PlayAddressT({address="https://music.yandex.com/album/" .. album_id})

end

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentTitle_UTF8 = title
m_simpleTV.Control.CurrentAddress = url
