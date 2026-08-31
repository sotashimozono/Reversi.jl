function Reversi.launch_replay_gui(record::GameRecord; title::String="Game Replay")
    return Reversi.launch_replay_gui(record.moves; title=title)
end

function _build_replay_view(moves::Vector{String}; title::String="Game Replay")
    # Pre-compute all board states
    states = Vector{ReversiGame}(undef, length(moves)+1)
    move_colors = Vector{Int}(undef, length(moves))
    states[1] = ReversiGame()
    for (i, m) in enumerate(moves)
        g = deepcopy(states[i])
        move_colors[i] = g.current_player
        m == "pass" ? pass!(g) : make_move!(g, m)
        states[i + 1] = g
    end
    n_moves = length(moves)

    pos_obs = Observable(0)
    game_obs = Observable(states[1])
    show_last_obs = Observable(true)

    config = load_config()
    fig = Figure(;
        size=(config.window_width, config.window_height),
        backgroundcolor=_get_color(config, "background"),
    )

    # -- Title bar --
    Label(
        fig[1, 1];
        text=title,
        color=_get_color(config, "text"),
        fontsize=(config.fontsize+1),
        font=:bold,
        halign=:left,
        tellwidth=false,
    )
    Label(
        fig[1, 1];
        text=@lift(
            let (b, w) = count_pieces($game_obs)
                "B $b – W $w"
            end
        ),
        color=_get_color(config, "text_dim"),
        fontsize=config.fontsize,
        halign=:right,
        tellwidth=false,
    )
    rowsize!(fig.layout, 1, Fixed(36))

    # -- Board --
    ax = Axis(
        fig[2, 1];
        aspect=DataAspect(),
        limits=(-0.40, 8.32, -0.24, 8.55),
        backgroundcolor=_get_color(config, "background"),
        xgridvisible=false,
        ygridvisible=false,
        xticksvisible=false,
        yticksvisible=false,
        xticklabelsvisible=false,
        yticklabelsvisible=false,
        leftspinevisible=false,
        rightspinevisible=false,
        topspinevisible=false,
        bottomspinevisible=false,
    )

    # -- Navigation bar --
    c_panel = _get_color(config, "panel")
    c_text = _get_color(config, "text")
    nav = fig[3, 1] = GridLayout()
    btn_first = Button(
        nav[1, 1];
        label="|◀",
        buttoncolor=c_panel,
        labelcolor=c_text,
        fontsize=config.fontsize,
        width=44,
    )
    btn_prev = Button(
        nav[1, 2];
        label="◀",
        buttoncolor=c_panel,
        labelcolor=c_text,
        fontsize=config.fontsize,
        width=44,
    )
    btn_next = Button(
        nav[1, 3];
        label="▶",
        buttoncolor=c_panel,
        labelcolor=c_text,
        fontsize=config.fontsize,
        width=44,
    )
    btn_last = Button(
        nav[1, 4];
        label="▶|",
        buttoncolor=c_panel,
        labelcolor=c_text,
        fontsize=config.fontsize,
        width=44,
    )
    slider = Slider(nav[1, 5]; range=0:n_moves, startvalue=0)
    Label(
        nav[1, 6];
        text=@lift("Move $($pos_obs) / $n_moves"),
        color=_get_color(config, "text_dim"),
        fontsize=(config.fontsize-1),
        halign=:left,
        tellwidth=false,
    )
    tgl_last = Toggle(nav[1, 7]; active=config.show_last_move)
    Label(
        nav[1, 8];
        text="Last Move",
        color=_get_color(config, "text_dim"),
        fontsize=(config.fontsize-2),
    )
    rowsize!(fig.layout, 3, Fixed(48))
    colsize!(nav, 5, Relative(1.0))

    # -- Kifu sidebar --
    kifu_panel = fig[1:3, 2] = GridLayout()
    Label(
        kifu_panel[1, 1];
        text="Move History",
        color=_get_color(config, "text"),
        fontsize=config.fontsize,
        font=:bold,
        halign=:center,
    )
    kifu_ax = Axis(
        kifu_panel[2, 1];
        backgroundcolor=_get_color(config, "panel"),
        xgridvisible=false,
        ygridvisible=false,
        xticksvisible=false,
        yticksvisible=false,
        xticklabelsvisible=false,
        yticklabelsvisible=false,
        leftspinevisible=false,
        rightspinevisible=false,
        topspinevisible=false,
        bottomspinevisible=false,
        yreversed=true,
    )
    colsize!(fig.layout, 1, Relative(1.0))
    colsize!(fig.layout, 2, Fixed(config.sidebar_width))
    rowsize!(fig.layout, 2, Relative(1.0))

    # Pre-build kifu entries once (move_n, color, notation)
    kifu_entries = [(i, move_colors[i], moves[i]) for i in 1:n_moves]

    # ---------------------------------------------------------------------------
    # Navigation logic
    # ---------------------------------------------------------------------------
    function _goto!(p)
        p = clamp(p, 0, n_moves)
        pos_obs[] = p
        game_obs[] = states[p + 1]
        slider.value[] = p
        lm = (show_last_obs[] && p > 0 && moves[p] != "pass") ? Position(moves[p]) : nothing
        _refresh_board!(ax, states[p + 1], false, show_last_obs[], lm, false, config)
        return _refresh_replay_kifu!(kifu_ax, moves, move_colors, p, config)
    end

    on(tgl_last.active) do v
        show_last_obs[] = v
        return _goto!(pos_obs[])
    end
    on(ax.scene.viewport) do _
        return _goto!(pos_obs[])
    end
    on(btn_first.clicks) do _
        return _goto!(0)
    end
    on(btn_prev.clicks) do _
        return _goto!(pos_obs[]-1)
    end
    on(btn_next.clicks) do _
        return _goto!(pos_obs[]+1)
    end
    on(btn_last.clicks) do _
        return _goto!(n_moves)
    end
    on(slider.value) do v
        v == pos_obs[] && return nothing
        return _goto!(v)
    end
    on(events(fig.scene).keyboardbutton) do event
        (event.action == Keyboard.press || event.action == Keyboard.repeat) ||
            return nothing
        event.key == Keyboard.left && _goto!(pos_obs[]-1)
        event.key == Keyboard.right && _goto!(pos_obs[]+1)
        event.key == Keyboard.home && _goto!(0)
        return event.key == Keyboard.end_ && _goto!(n_moves)
    end

    _goto!(0)
    return fig
end

function Reversi.launch_replay_gui(moves::Vector{String}; title::String="Game Replay")
    fig = _build_replay_view(moves; title=title)
    display(fig)
    return fig
end
