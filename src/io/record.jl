"""
    GameRecord

Stores the complete move history of a Reversi game.

Fields:
- `moves::Vector{String}` – ordered list of moves in standard notation or `"pass"`.
- `result::Int`           – `BLACK`, `WHITE`, `EMPTY` (draw), or `IN_PROGRESS`.
"""
struct GameRecord
    moves::Vector{String}
    result::Int
end

GameRecord(moves::Vector{String}) = GameRecord(moves, IN_PROGRESS)

# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

"""
    save_game(record, filepath)

Write a `GameRecord` to `filepath`.

Format:
```
MOVES: d3 c5 f4 ...
RESULT: BLACK | WHITE | DRAW | IN_PROGRESS
```
"""
function save_game(record::GameRecord, filepath::String)
    open(filepath, "w") do io
        println(io, "MOVES: " * join(record.moves, " "))
        result_str = if record.result == BLACK
            "BLACK"
        elseif record.result == WHITE
            "WHITE"
        elseif record.result == EMPTY
            "DRAW"
        elseif record.result == IN_PROGRESS
            "IN_PROGRESS"
        else
            "UNKNOWN"
        end
        return println(io, "RESULT: $result_str")
    end
end

"""
    load_game(filepath) -> GameRecord

Read a `GameRecord` from a file written by `save_game`.

Throws `ArgumentError` if the file is missing required fields or has an
unrecognised format, so callers get an explicit error rather than silently
receiving an empty record.
"""
function load_game(filepath::String)::GameRecord
    isfile(filepath) || throw(ArgumentError("File not found: $filepath"))

    moves_found = false
    result_found = false
    moves = String[]
    result = IN_PROGRESS

    # Use open...do so the file handle is closed before any exception propagates
    # (important on Windows where an open handle blocks rm()).
    open(filepath) do io
        for line in eachline(io)
            if startswith(line, "MOVES:")
                moves_found = true
                raw = strip(line[(length("MOVES:") + 1):end])
                moves = isempty(raw) ? String[] : String.(split(raw))
            elseif startswith(line, "RESULT:")
                result_found = true
                val = strip(line[(length("RESULT:") + 1):end])
                result = if val == "BLACK"
                    BLACK
                elseif val == "WHITE"
                    WHITE
                elseif val == "DRAW"
                    EMPTY
                elseif val == "IN_PROGRESS"
                    IN_PROGRESS
                else
                    throw(ArgumentError("Unrecognised RESULT value: \"$val\" in $filepath"))
                end
            end
        end
    end  # file handle closed here — safe to rm() on Windows

    moves_found || throw(ArgumentError("Missing MOVES line in $filepath"))
    result_found || throw(ArgumentError("Missing RESULT line in $filepath"))

    return GameRecord(moves, result)
end

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

"""
    validate_record(record) -> Union{Nothing, String}

Replay `record` on a fresh board and verify every move is legal.
Returns `nothing` if the record is valid, or a `String` describing the first
error found (move number, token, and reason).
"""
function validate_record(record::GameRecord)::Union{Nothing,String}
    game = ReversiGame()
    for (i, move_str) in enumerate(record.moves)
        if move_str == "pass"
            if !isempty(valid_moves(game))
                return "Move $i: \"pass\" but current player has legal moves"
            end
            pass!(game; force=true)
        else
            ok = make_move!(game, move_str)
            if !ok
                return "Move $i: \"$move_str\" is not a legal move"
            end
        end
    end
    return nothing
end

# ---------------------------------------------------------------------------
# Replay
# ---------------------------------------------------------------------------

"""
    replay_game(record; verbose=false, strict=false) -> ReversiGame

Replay all moves stored in `record` on a fresh `ReversiGame` and return the
final state.

- `verbose=true`  – print each move to stdout.
- `strict=true`   – throw `ArgumentError` on the first invalid move instead of
                    silently ignoring it.  Recommended when replaying external data.
"""
function replay_game(
    record::GameRecord; verbose::Bool=false, strict::Bool=false
)::ReversiGame
    game = ReversiGame()
    for (i, move_str) in enumerate(record.moves)
        verbose && println("Move $i: $move_str")

        if move_str == "pass"
            if strict && !isempty(valid_moves(game))
                throw(
                    ArgumentError(
                        "Move $i: \"pass\" is invalid — current player has legal moves"
                    ),
                )
            end
            pass!(game; force=true)
        else
            ok = make_move!(game, move_str)
            if !ok && strict
                throw(ArgumentError("Move $i: \"$move_str\" is not a legal move"))
            end
        end
    end
    return game
end
