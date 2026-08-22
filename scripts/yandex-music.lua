-- script for music.yandex.com (22/08/2026)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://music.yandex.com/track/52944518
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

local json = require "rxijson"
local header = 'Authorization: OAuth AgAAAAAYLxRXAAG8XicUsn4Rw0Cyu29SHjX1ACQ'


local function _get_year(_table)
    return _table.year and " (" .. _table.year .. ") " or ""
end

local function _get_artist(_table)
    local artists = {}
    for i=1, #_table.artists, 1 do
        table.insert(artists, _table.artists[i].name)
    end

    return table.concat(artists, ", ")
end

local function _get_title(_table)
    local version = _table.version and " (" .. _table.version .. ")" or ""
    return _table.title .. version
end

local function _get_cover(_table)
    local cover = _table.coverUri or _table.cover and _table.cover.uri or ""
    return string.gsub('http://' .. cover, "[%%]+", "200x200") or ""
end

local function _send_request(session, address)
    local err, answer = m_simpleTV.Http.Request(session, {url=address, headers=header})
    if err ~= 200 then
        m_simpleTV.Http.Close(session)
        m_simpleTV.OSD.ShowMessage("Connection error: " .. err, 255, 3)
        return
    end

    return json.decode(answer)
end

local function _set_panel_logo(url)
    if m_simpleTV.Control.MainMode == 0 then
        m_simpleTV.Control.ChangeChannelLogo(_get_cover(url), m_simpleTV.Control.ChannelID, 'CHANGE_IF_NOT_EQUAL')
    end
end

local function _get_page(pattern, prefix, suffix)
    local id1, id2 = string.match(inAdr, pattern)
    local address = "https://api.music.yandex.net/" .. (prefix or "") .. id1 .. (suffix or "") .. (id2 or "")

    return _send_request(session, address)
end

local function _show_select(logo, name, list, mode)
    _set_panel_logo(logo)
    local _, id = m_simpleTV.OSD.ShowSelect_UTF8(name, -1, list, 10000, mode)

    m_simpleTV.Control.ChangeAddress = 'Yes'
    m_simpleTV.Control.CurrentAddress = "wait"

    return id
end

local function _get_track(info)
    local track = _get_page("track/(%d+)", "tracks/", "/download-info")

    local address = track.result[1].downloadInfoUrl .. '&format=json'
    local track = _send_request(session, address)

    local str = 'XGRlBW9FXlekgbPrRHuSiA' .. string.sub(track.path, 2) .. track.s
    local hash = m_simpleTV.Common.CryptographicHash(str, "Md5", true)

    m_simpleTV.Control.CurrentTitle_UTF8 = _get_artist(info.result[1]) .. " - " .. _get_title(info.result[1])
    m_simpleTV.Control.CurrentAddress = 'https://' .. track.host .. '/get-mp3/' .. hash .. '/' .. track.ts .. track.path .. '$OPT:demux=mp4,any'
end

local function _get_album(tab)
    local name = _get_artist(tab.result) .. " - " .. _get_title(tab.result) .. _get_year(tab.result)

    local album = {}
    local index = 1
    local _table = tab.result.volumes

    for cd=1, #_table, 1 do
        for i=1, #_table[cd], 1 do
            album[index] = {}
            album[index].Id = index
            album[index].Name = _get_artist(_table[cd][i]) .. " - " .. _get_title(_table[cd][i])
            album[index].Address = "https://music.yandex.com/track/" .. _table[cd][i].id
            index = index + 1
        end
    end

    _show_select(tab.result, name, album, 2)
end

local function _get_playlist(tab)
    local name = tab.result.title

    local playlist = {}
    local _table = tab.result.tracks

    for i=1, #_table, 1 do
        playlist[i] = {}
        playlist[i].Id = i
        playlist[i].Name = _get_artist(_table[i].track) .. ' - ' .. _get_title(_table[i].track)
        playlist[i].Address = "https://music.yandex.com/track/" .. _table[i].track.id
    end

    _show_select(tab.result, name, playlist, 2)
end

local function _get_discography(tab)
    local discography = {}
    local _table = tab.result.albums

    for i=1, #_table, 1 do
        discography[i] = {}
        discography[i].Id = i
        discography[i].Name = _get_year(_table[i]) .. _get_artist(_table[i]) .. " - " .. _get_title(_table[i])
        discography[i].Address = "https://music.yandex.com/album/" .. _table[i].id
    end

    local id = _show_select(_table[1].artists[1], "Discography", discography, 1)
    m_simpleTV.Control.PlayAddressT({address=discography[id or 1].Address})
end


local key = string.match(inAdr, ".*/(%a+)/%d+")
local handle = ({track     = {func = _get_track,       args = {"/track/(%d+)", "tracks/", ""}},
                 album     = {func = _get_album,       args = {'/album/(%d+)', "albums/", "/with-tracks"}},
                 playlists = {func = _get_playlist,    args = {'/users/(.-)/playlists/(%d+)', "users/", "/playlists/"}},
                 artist    = {func = _get_discography, args = {'/artist/(%d+)', "artists/", "/direct-albums?sort_by=year"}},
                 label     = {func = _get_discography, args = {'/label/(%d+)', "labels/", "/albums?sort_by=year"}}
               })[key]
local tab = _get_page(unpack(handle.args))
handle.func(tab)

m_simpleTV.Http.Close(session)
