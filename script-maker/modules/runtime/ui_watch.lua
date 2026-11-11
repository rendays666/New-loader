--[[ RUNTIME/UI_WATCH — chip UI: rekam ImageButton/TextButton di PlayerGui.
     Data masuk ke D.State.runtimeCapture.ui. Baris di panel LOG dibatasi
     (PANEL_LIMIT) supaya game yang membuat ribuan tombol tidak membuat GUI lag.
     API: D.UIWatch.set(bool) ]]

return function(D)
    local S, Cfg = D.State, D.Config
    local W = { total = 0, panelLogged = 0 }
    D.UIWatch = W

    local PANEL_LIMIT = 40
    local conns = {}

    local function isButton(d)
        return d:IsA("ImageButton") or d:IsA("TextButton")
    end

    local function record(d)
        if not d or not d.Parent then return end
        local gui = D.UI.gui
        if gui and d:IsDescendantOf(gui) then return end -- jangan catat GUI Dumper sendiri

        local ok, e = pcall(function()
            return {
                time    = os.clock(),
                path    = d:GetFullName(),
                class   = d.ClassName,
                pos     = tostring(d.AbsolutePosition),
                size    = tostring(d.AbsoluteSize),
                text    = (d:IsA("TextButton") and d.Text) or "",
                image   = (d:IsA("ImageButton") and d.Image) or "",
                visible = d.Visible,
            }
        end)
        if not ok or not e then return end

        local list = S.runtimeCapture.ui
        list[#list + 1] = e
        if #list > Cfg.UI_MAX_ENTRIES then table.remove(list, 1) end
        W.total = W.total + 1

        if W.panelLogged < PANEL_LIMIT then
            W.panelLogged = W.panelLogged + 1
            D.Log.write(("🖱 [UI] %s [%s] pos=%s size=%s%s%s"):format(
                e.path, e.class, e.pos, e.size,
                e.text ~= "" and (" text=" .. e.text:sub(1, 24)) or "",
                e.image ~= "" and (" img=" .. e.image:sub(1, 40)) or ""),
                Color3.fromRGB(100, 255, 200), "ui")
            if W.panelLogged == PANEL_LIMIT then
                D.Log.write("[UI] (log panel dibatasi — data lengkap tetap masuk SMART/FULL)",
                    Cfg.COLOR.dim, "ui")
            end
        end
    end

    function W.set(state)
        if state == S.uiActive then return end
        S.uiActive = state

        if not state then
            for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
            conns = {}
            D.Log.write("[UI] ✗ stopped", Cfg.COLOR.dim, "ui")
            return
        end

        local pg = S.LocalPlayer:FindFirstChild("PlayerGui") or S.LocalPlayer:WaitForChild("PlayerGui", 3)
        if not pg then
            S.uiActive = false
            D.Log.write("[UI] ✗ PlayerGui not found", Cfg.COLOR.err, "ui")
            return
        end

        W.panelLogged = 0
        table.insert(conns, pg.DescendantAdded:Connect(function(d)
            if isButton(d) then
                task.delay(0.15, function()
                    if S.uiActive then D.Log.safe("ui_watch", record, d) end
                end)
            end
        end))
        D.Log.write("[UI] ✓ watching PlayerGui", Color3.fromRGB(100, 255, 200), "ui")

        task.spawn(function()
            local n = 0
            for _, d in ipairs(pg:GetDescendants()) do
                if not S.uiActive then return end
                if isButton(d) then D.Log.safe("ui_watch", record, d) end
                n = n + 1
                if n % 200 == 0 then task.wait() end
            end
            D.Log.write(("[UI] initial scan selesai (%d tombol tercatat)"):format(W.total),
                Cfg.COLOR.info, "ui")
        end)
    end

    function W.stop()
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        conns = {}
    end
end
