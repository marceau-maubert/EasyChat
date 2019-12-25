local chathud = EasyChat.ChatHUD

local function count(a, n)
	local x = 0
	local pos = 1
	for i = 1, #a do
		local newpos = a:find(n, pos, true)
		if not newpos then
			break
		end

		pos = newpos + 1
		x = x + 1
	end

	return x
end

local extra = { "steambored", "steamfacepalm", "steamhappy", "steammocking", "steamsad", "steamsalty" }

local EMOTS = "steam_emoticons.txt"
local function parse_emote_file() end
local url = "http://g1.metastruct.net:20080/opendata/public/emote_lzma.dat"

http.Fetch(url, function(dat, len, hdr, ret)
    if not dat or ret ~= 200 then
        ErrorNoHalt("steam emoticons update failed\n")
        return
    end
    
    local t = {  }
    dat = util.Decompress(dat)
    
    file.Write(EMOTS, dat)
    local count = count(dat,',')
    print(("Saved %d emoticons to %s"):format(count, EMOTS))
    parse_emote_file(dat)
end, function(err)
    ErrorNoHalt('[SteamEmots] ' .. err .. '\n')
end, { Referer = "http://steam.tools/emoticons/" })

local FOLDER = "steam_emoticons_big"
file.CreateDir(FOLDER,'DATA')

local function MaterialData(mat)
	return Material("../data/" .. mat)
end

local UNCACHED = false
local PROCESSING = true

local cache = {}

parse_emote_file = function(EMOTICONS)
	local inSplitPattern=","
	local theStart = 1
	local theSplitStart, theSplitEnd = EMOTICONS:find( inSplitPattern, theStart, true )
	while theSplitStart do
		cache[EMOTICONS:sub( theStart, theSplitStart-1 ) ]=UNCACHED
		theStart = theSplitEnd + 1
		theSplitStart, theSplitEnd = EMOTICONS:find( inSplitPattern, theStart, true )
	end
	cache[EMOTICONS:sub( theStart ) ] = UNCACHED
end

local function get_steam_emote(name)
	local c = cache[name]
	if c then
		if c == true then return end
		return c
	else
		if c == nil then return false end
	end

	-- Otherwise download dat shit
	cache[name] = PROCESSING

	local path = FOLDER .. '/' .. name .. '.png'

	local exists=file.Exists(path, 'DATA')
	if exists then
		local mat = MaterialData(path)

		if not mat or mat:IsError() then
            Msg("[Emoticons] ")
            print("Material found, but is error: ", name, "redownloading")
		else
			c = mat
			cache[name] = c
			return c
		end
	end

	local url = 'http://steamcommunity-a.akamaihd.net/economy/emoticonhover/'..name
	local function fail(err)
        Msg("[Emoticons] ")
        print("Http fetch failed for", url, ": " .. tostring(err))
	end

	http.Fetch(url,function(data,len,hdr,code)
		if code ~= 200 or len <= 222 then return fail(code) end

		local start,ending=data:find([[src="data:image/png;base64,]], 1, true)
		if not data then return fail("ending") end

		local start2,ending2=data:find([["]],ending+64,true)
		if not start2 then return fail("start2") end

		data = data:sub(ending+1,start2-1)
		if not data or data=="" then return fail("sub") end

		data = base64.decode(data)
		if not data or data=="" then return fail("Base64Decode") end

		file.Write(path,data)

		local mat = MaterialData(path)

		if not mat or mat:IsError() then
            Msg("[Emoticons] ")
            print("Downloaded material, but is error: ", name)
			return
		end

		cache[name] = mat

	end, fail)
end

function steam_emote(name)
	local mat = get_steam_emote(name)

	if mat then return function()
		surface.SetMaterial(mat)
		return mat
	end end

	if mat == false then error("invalid emoticon") end

	return function()
		if not mat then
			mat = get_steam_emote(name)
			if not mat then
				surface.SetTexture(0)
				return
			end
		end

		surface.SetMaterial(mat)
		return mat
	end
end

local content = file.Read(EMOTS,'DATA')
if content then
	parse_emote_file(content)
end

local emote_part = {
    SetEmoteMaterial = function() draw.NoTexture() end
}

function emote_part:Ctor(name)
    self:ComputeSize()
    self.SetEmoteMaterial = steam_emote(name)

    return self
end

function emote_part:ComputeSize()
    self.Size = { W = 32, H = 32 }
end

function emote_part:Draw()
    self.SetEmoteMaterial()
    surface.DrawTexturedRect(self.Pos.X, self.Pos.Y, self.Size.W, self.Size.H)
    draw.NoTexture()
end

chathud:RegisterPart("emote", emote_part, "%:([A-Za-z0-9_]+)%:")