#!/usr/bin/env julia
# custom_player.jl — Custom Player implementations
#
# Shows three patterns for implementing the Player interface:
#   1. HeuristicPlayer   – position-weight table
#   2. MinimaxPlayer     – alpha-beta tree search (uses copy() not deepcopy)
#   3. MobilityPlayer    – maximise own mobility, minimise opponent's
#
# Usage:
#   julia --project=next next/examples/custom_player.jl

using Reversi
using Reversi: BLACK, WHITE, EMPTY, count_pieces, is_game_over, opponent, mobility

println("="^60)
println("Custom Player Examples")
println("="^60)

# ---------------------------------------------------------------------------
# 1. HeuristicPlayer — positional weights
# ---------------------------------------------------------------------------
# Corners >> edges > center > squares adjacent to corners (bad)

struct HeuristicPlayer <: Player
    weights::Matrix{Float64}
    function HeuristicPlayer()
        return new(
            Float64[
                100 -20 10 5 5 10 -20 100;
                -20 -50 -2 -2 -2 -2 -50 -20;
                10 -2 5 3 3 5 -2 10;
                5 -2 3 1 1 3 -2 5;
                5 -2 3 1 1 3 -2 5;
                10 -2 5 3 3 5 -2 10;
                -20 -50 -2 -2 -2 -2 -50 -20;
                100 -20 10 5 5 10 -20 100
            ],
        )
    end
end

function Reversi.get_move(player::HeuristicPlayer, game::ReversiGame)
    moves = valid_moves(game)
    isempty(moves) && return nothing
    return argmax(m -> player.weights[m.row, m.col], moves)
end

# ---------------------------------------------------------------------------
# 2. MinimaxPlayer — alpha-beta pruning
#
# Uses copy(game) (fast field copy, no allocation overhead) instead of
# deepcopy.  Uses pass!(game; force=true) for the null move rather than
# direct field manipulation.
# ---------------------------------------------------------------------------

struct MinimaxPlayer <: Player
    depth::Int
    MinimaxPlayer(depth::Int=3) = new(depth)
end

function _evaluate(game::ReversiGame, color::Int)
    b, w = count_pieces(game)
    return color == BLACK ? b - w : w - b
end

function _minimax(
    game::ReversiGame, depth::Int, α::Float64, β::Float64, maximizing::Bool, color::Int
)::Float64
    depth == 0 || is_game_over(game) && return _evaluate(game, color)

    moves = valid_moves(game)
    if isempty(moves)
        g2 = copy(game)
        pass!(g2; force=true)
        return _minimax(g2, depth - 1, α, β, !maximizing, color)
    end

    if maximizing
        v = -Inf
        for m in moves
            g2 = copy(game)
            make_move!(g2, m)
            v = max(v, _minimax(g2, depth - 1, α, β, false, color))
            α = max(α, v)
            β <= α && break
        end
        return v
    else
        v = Inf
        for m in moves
            g2 = copy(game)
            make_move!(g2, m)
            v = min(v, _minimax(g2, depth - 1, α, β, true, color))
            β = min(β, v)
            β <= α && break
        end
        return v
    end
end

function Reversi.get_move(player::MinimaxPlayer, game::ReversiGame)
    moves = valid_moves(game)
    isempty(moves) && return nothing
    color = game.current_player
    best = moves[1]
    bval = -Inf
    for m in moves
        g2 = copy(game)
        make_move!(g2, m)
        val = _minimax(g2, player.depth - 1, -Inf, Inf, false, color)
        if val > bval
            bval = val
            best = m
        end
    end
    return best
end

# ---------------------------------------------------------------------------
# 3. MobilityPlayer — maximise (own mobility) − (opponent mobility)
# ---------------------------------------------------------------------------

struct MobilityPlayer <: Player end

function Reversi.get_move(::MobilityPlayer, game::ReversiGame)
    moves = valid_moves(game)
    isempty(moves) && return nothing
    opp = opponent(game.current_player)
    return argmax(moves) do m
        g2 = copy(game)
        make_move!(g2, m)
        return mobility(g2, game.current_player) - mobility(g2, opp)
    end
end

# ---------------------------------------------------------------------------
# Run matches
# ---------------------------------------------------------------------------

function run_match(name1, p1, name2, p2; n=10)
    wins = Dict(BLACK => 0, WHITE => 0, EMPTY => 0)
    for _ in 1:n
        w = play_game(p1, p2; verbose=false)
        wins[w] += 1
    end
    println("  $name1 (B) vs $name2 (W) over $n games:")
    return println("    B wins=$(wins[BLACK])  W wins=$(wins[WHITE])  draws=$(wins[EMPTY])")
end

println()
run_match("Heuristic", HeuristicPlayer(), "Random", RandomPlayer())
run_match("Minimax(2)", MinimaxPlayer(2), "Random", RandomPlayer())
run_match("Mobility", MobilityPlayer(), "Random", RandomPlayer())
run_match("Minimax(2)", MinimaxPlayer(2), "Heuristic", HeuristicPlayer())

println()
println("="^60)
println("Tips for integrating your own model:")
println("""
  struct MyMLPlayer <: Player
      model  # your ITensors / Flux / … model
  end

  function Reversi.get_move(player::MyMLPlayer, game::ReversiGame)
      moves = valid_moves(game)
      isempty(moves) && return nothing
      # Convert board to model input:
      #   mat = [get_piece(game, r, c) for r in 1:8, c in 1:8]
      # Score each move:
      #   scores = [score(player.model, game, m) for m in moves]
      # Pick best:
      return moves[argmax(scores)]
  end
""")
println("="^60)
