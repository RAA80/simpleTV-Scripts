-- script for sber-zvuk.com (21/01/2023)
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

m_simpleTV.Http.SetTimeout(session, 10000)

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

local function _get_album(_table)
    local album = {}
    for i=1, #_table, 1 do
        album[i] = {}
        album[i].Id = i
        album[i].Name = _table[i].artist_names[1] .. " - " .. _table[i].title
        album[i].Address = _get_track(_table[i].id) .. '$OPT:no-gnutls-system-trust'

        m_simpleTV.OSD.ShowMessage("Read " .. i .. " of " .. #_table .. " tracks", 255, 2)
        m_simpleTV.Common.Sleep(5000)
    end

    return album
end

local function _get_discography(_table)
    table.sort(_table, function(a, b)   -- сортировка по типу и по году
        return (a.type < b.type) or (a.type == b.type and a.releaseYear < b.releaseYear) end)

    local discography = {}
    for i=1, #_table, 1 do
        discography[i] = {}
        discography[i].Id = i
        discography[i].Name = _table[i].type .. ": " .. _table[i].title .. " (" .. _table[i].releaseYear .. ")"
        discography[i].Address = _table[i].id
    end

    return discography
end

local function _set_panel_logo(url)
    if m_simpleTV.Control.MainMode == 0 then
        local cover = string.gsub(url, "{size}", "200x200") or ""
        m_simpleTV.Control.ChangeChannelLogo(cover, m_simpleTV.Control.ChannelID, 'CHANGE_IF_NOT_EQUAL')
    end
end

local function _show_select(name, list, mode)
    local _, id = m_simpleTV.OSD.ShowSelect_UTF8(name, 0, list, 10000, mode)
    if not id then id = 1 end

    return list[id].Name, list[id].Address
end


local answer = _send_request(session, inAdr)
local title = string.match(answer, '"og:title" content="(.-)"/>')
local data = string.match(answer, '<script id="__NEXT_DATA__".-({.-})</script>')
local tab = json.decode(data)

if string.match(inAdr, 'track') or string.match(inAdr, 'release') or string.match(inAdr, 'playlist') then
    if string.match(inAdr, 'track') then tab = {tab.props.pageProps.track}
    elseif string.match(inAdr, 'release') then tab = tab.props.pageProps.release.tracks
    elseif string.match(inAdr, 'playlist') then tab = tab.props.pageProps.playlist.tracks
    end

    local list = _get_album(tab)
    _set_panel_logo(tab[1].image.src)
    title, url = _show_select(title, list, 0)

elseif string.match(inAdr, 'artist') then
    local list = _get_discography(tab.props.pageProps.data.additionalData.releases)
    _set_panel_logo(tab.props.pageProps.data.image.src)
    local _, album_id = _show_select(title, list, 1)

    m_simpleTV.Control.PlayAddressT({address="https://sber-zvuk.com/release/" .. album_id})

end

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentTitle_UTF8 = title
m_simpleTV.Control.CurrentAddress = url
