--[[ SOCIAL — Discord webhook (notify upload & send report) ]]

return function(REN)
    local HttpService = game:GetService("HttpService")
    local C = REN.Config
    local U = REN.Utils
    local S = REN.State
    local So = {}

    function So.notifyDiscord(entry, loudness)
        if not C.DiscordWebhook or C.DiscordWebhook == "" then return end
        local payload = {
            username = "REN Music Hub",
            embeds = {{
                title = "🎵 New Song Uploaded",
                description = "**" .. entry.name .. "**\n`" .. entry.id .. "`",
                color = 3066993,
                fields = {
                    { name = "Uploader",   value = entry.submittedByName .. " (`" .. entry.submittedBy .. "`)", inline = true },
                    { name = "Validation", value = "✅ Loaded (loud: " .. tostring(loudness) .. ")", inline = true },
                    { name = "Game",       value = tostring(game.PlaceId), inline = true },
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }},
        }
        task.spawn(function()
            pcall(function()
                U.httpReq(C.DiscordWebhook, "POST", HttpService:JSONEncode(payload))
            end)
        end)
    end

    function So.sendReport(entry, reason)
        if not C.DiscordWebhook or C.DiscordWebhook == "" then
            return false, "Webhook not set"
        end
        local payload = {
            username = "REN Music Reports",
            embeds = {{
                title = "🚩 Song Report", color = 15158332,
                fields = {
                    { name = "Song",          value = "**" .. entry.name .. "**\n`" .. entry.id .. "`", inline = false },
                    { name = "Reason",        value = reason, inline = false },
                    { name = "Reported by",   value = S.player.Name .. " (`" .. S.player.UserId .. "`)", inline = true },
                    { name = "Place ID",      value = tostring(game.PlaceId), inline = true },
                    { name = "Is Submission", value = tostring(entry.isSubmission), inline = true },
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }},
        }
        local r = U.httpReq(C.DiscordWebhook, "POST", HttpService:JSONEncode(payload))
        if r then return true end
        return false, "Failed to send report"
    end

    REN.Social = So
end
