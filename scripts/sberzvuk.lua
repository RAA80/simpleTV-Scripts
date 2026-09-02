-- script for zvuk.com (01/09/2026)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://zvuk.com/track/66985389
--          https://zvuk.com/release/10264599
--          https://zvuk.com/artist/521621
--          https://zvuk.com/playlist/7222566
--          https://zvuk.com/episode/90195375
--          https://zvuk.com/podcast/20762002


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, '//zvuk%.com/(.+)') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''    -- 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0', proxy, false)
if session == nil then return end

m_simpleTV.Http.SetTimeout(session, 20000)

------------------------------- Settings --------------------------------------

local token = nil   -- "your token" or nil

-------------------------------------------------------------------------------

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

local function _set_panel_logo(url)
    if m_simpleTV.Control.MainMode == 0 then
        local cover = string.gsub(url, "{size}", "200x200") or ""
        m_simpleTV.Control.ChangeChannelLogo(cover, m_simpleTV.Control.ChannelID, 'CHANGE_IF_NOT_EQUAL')
    end
end

local function _show_select(url, name, list, mode)
    _set_panel_logo(url)
    return m_simpleTV.OSD.ShowSelect_UTF8(name, -1, list, 10000, mode)
end

local function _get_token()
    local address = 'https://zvuk.com/api/v2/tiny/profile'
    local tab = _send_request(session, 'get', address, nil, nil)

    return tab.result.profile.token
end

local function _get_artist(_table)
    local artists = {}
    for i=1, #_table, 1 do
        table.insert(artists, _table[i])
    end

    return table.concat(artists, ", ")
end

local function _create_table(tab, tracks, logo, name)
    local list = {}
    for i=1, #tab, 1 do
        list[i] = {Id = i,
                   Name = _get_artist(tracks[tostring(tab[i])].artist_names or tracks[tostring(tab[i])].author_names) .. " - " .. tracks[tostring(tab[i])].title,
                   Address = 'https://zvuk.com/track/' .. tab[i]}
    end

    _show_select(logo, name, list, 2)

    m_simpleTV.Control.ChangeAddress = 'Yes'
    m_simpleTV.Control.CurrentAddress = "wait"
end

local function _get_discography(id, header)
    local address = 'https://zvuk.com/api/tiny/artists/releases?ids=' .. id .. "&limit=1000&include=release"
    local tab = _send_request(session, 'get', address, nil, header)

    local _table = tab.result.ids[id]
    local logo = 'https://cdn-image.zvuk.com/pic?id='.. id .. '&size=large&type=artist'
    local name = "Discography"

    local address = 'https://zvuk.com/api/tiny/releases?ids=' .. _get_artist(_table)
    local tab = _send_request(session, 'get', address, nil, header)

    local i = 1
    local list = {}
    for key, value in pairs(tab.result.releases) do
        local title = value.title
        local date = string.sub(value.date, 1, 4)
        local type_ = value.type

        list[i] = {Id = i,
                   Name = type_ .. ": " .. title .. " (" .. date .. ")",
                   Address = 'https://zvuk.com/release/' .. value.id}
        i = i + 1
    end

    local _, idx = m_simpleTV.OSD.ShowSelect_UTF8(name, 0, list, 10000, 3)
    return m_simpleTV.Control.PlayAddressT({address=list[idx or 1].Address})
end

local function _get_album(id, header)
    local address = 'https://zvuk.com/api/tiny/releases?ids=' .. id .. '&include=track'
    local tab = _send_request(session, 'get', address, nil, header)

    local _table = tab.result.releases[id].track_ids
    local tracks = tab.result.tracks
    local logo = tab.result.releases[id].image.src
    local name = _get_artist(tab.result.releases[id].artist_names) .. " - " .. tab.result.releases[id].title

    return _create_table(_table, tracks, logo, name)
end

local function _get_playlist(id, header)
    local address = 'https://zvuk.com/api/tiny/playlists?ids=' .. id .. '&include=track'
    local tab = _send_request(session, 'get', address, nil, header)

    local _table = tab.result.playlists[id].track_ids
    local tracks = tab.result.tracks
    local logo = "https://zvuk.com" .. tab.result.playlists[id].image.src
    local name = tab.result.playlists[id].title

    return _create_table(_table, tracks, logo, name)
end

local function _get_podcast(id, header)
    local address = 'https://zvuk.com/api/tiny/podcasts?ids=' .. id
    local tab = _send_request(session, 'get', address, nil, header)

    local _table = tab.result.podcasts[id].episode_ids
    local tracks = tab.result.episodes
    local logo = tab.result.podcasts[id].image.src
    local name = tab.result.podcasts[id].title

    return _create_table(_table, tracks, logo, name)
end

local function _get_track(id, header)
    local address = 'https://zvuk.com/api/v1/graphql'
    local body = '{"operationName":"GetTracks","variables":{"isFlacDRM":false,"ids":[' .. id .. ']},"query":"query GetTracks($ids: [ID!]!) {\\n    getTracks(ids: $ids) {\\n        id\\n        title\\n        searchTitle\\n        position\\n        duration\\n        availability\\n        artistTemplate\\n        condition\\n        explicit\\n        lyrics\\n        zchan\\n        hasFlac\\n        artists {\\n            id\\n            title\\n            image {\\n                src\\n                palette\\n                paletteBottom\\n            }\\n        }\\n        release {\\n            id\\n            title\\n            image {\\n                src\\n                palette\\n                paletteBottom\\n            }\\n        }\\n    }\\n}\\n"}'
    local tab1 = _send_request(session, 'post', address, body, header)

    local _table = tab1.data.getTracks[1].artists
    local artists = {}
    for i=1, #_table, 1 do
        table.insert(artists, _table[i].title)
    end
    local artist = table.concat(artists, ", ")

    local body = '{"operationName":"getStream","variables":{"isFlacDRM":false,"ids":[' .. id .. ']},"query":"query getStream($ids: [ID!]!, $isFlacDRM: Boolean = false) {\\n  mediaContents(ids: $ids) {\\n    ... on Track {\\n      stream {\\n        expire\\n        expireDelta\\n        high\\n        mid\\n        flacdrm @include(if: $isFlacDRM)\\n      }\\n    }\\n    ... on Episode {\\n      stream {\\n        expire\\n        expireDelta\\n        high\\n        mid\\n      }\\n    }\\n    ... on Chapter {\\n      stream {\\n        expire\\n        expireDelta\\n        high\\n        mid\\n      }\\n    }\\n  }\\n}\\n"}'
    local tab2 = _send_request(session, 'post', address, body, header)

    m_simpleTV.Control.CurrentTitle_UTF8 = artist .. " - " .. tab1.data.getTracks[1].title
    m_simpleTV.Control.CurrentAddress = tab2.data.mediaContents[1].stream.mid .. '$OPT:no-gnutls-system-trust'
end


local header = 'content-type: application/json\n' ..
               'Referer: https://zvuk.com/\n' ..
               'Origin: https://zvuk.com/\n' ..
               'x-auth-token: ' .. (token or _get_token())
local handlers = {track=_get_track,
                  episode=_get_track,
                  release=_get_album,
                  playlist=_get_playlist,
                  podcast=_get_podcast,
                  artist=_get_discography}
local frmt, id = string.match(inAdr, "https?://zvuk%.com/([%w/]+)/(%d+)")
handlers[frmt](id, header)

m_simpleTV.Http.Close(session)
