using Reversi
using Reversi: EMPTY, BLACK, WHITE, opponent, is_valid_position
using Reversi: compute_full_hash, get_piece, count_pieces
using Test

@testset "opponent" begin
    @test opponent(BLACK) == WHITE
    @test opponent(WHITE) == BLACK
end

@testset "is_valid_position" begin
    @test is_valid_position(1, 1)
    @test is_valid_position(8, 8)
    @test !is_valid_position(0, 1)
    @test !is_valid_position(1, 9)
    @test !is_valid_position(9, 1)
end

@testset "valid_moves – opening" begin
    game = ReversiGame()
    bm = valid_moves(game, BLACK)
    @test length(bm) == 4
    @test Position(3, 4) in bm
    @test Position(4, 3) in bm
    @test Position(5, 6) in bm
    @test Position(6, 5) in bm

    wm = valid_moves(game, WHITE)
    @test length(wm) == 4
    @test Position(3, 5) in wm
    @test Position(4, 6) in wm
    @test Position(5, 3) in wm
    @test Position(6, 4) in wm
end

@testset "mobility" begin
    game = ReversiGame()
    @test mobility(game, BLACK) == 4
    @test mobility(game, WHITE) == 4
end

@testset "make_move! – basic" begin
    game = ReversiGame()
    @test make_move!(game, 3, 4) == true
    @test get_piece(game, 3, 4) == BLACK
    @test get_piece(game, 4, 4) == BLACK   # flipped
    @test game.current_player == WHITE
    @test game.hash == compute_full_hash(game)
    @test game.pass_count == 0
end

@testset "make_move! – illegal moves return false" begin
    game = ReversiGame()
    @test make_move!(game, 3, 4) == true
    @test make_move!(game, 3, 4) == false   # occupied
    @test game.current_player == WHITE      # turn unchanged
    @test make_move!(ReversiGame(), 1, 1) == false  # no flips
end

@testset "make_move! – overloads" begin
    g1 = ReversiGame()
    @test make_move!(g1, "d3") == true
    g2 = ReversiGame()
    @test make_move!(g2, Position(3, 4)) == true
    @test g1.black == g2.black
end

@testset "flip verification" begin
    game = ReversiGame()
    make_move!(game, 3, 4)
    @test get_piece(game, 4, 4) == BLACK
    bc, wc = count_pieces(game)
    @test bc == 4
    @test wc == 1

    make_move!(game, 3, 3)
    @test get_piece(game, 3, 3) == WHITE
    @test get_piece(game, 4, 4) == WHITE   # flipped back
end

@testset "pass! – rejects when moves exist" begin
    game = ReversiGame()
    @test !isempty(valid_moves(game))
    @test_throws ArgumentError pass!(game)
end

@testset "pass! – force override" begin
    game = ReversiGame()
    prev = game.current_player
    pass!(game; force=true)
    @test game.pass_count == 1
    @test game.current_player == opponent(prev)
end

@testset "pass! – legal (no valid moves)" begin
    # Manufacture a position where current player has no moves
    game = ReversiGame()
    # Fill board so BLACK has no moves but game is not over
    game.black = zero(UInt64)
    game.white = typemax(UInt64)
    game.current_player = BLACK
    @test isempty(valid_moves(game, BLACK))
    pass!(game)   # should not throw
    @test game.pass_count == 1
end

@testset "is_game_over" begin
    game = ReversiGame()
    @test !is_game_over(game)

    pass!(game; force=true)
    @test !is_game_over(game)
    pass!(game; force=true)
    @test is_game_over(game)
end

@testset "is_game_over – full board" begin
    game = ReversiGame()
    game.black = typemax(UInt64)
    game.white = zero(UInt64)
    @test is_game_over(game)
    @test get_winner(game) == BLACK
end

@testset "get_winner" begin
    game = ReversiGame()
    game.black = (one(UInt64) << 0) | (one(UInt64) << 1)
    game.white = one(UInt64) << 2
    game.hash = compute_full_hash(game)
    @test get_winner(game) == BLACK

    game.black = one(UInt64) << 0
    game.white = (one(UInt64) << 1) | (one(UInt64) << 2)
    game.hash = compute_full_hash(game)
    @test get_winner(game) == WHITE

    game.black = one(UInt64) << 0
    game.white = one(UInt64) << 1
    game.hash = compute_full_hash(game)
    @test get_winner(game) == EMPTY
end

@testset "next_state – copy-on-move" begin
    game = ReversiGame()
    new_game = next_state(game, Position(3, 4))
    @test get_piece(game, 3, 4) == EMPTY   # original unchanged
    @test game.current_player == BLACK
    @test get_piece(new_game, 3, 4) == BLACK
    @test new_game.current_player == WHITE
    @test new_game.hash == compute_full_hash(new_game)
end

@testset "Zobrist consistency – random games" begin
    for _ in 1:5
        g = ReversiGame()
        while !is_game_over(g)
            ms = valid_moves(g)
            isempty(ms) ? pass!(g) : make_move!(g, rand(ms))
            @test g.hash == compute_full_hash(g)
        end
    end
end
