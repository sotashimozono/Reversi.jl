module ReversiMakieExt

using Reversi
using Reversi:
    BLACK,
    WHITE,
    Position,
    ReversiGame,
    Player,
    HumanPlayer,
    RandomPlayer,
    GreedyPlayer,
    GameRecord
using Reversi:
    valid_moves,
    make_move!,
    is_game_over,
    get_winner,
    count_pieces,
    pass!,
    get_move,
    position_to_string
using Makie

include("constants.jl")
include("components/board.jl")
include("components/kifu.jl")
include("components/sidebar.jl")
include("components/dialogs.jl")
include("core_logic/game_task.jl")
include("views/game_view.jl")
include("views/replay_view.jl")

end # module ReversiMakieExt
