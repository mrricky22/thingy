local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

-- Discord webhook URL
local WEBHOOK_URL = "https://discord.com/api/webhooks/1366018421711572992/TYeidqVzp8q69J4WiAYzYXBA33ka-_25jfONzMcOM44DE_1mxk89cIY9Tb3uUNg9GgTT"
local scriptToRun = [[
  game.Loaded:Wait()
  loadstring(game:HttpGet("https://raw.githubusercontent.com/BlitzIsKing/UniversalFarm/refs/heads/main/Jailbreak/autoArrest"))()
]]

-- File configuration
local LOG_FILE = "money.txt"

-- In-memory log for current session
local moneyLog = {} -- Format: {{money = number, timestamp = number, jobId = string}, ...}

-- Game info
local place_id = game.PlaceId
local job_id = game.JobId
local API = "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100"

-- Function to read existing log file
local function loadLogFile()
    if isfile(LOG_FILE) then
        local success, content = pcall(function()
            return readfile(LOG_FILE)
        end)
        if success and content then
            for line in content:gmatch("[^\r\n]+") do
                local money, timestamp, jobId = line:match("^(%d+):(%d+):([^\n]*)$")
                if money and timestamp then
                    table.insert(moneyLog, {
                        money = tonumber(money),
                        timestamp = tonumber(timestamp),
                        jobId = jobId or ""
                    })
                end
            end
            print("Loaded " .. #moneyLog .. " entries from log file")
        else
            warn("Failed to read log file: " .. tostring(content))
        end
    else
        print("No log file exists, will create new one on first write")
    end
end

-- Function to append money and timestamp to file
local function appendToLog(money, timestamp, jobId)
    local success, err = pcall(function()
        if not isfile(LOG_FILE) then
            writefile(LOG_FILE, "")
            print("Created new log file: " .. LOG_FILE)
        end
        appendfile(LOG_FILE, money .. ":" .. timestamp .. ":" .. jobId .. "\n")
    end)
    if success then
        table.insert(moneyLog, {money = money, timestamp = timestamp, jobId = jobId})
        print("Appended to log: Money = " .. money .. ", Timestamp = " .. timestamp .. ", JobId = " .. jobId)
    else
        warn("Failed to append to log file: " .. tostring(err))
    end
end

-- Function to get local player's information
local function getLocalPlayerInfo()
    local player = Players.LocalPlayer
    if not player then
        warn("LocalPlayer not found")
        return nil
    end
    
    local info = {
        PlayerName = player.Name,
        UserId = player.UserId,
        Money = 0,
        Timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        UnixTimestamp = os.time(),
        JobId = game.JobId
    }
    
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then
        warn("leaderstats not found for player: " .. player.Name)
        return info
    end
    
    local cash = leaderstats:FindFirstChild("Money")
    if cash and cash:IsA("IntValue") then
        info.Money = cash.Value
    else
        warn("Money not found or not an IntValue for player: " .. player.Name)
    end
    
    return info
end

-- Function to calculate total earned and estimated earnings per hour
local function calculateEarnings()
    if #moneyLog == 0 then
        return 0, 0
    end
    
    local totalEarned = moneyLog[#moneyLog].money - (moneyLog[1] and moneyLog[1].money or 0)
    
    local earningsPerHour = 0
    if #moneyLog >= 2 then
        local lastEntry = moneyLog[#moneyLog]
        local prevEntry = moneyLog[#moneyLog - 1]
        
        local moneyDiff = lastEntry.money - prevEntry.money
        local timeDiff = lastEntry.timestamp - prevEntry.timestamp
        
        if timeDiff > 0 then
            earningsPerHour = (moneyDiff / timeDiff) * 3600
        end
    end
    
    return totalEarned, earningsPerHour
end

-- Function to hop to a random server
local function hopServer()
    local request = loadstring(game:HttpGet("https://raw.githubusercontent.com/EpicPug/Stuff/main/request.lua"))()
    if request then
        local data
        local success, response
        local found_servers = {}
        
        success, response = pcall(function()
            data = request({Url = API:format(place_id)})
        end)

        if success and data and data.Body then
            local decode
            success, response = pcall(function()
                decode = HttpService:JSONDecode(data.Body)
            end)

            if success and decode and decode.data then
                for _, found in pairs(decode.data) do
                    if type(found) == "table" and found["id"] ~= job_id then
                        table.insert(found_servers, {
                            playing = found.playing,
                            maxPlayers = found.maxPlayers,
                            id = found.id
                        })
                    end
                end

                if #found_servers > 0 then
                    local valid_servers = {}
                    for _, server in ipairs(found_servers) do
                        if server.playing <= server.maxPlayers - 4 then
                            table.insert(valid_servers, server)
                        end
                    end

                    if #valid_servers > 0 then
                        local random_index = math.random(1, #valid_servers)
                        local selected_server = valid_servers[random_index]
                        
                        queue_on_teleport(scriptToRun)
                        
                        TeleportService.TeleportInitFailed:Connect(function()
                            TeleportService:TeleportToPlaceInstance(place_id, selected_server.id, Players.LocalPlayer)
                        end)

                        repeat
                            TeleportService:TeleportToPlaceInstance(place_id, selected_server.id, Players.LocalPlayer)
                            task.wait(2)
                        until not game
                    end
                end
            end
        end
    end
end

-- Function to send player info to Discord webhook
local function sendMoneyToWebhook()
    local playerInfo = getLocalPlayerInfo()
    
    if not playerInfo then
        warn("Failed to get player info, skipping webhook")
        return
    end
    
    appendToLog(playerInfo.Money, playerInfo.UnixTimestamp, playerInfo.JobId)
    
    if #moneyLog >= 2 then
        local lastEntry = moneyLog[#moneyLog]
        local prevEntry = moneyLog[#moneyLog - 1]
        
        if lastEntry.jobId == prevEntry.jobId and lastEntry.money <= prevEntry.money then
            print("No money gained in same server, initiating server hop")
            hopServer()
            return
        end
    end
    
    local totalEarned, earningsPerHour = calculateEarnings()
    
    local message = {
        embeds = {{
            title = "Player Money Update",
            fields = {
                {name = "Player", value = playerInfo.PlayerName, inline = true},
                {name = "User ID", value = tostring(playerInfo.UserId), inline = true},
                {name = "Current Money", value = "$" .. playerInfo.Money, inline = true},
                {name = "Total Earned", value = "$" .. totalEarned, inline = true},
                {name = "Est. Earnings/Hour", value = "$" .. math.floor(earningsPerHour + 0.5), inline = true},
                {name = "Job ID", value = playerInfo.JobId, inline = true},
                {name = "Timestamp", value = playerInfo.Timestamp, inline = false}
            },
            color = 0x00FF00,
            timestamp = playerInfo.Timestamp
        }}
    }
    
    local jsonBody = HttpService:JSONEncode(message)
    local requestOptions = {
        Url = WEBHOOK_URL,
        Method = "POST",
        Body = jsonBody,
        Headers = {
            ["Content-Type"] = "application/json"
        }
    }
    
    local success, response = pcall(function()
        return request(requestOptions)
    end)
    
    if success then
        if response.StatusCode == 200 or response.StatusCode == 204 then
            print(string.format(
                "[%s] Webhook sent successfully - Player: %s, Money: $%d, Total Earned: $%d, Est. $/hr: $%d, JobId: %s, Status: %d",
                playerInfo.Timestamp,
                playerInfo.PlayerName,
                playerInfo.Money,
                totalEarned,
                math.floor(earningsPerHour + 0.5),
                playerInfo.JobId,
                response.StatusCode
            ))
        else
            warn(string.format(
                "[%s] Webhook failed - Player: %s, Status: %d, Message: %s",
                playerInfo.Timestamp,
                playerInfo.PlayerName,
                response.StatusCode,
                response.StatusMessage or "No message"
            ))
        end
    else
        warn(string.format(
            "[%s] Failed to send webhook - Player: %s, Error: %s",
            playerInfo.Timestamp,
            playerInfo.PlayerName,
            tostring(response)
        ))
    end
end

-- Function to run webhook periodically
local function startWebhookLoop()
    while true do
        sendMoneyToWebhook()
        wait(120)
    end
end

-- Initialize: Load existing log
loadLogFile()

-- Start the loop in a coroutine to prevent blocking
coroutine.wrap(startWebhookLoop)()
