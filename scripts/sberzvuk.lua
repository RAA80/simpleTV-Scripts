-- script for sber-zvuk.com (30/07/2023)
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

if not string.match(inAdr, '//sber%-zvuk%.com/(.+)') and
   not string.match(inAdr, '//zvuk%.com/(.+)') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''    -- 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 10.0; rv:103.0) Gecko/20100101 Firefox/103.0', proxy, false)
if session == nil then return end

m_simpleTV.Http.SetTimeout(session, 10000)

---------------------------------------------------------------------------

local json = require "rxijson"


local function _send_request(session, method, address, body, header)
    local rc, answer = m_simpleTV.Http.Request(session, {method=method, url=address, body=body, headers=header})
    if rc ~= 200 then
        m_simpleTV.Http.Close(session)
        m_simpleTV.OSD.ShowMessage("Connection error: " .. rc, 255, 3)
        return
    end

    return answer
end

local function _get_token()
    local address = 'https://zvuk.com/api/tiny/profile'
    local answer = _send_request(session, 'get', address, nil, nil)
    local tab = json.decode(answer)

    return tab.result.token
end

local function _get_track(track_id, token)
    local address = 'https://zvuk.com/api/v1/graphql'
    local body = '{"operationName":"getStream","variables":{"isFlacDRM":false,"ids":[' .. track_id .. ']},"query":"query getStream($ids: [ID!]!, $isFlacDRM: Boolean = false) {\\n  mediaContents(ids: $ids) {\\n    ... on Track {\\n      stream {\\n        expire\\n        expireDelta\\n        high\\n        mid\\n        flacdrm @include(if: $isFlacDRM)\\n      }\\n    }\\n    ... on Episode {\\n      stream {\\n        expire\\n        expireDelta\\n        high\\n        mid\\n      }\\n    }\\n    ... on Chapter {\\n      stream {\\n        expire\\n        expireDelta\\n        high\\n        mid\\n      }\\n    }\\n  }\\n}\\n"}'
    local header = 'content-type: application/json\n' ..
                   'x-auth-token: ' .. token
    local answer = _send_request(session, 'post', address, body, header)
    local track = json.decode(answer)

    return track.data.mediaContents[1].stream.mid
end

local function _get_album(_table)
    local token = _get_token()

    local album = {}
    for i=1, #_table, 1 do
        album[i] = {}
        album[i].Id = i
        album[i].Name = _table[i].artist_names[1] .. " - " .. _table[i].title
        album[i].Address = _get_track(_table[i].id, token) .. '$OPT:no-gnutls-system-trust'

        m_simpleTV.OSD.ShowMessage("Read " .. i .. " of " .. #_table .. " tracks", 255, 2)
    end

    return album
end

local function _get_discography(_table)
    local discography = {}
    local index = 1
    for i=1, #_table, 1 do
        for j=1, #_table[i].releases, 1 do
            discography[index] = {}
            discography[index].Id = index
            discography[index].Name = _table[i].releases[j].type .. ": " .. _table[i].releases[j].title .. " (" .. _table[i].releases[j].releaseYear .. ")"
            discography[index].Address = _table[i].releases[j].id
            index = index + 1
        end
    end

    return discography
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


if string.match(inAdr, 'artist/(%d+)$') then
    inAdr = inAdr .. '/releases'
end

local answer = _send_request(session, 'get', inAdr, nil, nil)
local url, title
local data = string.match(answer, '<script id="__NEXT_DATA__".-({.-})</script>')
local tab = json.decode(data)

if string.match(inAdr, 'track/(%d+)$') or string.match(inAdr, 'release/(%d+)$') or string.match(inAdr, 'playlist/(%d+)$') or
   string.match(inAdr, 'episode/(%d+)$') or string.match(inAdr, 'podcast/(%d+)$') then
    if string.match(inAdr, 'track') then tab = {tab.props.pageProps.track}
    elseif string.match(inAdr, 'release') then tab = tab.props.pageProps.release.tracks
    elseif string.match(inAdr, 'playlist') then tab = tab.props.pageProps.playlist.tracks
    elseif string.match(inAdr, 'episode') then tab = {tab.props.pageProps.episode}
    elseif string.match(inAdr, 'podcast') then tab = tab.props.pageProps.podcast.episodes
    end

    local logo = tab[1].image.src
    local name = tab[1].release_title or tab[1].podcast_title
    local list = _get_album(tab)
    title, url = _show_select(logo, name, list, 0)

elseif string.match(inAdr, 'artist/(%d+)/releases$') then
    local logo = tab.props.pageProps.artistMeta.image.src
    local name = tab.props.pageProps.artistMeta.title
    local list = _get_discography(tab.props.pageProps.releaseBlocks)
    local _, album_id = _show_select(logo, name, list, 1)

    m_simpleTV.Control.PlayAddressT({address="https://zvuk.com/release/" .. album_id})
    return

end

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentTitle_UTF8 = title
m_simpleTV.Control.CurrentAddress = url
