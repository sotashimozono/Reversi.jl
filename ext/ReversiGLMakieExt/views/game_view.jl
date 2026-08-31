function Reversi.launch_gui(
    ::Val{:makie},
    black::Union{Player,Nothing}=nothing,
    white::Union{Player,Nothing}=nothing;
    show_hints::Union{Bool,Nothing}=nothing,
)
    config = load_config()
    b_player = isnothing(black) ? _get_player_by_name(config.black_player) : black
    w_player = isnothing(white) ? _get_player_by_name(config.white_player) : white
    sh = isnothing(show_hints) ? config.show_hints : show_hints

    # ---------------------------------------------------------------------------
    # Observables — game state
    # ---------------------------------------------------------------------------
    game_obs = Observable(ReversiGame())
    hints_obs = Observable(sh)
    game_over_obs = Observable(false)
    last_move_obs = Observable{Union{Position,Nothing}}(nothing)
    show_last_obs = Observable(config.show_last_move)
    kifu_obs = Observable(Tuple{Int,Int,String}[])
    score_history_obs = Observable(Float32[0.0f0])
    registry_obs = Observable(copy(_BUILTIN_PLAYERS))
    players = Ref{Dict{Int,Player}}(Dict(BLACK => b_player, WHITE => w_player))

    # ---------------------------------------------------------------------------
    # Observables — UI state machine
    # ---------------------------------------------------------------------------
    mode_obs = Observable(:live)   # :live | :review
    review_pos_obs = Observable(0)
    show_eval_obs = Observable(config.show_eval)
    show_sidebar_obs = Observable(config.show_kifu)
    auto_start_obs = Observable(false)
    game_gen = Ref(0)             # incremented on each new game; stale tasks exit

    # ---------------------------------------------------------------------------
    # Figure & layout
    # ---------------------------------------------------------------------------
    fig = Figure(;
        size=(config.window_width, config.window_height),
        backgroundcolor=_get_color(config, "background"),
    )
    content_grid = fig[1, 1] = GridLayout(; halign=:center, tellwidth=true)

    # ---------------------------------------------------------------------------
    # Row 1: top bar — Actions menu + player selectors
    # Phase 4: _find_idx uses _player_name for reliable sync with any player type
    # ---------------------------------------------------------------------------
    menu_bar = content_grid[1, 1:2] = GridLayout(; valign=:center)
    action_menu = Menu(
        menu_bar[1, 1];
        options=["▶ New Game", "+ Add Player"],
        textcolor=_get_color(config, "text"),
        fontsize=(config.fontsize - 2),
        width=100,
        height=24,
        prompt="Actions",
        default=nothing,
        selection_cell_color_inactive=_get_color(config, "panel"),
    )
    colsize!(menu_bar, 1, Fixed(110))

    menu_options_obs = Observable([e.name for e in registry_obs[]])
    on(registry_obs) do reg
        return menu_options_obs[] = [e.name for e in reg]
    end

    # Phase 4: resolve index by matching _player_name against registry entries
    function _find_idx(reg, p)
        name = _player_name(p)
        idx = findfirst(e -> e.name == name, reg)
        return something(idx, 1)
    end

    Label(
        menu_bar[1, 2];
        text="●",
        color=_get_color(config, "accent_black"),
        fontsize=10,
        halign=:right,
        tellwidth=false,
    )
    black_sel = Menu(
        menu_bar[1, 3];
        options=menu_options_obs,
        default=_find_idx(registry_obs[], b_player),
        fontsize=11,
        width=90,
        prompt="Human",
        selection_cell_color_inactive=_get_color(config, "accent_black"),
    )
    Label(
        menu_bar[1, 4];
        text="○",
        color=_get_color(config, "accent_white"),
        fontsize=10,
        halign=:right,
        tellwidth=false,
    )
    white_sel = Menu(
        menu_bar[1, 5];
        options=menu_options_obs,
        default=_find_idx(registry_obs[], w_player),
        fontsize=11,
        width=90,
        prompt="Human",
        selection_cell_color_inactive=_get_color(config, "accent_white"),
    )
    colsize!(menu_bar, 2, Fixed(18))
    colsize!(menu_bar, 3, Fixed(100))
    colsize!(menu_bar, 4, Fixed(18))
    colsize!(menu_bar, 5, Fixed(100))
    rowsize!(content_grid, 1, Fixed(34))

    # ---------------------------------------------------------------------------
    # Row 2: board column (left) + kifu sidebar (right)
    # ---------------------------------------------------------------------------
    main_row = content_grid[2, 1:2] = GridLayout(; valign=:center)
    main_col = main_row[1, 1] = GridLayout()
    rsb = main_row[1, 2] = GridLayout(; valign=:top)
    colsize!(main_row, 1, Fixed(480))
    rowsize!(content_grid, 2, Auto())

    # -- Board axis --
    ax = Axis(
        main_col[1, 1];
        width=480,
        height=480,
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
    rowsize!(main_col, 1, Fixed(480))

    # -- Evaluation graph (directly below board) --
    eval_panel = main_col[2, 1] = GridLayout()
    Label(
        eval_panel[1, 1];
        text="Evaluation",
        color=_get_color(config, "text_dim"),
        fontsize=(config.fontsize - 2),
        halign=:left,
    )
    eval_ax = Axis(
        eval_panel[2, 1];
        backgroundcolor=_get_color(config, "panel"),
        xgridvisible=false,
        ygridvisible=false,
        xticksvisible=false,
        yticksvisible=true,
        xticklabelsvisible=false,
        yticklabelsvisible=true,
        leftspinevisible=false,
        rightspinevisible=true,
        topspinevisible=false,
        bottomspinevisible=false,
        rightspinecolor=_get_color(config, "text_dim"),
        yticks=([-32, 0, 32], ["-32", "0", "+32"]),
        ytickalign=1,
        yticklabelsize=8,
        yticklabelcolor=_get_color(config, "text_dim"),
    )
    rowsize!(main_col, 2, Fixed(config.show_eval ? 100 : 0))

    # -- Status bar (piece counts + game state) --
    status_bar = main_col[3, 1] = GridLayout()
    Label(
        status_bar[1, 1];
        text=@lift("$(count_pieces($game_obs)[2])"),
        color=_get_color(config, "accent_white"),
        fontsize=(config.fontsize + 8),
        font=:bold,
        halign=:center,
    )
    Label(
        status_bar[1, 2];
        text=@lift("$(count_pieces($game_obs)[1])"),
        color=_get_color(config, "accent_black"),
        fontsize=(config.fontsize + 8),
        font=:bold,
        halign=:center,
    )
    Label(
        status_bar[1, 3];
        text=@lift(
            if $mode_obs == :review
                "Reviewing move $($review_pos_obs)"
            elseif $game_over_obs
                "Game Over"
            elseif $game_obs.current_player == BLACK
                "Black's Turn"
            else
                "White's Turn"
            end
        ),
        color=@lift(
            $mode_obs == :review ? RGBf(1.0, 0.75, 0.3) : _get_color(config, "text_dim")
        ),
        fontsize=config.fontsize,
        halign=:center,
    )
    rowsize!(main_col, 3, Fixed(40))
    for c in 1:3
        colsize!(status_bar, c, Relative(1/3))
    end

    # -- Control toggles + Return-to-Live button --
    ctrl = main_col[4, 1] = GridLayout()
    tgl_hints = Toggle(ctrl[1, 1]; active=sh)
    Label(
        ctrl[1, 2];
        text="Hints",
        color=_get_color(config, "text_dim"),
        fontsize=(config.fontsize - 1),
    )
    tgl_last = Toggle(ctrl[1, 3]; active=config.show_last_move)
    Label(
        ctrl[1, 4];
        text="Last Move",
        color=_get_color(config, "text_dim"),
        fontsize=(config.fontsize - 1),
    )
    live_btn = Button(
        ctrl[1, 6];
        label="● Live",
        buttoncolor=_get_color(config, "panel"),
        labelcolor=_get_color(config, "text_dim"),
        fontsize=(config.fontsize - 2),
    )
    colsize!(ctrl, 4, Relative(1.0))
    rowsize!(main_col, 4, Fixed(36))

    # ---------------------------------------------------------------------------
    # Kifu sidebar
    # ---------------------------------------------------------------------------
    kifu_panel = rsb[1, 1] = GridLayout(; valign=:top)
    kifu_header_lbl = Label(
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
        height=480,
        valign=:top,
    )
    rowsize!(rsb, 1, Fixed(520))
    colsize!(main_row, 2, Fixed(config.show_kifu ? 200 : 0))  # after sidebar content exists

    # ---------------------------------------------------------------------------
    # Phase 3: Conditional layout — show/hide eval panel and sidebar
    # ---------------------------------------------------------------------------
    on(show_eval_obs) do show
        rowsize!(main_col, 2, Fixed(show ? 100 : 0))
        config.show_eval = show
        save_session_config(config)
        # Refresh on re-show so the graph is current
        return show && _refresh_eval_graph!(
            eval_ax,
            score_history_obs[],
            mode_obs[] == :review ? review_pos_obs[] : 0,
            config,
        )
    end

    on(show_sidebar_obs) do show
        colsize!(main_row, 2, Fixed(show ? 200 : 0))
        kifu_header_lbl.visible[] = show
        kifu_ax.scene.visible[] = show
        kifu_ax.blockscene.visible[] = show
        config.show_kifu = show
        save_session_config(config)
        # Refresh on re-show so the kifu is current
        return show && _draw_kifu!(
            kifu_ax,
            kifu_obs[],
            config;
            active_n=mode_obs[] == :review ? review_pos_obs[] : 0,
        )
    end

    # ---------------------------------------------------------------------------
    # Review mode helpers
    # ---------------------------------------------------------------------------

    function enter_review!(n::Int)
        kifu = kifu_obs[]
        (1 <= n <= length(kifu)) || return nothing

        g = ReversiGame()
        lm = nothing
        for (i, (_, _, notation)) in enumerate(kifu)
            i > n && break
            if notation == "pass"
                pass!(g; force=true)
            else
                pos = Position(notation)
                make_move!(g, pos.row, pos.col)
                lm = pos
            end
        end

        mode_obs[] = :review
        review_pos_obs[] = n
        _refresh_board!(ax, g, false, true, lm, false, config)
        show_sidebar_obs[] && _draw_kifu!(kifu_ax, kifu, config; active_n=n)
        return show_eval_obs[] &&
               _refresh_eval_graph!(eval_ax, score_history_obs[], n, config)
    end

    function return_to_live!()
        mode_obs[] = :live
        review_pos_obs[] = 0
        _refresh_board!(
            ax,
            game_obs[],
            hints_obs[],
            show_last_obs[],
            last_move_obs[],
            game_over_obs[],
            config,
        )
        show_sidebar_obs[] && _draw_kifu!(kifu_ax, kifu_obs[], config; active_n=0)
        return show_eval_obs[] &&
               _refresh_eval_graph!(eval_ax, score_history_obs[], 0, config)
    end

    # ---------------------------------------------------------------------------
    # Reactive updates (live mode only)
    # ---------------------------------------------------------------------------
    on(game_obs) do game
        mode_obs[] == :review && return nothing
        return _refresh_board!(
            ax, game, hints_obs[], show_last_obs[], last_move_obs[], game_over_obs[], config
        )
    end
    on(kifu_obs) do kifu
        mode_obs[] == :review && return nothing
        show_sidebar_obs[] && _draw_kifu!(kifu_ax, kifu, config; active_n=0)
        # score history replay (needed for eval graph and review mode even when hidden)
        hist = Float32[0.0f0]
        g = ReversiGame()
        for (_, _, notation) in kifu
            if notation == "pass"
                pass!(g; force=true)
            else
                pos = Position(notation)
                make_move!(g, pos.row, pos.col)
            end
            b, w = count_pieces(g)
            push!(hist, Float32(b - w))
        end
        score_history_obs[] = hist
        return show_eval_obs[] && _refresh_eval_graph!(eval_ax, hist, 0, config)
    end
    on(tgl_hints.active) do v
        hints_obs[] = v
        config.show_hints = v
        save_session_config(config)
        return mode_obs[] == :live && _refresh_board!(
            ax, game_obs[], v, show_last_obs[], last_move_obs[], game_over_obs[], config
        )
    end
    on(tgl_last.active) do v
        show_last_obs[] = v
        config.show_last_move = v
        save_session_config(config)
        return mode_obs[] == :live && _refresh_board!(
            ax, game_obs[], hints_obs[], v, last_move_obs[], game_over_obs[], config
        )
    end
    on(ax.scene.viewport) do _
        return mode_obs[] == :live && _refresh_board!(
            ax,
            game_obs[],
            hints_obs[],
            show_last_obs[],
            last_move_obs[],
            game_over_obs[],
            config,
        )
    end

    # Sync Live/Review button style with mode
    on(mode_obs) do mode
        if mode == :review
            live_btn.buttoncolor[] = RGBf(0.65, 0.30, 0.05)
            live_btn.labelcolor[] = RGBf(1.0, 1.0, 1.0)
            live_btn.label[] = "← Return to Live"
        else
            live_btn.buttoncolor[] = _get_color(config, "panel")
            live_btn.labelcolor[] = _get_color(config, "text_dim")
            live_btn.label[] = "● Live"
        end
    end
    on(live_btn.clicks) do _
        return mode_obs[] == :review && return_to_live!()
    end

    # Auto-restart: when game ends and auto_start_obs is on, start next game
    on(game_over_obs) do is_over
        is_over && auto_start_obs[] || return nothing
        sleep(0.4)   # brief pause so the final position is visible
        return start_game!(
            _selected_player(black_sel, registry_obs[]),
            _selected_player(white_sel, registry_obs[]),
        )
    end

    # ---------------------------------------------------------------------------
    # Game session management
    # ---------------------------------------------------------------------------
    function start_game!(new_black::Player, new_white::Player)
        for p in values(players[])
            if p isa HumanPlayer &&
                isopen(p.move_channel) &&
                p !== new_black &&
                p !== new_white
                close(p.move_channel)
            end
        end
        mode_obs[] = :live
        review_pos_obs[] = 0
        players[] = Dict{Int,Player}(BLACK => new_black, WHITE => new_white)
        kifu_ref = Ref(Tuple{Int,Int,String}[])
        game_ref = Ref(ReversiGame())
        game_over_obs[] = false
        last_move_obs[] = nothing
        score_history_obs[] = Float32[0.0f0]
        kifu_obs[] = kifu_ref[]
        game_obs[] = game_ref[]
        game_gen[] += 1
        my_gen = game_gen[]
        @async run_game!(
            game_ref,
            kifu_ref,
            players,
            game_obs,
            kifu_obs,
            last_move_obs,
            game_over_obs;
            stop_check=() -> game_gen[] != my_gen,
        )
    end

    on(action_menu.selection) do action
        isnothing(action) && return nothing
        action_menu.i_selected[] = 0
        if action == "▶ New Game"
            return start_game!(
                _selected_player(black_sel, registry_obs[]),
                _selected_player(white_sel, registry_obs[]),
            )
        elseif action == "+ Add Player"
            return _open_add_player_dialog!(registry_obs, () -> nothing, config)
        end
        return nothing
    end

    # ---------------------------------------------------------------------------
    # Board clicks — Phase 3: disabled during AI thinking AND review mode
    # ---------------------------------------------------------------------------
    ai_thinking_obs = Observable(false)

    register_interaction!(ax, :board_click) do event::MouseEvent, _
        event.type == MouseEventTypes.leftclick || return nothing
        mode_obs[] == :review && return nothing
        ai_thinking_obs[] && return nothing
        game = game_obs[]
        game_over_obs[] && return nothing
        data_pos = event.data
        (0.0 <= data_pos[1] <= 8.0 && 0.0 <= data_pos[2] <= 8.0) || return nothing
        col = clamp(Int(floor(data_pos[1])) + 1, 1, 8)
        row = clamp(_BOARD_SIZE - Int(floor(data_pos[2])), 1, 8)
        cp = players[][game.current_player]
        if cp isa HumanPlayer && isopen(cp.move_channel)
            put!(cp.move_channel, Position(row, col))
        end
    end

    # ---------------------------------------------------------------------------
    # Kifu clicks → enter review mode
    # ---------------------------------------------------------------------------
    on(events(fig.scene).mousebutton) do event
        event.button == Mouse.left && event.action == Mouse.press || return nothing
        is_mouseinside(kifu_ax.scene) || return nothing
        isempty(kifu_obs[]) && return nothing
        n = Reversi.kifu_row_at(mouseposition(kifu_ax.scene)[2])
        n_clamped = clamp(n, 1, length(kifu_obs[]))
        return n >= 1 && n == n_clamped && enter_review!(n_clamped)
    end

    # ---------------------------------------------------------------------------
    # Keyboard shortcuts: ←/→ step review, Escape returns to live
    # ---------------------------------------------------------------------------
    on(events(fig.scene).keyboardbutton) do event
        (event.action == Keyboard.press || event.action == Keyboard.repeat) ||
            return nothing
        key = event.key
        n_kifu = length(kifu_obs[])
        cur = review_pos_obs[]

        if key == Keyboard.escape
            mode_obs[] == :review && return_to_live!()
        elseif key == Keyboard.left
            target = mode_obs[] == :review ? cur - 1 : n_kifu
            if target >= 1
                enter_review!(target)
            else
                (mode_obs[] == :review && return_to_live!())
            end
        elseif key == Keyboard.right
            target = mode_obs[] == :review ? cur + 1 : n_kifu
            target <= n_kifu && enter_review!(target)
        end
    end

    # ---------------------------------------------------------------------------
    # Initial render & game start
    # ---------------------------------------------------------------------------
    _draw_kifu!(kifu_ax, Tuple{Int,Int,String}[], config)
    _refresh_eval_graph!(eval_ax, Float32[], 0, config)
    _refresh_board!(ax, game_obs[], sh, false, nothing, false, config)
    display(fig)
    Timer(1.0) do _
        return start_game!(b_player, w_player)
    end
    return fig
end
