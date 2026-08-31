function _draw_board!(ax, config::GUIConfig)
    c_board = _get_color(config, "board")
    c_grid = _get_color(config, "grid")
    c_text = _get_color(config, "text")
    poly!(ax, Point2f[(0, 0), (8, 0), (8, 8), (0, 8)]; color=c_board, strokewidth=0)
    for i in 0:_BOARD_SIZE
        lines!(ax, [i, i], [0, 8]; color=c_grid, linewidth=1.0)
        lines!(ax, [0, 8], [i, i]; color=c_grid, linewidth=1.0)
    end
    for (r, c) in [(3, 3), (3, 6), (6, 3), (6, 6)]
        x, y = _board_to_xy(r, c)
        scatter!(ax, [x], [y]; color=c_grid, markersize=8)
    end
    for (i, ch) in enumerate('a':'h')
        text!(
            ax,
            i-0.5,
            8.18;
            text=string(ch),
            color=c_text,
            fontsize=(config.fontsize+1),
            align=(:center, :bottom),
        )
    end
    for r in 1:8
        text!(
            ax,
            -0.18,
            8-r+0.5;
            text=string(r),
            color=c_text,
            fontsize=(config.fontsize+1),
            align=(:right, :center),
        )
    end
end

function _draw_pieces!(
    ax,
    game::ReversiGame,
    px_per_unit::Real,
    config::GUIConfig,
    last_move::Union{Position,Nothing}=nothing,
)
    c_black = _get_color(config, "black_piece")
    c_white = _get_color(config, "white_piece")
    c_last = _get_color(config, "last_move")
    c_stroke = _get_color(config, "text_dim")
    black_pts = Point2f[]
    white_pts = Point2f[]
    for row in 1:8, col in 1:8
        piece = Reversi.get_piece(game, row, col)
        x, y = _board_to_xy(row, col)
        piece == BLACK && push!(black_pts, Point2f(x, y))
        piece == WHITE && push!(white_pts, Point2f(x, y))
    end
    ms = 0.44 * 2 * px_per_unit
    isempty(black_pts) || scatter!(
        ax,
        black_pts;
        color=c_black,
        markersize=ms,
        strokecolor=c_stroke,
        strokewidth=2.0,
    )
    isempty(white_pts) || scatter!(
        ax,
        white_pts;
        color=c_white,
        markersize=ms,
        strokecolor=c_stroke,
        strokewidth=2.0,
    )
    if last_move !== nothing
        c0 = last_move.col - 1
        r0 = _BOARD_SIZE - last_move.row
        lines!(
            ax,
            [c0, c0+1, c0+1, c0, c0],
            [r0, r0, r0+1, r0+1, r0];
            color=c_last,
            linewidth=3.5,
        )
    end
end

function _draw_hints!(ax, game::ReversiGame, px_per_unit::Real, config::GUIConfig)
    moves = valid_moves(game)
    isempty(moves) && return nothing
    pts = [Point2f(_board_to_xy(m.row, m.col)...) for m in moves]
    return scatter!(
        ax,
        pts;
        color=_get_color(config, "hint"),
        markersize=0.18*2*px_per_unit,
        strokewidth=0,
    )
end

_px_per_unit(ax) = max(1.0, ax.scene.viewport[].widths[1] / 8.0)

function _refresh_board!(ax, game, show_hints, show_last, last_move, game_over, config)
    ppu = _px_per_unit(ax)
    empty!(ax)
    _draw_board!(ax, config)
    _draw_pieces!(ax, game, ppu, config, show_last ? last_move : nothing)
    return show_hints && !game_over && _draw_hints!(ax, game, ppu, config)
end
