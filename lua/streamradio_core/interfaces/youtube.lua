local RADIOIFACE = RADIOIFACE
if not istable( RADIOIFACE ) then
	StreamRadioLib.Interface.Load()
	return
end

RADIOIFACE.name = "YouTube"
RADIOIFACE.subinterfaces_folder = "youtube"
RADIOIFACE.download = true
RADIOIFACE.download_timeout = 20
RADIOIFACE.MaxBitrate = 256

local es = RADIOIFACE.errorspace

local ERROR_DISABLED = es + 0
local ERROR_NO_ID = es + 1



local youtube_error_note = [[
YouTube support is done via third party services, which are NOT under my control.
So please do not blame me about problems with this.
]]

RADIOIFACE.youtube_error_note = string.Trim(youtube_error_note)
youtube_error_note = RADIOIFACE.youtube_error_note

local youtube_error_end = [[
Notes:
  - Make sure you enter a YouTube URL of an existing video.
  - Do not try to play from YouTube playlists or channels. Those are not supported.
  - Make sure the video is not blocked.
  - Retry later.

]] .. youtube_error_note

RADIOIFACE.youtube_error_end = string.Trim(youtube_error_end)
youtube_error_end = RADIOIFACE.youtube_error_end

RADIOIFACE.youtube_help_url = "http://steamcommunity.com/workshop/filedetails/discussion/246756300/360671352684917592/"
local youtube_help_url = RADIOIFACE.youtube_help_url



RADIOIFACE.Errorcodes[ERROR_NO_ID] = {
	desc = "Invalid ID",
	text = [[
An invalid video ID was given.

Notes:
  - Make sure you enter a YouTube URL of an existing video.
  - Do not try to play from YouTube playlists or channels. Those are not supported.

]] .. youtube_error_note,
	url = youtube_help_url,
}

RADIOIFACE.Errorcodes[ERROR_DISABLED] = {
	desc = "Support is not enabled",
	text = [[
Playback from YouTube is disabled.
You can enable it with the tickbox below or in the Stream Radio settings.

Notes:
  - This is slow and unreliable.
  - Use at your own risk.

]] .. youtube_error_note,
	url = youtube_help_url,
	userdata = {
		tickbox = {
			text = "Enable YouTube support\n(slow and unreliable!)",
			cmd = "cl_streamradio_youtubesupport",
		},
	},
}



local YoutubePatterns = {
	"youtube%://([%w%-%_]+)",
	"yt%://([%w%-%_]+)",
	"%?v=([%w%-%_]+)",
	"%&v=([%w%-%_]+)",
	"/v/([%w%-%_]+)",
	"/videos/([%w%-%_]+)",
	"/embed/([%w%-%_]+)",
	"youtu%.be/([%w%-%_]+)",
	"%?video=([%w%-%_]+)",
	"%&video=([%w%-%_]+)",
}

local YoutubeURLs = {
	"youtube://",
	"yt://",
	"://youtube.",
	".youtube.",
	"://youtu.be",
}

function RADIOIFACE:PrintError(url, code)
	StreamRadioLib.Debug([[
Error Converting YouTube URL: '%s'
Code: %d, %s
Retrying with next module...
]], url, code, StreamRadioLib.DecodeErrorCode(code))

end

function RADIOIFACE:CheckURL(url)
	for i, v in ipairs(YoutubeURLs) do
		local result = string.find(string.lower(url), v, 1, true)

		if not result then
			continue
		end

		return true
	end

	return false
end

function RADIOIFACE:ParseURL(url)
	for i, v in ipairs(YoutubePatterns) do
		local result = string.Trim(string.match(url, v) or "")

		if result == "" then
			continue
		end

		return result
	end

	return nil
end

function RADIOIFACE:CheckConvertCondition(url, callback)
	if CLIENT and not StreamRadioLib.HasYoutubeSupport() then
		callback(self, false, nil, ERROR_DISABLED)
		return false
	end

	return true
end

function RADIOIFACE:Convert(url, callback)
	if not self:CheckConvertCondition(url, callback) then
		return true
	end

	local id = self:ParseURL(url)

	if not id then
		callback(self, false, nil, ERROR_NO_ID)
		return true
	end

	local stack = self:GetSubInterfaceStack()
	if not stack then
		callback(self, false, nil, -1)
		return true
	end

	local lasterror = nil

	local function iterration()
		if not self:CheckConvertCondition(url, callback) then
			return
		end

		if lasterror then
			self:PrintError(url, lasterror)
		end

		local subiface = stack:Top()
		if not subiface then
			callback(self, false, nil, lasterror or -1)
			return
		end

		stack:Pop()

		if not subiface.Convert then
			callback(self, false, nil, lasterror or -1)
			return
		end

		subiface:Convert(url, function(this, success, convered_url, errorcode, data)
			if not self:CheckConvertCondition(url, callback) then
				return
			end

			if not success then
				lasterror = errorcode
				iterration()
				return
			end

			callback(self, success, convered_url, errorcode, data)
		end, id)
	end

	iterration()
	return true
end
