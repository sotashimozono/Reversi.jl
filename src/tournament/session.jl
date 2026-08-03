"""
    start_tournament!(session::TournamentSession)

Launch the tournament as a background `Task`. Iterates over every ordered
player pair and runs `num_games` games per pair.
"""
function start_tournament!(session::TournamentSession)
    lock(session.lock) do
        session.is_running && error("Tournament is already running")
        for r in session.pair_results
            r.black_wins = 0
            r.white_wins = 0
            r.draws = 0
            r.completed = 0
        end
        return session.is_running = true
    end

    session.task = @async begin
        try
            for result in session.pair_results
                session.is_running || break
                black = session.players[result.black_idx]
                white = session.players[result.white_idx]
                for _ in 1:session.num_games
                    session.is_running || break
                    winner = play_game(black, white; verbose=false)
                    lock(session.lock) do
                        if winner == BLACK
                            result.black_wins += 1
                        elseif winner == WHITE
                            result.white_wins += 1
                        else
                            result.draws += 1
                        end
                        result.completed += 1
                    end
                end
            end
        catch e
            @error "Tournament error" exception = (e, catch_backtrace())
        finally
            lock(session.lock) do
                session.is_running = false
            end
        end
    end

    return nothing
end

"""
    stop_tournament!(session::TournamentSession)

Signal the tournament loop to stop after the current game.
"""
function stop_tournament!(session::TournamentSession)
    lock(session.lock) do
        return session.is_running = false
    end
    return nothing
end

"""
    tournament_status(session::TournamentSession) -> Dict

JSON-friendly status snapshot of the tournament.
"""
function tournament_status(session::TournamentSession)
    lock(session.lock) do
        total_pairs = length(session.pair_results)
        completed_pairs = count(r -> r.completed >= r.total, session.pair_results)
        total_games = total_pairs * session.num_games
        completed_games = sum(r.completed for r in session.pair_results; init=0)

        results = [
            Dict(
                "black" => session.player_names[r.black_idx],
                "white" => session.player_names[r.white_idx],
                "black_wins" => r.black_wins,
                "white_wins" => r.white_wins,
                "draws" => r.draws,
                "completed" => r.completed,
                "total" => r.total,
            ) for r in session.pair_results
        ]

        return Dict{String,Any}(
            "is_running" => session.is_running,
            "players" => copy(session.player_names),
            "num_games" => session.num_games,
            "total_pairs" => total_pairs,
            "completed_pairs" => completed_pairs,
            "total_games" => total_games,
            "completed_games" => completed_games,
            "results" => results,
        )
    end
end
