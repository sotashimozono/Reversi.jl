const _BOARD_SIZE = 8

_board_to_xy(row, col) = (col - 0.5, _BOARD_SIZE - row + 0.5)

function _get_color(config::GUIConfig, key::String)
    hex = get(config.colors, key, "#000000")
    c = Reversi.parse_color(hex)
    return length(c) == 3 ? RGBf(c...) : RGBAf(c...)
end

_player_name(::HumanPlayer) = "Human"
_player_name(::RandomPlayer) = "Random AI"
_player_name(::GreedyPlayer) = "Greedy AI"
_player_name(p::Player) = string(typeof(p))
