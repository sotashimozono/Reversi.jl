"""
    Classical (non-ML) AI players for Reversi.

All players implement the `Player` interface defined in `player.jl`.
They rely only on primitives from `struct.jl` and `rules.jl`
(`copy`, `make_move!`, `pass!`, `valid_moves`, `is_game_over`,
`get_winner`, `count_pieces`, `mobility`, `opponent`).
"""

# ---------------------------------------------------------------------------
# HeuristicPlayer — static positional weights
# ---------------------------------------------------------------------------

const POSITIONAL_WEIGHTS = Float64[
    100 -20 10 5 5 10 -20 100;
    -20 -50 -2 -2 -2 -2 -50 -20;
    10 -2 5 3 3 5 -2 10;
    5 -2 3 1 1 3 -2 5;
    5 -2 3 1 1 3 -2 5;
    10 -2 5 3 3 5 -2 10;
    -20 -50 -2 -2 -2 -2 -50 -20;
    100 -20 10 5 5 10 -20 100
]

"""
    HeuristicPlayer <: Player

A player that picks the move with the highest positional weight.
Corners are strongly preferred; corner-adjacent squares are penalised.
"""
struct HeuristicPlayer <: Player end

function get_move(::HeuristicPlayer, game::ReversiGame)
    moves = valid_moves(game)
    isempty(moves) && return nothing
    return argmax(m -> POSITIONAL_WEIGHTS[m.row, m.col], moves)
end

# ---------------------------------------------------------------------------
# CornerPlayer — corners > positional weights
# ---------------------------------------------------------------------------

const CORNERS = Set(((1, 1), (1, 8), (8, 1), (8, 8)))

"""
    CornerPlayer <: Player

Picks any available corner move first, then falls back to `HeuristicPlayer`'s
positional weights.
"""
struct CornerPlayer <: Player end

function get_move(::CornerPlayer, game::ReversiGame)
    moves = valid_moves(game)
    isempty(moves) && return nothing
    for m in moves
        (m.row, m.col) in CORNERS && return m
    end
    return argmax(m -> POSITIONAL_WEIGHTS[m.row, m.col], moves)
end

# ---------------------------------------------------------------------------
# MobilityPlayer — maximise (own mobility) - (opponent mobility)
# ---------------------------------------------------------------------------

"""
    MobilityPlayer <: Player

Picks the move that leaves the opponent with the fewest legal replies while
keeping its own mobility high.
"""
struct MobilityPlayer <: Player end

function get_move(::MobilityPlayer, game::ReversiGame)
    moves = valid_moves(game)
    isempty(moves) && return nothing
    me = game.current_player
    opp = opponent(me)
    return argmax(moves) do m
        g2 = copy(game)
        make_move!(g2, m.row, m.col)
        return mobility(g2, me) - mobility(g2, opp)
    end
end

# ---------------------------------------------------------------------------
# MinimaxPlayer — alpha-beta search on piece-count difference
# ---------------------------------------------------------------------------

"""
    MinimaxPlayer(depth::Int=3) <: Player

Alpha-beta search using a piece-count difference evaluation.
`depth` controls the search depth in plies.
"""
struct MinimaxPlayer <: Player
    depth::Int
    MinimaxPlayer(depth::Int=3) = new(depth)
end

_piece_diff(game::ReversiGame, color::Int) =
    let (b, w) = count_pieces(game)
        color == BLACK ? b - w : w - b
    end

function _minimax_search(
    game::ReversiGame, depth::Int, α::Float64, β::Float64, maximizing::Bool, color::Int
)::Float64
    if depth == 0 || is_game_over(game)
        return Float64(_piece_diff(game, color))
    end
    moves = valid_moves(game)
    if isempty(moves)
        g2 = copy(game)
        pass!(g2; force=true)
        return _minimax_search(g2, depth - 1, α, β, !maximizing, color)
    end
    if maximizing
        v = -Inf
        for m in moves
            g2 = copy(game)
            make_move!(g2, m.row, m.col)
            v = max(v, _minimax_search(g2, depth - 1, α, β, false, color))
            α = max(α, v)
            β <= α && break
        end
        return v
    else
        v = Inf
        for m in moves
            g2 = copy(game)
            make_move!(g2, m.row, m.col)
            v = min(v, _minimax_search(g2, depth - 1, α, β, true, color))
            β = min(β, v)
            β <= α && break
        end
        return v
    end
end

function get_move(player::MinimaxPlayer, game::ReversiGame)
    moves = valid_moves(game)
    isempty(moves) && return nothing
    color = game.current_player
    best = moves[1]
    bval = -Inf
    for m in moves
        g2 = copy(game)
        make_move!(g2, m.row, m.col)
        val = _minimax_search(g2, player.depth - 1, -Inf, Inf, false, color)
        if val > bval
            bval = val
            best = m
        end
    end
    return best
end

# ---------------------------------------------------------------------------
# MCTSPlayer — Monte Carlo Tree Search with random rollouts
# ---------------------------------------------------------------------------

"""
    MCTSPlayer(iterations::Int=200, c::Float64=1.414) <: Player

Monte Carlo Tree Search with UCB1 selection and random rollouts.
`iterations` controls the number of simulations per move.
"""
struct MCTSPlayer <: Player
    iterations::Int
    c::Float64
    MCTSPlayer(iterations::Int=200, c::Float64=1.414) = new(iterations, c)
end

mutable struct _MCTSNode
    wins::Float64
    visits::Int
    untried::Vector{Position}
    children::Dict{Tuple{Int,Int},_MCTSNode}
    parent::Union{_MCTSNode,Nothing}
    player_to_move::Int
    move_from_parent::Union{Position,Nothing}
end

function _new_mcts_node(game::ReversiGame, parent, move)
    return _MCTSNode(
        0.0,
        0,
        valid_moves(game),
        Dict{Tuple{Int,Int},_MCTSNode}(),
        parent,
        game.current_player,
        move,
    )
end

function _mcts_select(node::_MCTSNode, c::Float64)
    @inbounds best_score = -Inf
    best_child = first(values(node.children))
    logN = log(node.visits)
    for child in values(node.children)
        exploit = child.wins / child.visits
        explore = c * sqrt(logN / child.visits)
        s = exploit + explore
        if s > best_score
            best_score = s
            best_child = child
        end
    end
    return best_child
end

function _mcts_rollout(game::ReversiGame)
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

function _mcts_backprop!(node::_MCTSNode, winner::Int)
    n = node
    while n !== nothing
        n.visits += 1
        # Reward is from the perspective of the player who JUST moved to create n.
        # n.player_to_move is the player about to move *at* n, so the player who
        # made the move leading here is opponent(n.player_to_move).
        mover = opponent(n.player_to_move)
        if winner == mover
            n.wins += 1.0
        elseif winner == EMPTY
            n.wins += 0.5
        end
        n = n.parent
    end
end

function get_move(player::MCTSPlayer, game::ReversiGame)
    moves = valid_moves(game)
    isempty(moves) && return nothing
    length(moves) == 1 && return moves[1]

    root = _new_mcts_node(game, nothing, nothing)

    for _ in 1:player.iterations
        node = root
        g = copy(game)

        # Selection
        while isempty(node.untried) && !isempty(node.children) && !is_game_over(g)
            node = _mcts_select(node, player.c)
            mv = node.move_from_parent
            mv === nothing ? pass!(g; force=true) : make_move!(g, mv.row, mv.col)
        end

        # Expansion
        if !isempty(node.untried) && !is_game_over(g)
            idx = rand(1:length(node.untried))
            mv = node.untried[idx]
            deleteat!(node.untried, idx)
            make_move!(g, mv.row, mv.col)
            child = _new_mcts_node(g, node, mv)
            node.children[(mv.row, mv.col)] = child
            node = child
        end

        # Simulation + Backpropagation
        winner = _mcts_rollout(g)
        _mcts_backprop!(node, winner)
    end

    # Pick most-visited child of root
    best_visits = -1
    best_move = moves[1]
    for (key, child) in root.children
        if child.visits > best_visits
            best_visits = child.visits
            best_move = Position(key[1], key[2])
        end
    end
    return best_move
end
