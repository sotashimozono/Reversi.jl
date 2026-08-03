"""
    Position analysis — score every legal move at the current game state using
    any `Player` as the evaluator. Different player types use different scoring
    conventions (positional weights, piece-count diff, mobility, win rate from
    rollouts, etc.), but the returned dict has a uniform shape.
"""

# ---------------------------------------------------------------------------
# Per-move scoring — dispatch on player type
# ---------------------------------------------------------------------------

"""
    score_move(player::Player, game::ReversiGame, move::Position) -> Float64

Return a scalar score for `move` in the current `game`, according to `player`'s
evaluation. Higher is better (from the current player's perspective).
"""
function score_move end

function score_move(::HeuristicPlayer, ::ReversiGame, move::Position)
    return POSITIONAL_WEIGHTS[move.row, move.col]
end

function score_move(::CornerPlayer, ::ReversiGame, move::Position)
    bonus = (move.row, move.col) in CORNERS ? 1000.0 : 0.0
    return bonus + POSITIONAL_WEIGHTS[move.row, move.col]
end

function score_move(::MobilityPlayer, game::ReversiGame, move::Position)
    me = game.current_player
    opp = opponent(me)
    g2 = copy(game)
    make_move!(g2, move.row, move.col)
    return Float64(mobility(g2, me) - mobility(g2, opp))
end

function score_move(::GreedyPlayer, game::ReversiGame, move::Position)
    player_bb = game.current_player == BLACK ? game.black : game.white
    opponent_bb = game.current_player == BLACK ? game.white : game.black
    bit = one(UInt64) << ((move.row - 1) * 8 + (move.col - 1))
    return Float64(count_ones(compute_flips(bit, player_bb, opponent_bb)))
end

function score_move(player::MinimaxPlayer, game::ReversiGame, move::Position)
    color = game.current_player
    g2 = copy(game)
    make_move!(g2, move.row, move.col)
    # After our move, opponent is to move; minimise from our perspective.
    return _minimax_search(g2, player.depth - 1, -Inf, Inf, false, color)
end

function score_move(player::MCTSPlayer, game::ReversiGame, move::Position)
    # Cheap per-move rollout average. For proper analysis, consumers should
    # call `evaluate_position` which shares a single tree search.
    me = game.current_player
    wins = 0.0
    for _ in 1:player.iterations
        g2 = copy(game)
        make_move!(g2, move.row, move.col)
        winner = _rollout_random(g2)
        if winner == me
            wins += 1.0
        elseif winner == EMPTY
            wins += 0.5
        end
    end
    return wins / player.iterations
end

# Shared random rollout utility (used by MCTSPlayer score_move)
function _rollout_random(game::ReversiGame)
    g = copy(game)
    while !is_game_over(g)
        moves = valid_moves(g)
        if isempty(moves)
            pass!(g; force=true)
        else
            m = rand(moves)
            make_move!(g, m.row, m.col)
        end
    end
    return get_winner(g)
end

# Fallback for any player without a specialised scorer — run a 1-ply lookahead
# and score by piece-count diff.
function score_move(::Player, game::ReversiGame, move::Position)
    me = game.current_player
    g2 = copy(game)
    make_move!(g2, move.row, move.col)
    b, w = count_pieces(g2)
    return Float64(me == BLACK ? b - w : w - b)
end

# ---------------------------------------------------------------------------
# Position-level evaluation
# ---------------------------------------------------------------------------

"""
    evaluate_position(player::Player, game::ReversiGame) -> Dict

Score every legal move at `game`'s current state using `player`.
Returns a JSON-friendly dict with:
- `"scores"`   — vector of `(row, col, score)` named tuples
- `"best"`     — best move position as `(row, col)` or `nothing`
- `"player"`   — current player (BLACK or WHITE)
- `"heatmap"`  — 8×8 matrix of scores for legal moves (zeros elsewhere)
"""
function evaluate_position(player::Player, game::ReversiGame)
    moves = valid_moves(game)
    heatmap = zeros(Float32, 8, 8)
    scores = Tuple{Int,Int,Float64}[]
    best_move = nothing
    best_score = -Inf

    for m in moves
        s = score_move(player, game, m)
        heatmap[m.row, m.col] = Float32(s)
        push!(scores, (m.row, m.col, s))
        if s > best_score
            best_score = s
            best_move = m
        end
    end

    return Dict{String,Any}(
        "scores" => [Dict("row" => r, "col" => c, "score" => s) for (r, c, s) in scores],
        "best" => if best_move === nothing
            nothing
        else
            Dict("row" => best_move.row, "col" => best_move.col, "score" => best_score)
        end,
        "player" => game.current_player,
        "heatmap" => [heatmap[r, :] for r in 1:8],
    )
end

# ---------------------------------------------------------------------------
# Principal variation — trace the best line N plies ahead
# ---------------------------------------------------------------------------

"""
    principal_variation(player::Player, game::ReversiGame, depth::Int) -> Dict

Trace the "principal variation" — the sequence of moves that would be played
if both sides followed `player`'s evaluation for `depth` plies.

Returns a dict with:
- `"moves"` — Vector of `(row, col, notation, player)` tuples, one per ply
- `"boards"` — Vector of 8×8 board snapshots after each ply (absolute encoding)
- `"final_score"` — `(black, white)` piece counts after the last traced move
"""
function principal_variation(player::Player, game::ReversiGame, depth::Int)
    g = copy(game)
    moves_trace = []
    boards = []

    for step in 1:depth
        if is_game_over(g)
            break
        end
        moves = valid_moves(g)
        color = g.current_player
        if isempty(moves)
            pass!(g; force=true)
            push!(
                moves_trace,
                Dict(
                    "row" => 0,
                    "col" => 0,
                    "notation" => "pass",
                    "player" => color,
                    "step" => step,
                ),
            )
        else
            mv = get_move(player, g)
            if mv === nothing
                pass!(g; force=true)
                push!(
                    moves_trace,
                    Dict(
                        "row" => 0,
                        "col" => 0,
                        "notation" => "pass",
                        "player" => color,
                        "step" => step,
                    ),
                )
            else
                make_move!(g, mv.row, mv.col)
                push!(
                    moves_trace,
                    Dict(
                        "row" => mv.row,
                        "col" => mv.col,
                        "notation" => position_to_string(mv),
                        "player" => color,
                        "step" => step,
                    ),
                )
            end
        end
        # Absolute board encoding (BLACK=1, WHITE=-1, EMPTY=0)
        push!(boards, board_to_matrix(g; flip_for_current=false))
    end

    b, w = count_pieces(g)
    return Dict{String,Any}(
        "moves" => moves_trace,
        "boards" => boards,
        "final_score" => Dict("black" => b, "white" => w),
        "depth" => length(moves_trace),
    )
end

# ---------------------------------------------------------------------------
# Name → player factory (used by web API)
# ---------------------------------------------------------------------------

"""
    make_evaluator(name::AbstractString) -> Player

Construct an evaluator player from a short name:
- `"heuristic"`  → `HeuristicPlayer()`
- `"corner"`     → `CornerPlayer()`
- `"mobility"`   → `MobilityPlayer()`
- `"greedy"`     → `GreedyPlayer()`
- `"minimax-N"`  → `MinimaxPlayer(N)` (N = 1..6)
- `"mcts-N"`     → `MCTSPlayer(N)` (N = 20..500)
"""
function make_evaluator(name::AbstractString)
    name = lowercase(strip(name))
    name == "heuristic" && return HeuristicPlayer()
    name == "corner" && return CornerPlayer()
    name == "mobility" && return MobilityPlayer()
    name == "greedy" && return GreedyPlayer()
    name == "random" && return RandomPlayer()

    if startswith(name, "minimax-")
        depth = tryparse(Int, name[(length("minimax-") + 1):end])
        depth === nothing && throw(ArgumentError("Invalid minimax spec: $name"))
        return MinimaxPlayer(clamp(depth, 1, 6))
    end
    if startswith(name, "mcts-")
        iter = tryparse(Int, name[(length("mcts-") + 1):end])
        iter === nothing && throw(ArgumentError("Invalid mcts spec: $name"))
        return MCTSPlayer(clamp(iter, 10, 5000))
    end
    return throw(ArgumentError("Unknown evaluator: $name"))
end
