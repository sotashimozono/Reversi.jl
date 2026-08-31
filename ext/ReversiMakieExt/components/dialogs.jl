function _open_add_player_dialog!(
    registry_obs::Observable, update_cb::Function, config::GUIConfig
)
    c_bg = _get_color(config, "background")
    c_text = _get_color(config, "text")
    c_dim = _get_color(config, "text_dim")
    c_panel = _get_color(config, "panel")
    c_accent = _get_color(config, "accent_black")
    c_err = _get_color(config, "last_move")
    fs = config.fontsize

    dlg = Figure(; size=(480, 240), backgroundcolor=c_bg)

    Label(
        dlg[1, 1:2];
        text="Register Custom Player",
        color=c_text,
        fontsize=fs+2,
        font=:bold,
        halign=:center,
    )
    Label(dlg[2, 1]; text="Name:", color=c_dim, fontsize=fs, halign=:right)
    Label(dlg[3, 1]; text="Expression:", color=c_dim, fontsize=fs, halign=:right)

    name_tb = Textbox(dlg[2, 2]; placeholder="e.g. My AI", fontsize=fs, width=300)
    expr_tb = Textbox(dlg[3, 2]; placeholder="e.g. MyPlayer()", fontsize=fs, width=300)
    msg_lbl = Label(dlg[4, 1:2]; text="", color=c_err, fontsize=fs-2)

    btn_row = dlg[5, 1:2] = GridLayout()
    btn_cancel = Button(
        btn_row[1, 1]; label="Cancel", buttoncolor=c_panel, labelcolor=c_dim, fontsize=fs
    )
    btn_reg = Button(
        btn_row[1, 2];
        label="✔ Register",
        buttoncolor=c_panel,
        labelcolor=c_accent,
        fontsize=fs,
    )

    on(btn_cancel.clicks) do _
        return close(dlg.scene)
    end

    on(btn_reg.clicks) do _
        raw_name = strip(name_tb.stored_string[])
        raw_expr = strip(expr_tb.stored_string[])
        isempty(raw_name) && (msg_lbl.text[]="⚠ Please enter a name."; return nothing)
        isempty(raw_expr) &&
            (msg_lbl.text[]="⚠ Please enter a Julia expression."; return nothing)
        local player_instance
        try
            player_instance = Main.eval(Meta.parse(raw_expr))
        catch e
            msg_lbl.text[] = "⚠ Error: $(sprint(showerror, e))"
            return nothing
        end
        if !(player_instance isa Player)
            msg_lbl.text[] = "⚠ Result is not a Player (got $(typeof(player_instance)))."
            return nothing
        end
        expr_str = raw_expr
        entry = NamedPlayerEntry(String(raw_name), () -> Main.eval(Meta.parse(expr_str)))
        registry_obs[] = vcat(registry_obs[], [entry])
        update_cb()
        return close(dlg.scene)
    end

    display(dlg)
    return dlg
end
