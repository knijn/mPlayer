local modem = peripheral.find("modem")
local speaker = peripheral.find("speaker")
local dfpwm = require("cc.audio.dfpwm")
local version = 1.1
local args = {...}
if args[1] and tonumber(args[1]) then
  print("Tuning to " .. tonumber(args[1]))
  modem.open(tonumber(args[1]))
end

local function update()
    local s = shell.getRunningProgram()
    handle = http.get("https://raw.githubusercontent.com/knijn/mPlayer/main/mPlayer.lua")
    if not handle then
        error("Could not download new version, Please update manually.",0)
    else
        data = handle.readAll()
        local f = fs.open(s, "w")
        handle.close()
        f.write(data)
        f.close()
        error("Please reopen mStream")
    end
end

local h = http.get("https://raw.githubusercontent.com/knijn/mPlayer/main/data.json")
local latestVersion = textutils.unserialiseJSON(h.readAll()).latestVersion

if latestVersion > version then update() end


local decoder = dfpwm.make_decoder()
local selection = 2048
local playing = false
local song
local channelName
local signalType

modem.closeAll()

local function handleInput()
  while true do
    local event, key, is_down = os.pullEvent("key")
    if key == keys.up then
      modem.close(selection)
      selection = selection + 1
      modem.open(selection)
    elseif key == keys.down then
      modem.close(selection)
      selection = selection - 1
      modem.open(selection)
    end
  end
end

local function drawInfo()
  while true do
    local xSize, ySize = term.getSize()
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1,1)
    term.setBackgroundColor(colors.cyan)
    term.clearLine()
    print("mPlayer " .. version)
    term.setBackgroundColor(colors.black)
    --print("Music playback might stutter, this is known")
    term.setCursorPos(1,4)
    if playing then
      if stationName then
        term.write(stationName)
      else
        term.write("PLAYING")
      end
      if title then
        term.setCursorPos(1,6)
        term.write(title)
      end
    else
      term.write("NO SIGNAL")
    end


    term.setCursorPos(1,ySize)
    if signalType then
      term.write("Channel " .. selection .. "   Signal Type: " .. signalType)
    else
      term.write("Channel " .. selection)
    end
    sleep(0.2)
  end
end

local function play()
  while true do
    local msg
    local function modemfunc()
      modem.open(selection)
      event, side, ch, rch, msg, dist = os.pullEvent("modem_message")
      playing = true
    end
    local function wait()
      sleep(3)
      playing = false
      song = nil
      channelType = nil
      channelName = nil
    end
    parallel.waitForAny(modemfunc,wait)
    if msg then
      local buffer
      if type(msg) == "string" then
        buffer = decoder(msg)
        signalType = "classic"
      else
        if msg.protocol == "CCSMB-5" then
          buffer = msg.buffer
          stationName = msg.station

          title = msg.title
          signalType = msg.protocol
          while not speaker.playAudio(buffer) do
            os.pullEvent("speaker_audio_empty")
          end
        end
      end
    end
    sleep(0)
  end
end

while true do
  parallel.waitForAny(play,handleInput,drawInfo)
end
