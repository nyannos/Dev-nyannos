--[[
    NYANN MUSIC
    Redz Library V5
    Playlist + Sound ID
]]

local RedzLib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/tlredz/Library/refs/heads/main/redz-V5-remake/main.luau"
))()

local SoundService = game:GetService("SoundService")

local PLAYLIST_URL = "https://pastefy.app/0QU2aU7c/raw"
local FOLDER = "FluentMusicPlayer"

local Window = RedzLib:MakeWindow({
    Title = "Menu Music",
    SubTitle = "Music | by real_@nyann",
    ScriptFolder = FOLDER
})

local Tabs = {
    Info = Window:MakeTab({"Information", "info"}),
    Player = Window:MakeTab({"Main", "music"}),
    Settings = Window:MakeTab({"Setting", "settings"})
}

--==================================================
-- VARIABLES
--==================================================

local playlist = {}
local filteredPlaylist = {}

local currentIndex = 0
local currentSound = nil
local customSound = nil

local endedConnection = nil
local customEndedConnection = nil
local soundAddedConnection = nil

local selectedTrackValue = nil
local selectedTitle = "Chưa chọn bài"

local searchText = ""
local customSoundId = nil

local volume = 1
local autoNext = true
local shuffleMode = false
local muteGameSounds = true
local loadingPlaylist = false

local originalVolumes = {}
local TrackSelect

--==================================================
-- NOTIFY
--==================================================

local function notify(title, content, duration)
    pcall(function()
        Window:Notify({
            Title = title,
            Content = content,
            Duration = duration or 5
        })
    end)
end

--==================================================
-- STRING
--==================================================

local function trim(s)
    return tostring(s):gsub("^%s+", ""):gsub("%s+$", "")
end

local function decode(s)
    s = s:gsub('\\"', '"')
    s = s:gsub('\\/', '/')
    s = s:gsub('\\\\', '\\')

    s = s:gsub('\\u(%x%x%x%x)', function(hex)
        local n = tonumber(hex, 16)

        if n and utf8 and utf8.char then
            local ok, result = pcall(utf8.char, n)
            if ok then
                return result
            end
        end

        return ""
    end)

    return s
end

--==================================================
-- PARSE PLAYLIST
--==================================================

local function parsePlaylist(raw)
    local result = {}

    for obj in raw:gmatch("%b{}") do

        local name = obj:match('"name"%s*:%s*"(.-)"')
        local artist = obj:match('"artist"%s*:%s*"(.-)"')
        local url = obj:match('"download_url"%s*:%s*"(.-)"')

        if name and url then

            name = decode(name)
            artist = decode(artist or "Unknown artist")
            url = decode(url)

            local genre =
                decode(obj:match('"genre"%s*:%s*"(.-)"') or "Unknown genre")

            local country =
                decode(obj:match('"country"%s*:%s*"(.-)"') or "Unknown country")

            local year =
                tonumber(obj:match('"release_year"%s*:%s*(%d+)')) or 0

            name = trim(name)
            artist = trim(artist)
            genre = trim(genre)
            country = trim(country)

            table.insert(result, {
                name = name,
                artist = artist,
                url = url,
                genre = genre,
                country = country,
                release_year = year,

                label =
                    name
                    .. " — "
                    .. artist
                    .. " ["
                    .. genre
                    .. "]"
            })
        end
    end

    return result
end

--==================================================
-- MUSIC CHECK
--==================================================

local function isMusic(sound)
    return sound == currentSound
        or sound == customSound
        or sound.Name == "FluentMusicPlayerSound"
        or sound.Name == "FluentCustomMusic"
end

--==================================================
-- STOP PLAYLIST
--==================================================

local function stopCurrent()
    if endedConnection then
        endedConnection:Disconnect()
        endedConnection = nil
    end

    if currentSound then
        pcall(function()
            currentSound:Stop()
            currentSound:Destroy()
        end)

        currentSound = nil
    end
end

--==================================================
-- STOP CUSTOM ID
--==================================================

local function stopCustom()
    if customEndedConnection then
        customEndedConnection:Disconnect()
        customEndedConnection = nil
    end

    if customSound then
        pcall(function()
            customSound:Stop()
            customSound:Destroy()
        end)

        customSound = nil
    end
end

--==================================================
-- STOP ALL
--==================================================

local function stopAll()
    stopCurrent()
    stopCustom()
end

--==================================================
-- MUTE GAME
--==================================================

local function setGameMuted(enabled)
    muteGameSounds = enabled

    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("Sound") and not isMusic(obj) then

            if enabled then

                if originalVolumes[obj] == nil then
                    originalVolumes[obj] = obj.Volume
                end

                obj.Volume = 0

            elseif originalVolumes[obj] ~= nil then

                obj.Volume = originalVolumes[obj]
                originalVolumes[obj] = nil
            end
        end
    end
end

--==================================================
-- RANDOM
--==================================================

local function randomIndex(exclude)
    if #playlist == 0 then
        return nil
    end

    if #playlist == 1 then
        return 1
    end

    local index

    repeat
        index = math.random(1, #playlist)
    until index ~= exclude

    return index
end

--==================================================
-- UPDATE DROPDOWN
--==================================================

local function updateDropdown()
    if not TrackSelect then
        return
    end

    local values = {}
    filteredPlaylist = {}

    for index, track in ipairs(playlist) do

        local search =
            string.lower(
                track.name
                .. " "
                .. track.artist
                .. " "
                .. track.genre
                .. " "
                .. track.country
                .. " "
                .. tostring(track.release_year)
            )

        if searchText == ""
            or search:find(searchText, 1, true) then

            table.insert(filteredPlaylist, {
                index = index,
                track = track
            })

            table.insert(values, track.label)
        end
    end

    if #values > 0 then
        TrackSelect:NewOptions(table.unpack(values))
        selectedTrackValue = values[1]
    else
        TrackSelect:NewOptions("Không tìm thấy bài hát")
        selectedTrackValue = nil
    end
end

--==================================================
-- PLAY PLAYLIST
--==================================================

local playTrack

playTrack = function(index)

    if #playlist == 0 then
        notify("Music Player", "Playlist đang trống.")
        return
    end

    index = tonumber(index) or 1

    if index < 1 or index > #playlist then
        index = 1
    end

    local track = playlist[index]

    currentIndex = index
    selectedTitle = track.label

    if not writefile
        or not (getcustomasset or getsynasset) then

        notify(
            "Không tương thích",
            "Executor cần writefile và getcustomasset/getsynasset.",
            7
        )

        return
    end

    stopAll()

    notify(
        "Đang tải nhạc",
        track.label,
        4
    )

    task.spawn(function()

        local fileName =
            FOLDER .. "/track_" .. index .. ".mp3"

        -- DOWNLOAD

        if not isfile(fileName) then

            local ok, data = pcall(function()
                return game:HttpGet(track.url)
            end)

            if not ok or not data or #data == 0 then
                notify(
                    "Lỗi tải nhạc",
                    "Không thể tải: " .. track.name,
                    6
                )

                return
            end

            local wrote = pcall(function()
                writefile(fileName, data)
            end)

            if not wrote then
                notify(
                    "Lỗi lưu file",
                    "Không thể lưu file nhạc.",
                    6
                )

                return
            end
        end

        if currentIndex ~= index then
            return
        end

        -- ASSET

        local getAsset =
            getcustomasset or getsynasset

        local ok, asset = pcall(function()
            return getAsset(fileName)
        end)

        if not ok or not asset then
            notify(
                "Lỗi asset",
                "Không thể tạo custom asset.",
                6
            )

            return
        end

        -- SOUND

        local sound = Instance.new("Sound")

        sound.Name = "FluentMusicPlayerSound"
        sound.SoundId = asset
        sound.Volume = volume
        sound.Looped = false
        sound.Parent = SoundService

        currentSound = sound

        endedConnection =
            sound.Ended:Connect(function()

                if currentSound ~= sound then
                    return
                end

                currentSound = nil

                if endedConnection then
                    endedConnection:Disconnect()
                    endedConnection = nil
                end

                pcall(function()
                    sound:Destroy()
                end)

                if autoNext and #playlist > 0 then

                    task.wait(0.25)

                    if shuffleMode then

                        local nextIndex =
                            randomIndex(index)

                        if nextIndex then
                            playTrack(nextIndex)
                        end

                    else

                        playTrack(
                            (index % #playlist) + 1
                        )
                    end
                end
            end)

        sound:Play()

        notify(
            "Đang phát",
            track.label,
            4
        )
    end)
end

--==================================================
-- PLAY SOUND ID
--==================================================

local function playCustom(id)

    id = tostring(id or "")
    id = id:gsub("%D", "")

    if id == "" then
        notify(
            "Music Player",
            "Hãy nhập Sound ID.",
            5
        )

        return
    end

    stopAll()

    local sound = Instance.new("Sound")

    sound.Name = "FluentCustomMusic"
    sound.SoundId = "rbxassetid://" .. id
    sound.Volume = volume
    sound.Looped = false
    sound.Parent = SoundService

    customSound = sound

    customEndedConnection =
        sound.Ended:Connect(function()

            if customSound ~= sound then
                return
            end

            customSound = nil

            if customEndedConnection then
                customEndedConnection:Disconnect()
                customEndedConnection = nil
            end

            pcall(function()
                sound:Destroy()
            end)
        end)

    sound:Play()

    notify(
        "Đang phát",
        "Sound ID: " .. id,
        5
    )
end

--==================================================
-- LOAD PLAYLIST
--==================================================

local function loadPlaylist()

    if loadingPlaylist then
        return
    end

    loadingPlaylist = true

    local ok, raw = pcall(function()
        return game:HttpGet(PLAYLIST_URL)
    end)

    if not ok or not raw or #raw == 0 then

        loadingPlaylist = false

        notify(
            "Lỗi playlist",
            "Không thể tải Pastefy.",
            7
        )

        return
    end

    local result = parsePlaylist(raw)

    if #result == 0 then

        loadingPlaylist = false

        notify(
            "Lỗi playlist",
            "Không tìm thấy bài hát.",
            7
        )

        return
    end

    playlist = result
    loadingPlaylist = false

    updateDropdown()

    notify(
        "Playlist sẵn sàng",
        "Đã tải " .. #playlist .. " bài.",
        5
    )
end

--==================================================
-- INFORMATION
--==================================================

Tabs.Info:AddSection("Information")

Tabs.Info:AddDiscordInvite({
    Title = "nyann | Community",
    Banner = "rbxassetid://94678517792779",
    Logo = "rbxassetid://94678517792779",
    Invite = "https://discord.gg/q2qzCDBcG",
    Members = 36,
    Online = 67
})

--==================================================
-- MAIN - PLAYLIST
--==================================================

Tabs.Player:AddSection("Playlist")

Tabs.Player:AddTextBox({
    Title = "Tìm kiếm nhạc",
    Placeholder = "Search",
    Default = "",

    Callback = function(value)

        searchText =
            string.lower(
                tostring(value or "")
            )

        updateDropdown()
    end
})

TrackSelect = Tabs.Player:AddDropdown({

    Title = "Chọn bài hát",

    Options = {
        "Đang tải playlist..."
    },

    Default = "Đang tải playlist...",

    Callback = function(value)

        selectedTrackValue = value

        for _, item in ipairs(filteredPlaylist) do

            if item.track.label == value then

                selectedTitle =
                    item.track.label

                currentIndex =
                    item.index

                break
            end
        end
    end
})

Tabs.Player:AddButton({

    Title = "Phát bài đã chọn",

    Callback = function()

        for _, item in ipairs(filteredPlaylist) do

            if item.track.label ==
                selectedTrackValue then

                playTrack(item.index)
                return
            end
        end

        notify(
            "Music Player",
            "Chưa chọn bài hát."
        )
    end
})

Tabs.Player:AddButton({

    Title = "Bài trước",

    Callback = function()

        if #playlist > 0 then

            playTrack(
                ((currentIndex - 2) % #playlist) + 1
            )
        end
    end
})

Tabs.Player:AddButton({

    Title = "Bài tiếp theo",

    Callback = function()

        if #playlist > 0 then

            playTrack(
                (currentIndex % #playlist) + 1
            )
        end
    end
})

Tabs.Player:AddButton({

    Title = "Phát ngẫu nhiên",

    Callback = function()

        local index =
            randomIndex(currentIndex)

        if index then
            playTrack(index)
        end
    end
})

Tabs.Player:AddButton({

    Title = "Dừng nhạc",

    Callback = function()

        stopAll()

        notify(
            "Music Player",
            "Đã dừng nhạc."
        )
    end
})

--==================================================
-- MAIN - SOUND ID
--==================================================

Tabs.Player:AddSection("Sound ID")

Tabs.Player:AddTextBox({

    Title = "Nhập ID nhạc",

    Placeholder = "...",

    Default = "",

    Callback = function(value)

        value = tostring(value or "")
        value = value:gsub("%D", "")

        if value ~= "" then
            customSoundId = value
        else
            customSoundId = nil
        end
    end
})

Tabs.Player:AddButton({

    Title = "Phát nhạc bằng ID",

    Callback = function()

        if not customSoundId then

            notify(
                "Music Player",
                "Hãy nhập Sound ID trước.",
                5
            )

            return
        end

        playCustom(customSoundId)
    end
})

Tabs.Player:AddButton({

    Title = "Dừng nhạc ID",

    Callback = function()

        if customSound then

            stopCustom()

            notify(
                "Music Player",
                "Đã dừng nhạc ID.",
                4
            )

        else

            notify(
                "Music Player",
                "Không có nhạc ID.",
                4
            )
        end
    end
})

--==================================================
-- MAIN - AUDIO
--==================================================

Tabs.Player:AddSection("Audio")

Tabs.Player:AddSlider({

    Title = "Âm lượng",

    Default = 100,

    Min = 0,

    Max = 100,

    Increase = 1,

    Callback = function(value)

        volume = value / 100

        if currentSound then
            currentSound.Volume = volume
        end

        if customSound then
            customSound.Volume = volume
        end
    end
})

Tabs.Player:AddToggle({

    Title = "Tự động phát bài tiếp theo",

    Default = true,

    Callback = function(value)
        autoNext = value
    end
})

Tabs.Player:AddToggle({

    Title = "Tự động phát ngẫu nhiên",

    Default = false,

    Callback = function(value)
        shuffleMode = value
    end
})

Tabs.Player:AddToggle({

    Title = "Tắt âm thanh game",

    Default = true,

    Callback = function(value)
        setGameMuted(value)
    end
})

Tabs.Player:AddParagraph(
    "Trạng thái",
    "Bài hiện tại: " .. selectedTitle
)

--==================================================
-- SETTINGS
--==================================================

Tabs.Settings:AddSection("Settings")

Tabs.Settings:AddButton({

    Title = "Tải lại playlist",

    Callback = loadPlaylist
})

Tabs.Settings:AddParagraph(

    "Music Player",

    "Nhập Sound ID trong Main để phát audio."
)

--==================================================
-- START
--==================================================

Window:SelectTab(1)

Window:NewMinimizer(
    Enum.KeyCode.LeftControl
)

Window:Notify({

    Title = "Music Player",

    Content = "Đang tải playlist...",

    Duration = 5
})

task.spawn(function()
    loadPlaylist()
end)

setGameMuted(true)

--==================================================
-- MUTE NEW SOUND
--==================================================

soundAddedConnection =
    game.DescendantAdded:Connect(function(obj)

        if obj:IsA("Sound")
            and muteGameSounds
            and not isMusic(obj) then

            originalVolumes[obj] =
                obj.Volume

            obj.Volume = 0
        end
    end)

--==================================================
-- CLEANUP
--==================================================

game:BindToClose(function()

    stopAll()

    if soundAddedConnection then

        soundAddedConnection:Disconnect()

        soundAddedConnection = nil
    end
end)
