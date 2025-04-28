local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- Discord webhook URL
local WEBHOOK_URL = "https://discord.com/api/webhooks/1366018421711572992/TYeidqVzp8q69J4WiAYzYXBA33ka-_25jfONzMcOM44DE_1mxk89cIY9Tb3uUNg9GgTT"
local scriptToRun = [[
    -- Wait until the game is fully loaded
    game.Loaded:Wait()
 
    -- Once the game is loaded, run the external script
    wait(2)
    loadstring(game:HttpGet("https://raw.githubusercontent.com/mrricky22/thingy/refs/heads/main/new.lua"))()
]]

-- File configuration
local LOG_FILE = "money.txt"

-- In-memory log for current session
local moneyLog = {} -- Format: {{money = number, timestamp = number}, ...}

-- Function to read existing log file
local function loadLogFile()
    if isfile(LOG_FILE) then
        local success, content = pcall(function()
            return readfile(LOG_FILE)
        end)
        if success and content then
            for line in content:gmatch("[^\r\n]+") do
                local money, timestamp = line:match("^(%d+):(%d+)$")
                if money and timestamp then
                    table.insert(moneyLog, {
                        money = tonumber(money),
                        timestamp = tonumber(timestamp)
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
local function appendToLog(money, timestamp)
    local success, err = pcall(function()
        -- Create file if it doesn't exist
        if not isfile(LOG_FILE) then
            writefile(LOG_FILE, "")
            print("Created new log file: " .. LOG_FILE)
        end
        appendfile(LOG_FILE, money .. ":" .. timestamp .. "\n")
    end)
    if success then
        table.insert(moneyLog, {money = money, timestamp = timestamp})
        print("Appended to log: Money = " .. money .. ", Timestamp = " .. timestamp)
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
        UnixTimestamp = os.time()
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
    
    -- Total earned: Current money - First recorded money
    local totalEarned = moneyLog[#moneyLog].money - (moneyLog[1] and moneyLog[1].money or 0)
    
    -- Estimated earnings per hour: Compare with previous entry
    local earningsPerHour = 0
    if #moneyLog >= 2 then
        local lastEntry = moneyLog[#moneyLog]
        local prevEntry = moneyLog[#moneyLog - 1]
        
        local moneyDiff = lastEntry.money - prevEntry.money
        local timeDiff = lastEntry.timestamp - prevEntry.timestamp -- Time difference in seconds
        
        if timeDiff > 0 then
            -- Earnings per second * 3600 (seconds in an hour)
            earningsPerHour = (moneyDiff / timeDiff) * 3600
        end
    end
    
    return totalEarned, earningsPerHour
end

-- Function to send player info to Discord webhook
local function sendMoneyToWebhook()
    local playerInfo = getLocalPlayerInfo()
    
    if not playerInfo then
        warn("Failed to get player info, skipping webhook")
        return
    end
    
    -- Append to log file and in-memory log
    appendToLog(playerInfo.Money, playerInfo.UnixTimestamp)
    
    -- Calculate earnings
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
                "[%s] Webhook sent successfully - Player: %s, Money: $%d, Total Earned: $%d, Est. $/hr: $%d, Status: %d",
                playerInfo.Timestamp,
                playerInfo.PlayerName,
                playerInfo.Money,
                totalEarned,
                math.floor(earningsPerHour + 0.5),
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
        wait(60) -- Wait 60 seconds (1 minute)
    end
end

-- Initialize: Load existing log
loadLogFile()

-- Start the loop in a coroutine to prevent blocking
coroutine.wrap(startWebhookLoop)()
