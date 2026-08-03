"""
    display_board(game; hints=Position[])

Display the current board state in the terminal.
Columns are labelled `a`–`h` and rows `1`–`8`.
Optional `hints` highlights valid moves with a green `*`.
"""
function display_board(game::ReversiGame; hints::Vector{Position}=Position[])
    hint_set = Set(hints)
    println("  a b c d e f g h")
    for row in 1:8
        print("$row ")
        for col in 1:8
            bit = one(UInt64) << ((row - 1) * 8 + (col - 1))
            pos = Position(row, col)
            if (game.black & bit) != 0
                print("● ")
            elseif (game.white & bit) != 0
                print("○ ")
            elseif pos in hint_set
                print("\e[32m* \e[0m")
            else
                print("· ")
            end
        end
        println()
    end
    black_count, white_count = count_pieces(game)
    println("Black (●): $black_count  White (○): $white_count")
    return println(
        "Current player: $(game.current_player == BLACK ? "Black (●)" : "White (○)")"
    )
end
