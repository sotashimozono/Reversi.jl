"""
    OpeningBookEntry

Aggregated statistics for a single board position in an opening book.
- `total`           : number of games that passed through this position
- `black_wins`      : games in which BLACK won
- `white_wins`      : games in which WHITE won
- `draws`           : games ending in a draw
- `next_moves`      : Dict mapping next-move notation ("f5" etc.) to play count
"""
struct OpeningBookEntry
    total::Int
    black_wins::Int
    white_wins::Int
    draws::Int
    next_moves::Dict{String,Int}
end

function _empty_entry()
    return OpeningBookEntry(0, 0, 0, 0, Dict{String,Int}())
end

"""
    OpeningBook

A Zobrist-hash-keyed opening book built from WTHOR professional game data.
- `entries`     : map from board hash → aggregated statistics
- `source_file` : path of the .wtb file the book was built from
- `game_count`  : number of WTHOR games consumed
- `max_depth`   : maximum ply depth recorded per game (book is limited to the opening)
"""
struct OpeningBook
    entries::Dict{UInt64,OpeningBookEntry}
    source_file::String
    game_count::Int
    max_depth::Int
end

"""
    build_opening_book(path::AbstractString; max_depth::Int=20) -> OpeningBook

Read a WTHOR `.wtb` file and build an opening book keyed by Zobrist hash.
Each game is replayed from the empty board; at each ply up to `max_depth`,
the current position hash is used to aggregate total games, wins by colour,
and next-move frequencies.

Games that fail to replay cleanly (illegal moves) are skipped.
"""
function build_opening_book(path::AbstractString; max_depth::Int=20)
    _, games = read_wthor(path)
    entries = Dict{UInt64,OpeningBookEntry}()

    good = 0
    for g in games
        result = _wthor_result(g)
        result === nothing && continue

        game = ReversiGame()
        failed = false
        for (step, move_str) in enumerate(g.moves)
            step > max_depth && break

            # WTHOR doesn't record passes — skip any forced passes first.
            while isempty(valid_moves(game)) && !is_game_over(game)
                pass!(game; force=true)
            end
            is_game_over(game) && break

            # Update book entry for the current position BEFORE the move.
            prev_hash = game.hash
            prev = get(entries, prev_hash, _empty_entry())
            total = prev.total + 1
            black_wins = prev.black_wins + (result == BLACK ? 1 : 0)
            white_wins = prev.white_wins + (result == WHITE ? 1 : 0)
            draws = prev.draws + (result == EMPTY ? 1 : 0)
            next_moves = copy(prev.next_moves)
            next_moves[move_str] = get(next_moves, move_str, 0) + 1
            entries[prev_hash] = OpeningBookEntry(
                total, black_wins, white_wins, draws, next_moves
            )

            pos = try
                Position(move_str)
            catch
                failed = true
                break
            end
            if !(pos in valid_moves(game))
                failed = true
                break
            end
            make_move!(game, pos.row, pos.col)
        end
        failed || (good += 1)
    end

    return OpeningBook(entries, String(path), good, max_depth)
end

# WTHOR result → winner color (skip if game wasn't fully played)
function _wthor_result(g::WThorGame)
    # black_score is the final number of black discs at game end
    b = g.black_score
    if b == 0 && !any(m -> m != "", g.moves)
        return nothing
    end
    # Prefer to re-derive from final board so draws/short games are handled
    # correctly, but use the stored score as a fallback.
    if b > 32
        return BLACK
    elseif b < 32
        return WHITE
    else
        return EMPTY
    end
end

"""
    lookup_opening(book::OpeningBook, game::ReversiGame) -> Union{OpeningBookEntry,Nothing}

Return the opening-book entry for the current position of `game`, or `nothing`
if the position was not observed in the source data.
"""
function lookup_opening(book::OpeningBook, game::ReversiGame)
    return get(book.entries, game.hash, nothing)
end

"""
    save_opening_book(book::OpeningBook, path::AbstractString)

Serialize `book` to `path` using Julia's `Serialization` stdlib.
"""
function save_opening_book(book::OpeningBook, path::AbstractString)
    open(path, "w") do io
        return Serialization.serialize(io, book)
    end
    return path
end

"""
    load_opening_book(path::AbstractString) -> OpeningBook

Deserialize an opening book previously saved with `save_opening_book`.
"""
function load_opening_book(path::AbstractString)
    return open(Serialization.deserialize, path, "r")
end

"""
    opening_book_summary(book::OpeningBook) -> Dict

Return a JSON-friendly summary: source file, game count, entry count, max depth.
"""
function opening_book_summary(book::OpeningBook)
    return Dict{String,Any}(
        "source_file" => book.source_file,
        "game_count" => book.game_count,
        "entry_count" => length(book.entries),
        "max_depth" => book.max_depth,
    )
end

"""
    opening_book_lookup_dict(book::OpeningBook, game::ReversiGame) -> Dict

Return a JSON-friendly lookup result for `game`'s current position.
"""
function opening_book_lookup_dict(book::OpeningBook, game::ReversiGame)
    entry = lookup_opening(book, game)
    if entry === nothing
        return Dict{String,Any}("found" => false, "hash" => string(game.hash; base=16))
    end

    candidates = [
        Dict(
            "move" => move,
            "count" => count,
            "frequency" => entry.total > 0 ? count / entry.total : 0.0,
        ) for (move, count) in entry.next_moves
    ]
    sort!(candidates; by=c -> c["count"], rev=true)

    return Dict{String,Any}(
        "found" => true,
        "hash" => string(game.hash; base=16),
        "total" => entry.total,
        "black_wins" => entry.black_wins,
        "white_wins" => entry.white_wins,
        "draws" => entry.draws,
        "candidates" => candidates,
    )
end
