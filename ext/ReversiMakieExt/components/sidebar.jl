# ---------------------------------------------------------------------------
# Score bar
#
# A thin horizontal axis divided into black/white proportions.
# ---------------------------------------------------------------------------

function _refresh_score_bar!(score_ax, b_count::Int, w_count::Int, config::GUIConfig)
    empty!(score_ax)
    total = b_count + w_count
    total == 0 && return nothing

    frac_b = Float32(b_count / total)
    c_b = _get_color(config, "black_piece")
    c_w = _get_color(config, "white_piece")
    c_txt_b = _get_color(config, "text")      # text on black portion
    c_txt_w = _get_color(config, "background") # text on white portion

    # Black portion
    poly!(
        score_ax,
        Point2f[(0, 0), (frac_b, 0), (frac_b, 1), (0, 1)];
        color=c_b,
        strokewidth=0,
    )
    # White portion
    poly!(
        score_ax,
        Point2f[(frac_b, 0), (1, 0), (1, 1), (frac_b, 1)];
        color=c_w,
        strokewidth=0,
    )

    # Score numbers — only show when the slice is wide enough
    frac_b > 0.15 && text!(
        score_ax,
        frac_b / 2,
        0.5;
        text=string(b_count),
        color=c_txt_b,
        align=(:center, :center),
        fontsize=10,
        font=:bold,
    )
    (1 - frac_b) > 0.15 && text!(
        score_ax,
        frac_b + (1 - frac_b) / 2,
        0.5;
        text=string(w_count),
        color=c_txt_w,
        align=(:center, :center),
        fontsize=10,
        font=:bold,
    )

    xlims!(score_ax, 0, 1)
    return ylims!(score_ax, 0, 1)
end

# ---------------------------------------------------------------------------
# Evaluation graph
#
# score_history : Vector{Float32} — element i = piece_diff after move (i-1)
#   index 1 = initial position (always 0), index k = after move k-1
# active_n      : highlighted move in review mode (0 = none)
# ---------------------------------------------------------------------------

function _refresh_eval_graph!(
    eval_ax, score_history::Vector{Float32}, active_n::Int, config::GUIConfig
)
    empty!(eval_ax)
    n = length(score_history)
    n <= 1 && return nothing

    c_b = _get_color(config, "accent_black")
    c_w = _get_color(config, "accent_white")
    c_dim = _get_color(config, "text_dim")

    xs = collect(Float32, 0:(n - 1))
    ys = score_history

    # Zero baseline
    hlines!(eval_ax, [0.0f0]; color=c_dim, linewidth=0.8, linestyle=:dash)

    # Shaded area: black advantage above, white below
    zeros_v = zeros(Float32, n)
    band!(eval_ax, xs, zeros_v, clamp.(ys, 0.0f0, Inf32); color=(c_b, 0.20))
    band!(eval_ax, xs, clamp.(ys, -Inf32, 0.0f0), zeros_v; color=(c_w, 0.20))

    # Score curve
    lines!(eval_ax, xs, ys; color=c_b, linewidth=2)

    # Review position marker (yellow dot)
    if 0 < active_n < n
        scatter!(
            eval_ax,
            [Float32(active_n)],
            [ys[active_n + 1]];
            color=RGBf(1.0, 0.85, 0.2),
            markersize=10,
            strokewidth=0,
        )
    end

    ylims!(eval_ax, -65, 65)
    return xlims!(eval_ax, 0, max(1.0f0, Float32(n - 1)))
end
