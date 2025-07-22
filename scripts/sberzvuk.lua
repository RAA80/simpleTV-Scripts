-- script for zvuk.com (22/07/2025)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://zvuk.com/track/66985389
-- example: https://zvuk.com/release/10264599
-- example: https://zvuk.com/artist/521621
-- example: https://zvuk.com/playlist/7222566
-- example: https://zvuk.com/episode/90195375
-- example: https://zvuk.com/podcast/20762002


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, '//zvuk%.com/(.+)') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''    -- 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 10.0; rv:103.0) Gecko/20100101 Firefox/103.0', proxy, false)
if session == nil then return end

m_simpleTV.Http.SetTimeout(session, 20000)

---------------------------------------------------------------------------

local json = require "rxijson"


local function _send_request(session, method, address, body, header)
    local rc, answer = m_simpleTV.Http.Request(session, {method=method, url=address, body=body, headers=header})
    if rc ~= 200 then
        m_simpleTV.Http.Close(session)
        m_simpleTV.OSD.ShowMessage("Connection error: " .. rc, 255, 3)
        return
    end

    return json.decode(answer)
end

local function _get_token()
    local address = 'https://zvuk.com/api/tiny/profile'
    local tab = _send_request(session, 'get', address, nil, nil)

    return tab.result.token
end

local function _get_artist(_table)
    local artists = {}
    for i=1, #_table, 1 do
        table.insert(artists, _table[i])
    end

    return table.concat(artists, ", ")
end

local function _get_track(id, token)
    local address = 'https://zvuk.com/api/v1/graphql'
    local body = '{"operationName":"getStream","variables":{"isFlacDRM":false,"ids":[' .. id .. ']},"query":"query getStream($ids: [ID!]!, $isFlacDRM: Boolean = false) {\\n  mediaContents(ids: $ids) {\\n    ... on Track {\\n      stream {\\n        expire\\n        expireDelta\\n        high\\n        mid\\n        flacdrm @include(if: $isFlacDRM)\\n      }\\n    }\\n    ... on Episode {\\n      stream {\\n        expire\\n        expireDelta\\n        high\\n        mid\\n      }\\n    }\\n    ... on Chapter {\\n      stream {\\n        expire\\n        expireDelta\\n        high\\n        mid\\n      }\\n    }\\n  }\\n}\\n"}'
    local header = 'content-type: application/json\n' ..
                   'x-auth-token: ' .. token
    local tab = _send_request(session, 'post', address, body, header)

    return tab.data.mediaContents[1].stream.mid
end

local function _get_album(id, token)
    local address = 'https://zvuk.com/api/tiny/releases?ids=' .. id .. '&include=track'
    local tab = _send_request(session, 'get', address, nil, nil)

    local _table = tab.result.releases[id].track_ids
    local tracks = tab.result.tracks
    local logo = tab.result.releases[id].image.src
    local name = _get_artist(tab.result.releases[id].artist_names) .. " - " .. tab.result.releases[id].title

    local album = {}
    for i=1, #_table, 1 do
        album[i] = {}
        album[i].Id = i
        album[i].Name = _get_artist(tracks[tostring(_table[i])].artist_names) .. " - " .. tracks[tostring(_table[i])].title
        album[i].Address = _get_track(_table[i], token) .. '$OPT:no-gnutls-system-trust'
    end

    return logo, name, album
end

local function _get_playlist(id, token)
    local address = 'https://zvuk.com/api/tiny/playlists?ids=' .. id .. '&include=track'
    local tab = _send_request(session, 'get', address, nil, nil)

    local _table = tab.result.playlists[id].track_ids
    local tracks = tab.result.tracks
    local logo = "https://zvuk.com" .. tab.result.playlists[id].image.src
    local name = tab.result.playlists[id].title

    local playlist = {}
    for i=1, #_table, 1 do
        playlist[i] = {}
        playlist[i].Id = i
        playlist[i].Name = _get_artist(tracks[tostring(_table[i])].artist_names) .. " - " .. tracks[tostring(_table[i])].title
        playlist[i].Address = _get_track(_table[i], token) .. '$OPT:no-gnutls-system-trust'
    end

    return logo, name, playlist
end

local function _get_podcast(id, token)
    local address = 'https://zvuk.com/api/tiny/podcasts?ids=' .. id
    local tab = _send_request(session, 'get', address, nil, nil)

    local _table = tab.result.podcasts[id].episode_ids
    local tracks = tab.result.episodes
    local logo = tab.result.podcasts[id].image.src
    local name = tab.result.podcasts[id].title

    local podcast = {}
    for i=1, #_table, 1 do
        podcast[i] = {}
        podcast[i].Id = i
        podcast[i].Name = _get_artist(tracks[tostring(_table[i])].author_names) .. " - " .. tracks[tostring(_table[i])].title
        podcast[i].Address = _get_track(_table[i], token) .. '$OPT:no-gnutls-system-trust'
    end

    return logo, name, podcast
end

local function _get_discography(id)
    local address = 'https://zvuk.com/api/tiny/artists/releases?ids=' .. id .. "&limit=1000"
    local tab = _send_request(session, 'get', address, nil, nil)

    local _table = tab.result.ids[id]

    local address = 'https://zvuk.com/api/tiny/artists?ids=' .. id
    local tab = _send_request(session, 'get', address, nil, nil)

    local logo = tab.result.artists[id].image.src
    local name = tab.result.artists[id].title

    local discography = {}
    local j = 1
    for i=1, #_table, 1 do
        local address = 'https://zvuk.com/api/tiny/releases?ids=' .. _table[i]
        local tab = _send_request(session, 'get', address, nil, nil)

        if next(tab and tab.result.releases) ~= nil then
            local title = tab.result.releases[tostring(_table[i])].title
            local date = string.sub(tab.result.releases[tostring(_table[i])].date, 1, 4)
            local type_ = tab.result.releases[tostring(_table[i])].type

            discography[j] = {}
            discography[j].Id = j
            discography[j].Name = type_ .. ": " .. title .. " (" .. date .. ")"
            discography[j].Address = 'https://zvuk.com/release/' .. _table[i]

            j = j + 1
        end
    end

    return logo, name, discography
end

local function _set_panel_logo(url)
    if m_simpleTV.Control.MainMode == 0 then
        local cover = string.gsub(url, "{size}", "200x200") or ""
        m_simpleTV.Control.ChangeChannelLogo(cover, m_simpleTV.Control.ChannelID, 'CHANGE_IF_NOT_EQUAL')
    end
end

local function _show_select(url, name, list, mode)
    _set_panel_logo(url)
    local _, id = m_simpleTV.OSD.ShowSelect_UTF8(name, 0, list, 10000, mode)

    return list[id or 1].Name, list[id or 1].Address
end


local url, title = ""
local token = _get_token()

if string.match(inAdr, 'track/(%d+)$') or string.match(inAdr, 'episode/(%d+)$') then
    local id = string.match(inAdr, 'track/(%d+)$') or string.match(inAdr, 'episode/(%d+)$')
    url = _get_track(id, token)
elseif string.match(inAdr, 'release/(%d+)$') then
    local id = string.match(inAdr, 'release/(%d+)$')
    logo, name, album = _get_album(id, token)
    title, url = _show_select(logo, name, album, 0)
elseif string.match(inAdr, 'playlist/(%d+)$') then
    local id = string.match(inAdr, 'playlist/(%d+)$')
    logo, name, playlist = _get_playlist(id, token)
    title, url = _show_select(logo, name, playlist, 0)
elseif string.match(inAdr, 'podcast/(%d+)$') then
    local id = string.match(inAdr, 'podcast/(%d+)$')
    logo, name, podcast = _get_podcast(id, token)
    title, url = _show_select(logo, name, podcast, 0)
elseif string.match(inAdr, 'artist/(%d+)$') then
    local id = string.match(inAdr, 'artist/(%d+)$')
    logo, name, discography = _get_discography(id)
    title, url = _show_select(logo, name, discography, 1)

    m_simpleTV.Control.PlayAddressT({address=url})
    return
end

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentTitle_UTF8 = title
m_simpleTV.Control.CurrentAddress = url
