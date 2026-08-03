module ReversiWebExt

using Reversi
using Oxygen
using HTTP
using JSON3
using DefaultApplication
using TOML

# Import necessary types/functions from Reversi (or use qualified names)
import Reversi:
    launch_gui,
    Position,
    ReversiGame,
    count_pieces,
    valid_moves,
    is_game_over,
    get_winner,
    board_to_matrix,
    make_move!,
    pass!,
    position_to_string,
    RandomPlayer,
    GreedyPlayer,
    get_move,
    EMPTY,
    # Training
    TrainingSession,
    RandomTrainer,
    start_training!,
    stop_training!,
    training_status,
    training_history,
    training_policy,
    hyperparameters,
    save_trainer,
    load_trainer,
    # Analysis
    evaluate_position,
    principal_variation,
    make_evaluator,
    # Tournament
    TournamentSession,
    start_tournament!,
    stop_tournament!,
    tournament_status,
    # Opening book
    OpeningBook,
    build_opening_book,
    opening_book_summary,
    opening_book_lookup_dict

"""
    launch_gui(:web; port=8080, open_browser=true)

Implementation of the web UI launcher under the unified launch_gui API.
"""
function Reversi.launch_gui(::Val{:web}; port::Int=8080, open_browser::Bool=true)
    # 1. State initialization (using Ref to allow resetting from closures)
    game_ref = Ref(ReversiGame())
    history = String[]

    # Opening book state
    opening_book_ref = Ref{Union{OpeningBook,Nothing}}(nothing)

    # Path to frontend public build
    # Assuming the app is installed, we find the project root
    pkg_root = joinpath(@__DIR__, "..", "..")
    frontend_dir = joinpath(pkg_root, "web", "frontend", "dist")
    config_path = joinpath(pkg_root, "config", "default_config.toml")

    # Auto-load opening book if configured
    if isfile(config_path)
        try
            cfg = TOML.parsefile(config_path)
            wp = get(get(cfg, "web", Dict()), "opening", Dict())
            path_val = get(wp, "wthor_path", "")
            max_depth = Int(get(wp, "max_depth", 20))
            if !isempty(path_val) && isfile(path_val)
                @info "Building opening book from $path_val..."
                @async try
                    opening_book_ref[] = build_opening_book(path_val; max_depth=max_depth)
                    @info "Opening book loaded: $(length(opening_book_ref[].entries)) positions from $(opening_book_ref[].game_count) games"
                catch e
                    @warn "Failed to auto-build opening book: $e"
                end
            end
        catch e
            @warn "Could not read opening config: $e"
        end
    end

    # 2. API Endpoints
    @get "/api/config" function (req::HTTP.Request)
        if isfile(config_path)
            return TOML.parsefile(config_path)
        else
            return Dict()
        end
    end

    @get "/api/game/state" function (req::HTTP.Request)
        params = queryparams(req)
        index_str = get(params, "index", nothing)

        target_game = game_ref[]
        is_replay = false

        if index_str !== nothing
            idx = tryparse(Int, index_str)
            if idx !== nothing && 0 <= idx <= length(history)
                # Reconstruct game state for replay
                target_game = ReversiGame()
                for i in 1:idx
                    move_str = history[i]
                    if move_str == "pass"
                        pass!(target_game; force=true)
                    else
                        pos = Position(move_str)
                        make_move!(target_game, pos.row, pos.col)
                    end
                end
                is_replay = true
            end
        end

        b_count, w_count = count_pieces(target_game)
        v_moves = is_replay ? Position[] : valid_moves(target_game)

        game_status = is_game_over(target_game) ? "finished" : "playing"
        winner = game_status == "finished" ? get_winner(target_game) : EMPTY

        return Dict(
            "board" => board_to_matrix(target_game, flip_for_current=false),
            "current_player" => target_game.current_player,
            "black_score" => b_count,
            "white_score" => w_count,
            "status" => game_status,
            "winner" => winner,
            "valid_moves" => [[m.row, m.col] for m in v_moves],
            "history" => history,
            "viewing_index" =>
                index_str === nothing ? length(history) : parse(Int, index_str),
        )
    end

    @post "/api/game/move" function (req::HTTP.Request)
        game = game_ref[]
        body = JSON3.read(req.body)
        row = Int(body.row)
        col = Int(body.col)

        if make_move!(game, row, col)
            push!(history, position_to_string(Position(row, col)))

            # Auto-pass logic
            _handle_auto_passes!(game, history)

            return Dict("status" => "success")
        else
            return HTTP.Response(400, "Invalid move")
        end
    end

    @get "/api/game/ai_move" function (req::HTTP.Request)
        params = queryparams(req)
        ai_type = get(params, "type", "greedy")

        game = game_ref[]
        player = ai_type == "random" ? RandomPlayer() : GreedyPlayer()

        move = get_move(player, game)

        if move === nothing
            if !is_game_over(game)
                pass!(game; force=false)
                push!(history, "pass")
            end
        else
            make_move!(game, move.row, move.col)
            push!(history, position_to_string(move))
        end

        _handle_auto_passes!(game, history)

        return Dict("status" => "success")
    end

    @post "/api/game/reset" function (req::HTTP.Request)
        game_ref[] = ReversiGame()
        empty!(history)
        return Dict("status" => "success")
    end

    # --- Training API ---
    session_ref = Ref{Union{TrainingSession,Nothing}}(nothing)

    @post "/api/training/start" function (req::HTTP.Request)
        body = JSON3.read(req.body)
        num_episodes = get(body, :num_episodes, 100)
        trainer_type = get(body, :trainer_type, "random")

        trainer = if trainer_type == "random"
            RandomTrainer()
        else
            RandomTrainer()  # fallback; future trainers added here
        end

        session = TrainingSession(trainer; num_episodes=Int(num_episodes))
        session_ref[] = session
        start_training!(session)
        return Dict("status" => "started", "num_episodes" => num_episodes)
    end

    @post "/api/training/stop" function (req::HTTP.Request)
        session = session_ref[]
        if session !== nothing
            stop_training!(session)
            return Dict("status" => "stopped")
        else
            return Dict("status" => "no_session")
        end
    end

    @get "/api/training/status" function (req::HTTP.Request)
        session = session_ref[]
        if session !== nothing
            return training_status(session)
        else
            return Dict(
                "is_running" => false,
                "total_episodes" => 0,
                "completed_episodes" => 0,
                "latest" => nothing,
            )
        end
    end

    @get "/api/training/history" function (req::HTTP.Request)
        session = session_ref[]
        if session !== nothing
            return training_history(session)
        else
            return []
        end
    end

    @get "/api/training/policy" function (req::HTTP.Request)
        session = session_ref[]
        if session !== nothing
            p = training_policy(session)
            return Dict("policy" => [p[r, :] for r in 1:8])
        else
            return Dict("policy" => [zeros(Float32, 8) for _ in 1:8])
        end
    end

    @get "/api/training/hyperparameters" function (req::HTTP.Request)
        session = session_ref[]
        if session !== nothing
            return hyperparameters(session.trainer)
        else
            return Dict{String,Any}()
        end
    end

    # --- Analysis API ---

    @get "/api/analysis/evaluate" function (req::HTTP.Request)
        params = queryparams(req)
        evaluator_name = get(params, "player", "heuristic")
        index_str = get(params, "index", nothing)

        target_game = game_ref[]
        if index_str !== nothing
            idx = tryparse(Int, index_str)
            if idx !== nothing && 0 <= idx <= length(history)
                target_game = ReversiGame()
                for i in 1:idx
                    move_str = history[i]
                    if move_str == "pass"
                        pass!(target_game; force=true)
                    else
                        pos = Position(move_str)
                        make_move!(target_game, pos.row, pos.col)
                    end
                end
            end
        end

        try
            evaluator = make_evaluator(evaluator_name)
            return evaluate_position(evaluator, target_game)
        catch e
            return HTTP.Response(400, "Invalid evaluator: $evaluator_name ($(typeof(e)))")
        end
    end

    @get "/api/analysis/line" function (req::HTTP.Request)
        params = queryparams(req)
        evaluator_name = get(params, "player", "minimax-3")
        depth = something(tryparse(Int, get(params, "depth", "6")), 6)
        index_str = get(params, "index", nothing)

        target_game = game_ref[]
        if index_str !== nothing
            idx = tryparse(Int, index_str)
            if idx !== nothing && 0 <= idx <= length(history)
                target_game = ReversiGame()
                for i in 1:idx
                    move_str = history[i]
                    if move_str == "pass"
                        pass!(target_game; force=true)
                    else
                        pos = Position(move_str)
                        make_move!(target_game, pos.row, pos.col)
                    end
                end
            end
        end

        try
            evaluator = make_evaluator(evaluator_name)
            return principal_variation(evaluator, target_game, clamp(depth, 1, 20))
        catch e
            return HTTP.Response(400, "Invalid analysis: $evaluator_name ($(typeof(e)))")
        end
    end

    # --- Tournament API ---
    tournament_ref = Ref{Union{TournamentSession,Nothing}}(nothing)

    @post "/api/tournament/start" function (req::HTTP.Request)
        body = JSON3.read(req.body)
        player_specs = [String(p) for p in body.players]
        num_games = Int(get(body, :num_games, 5))

        try
            players = [make_evaluator(spec) for spec in player_specs]
            session = TournamentSession(player_specs, players; num_games=num_games)
            tournament_ref[] = session
            start_tournament!(session)
            return Dict(
                "status" => "started", "num_games" => num_games, "players" => player_specs
            )
        catch e
            return HTTP.Response(
                400, "Invalid tournament config: $(typeof(e)) $(sprint(showerror, e))"
            )
        end
    end

    @post "/api/tournament/stop" function (req::HTTP.Request)
        session = tournament_ref[]
        if session !== nothing
            stop_tournament!(session)
            return Dict("status" => "stopped")
        else
            return Dict("status" => "no_session")
        end
    end

    @get "/api/tournament/status" function (req::HTTP.Request)
        session = tournament_ref[]
        if session !== nothing
            return tournament_status(session)
        else
            return Dict{String,Any}(
                "is_running" => false,
                "players" => String[],
                "num_games" => 0,
                "total_pairs" => 0,
                "completed_pairs" => 0,
                "total_games" => 0,
                "completed_games" => 0,
                "results" => [],
            )
        end
    end

    # --- Opening Book API ---

    @get "/api/opening/status" function (req::HTTP.Request)
        book = opening_book_ref[]
        if book === nothing
            return Dict{String,Any}(
                "loaded" => false,
                "source_file" => "",
                "game_count" => 0,
                "entry_count" => 0,
                "max_depth" => 0,
            )
        else
            s = opening_book_summary(book)
            s["loaded"] = true
            return s
        end
    end

    @post "/api/opening/build" function (req::HTTP.Request)
        body = JSON3.read(req.body)
        path_val = String(get(body, :wthor_path, ""))
        max_depth = Int(get(body, :max_depth, 20))
        if isempty(path_val) || !isfile(path_val)
            return HTTP.Response(400, "File not found: $path_val")
        end
        try
            opening_book_ref[] = build_opening_book(path_val; max_depth=max_depth)
            s = opening_book_summary(opening_book_ref[])
            s["loaded"] = true
            return s
        catch e
            return HTTP.Response(
                400, "Failed to build opening book: $(typeof(e)) $(sprint(showerror, e))"
            )
        end
    end

    @get "/api/opening/lookup" function (req::HTTP.Request)
        book = opening_book_ref[]
        if book === nothing
            return Dict{String,Any}("loaded" => false, "found" => false)
        end

        params = queryparams(req)
        index_str = get(params, "index", nothing)

        target_game = game_ref[]
        if index_str !== nothing
            idx = tryparse(Int, index_str)
            if idx !== nothing && 0 <= idx <= length(history)
                target_game = ReversiGame()
                for i in 1:idx
                    move_str = history[i]
                    if move_str == "pass"
                        pass!(target_game; force=true)
                    else
                        pos = Position(move_str)
                        make_move!(target_game, pos.row, pos.col)
                    end
                end
            end
        end

        result = opening_book_lookup_dict(book, target_game)
        result["loaded"] = true
        return result
    end

    # 3. CORS & Response Middleware
    function cors_middleware(handler)
        return function (req::HTTP.Request)
            if HTTP.method(req) == "OPTIONS"
                return HTTP.Response(
                    200,
                    [
                        "Access-Control-Allow-Origin" => "*",
                        "Access-Control-Allow-Methods" => "POST, GET, OPTIONS",
                        "Access-Control-Allow-Headers" => "*",
                        "Access-Control-Max-Age" => "86400",
                    ],
                )
            end
            response = handler(req)
            res = if response isa HTTP.Response
                response
            else
                HTTP.Response(200, JSON3.write(response))
            end
            HTTP.setheader(res, "Access-Control-Allow-Origin" => "*")
            if !(response isa HTTP.Response)
                HTTP.setheader(res, "Content-Type" => "application/json")
            end
            return res
        end
    end

    # 4. Starting the server
    @info "Starting local Reversi Server on http://localhost:$port"

    if open_browser
        @async begin
            sleep(1.0)
            try
                DefaultApplication.open("http://localhost:$port")
            catch e
                @warn "Could not automatically open browser: $e"
            end
        end
    end

    # Static file serving
    if isdir(frontend_dir)
        Oxygen.staticfiles(frontend_dir, "/")
    else
        @warn "Frontend build not found at $frontend_dir. API-only mode."
        @get "/" function (req::HTTP.Request)
            return "<h1>Reversi.jl API Server</h1><p>Frontend build not found. Please run <code>npm run build</code> in <code>web/frontend/</code>.</p>"
        end
    end

    return serve(; host="0.0.0.0", port=port, middleware=[cors_middleware])
end

# Internal helper for auto-passing
function _handle_auto_passes!(game, history)
    while !is_game_over(game) && isempty(valid_moves(game))
        pass!(game; force=false)
        push!(history, "pass")
    end
end

end # module
