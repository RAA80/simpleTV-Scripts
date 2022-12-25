-- script for matchtv.ru (25/12/2022)
-- https://github.com/RAA80/simpleTV-Scripts

-- example: https://matchtv.ru/on-air
-- example: https://matchtv.ru/channel/matchtv
-- example: https://matchtv.ru/channel/strana


if m_simpleTV.Control.ChangeAddress ~= 'No' then return end

local inAdr = m_simpleTV.Control.CurrentAddress
if inAdr == nil then return end

if not string.match(inAdr, '//matchtv%.ru/') then return end

m_simpleTV.Control.ChangeAddress = 'Yes'
m_simpleTV.Control.CurrentAddress = ''

local proxy = ''    -- 'http://proxy-nossl.antizapret.prostovpn.org:29976'
local session = m_simpleTV.Http.New('Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:104.0) Gecko/20100101 Firefox/104.0', proxy, false)
if session == nil then return end

m_simpleTV.Http.SetTimeout(session, 10000)

---------------------------------------------------------------------------

local function _send_request(session, address)
    local err, answer = m_simpleTV.Http.Request(session, {url=address})
    if err ~= 200 then
        m_simpleTV.Http.Close(session)
        m_simpleTV.OSD.ShowMessage("Connection error: " .. err, 255, 3)
        return
    end

    return answer
end

local url = inAdr
for _, expr in ipairs({'<div class="video%-player.-src="([^"]+)',
                       '"config%=(.-)"',
                       '<video_hd><!%[CDATA%[(.-)%]%]',
                       '<track .-><!%[CDATA%[(.-)%]%]></track>'
                     }) do
    local answer = _send_request(session, url)
    url = string.match(answer, expr)
end

m_simpleTV.Http.Close(session)
m_simpleTV.Control.CurrentAddress = url
