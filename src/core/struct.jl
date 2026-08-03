# Player color constants
const EMPTY = 0
const BLACK = 1
const WHITE = -1

"""Result sentinel: game is still in progress (not yet finished)."""
const IN_PROGRESS = 2

"""
    Position

Represents a position on the Reversi board (row, col).
Supports construction from standard Reversi notation (e.g. "e4").
"""
struct Position
    row::Int
    col::Int
end

"""
    Position(s::AbstractString) -> Position

Parse a standard Reversi notation string (e.g. `"e4"`) into a `Position`.
Column letters `a`–`h` map to columns 1–8; row digits `1`–`8` map to rows 1–8.

# Examples
```julia
Position("e4")  # Position(4, 5)
Position("a1")  # Position(1, 1)
```
"""
function Position(s::AbstractString)
    length(s) == 2 ||
        throw(ArgumentError("Position string must be 2 characters, e.g. \"e4\""))
    col_char = s[1]
    row_char = s[2]
    'a' <= col_char <= 'h' || throw(ArgumentError("Column must be a-h, got '$col_char'"))
    '1' <= row_char <= '8' || throw(ArgumentError("Row must be 1-8, got '$row_char'"))
    col = Int(col_char) - Int('a') + 1
    row = Int(row_char) - Int('1') + 1
    return Position(row, col)
end

"""
    position_to_string(pos::Position) -> String

Convert a `Position` to standard Reversi notation (e.g. `Position(4, 5)` → `"e4"`).
"""
function position_to_string(pos::Position)
    col_char = Char(Int('a') + pos.col - 1)
    return string(col_char) * string(pos.row)
end

function Base.show(io::IO, pos::Position)
    return print(io, "Position($(pos.row), $(pos.col)) [$(position_to_string(pos))]")
end

# ---------------------------------------------------------------------------
# Zobrist hash table (fixed seed for reproducibility, no external deps)
# ---------------------------------------------------------------------------

@inline _color_idx(c::Int) = c == BLACK ? 1 : 2

"""
    ZOBRIST_TABLE

128-entry table of random `UInt64` values indexed by `[row, col, color_idx]`
(color_idx 1 = BLACK, 2 = WHITE) used for incremental Zobrist hashing.
"""
const ZOBRIST_TABLE = let
    table = Array{UInt64}(undef, 8, 8, 2)
    seed = UInt64(0x123456789ABCDEF0)
    for i in eachindex(table)
        seed = seed * UInt64(6364136223846793005) + UInt64(1442695040888963407)
        table[i] = seed
    end
    table
end

# ---------------------------------------------------------------------------
# ReversiGame struct
# ---------------------------------------------------------------------------

"""
    ReversiGame

Represents the state of a Reversi game using two `UInt64` bitboards.

Fields:
- `black::UInt64`  – bitmask of squares occupied by Black
- `white::UInt64`  – bitmask of squares occupied by White
- `current_player::Int` – `BLACK` or `WHITE`
- `pass_count::Int` – consecutive passes (≥ 2 → game over)
- `hash::UInt64`   – incremental Zobrist hash of the current position
"""
mutable struct ReversiGame
    black::UInt64
    white::UInt64
    current_player::Int
    pass_count::Int
    hash::UInt64

    function ReversiGame()
        black = (one(UInt64) << 28) | (one(UInt64) << 35)
        white = (one(UInt64) << 27) | (one(UInt64) << 36)
        h =
            ZOBRIST_TABLE[4, 5, _color_idx(BLACK)] ⊻
            ZOBRIST_TABLE[5, 4, _color_idx(BLACK)] ⊻
            ZOBRIST_TABLE[4, 4, _color_idx(WHITE)] ⊻ ZOBRIST_TABLE[5, 5, _color_idx(WHITE)]
        return new(black, white, BLACK, 0, h)
    end
end

"""
    copy(game::ReversiGame) -> ReversiGame

Fast field-by-field copy of a `ReversiGame`.  Prefer this over `deepcopy` since
all fields are value types (integers).
"""
function Base.copy(game::ReversiGame)
    g = ReversiGame()
    g.black = game.black
    g.white = game.white
    g.current_player = game.current_player
    g.pass_count = game.pass_count
    g.hash = game.hash
    return g
end

# ---------------------------------------------------------------------------
# Hash utilities
# ---------------------------------------------------------------------------

"""
    compute_full_hash(game::ReversiGame) -> UInt64

Compute the Zobrist hash of `game` from scratch.  Useful for debugging.
"""
function compute_full_hash(game::ReversiGame)::UInt64
    h = zero(UInt64)
    b = game.black
    while b != 0
        idx = trailing_zeros(b)
        r = div(idx, 8) + 1
        c = mod(idx, 8) + 1
        h ⊻= ZOBRIST_TABLE[r, c, _color_idx(BLACK)]
        b &= b - one(UInt64)
    end
    w = game.white
    while w != 0
        idx = trailing_zeros(w)
        r = div(idx, 8) + 1
        c = mod(idx, 8) + 1
        h ⊻= ZOBRIST_TABLE[r, c, _color_idx(WHITE)]
        w &= w - one(UInt64)
    end
    return h
end

"""
    update_hash(current_hash, row, col, color) -> UInt64

Toggle one piece of `color` at `(row, col)` in the hash (add or remove).
"""
function update_hash(current_hash::UInt64, row::Int, col::Int, color::Int)::UInt64
    return current_hash ⊻ ZOBRIST_TABLE[row, col, _color_idx(color)]
end
