--[[ CONFIG — konstanta statis: limit scan, daftar root, keyword, teks tooltip (English), warna/tema.
     Tidak ada logika di sini. Kalau mau ubah angka/limit/teks, cukup file ini. ]]

return function(D)
    D.Config = {
        VERSION  = D.version,
        GUI_NAME = "ScriptDumperGui",

        SCAN = {
            MAX_SCRIPT_SIZE  = 200 * 1024,
            MAX_TOTAL_MEM    = 10 * 1024 * 1024,
            ROOT_TIMEOUT     = 45,
            MAX_SCRIPTS_ROOT = 800,
            BIG_LOG_THRESH   = 50 * 1024,
            RENDER_CAP       = 400,
        },

        -- Capture FireServer / InvokeServer (HK1 / HK2)
        FS = {
            DEDUP_SEC       = 0.01, -- remote + method + ARGUMEN identik dalam < 10ms dianggap duplikat
            MAX_ENTRIES     = 500,  -- batas data tersimpan di runtimeCapture.fireServer
            MAX_ARGS        = 8,    -- argumen yang dicatat per panggilan
            MAX_PENDING     = 256,  -- batas antrean di dalam hook (sisanya di-drop)
            DRAIN_PER_FRAME = 24,   -- item antrean yang diproses per Heartbeat
        },

        UI_MAX_ENTRIES  = 300, -- batas runtimeCapture.ui
        LOG_MAX_ENTRIES = 300, -- batas runtimeCapture.log
        MAX_LOG_LABELS  = 250, -- batas baris di panel LOG

        CORE_NAMES = {
            PlayerModule = true, CameraModule = true, ControlModule = true,
            ChatScript = true, Chat = true, PlayerScriptsChat = true,
            Animate = true, Health = true, Sound = true,
            ClickToMove = true, ClassicCamera = true,
        },

        SKIP_ROOTS = {
            { name = "ReplicatedStorage", abbr = "RS" },
            { name = "ReplicatedFirst",   abbr = "RF" },
            { name = "StarterPlayer",     abbr = "SP" },
            { name = "StarterGui",        abbr = "SG" },
            { name = "Workspace",         abbr = "WS" },
            { name = "Players",           abbr = "PL" },
            { name = "Lighting",          abbr = "LT" },
            { name = "SoundService",      abbr = "SS" },
            { name = "Chat",              abbr = "CH" },
            { name = "Teams",             abbr = "TM" },
        },

        MECHANIC_KW = {
            "damage","health","hit","attack","weapon","kill","death","respawn",
            "shield","armor","dmg","crit","swing","punch",
            "coin","cash","money","currency","gem","gold","shop","buy","purchase",
            "price","cost","sell","reward","drop","loot","chest",
            "xp","level","rank","exp","progress","unlock","upgrade","tier",
            "quest","mission","achievement","badge",
            "item","inventory","tool","gear","equip",
            "speed","jump","walk","run","sprint","stamina","dash","ability",
            "skill","power","cooldown","boost",
            "spawn","teleport","zone","area","map","portal","gate","round",
            "match","team","score","point","leaderboard","stat","win","lose",
            "save","load","data","profile","session",
            "ui","gui","menu","button","hud","notification",
        },

        TYPE_COLOR = {
            LocalScript  = Color3.fromRGB(120, 200, 255),
            ModuleScript = Color3.fromRGB(255, 200, 100),
            Script       = Color3.fromRGB(255, 130, 130),
        },

        STATUS_COLOR = {
            readable  = Color3.fromRGB(140, 220, 140),
            empty     = Color3.fromRGB(160, 160, 160),
            obf       = Color3.fromRGB(255, 180, 80),
            bcode     = Color3.fromRGB(200, 130, 255),
            truncated = Color3.fromRGB(255, 220, 90),
            skipped   = Color3.fromRGB(120, 120, 120),
        },

        COLOR = {
            ok     = Color3.fromRGB(100, 255, 150),
            warn   = Color3.fromRGB(255, 180, 80),
            err    = Color3.fromRGB(255, 100, 100),
            info   = Color3.fromRGB(150, 220, 255),
            dim    = Color3.fromRGB(200, 150, 100),
            busy   = Color3.fromRGB(255, 200, 100),
            on     = Color3.fromRGB(0, 140, 80),
            off    = Color3.fromRGB(80, 40, 40),
            tabOff = Color3.fromRGB(45, 45, 55),
        },

        -- Tema GUI (dipakai ui/kit + ui/frame)
        THEME = {
            bg     = Color3.fromRGB(16, 17, 23),
            panel  = Color3.fromRGB(26, 27, 36),
            card   = Color3.fromRGB(33, 35, 47),
            field  = Color3.fromRGB(20, 21, 29),
            btn    = Color3.fromRGB(52, 55, 72),
            text   = Color3.fromRGB(235, 236, 242),
            dim    = Color3.fromRGB(150, 154, 175),
            accent = Color3.fromRGB(78, 128, 255),
            good   = Color3.fromRGB(32, 160, 96),
            bad    = Color3.fromRGB(190, 70, 70),
            warn   = Color3.fromRGB(215, 150, 45),
            event  = Color3.fromRGB(110, 170, 255),
            func   = Color3.fromRGB(255, 180, 90),
            line   = Color3.fromRGB(64, 68, 92),
        },

        -- Metode capture remote (chip lama HK/UC digabung: UC = hookfunction yang sama dengan HK2)
        CAPTURE_METHODS = {
            { id = "auto", text = "Auto",     desc = "Tries Stealth first, falls back to Namecall. Best for most people." },
            { id = "hk2",  text = "Stealth",  desc = "Hooks FireServer/InvokeServer directly (hookfunction). Leaves __namecall untouched." },
            { id = "hk1",  text = "Namecall", desc = "Hooks __namecall (hookmetamethod). Fast, but some games detect it." },
        },

        -- AI BRIEF (export ringkas ~15K karakter) — dipakai build/brief_data + build/brief
        BRIEF = {
            MAX_CHARS     = 15000,
            MAX_ATTR_SCAN = 40000, -- batas jumlah instance yang dicek atributnya
            MAX_CONFIG    = 400,   -- batas keamanan (game dengan ribuan Value)
            OTHER_CONFIG  = 20,    -- nilai non-kunci yang tetap ditampilkan
            TREE_MAX_KIDS = 20,
            TREE_DEPTH    = { ReplicatedStorage = 3, StarterPlayer = 3, ReplicatedFirst = 2, StarterGui = 2,
                              StarterPack = 2, Workspace = 1, Lighting = 1, Teams = 1 },
            CONFIG_KEYS = {
                "price", "cost", "cooldown", "cd", "damage", "dmg", "ratio", "rate", "limit", "max", "min",
                "speed", "health", "hp", "range", "ammo", "mag", "reload", "delay", "duration", "spread",
                "recoil", "rpm", "firerate", "multiplier", "reward", "xp", "cash", "coin", "money", "kill",
                "point", "capture", "time", "count", "cap", "amount", "level", "burst", "radius", "force",
                "power", "stamina", "regen", "heal", "sprint", "walk", "jump", "fire", "velocity", "pen",
            },
            SYSTEMS = {
                { name = "Weapon",    kw = { "gun", "weapon", "fire", "reload", "ammo", "bullet", "damage", "shoot", "aim",
                                              "recoil", "bayonet", "barrel", "hatchet", "knife", "flash", "pen" } },
                { name = "Shop",      kw = { "shop", "purchase", "buy", "store", "price", "perk", "equipment" } },
                { name = "Class",     kw = { "class", "loadout", "choose", "role" } },
                { name = "Teleport",  kw = { "teleport", "spawn", "waypoint", "loadcharacter" } },
                { name = "Votekick",  kw = { "votekick", "kick", "vote" } },
                { name = "Inventory", kw = { "inventory", "backpack", "equip", "tool", "hotbar" } },
                { name = "Heal",      kw = { "heal", "medic", "bandage", "health" } },
                { name = "Grenade",   kw = { "grenade", "explosive", "frag", "mortar", "smoke" } },
            },
        },

        BTN_INFO = {
            SCAN    = { name = "Scan game", desc = "Reads the code of every script in the selected places.",
                        use = "Do this first. Most reports need scan results." },
            STOP    = { name = "Stop scan", desc = "Stops a running scan. Results found so far are kept.",
                        use = "Use it if the scan is too slow." },
            CLEAR   = { name = "Clear results", desc = "Removes the scan results from the list.",
                        use = "Use before a fresh scan." },
            SMART   = { name = "Smart report", desc = "Snapshot + captured data + game mechanics + diagnostics, saved as a .txt file.",
                        use = "Best all-round report. Send it to an AI or keep it as a backup." },
            FULL    = { name = "Full report", desc = "Everything in Smart plus index, remotes, tree and config values.",
                        use = "Complete backup. File can be large." },
            MECH    = { name = "Mechanics", desc = "Game mechanics summary (damage, shop, quests...). Copied to clipboard.",
                        use = "Paste into an AI to understand how the game works." },
            INDEX   = { name = "Script index", desc = "List of scripts and whether they are readable, empty or obfuscated.",
                        use = "Check how much of the game code you can actually read." },
            PATHS   = { name = "All paths", desc = "Full path of every scanned script.", use = "Handy reference list." },
            REMOTES = { name = "Remotes list", desc = "All RemoteEvents / RemoteFunctions found in the game.",
                        use = "See how the client talks to the server." },
            TREE    = { name = "Game tree", desc = "Folder structure of the main services (2-3 levels).",
                        use = "Map the game layout." },
            CONFIG  = { name = "Config values", desc = "Value objects and attributes (prices, cooldowns, ratios).",
                        use = "Find tuning numbers." },
            REPLAY  = { name = "Replay call", desc = "Sends the selected call to the server again with the same arguments.",
                        use = "Test what a remote does. Use carefully: it really fires the remote." },
            BLOCK   = { name = "Block remote", desc = "Stops this remote from reaching the server while blocking is on.",
                        use = "Check what breaks without it. Unblock to restore." },
            IGNORE  = { name = "Ignore remote", desc = "Hides this remote from the list (spammy remotes).",
                        use = "Reduce noise. 'Reset filters' brings them back." },
            BRIEF   = { name = "AI brief", desc = "Compact export (about 15,000 characters): header, unique remotes with signatures, key config values, mechanics summary, tree, unique API surface, grouped UI, diagnostics.",
                        use = "Best file to send to an AI. Identical scripts are collapsed, so it stays small." },
            EXPORTALL = { name = "Export ALL files", desc = "Saves AI brief, Smart, Full, Mechanics, Index, Paths, Remotes, Tree and Config as separate .txt files in one go.",
                          use = "One tap instead of exporting each report. Files are NOT merged." },
            TEMPLATE = { name = "Code template", desc = "Switches the generated code style: simple, advanced (pcall) or debug (prints).",
                         use = "Pick what you want to copy." },
        },

        ROOT_INFO = {
            RS = { name = "ReplicatedStorage", desc = "Shared remotes and modules.", use = "Most important place for game logic." },
            RF = { name = "ReplicatedFirst",   desc = "Loading scripts.", use = "Rarely useful." },
            SP = { name = "StarterPlayer",     desc = "Player scripts (movement, camera, input).", use = "Important." },
            SG = { name = "StarterGui",        desc = "UI templates and their scripts.", use = "Sometimes useful." },
            WS = { name = "Workspace",         desc = "Map, models, NPCs, tools.", use = "Biggest place. Slow to scan." },
            PL = { name = "Players",           desc = "Scripts that are actually running for you.", use = "Important." },
            LT = { name = "Lighting",          desc = "Visual effects and sky.", use = "Rarely has scripts." },
            SS = { name = "SoundService",      desc = "Sound groups.", use = "Rarely has scripts." },
            CH = { name = "Chat",              desc = "Chat system.", use = "Only for chat commands." },
            TM = { name = "Teams",             desc = "Team objects.", use = "Only for team logic." },
        },

        TOGGLE_INFO = {
            decompile = { name = "Decompile empty scripts", desc = "Tries decompile() when a script has no readable source. Slow and can crash weak executors.",
                          use = "Turn on only if many scripts show as empty." },
            bytecode  = { name = "Dump bytecode", desc = "Saves raw bytecode when nothing else works. Very large, not readable.",
                          use = "Almost never needed." },
            readCore  = { name = "Include Roblox core scripts", desc = "Also reads PlayerModule, CameraModule, ChatScript (about 300 KB).",
                          use = "Only if you need Roblox's own movement/camera code." },
            capture   = { name = "Record game actions", desc = "Records every FireServer / InvokeServer call the game makes, with arguments.",
                          use = "Turn on, then do the action in the game once." },
            uiwatch   = { name = "Record on-screen buttons", desc = "Records buttons that appear in your PlayerGui.",
                          use = "Find buttons that are created while playing." },
            passive   = { name = "Listen to server messages", desc = "Logs game errors/warnings and RemoteEvents the server sends to you.",
                          use = "See what the server tells the client." },
        },
    }
end
