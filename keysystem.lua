-- KeySystemPro Fluent preset
-- Set Handle and ScriptId. The script loads only when the user presses Load.

local CONFIG = {
    Handle   = "rendays", -- put ur handle here.
    ScriptId = "example", -- you can also set it to game.GameId then Place the Real Game id as Script Id In dashboard.
    Key      = "", -- leave it empty user can put key in the Gui
    KeyPage  = "https://msha.ke/renrenhub#renrenhub-key-system",
}

--[[
if game.PlaceId == "..." then CONFIG.ScriptId = "Example1" end
if game.GameId == "..." then CONFIG.ScriptId = "example2" end
]]

local function fail(message)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", { Title = "KeySystemPro", Text = tostring(message), Duration = 6 })
    end)
    error(tostring(message), 0)
end

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
if not Fluent then fail("Could not load Fluent.") end

local api = loadstring(game:HttpGet("https://cdn.keysystem.pro/v1/loader.lua"))()
if not api then fail("Could not load the loader SDK.") end

if not CONFIG.Handle or CONFIG.Handle == "" or CONFIG.Handle == "YOUR_HANDLE" then fail("Set CONFIG.Handle in the preset.") end
if not CONFIG.ScriptId or CONFIG.ScriptId == "" then fail("Set CONFIG.ScriptId in the preset.") end

api.owner = tostring(CONFIG.Handle)
api.script_id = tostring(CONFIG.ScriptId)
api.script_key = tostring(CONFIG.Key or "")
api.notify = false

local Window = Fluent:CreateWindow({
    Title = "KeySystemPro",
    SubTitle = "Loader - @" .. tostring(CONFIG.Handle),
    TabWidth = 140,
    Size = UDim2.fromOffset(480, 340),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl,
})

local Main = Window:AddTab({ Title = "Main", Icon = "" })

local function notify(title, content)
    Fluent:Notify({ Title = tostring(title), Content = tostring(content or ""), Duration = 6 })
end

local currentKey = tostring(CONFIG.Key or "")

local status = Main:AddParagraph({ Title = "Status", Content = "Enter your key and press Load." })
local function setStatus(text) pcall(function() status:SetDesc(text) end) end

local function checkAndLoad()
    local ran, err = pcall(function()
        api.script_key = currentKey
        if currentKey ~= "" then
            local key = api.check_key()
            if type(key) ~= "table" or key.code ~= "KEY_VALID" then
                local code = (type(key) == "table" and key.code) or "KEY_INCORRECT"
                setStatus("Key invalid: " .. tostring(code))
                return notify("Key " .. tostring(code), (type(key) == "table" and key.message) or "This key is not valid.")
            end
            setStatus("Key valid. Loading...")
        else
            setStatus("Loading...")
        end
        api.script_id = tostring(CONFIG.ScriptId)
        local loaded, res = api.load_script()
        if loaded then
            setStatus("Script is running.")
            notify("Loaded", "Script is running.")
        else
            local code = (type(res) == "table" and res.code) or "LOAD_FAILED"
            local msg = (type(res) == "table" and res.message) or tostring(res)
            setStatus("Failed: " .. tostring(code))
            notify("Failed: " .. tostring(code), msg)
        end
    end)
    if not ran then
        setStatus("Error: " .. tostring(err))
        notify("Error", tostring(err))
    end
end

Main:AddInput("LicenseKey", {
    Title = "License key",
    Description = "",
    Default = currentKey,
    Placeholder = "XXXX-XXXX-XXXX-XXXX",
    Numeric = false,
    Finished = false,
    Callback = function(value)
        currentKey = tostring(value or ""):gsub("%s", "")
        api.script_key = currentKey
    end,
})

Main:AddButton({
    Title = "Load",
    Description = "Checks your key, then loads the script.",
    Callback = checkAndLoad,
})

if CONFIG.KeyPage and CONFIG.KeyPage ~= "" then
    Main:AddButton({
        Title = "Get a key",
        Callback = function()
            pcall(function() setclipboard(CONFIG.KeyPage) end)
            notify("Key page", CONFIG.KeyPage)
        end,
    })
end
