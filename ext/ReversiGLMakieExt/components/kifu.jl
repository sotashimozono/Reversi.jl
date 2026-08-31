# ---------------------------------------------------------------------------
# Unified kifu drawing
#
# entries : Vector{Tuple{move_n, color, notation}}
# active_n: highlight this move number (0 = none, used in live mode)
# ---------------------------------------------------------------------------

function _draw_kifu!(
    kifu_ax, entries::Vector{Tuple{Int,Int,String}}, config::GUIConfig; active_n::Int=0
)
    empty!(kifu_ax)
    c_text = _get_color(config, "text")
    c_text_dim = _get_color(config, "text_dim")
    c_accent_b = _get_color(config, "accent_black")
    c_active = RGBf(1.0, 0.85, 0.2)
    fs = config.fontsize - 2
    if isempty(entries)
        text!(
            kifu_ax,
            0.5,
            0.5;
            text="No moves yet",
            color=c_text_dim,
            fontsize=fs,
            align=(:center, :center),
            space=:relative,
        )
        ylims!(kifu_ax, 1, 0)
        return nothing
    end
    for (n, color, notation) in entries
        pc_tag = color == BLACK ? "[B]" : "[W]"
        line_color = color == BLACK ? c_accent_b : c_text
        text!(
            kifu_ax,
            0.05,
            Reversi.kifu_row_y(n);
            text=lpad(string(n), 3),
            color=c_text_dim,
            fontsize=fs,
            align=(:left, :top),
        )
        text!(
            kifu_ax,
            0.35,
            Reversi.kifu_row_y(n);
            text="$pc_tag  $notation",
            color=line_color,
            fontsize=fs,
            align=(:left, :top),
        )
    end
    ylims!(kifu_ax, Reversi.kifu_row_limits(length(entries))...)
    return xlims!(kifu_ax, 0, 1)
end

function _refresh_replay_kifu!(kifu_ax, moves, move_colors, current_p, config)
    empty!(kifu_ax)
    c_text = _get_color(config, "text")
    c_text_dim = _get_color(config, "text_dim")
    c_accent_b = _get_color(config, "accent_black")
    c_active = RGBf(1.0, 0.85, 0.2)
    fs = config.fontsize - 2
    n = length(moves)
    if n == 0
        text!(
            kifu_ax,
            0.5,
            0.5;
            text="No moves",
            color=c_text_dim,
            fontsize=fs,
            align=(:center, :center),
            space=:relative,
        )
        ylims!(kifu_ax, 1, 0)
        return nothing
    end
    for i in 1:n
        color = move_colors[i]
        pc_tag = color == BLACK ? "[B]" : "[W]"
        is_current = (i == current_p)
        row_color = is_current ? c_active : (color == BLACK ? c_accent_b : c_text)
        text!(
            kifu_ax,
            0.05,
            Reversi.kifu_row_y(i);
            text=lpad(string(i), 3),
            color=c_text_dim,
            fontsize=fs,
            align=(:left, :top),
        )
        text!(
            kifu_ax,
            0.35,
            Reversi.kifu_row_y(i);
            text="$pc_tag  $(moves[i])",
            color=row_color,
            fontsize=is_current ? fs+1 : fs,
            font=is_current ? :bold : :regular,
            align=(:left, :top),
        )
    end
    ylims!(kifu_ax, Reversi.kifu_row_limits(n)...)
    return xlims!(kifu_ax, 0, 1)
end
