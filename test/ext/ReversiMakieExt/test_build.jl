using Reversi
using Makie

# Everything below is vacuous if the extension did not load, so that is the first assertion.
REVERSI_MAKIE_EXT = Base.get_extension(Reversi, :ReversiMakieExt)

@testset "the Makie extension loads" begin
    @test REVERSI_MAKIE_EXT !== nothing
end

# Julia resolves free variables when a function runs, not when it is defined, so loading
# the extension alone sees none of this: each bug in #54 needed the builder to be called.
# The limit is event handlers — their bodies do not run while building, so a name that only
# a click would reach still escapes. #54's fourth bug was of that kind; the arithmetic it
# got wrong now lives in src/ui/gui.jl, where test/ui/test_gui.jl covers it instead.
@testset "the game window builds without a display" begin
    fig, start! = REVERSI_MAKIE_EXT._build_game_view()
    @test fig isa Makie.Figure
    @test start! isa Function
end

@testset "the replay window builds without a display" begin
    moves = let g = ReversiGame(), acc = String[]
        for _ in 1:6
            vm = valid_moves(g)
            isempty(vm) && break
            p = first(vm)
            push!(acc, position_to_string(p))
            make_move!(g, p.row, p.col)
        end
        acc
    end
    @test length(moves) >= 4   # a replay of nothing exercises only the empty branch
    @test REVERSI_MAKIE_EXT._build_replay_view(moves) isa Makie.Figure
end

# The builder starts with an empty move list, so it returns from the `isempty` branch
# and never reaches the row loop — that path needs a panel drawn with rows in it.
@testset "the kifu panel draws every row it is given" begin
    config = Reversi.load_config()
    entries = [(1, BLACK, "d3"), (2, WHITE, "c3"), (3, BLACK, "e3")]

    f = Makie.Figure()
    ax = Makie.Axis(f[1, 1])
    REVERSI_MAKIE_EXT._draw_kifu!(ax, entries, config)
    @test length(ax.scene.plots) >= 2 * length(entries)   # a number and a move per row

    f2 = Makie.Figure()
    ax2 = Makie.Axis(f2[1, 1])
    REVERSI_MAKIE_EXT._refresh_replay_kifu!(ax2, ["d3", "c3"], [BLACK, WHITE], 1, config)
    @test length(ax2.scene.plots) >= 4

    f3 = Makie.Figure()
    ax3 = Makie.Axis(f3[1, 1])
    REVERSI_MAKIE_EXT._draw_kifu!(ax3, Tuple{Int,Int,String}[], config)
    @test !isempty(ax3.scene.plots)                       # the "No moves yet" placeholder
end
