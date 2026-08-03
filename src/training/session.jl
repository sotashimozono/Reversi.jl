"""
    start_training!(session::TrainingSession)

Launch the training loop as a background `Task`.
Each episode calls `train_episode!(trainer, episode_number)` and appends
the result to `session.metrics_history`.
"""
function start_training!(session::TrainingSession)
    lock(session.lock) do
        session.is_running && error("Training is already running")
        empty!(session.metrics_history)
        return session.is_running = true
    end

    bs = batch_size(session.trainer)

    session.task = @async begin
        try
            ep = 1
            while ep <= session.num_episodes
                session.is_running || break
                n = min(bs, session.num_episodes - ep + 1)
                batch = train_batch!(session.trainer, ep, n)
                lock(session.lock) do
                    append!(session.metrics_history, batch)
                end
                ep += n
            end
        catch e
            @error "Training error" exception = (e, catch_backtrace())
        finally
            lock(session.lock) do
                session.is_running = false
            end
        end
    end

    return nothing
end

"""
    stop_training!(session::TrainingSession)

Signal the training loop to stop after the current episode finishes.
"""
function stop_training!(session::TrainingSession)
    lock(session.lock) do
        return session.is_running = false
    end
    return nothing
end

"""
    training_status(session::TrainingSession) -> Dict

Return the current training status: running flag, episode count, latest metrics.
"""
function training_status(session::TrainingSession)
    lock(session.lock) do
        n = length(session.metrics_history)
        latest = n > 0 ? session.metrics_history[end] : nothing
        return Dict(
            "is_running" => session.is_running,
            "total_episodes" => session.num_episodes,
            "completed_episodes" => n,
            "latest" => _metrics_to_dict(latest),
        )
    end
end

"""
    training_history(session::TrainingSession) -> Vector{Dict}

Return the full metrics history as a vector of dicts (JSON-serializable).
"""
function training_history(session::TrainingSession)
    lock(session.lock) do
        return [_metrics_to_dict(m) for m in session.metrics_history]
    end
end

"""
    training_policy(session::TrainingSession) -> Matrix{Float32}

Return the latest policy heatmap (8×8). Returns zeros if no episodes completed.
"""
function training_policy(session::TrainingSession)
    lock(session.lock) do
        n = length(session.metrics_history)
        return n > 0 ? session.metrics_history[end].policy : zeros(Float32, 8, 8)
    end
end

function _metrics_to_dict(m::TrainingMetrics)
    return Dict{String,Any}(
        "episode" => m.episode,
        "winner" => m.winner,
        "black_score" => m.black_score,
        "white_score" => m.white_score,
        "win_rate" => m.win_rate,
        "value" => m.value,
        "loss" => m.loss,
    )
end

function _metrics_to_dict(::Nothing)
    return nothing
end
