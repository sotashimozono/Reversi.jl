using Reversi

# game_loop! -----------------------------------------------------------------

@testset "game_loop! completes a full game" begin
    game = ReversiGame()
    players = Dict{Int,Player}(BLACK => RandomPlayer(), WHITE => RandomPlayer())
    result = game_loop!(game, players)
    @test is_game_over(result)
end

@testset "game_loop! on_move callback receives every move" begin
    moves_recorded = Tuple{Int,String}[]   # (color, notation)
    game = ReversiGame()
    players = Dict{Int,Player}(BLACK => RandomPlayer(), WHITE => RandomPlayer())
    game_loop!(
        game,
        players;
        on_move=(g, color, notation) -> push!(moves_recorded, (color, notation)),
    )
    @test length(moves_recorded) >= 4    # any real game has at least a few moves
    @test all(c in (BLACK, WHITE) for (c, _) in moves_recorded)
    @test all(n isa String for (_, n) in moves_recorded)
end

@testset "game_loop! on_done called exactly once" begin
    done_count = Ref(0)
    game = ReversiGame()
    players = Dict{Int,Player}(BLACK => RandomPlayer(), WHITE => RandomPlayer())
    game_loop!(game, players; on_done=_ -> (done_count[] += 1))
    @test done_count[] == 1
end

@testset "game_loop! notations are valid positions or pass" begin
    game = ReversiGame()
    players = Dict{Int,Player}(BLACK => RandomPlayer(), WHITE => RandomPlayer())
    notations = String[]
    game_loop!(game, players; on_move=(g, c, n) -> push!(notations, n))
    for n in notations
        if n != "pass"
            @test occursin(r"^[a-h][1-8]$", n)
        end
    end
end

@testset "game_loop! with GreedyPlayer completes" begin
    game = ReversiGame()
    players = Dict{Int,Player}(BLACK => GreedyPlayer(), WHITE => RandomPlayer())
    result = game_loop!(game, players)
    @test is_game_over(result)
    b, w = count_pieces(result)
    @test b + w > 0
end

@testset "game_loop! does not modify original game copy" begin
    original = ReversiGame()
    game_copy = copy(original)
    players = Dict{Int,Player}(BLACK => RandomPlayer(), WHITE => RandomPlayer())
    game_loop!(game_copy, players)
    @test original.black == ReversiGame().black
    @test original.white == ReversiGame().white
end
