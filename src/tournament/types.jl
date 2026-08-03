"""
    TournamentPairResult

Aggregated results for a single ordered pair (black_player_idx, white_player_idx)
in the tournament.
"""
mutable struct TournamentPairResult
    black_idx::Int
    white_idx::Int
    black_wins::Int
    white_wins::Int
    draws::Int
    completed::Int
    total::Int
end

TournamentPairResult(b, w, total) = TournamentPairResult(b, w, 0, 0, 0, 0, total)

"""
    TournamentSession

Round-robin tournament between a list of named players. Each ordered pair (i, j)
(with i != j) plays `num_games` games as (black=i, white=j).
"""
mutable struct TournamentSession
    player_names::Vector{String}
    players::Vector{Player}
    num_games::Int
    pair_results::Vector{TournamentPairResult}
    is_running::Bool
    task::Union{Task,Nothing}
    lock::ReentrantLock

    function TournamentSession(
        player_names::Vector{String}, players::Vector{<:Player}; num_games::Int=5
    )
        n = length(players)
        length(player_names) == n ||
            throw(ArgumentError("player_names and players length mismatch"))
        pair_results = TournamentPairResult[]
        for i in 1:n, j in 1:n
            i == j && continue
            push!(pair_results, TournamentPairResult(i, j, num_games))
        end
        return new(
            copy(player_names),
            Vector{Player}(players),
            num_games,
            pair_results,
            false,
            nothing,
            ReentrantLock(),
        )
    end
end
