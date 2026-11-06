--[[ UI WIDGETS — factory Instance + palet warna ]]

return function(REN)
    local W = {}
    W.GREEN = Color3.fromRGB(0, 220, 160)
    W.TXT   = Color3.fromRGB(220, 220, 240)
    W.RED   = Color3.fromRGB(255, 100, 100)
    W.INFO  = Color3.fromRGB(180, 200, 220)

    function W.mk(class, props, parent)
        local o = Instance.new(class)
        for k, v in pairs(props) do o[k] = v end
        o.Parent = parent
        return o
    end

    function W.corner(o, r)
        W.mk("UICorner", {CornerRadius = UDim.new(0, r)}, o)
    end

    function W.pad(o, l, t)
        W.mk("UIPadding", {
            PaddingLeft = UDim.new(0, l or 0),
            PaddingTop  = UDim.new(0, t or 0),
        }, o)
    end

    function W.button(parent, props, r)
        props.BorderSizePixel   = 0
        props.AutoButtonColor   = false
        props.Font              = props.Font or Enum.Font.GothamBold
        props.TextColor3        = props.TextColor3 or W.TXT
        local b = W.mk("TextButton", props, parent)
        W.corner(b, r or 5)
        return b
    end

    function W.label(parent, props)
        props.BackgroundTransparency = 1
        props.Font                   = props.Font or Enum.Font.Gotham
        props.TextXAlignment         = props.TextXAlignment or Enum.TextXAlignment.Left
        return W.mk("TextLabel", props, parent)
    end

    function W.input(parent, props)
        props.BorderSizePixel      = 0
        props.BackgroundColor3     = props.BackgroundColor3 or Color3.fromRGB(35, 40, 55)
        props.PlaceholderColor3    = Color3.fromRGB(140, 145, 165)
        props.TextColor3           = Color3.fromRGB(230, 230, 240)
        props.Font                 = Enum.Font.Gotham
        props.TextSize             = 10
        props.TextXAlignment       = Enum.TextXAlignment.Left
        props.ClearTextOnFocus     = false
        props.Text                 = ""
        local b = W.mk("TextBox", props, parent)
        W.corner(b, 5)
        W.pad(b, 6, props.MultiLine and 4 or 0)
        return b
    end

    REN.Widgets = W
end
