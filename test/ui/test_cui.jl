using Reversi
using Reversi: BLACK, WHITE, EMPTY, valid_moves, make_move!
using Test

# display_board は副作用（stdout 出力）のみ。
# Julia 1.12 では redirect_stdout が IOBuffer を受け付けないため
# 一時ファイル経由でキャプチャする。

function capture_board(f::Function)
    tmp = tempname()
    open(tmp, "w") do fh
        redirect_stdout(fh) do
            return f()
        end
    end
    out = read(tmp, String)
    rm(tmp)
    return out
end

@testset "display_board – contains expected symbols" begin
    game = ReversiGame()
    output = capture_board(() -> display_board(game))
    @test occursin("●", output)
    @test occursin("○", output)
    @test occursin("Black", output)
    @test occursin("White", output)
    for ch in 'a':'h'
        @test occursin(string(ch), output)
    end
end

@testset "display_board – with hints" begin
    game = ReversiGame()
    hints = valid_moves(game)
    output = capture_board(() -> display_board(game; hints=hints))
    @test occursin("*", output)
end

@testset "display_board – no hints shown when hints=[]" begin
    game = ReversiGame()
    output = capture_board(() -> display_board(game; hints=Position[]))
    @test !occursin("*", output)
end

@testset "display_board – score reflects board state" begin
    game = ReversiGame()
    make_move!(game, "d3")   # BLACK=4, WHITE=1
    output = capture_board(() -> display_board(game))
    @test occursin("4", output)
    @test occursin("1", output)
end
