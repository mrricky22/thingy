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
        Timestamp = os.date("%Y-%m-%d %H:%M:%S")
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

-- Function to send player info to Discord webhook
local function sendMoneyToWebhook()
    local playerInfo = getLocalPlayerInfo()
    
    if not playerInfo then
        warn("Failed to get player info, skipping webhook")
        return
    end
    
    local message = {
        embeds = {{
            title = "Player Money Update",
            fields = {
                {name = "Player", value = playerInfo.PlayerName, inline = true},
                {name = "User ID", value = tostring(playerInfo.UserId), inline = true},
                {name = "Money", value = "$" .. playerInfo.Money, inline = true},
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
                "[%s] Webhook sent successfully - Player: %s, Money: $%d, Status: %d",
                playerInfo.Timestamp,
                playerInfo.PlayerName,
                playerInfo.Money,
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

-- Start the loop in a coroutine to prevent blocking
coroutine.wrap(startWebhookLoop)()
