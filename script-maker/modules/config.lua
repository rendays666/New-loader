--[[ CONFIG — konstanta statis: limit scan, daftar root, keyword, teks tooltip, warna.
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

        -- Capture FireServer / InvokeServer (HK + UC)
        FS = {
            DEDUP_SEC       = 0.01, -- panggilan identik < 10ms dianggap duplikat
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

        BTN_INFO = {
            SCAN  = {name="SCAN", desc="Scan .Source semua script dari root aktif.",
                     use="Wajib. Tombol lain butuh hasil scan."},
            SMART = {name="SMART", desc="Build mechanics pack + save .txt (include config snapshot + runtime).",
                     use="Arsip gameplay + request AI lain analisis."},
            MECH  = {name="MECH", desc="Build mechanics pack → clipboard.",
                     use="Paste ke AI buat analisis gameplay cepat."},
            INDEX = {name="INDEX", desc="Daftar script + status.",
                     use="Cek readable vs obf vs trunc."},
            FULL  = {name="FULL", desc="Save semua: config+index+mechanics+remotes+tree+runtime.",
                     use="Backup lengkap ke repo pribadi."},
            CLR   = {name="CLR", desc="Clear list / abort scan.",
                     use="Reset sebelum re-scan atau stop scan lambat."},
            REM   = {name="REM", desc="List RemoteEvent/RemoteFunction.",
                     use="Lihat daftar remote yang dipakai game."},
            CFG   = {name="CFG", desc="Dump Value + Attributes.",
                     use="Angka tuning (harga, cooldown, ratio)."},
            PATH  = {name="PATH", desc="Daftar full path semua script.",
                     use="Copy path untuk referensi."},
            RUN   = {name="RUN", desc="Hook LogService + OnClientEvent (passive log).",
                     use="Lihat error/warning + argumen server→client."},
            TREE  = {name="TREE", desc="Hierarchy service 2-3 level.",
                     use="Mapping struktur game."},
        },

        ROOT_INFO = {
            RS = {name="ReplicatedStorage", desc="Remote + ModuleScript shared.",
                  use="Komunikasi client-server."},
            RF = {name="ReplicatedFirst", desc="Script loading awal.",
                  use="Jalan sebelum game ready."},
            SP = {name="StarterPlayer", desc="Template LocalScript player.",
                  use="Gerakan, camera, ability, input player."},
            SG = {name="StarterGui", desc="Template UI.",
                  use="Struktur UI sebelum di-clone ke PlayerGui."},
            WS = {name="Workspace", desc="Map, model, NPC, Tool.",
                  use="Paling banyak instance — lambat."},
            PL = {name="Players", desc="Player object + PlayerScripts runtime.",
                  use="Script yang beneran jalan."},
            LT = {name="Lighting", desc="Efek visual, sky.", use="Jarang ada script."},
            SS = {name="SoundService", desc="Sound group.", use="Jarang ada script."},
            CH = {name="Chat", desc="TextChatService.", use="Audit command handler chat."},
            TM = {name="Teams", desc="Team container.", use="Cek team logic."},
        },

        TOGGLE_INFO = {
            DC = {name="DC — Decompile Fallback",
                  desc="Coba decompile() kalau .Source kosong. LAMBAT + crash-prone.",
                  use="Aktifkan hanya untuk script spesifik yang source kosong."},
            BC = {name="BC — Bytecode Dump",
                  desc="Bytecode mentah kalau decompile gagal. SANGAT besar.",
                  use="Hanya untuk arsip — bytecode tidak terbaca."},
            RC = {name="RC — Read Roblox Core",
                  desc="Ikut baca PlayerModule/CameraModule/ChatScript (≈300KB).",
                  use="Hanya kalau butuh movement/camera code Roblox."},
            UI = {name="UI — Watch PlayerGui",
                  desc="Rekam ImageButton/TextButton yang muncul di PlayerGui.",
                  use="Cari nama tombol yang di-generate runtime."},
            HK = {name="HK — Hook FireServer",
                  desc="Log argumen FireServer/InvokeServer. Hook ringan + antrean, tidak mengganggu GUI game.",
                  use="Lihat isi argumen remote (origin, direction, weapon)."},
            UC = {name="UC — Unreliable Mode",
                  desc="Patch metatable (fallback kalau HK gagal catch). Hanya aktif kalau HK mati.",
                  use="Kalau RemoteEvent Unreliable lolos dari HK."},
            RT = {name="RT — Clear Runtime",
                  desc="Hapus semua capture (UI + FireServer + Log).",
                  use="Reset sebelum capture baru."},
        },
    }
end
