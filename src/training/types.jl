using Serialization

"""
    AbstractTrainer

Abstract type for all trainer implementations.

Required interface:
- `train_episode!(trainer, episode::Int) -> TrainingMetrics`

Optional interface (with sensible defaults — override as needed):
- `predict_value(trainer, game) -> Float32`            # value of current state
- `hyperparameters(trainer) -> Dict{String,Any}`       # for UI display
- `opponent(trainer) -> Union{Player,Nothing}`         # baseline opponent (nothing = self-play)
- `batch_size(trainer) -> Int`                         # episodes per batch (default 1)
- `train_batch!(trainer, ep_start, n) -> Vector{TrainingMetrics}`
- `save_trainer(trainer, path)` / `load_trainer(path)` # persistence
"""
abstract type AbstractTrainer end

"""
    TrainingMetrics

Metrics collected from a single training episode (one game).

Fields:
- `episode`        — episode number (1-based)
- `winner`         — `BLACK`, `WHITE`, or `EMPTY` (draw)
- `black_score`    — final black piece count
- `white_score`    — final white piece count
- `win_rate`       — per-episode indicator (1.0 if BLACK won, 0.0 otherwise)
- `policy`         — 8×8 move frequency / probability heatmap
- `value`          — predicted value of the initial state from BLACK's perspective
- `loss`           — training loss (if a weight update occurred this episode), or `nothing`
"""
Base.@kwdef struct TrainingMetrics
    episode::Int
    winner::Int
    black_score::Int
    white_score::Int
    win_rate::Float64
    policy::Matrix{Float32}
    value::Float32 = 0.0f0
    loss::Union{Float64,Nothing} = nothing
end

"""
    TrainingSession

Manages the lifecycle of a training run: background task, metrics history, locking.
"""
mutable struct TrainingSession
    trainer::AbstractTrainer
    num_episodes::Int
    metrics_history::Vector{TrainingMetrics}
    is_running::Bool
    task::Union{Task,Nothing}
    lock::ReentrantLock

    function TrainingSession(trainer::AbstractTrainer; num_episodes::Int=100)
        return new(
            trainer, num_episodes, TrainingMetrics[], false, nothing, ReentrantLock()
        )
    end
end

# ---------------------------------------------------------------------------
# Required interface
# ---------------------------------------------------------------------------

"""
    train_episode!(trainer::AbstractTrainer, episode::Int) -> TrainingMetrics

Run one training episode and return the collected metrics.
Must be implemented by every concrete `AbstractTrainer` subtype.
"""
function train_episode! end

# ---------------------------------------------------------------------------
# Optional interface (defaults)
# ---------------------------------------------------------------------------

# --- Feature 2: Value function ---

"""
    predict_value(trainer::AbstractTrainer, game::ReversiGame) -> Float32

Predict the value of `game`'s current state from the current player's perspective.
Convention: positive = current player winning, in roughly `[-1, 1]`.
Default: `0.0f0` (no information).
"""
predict_value(::AbstractTrainer, ::ReversiGame) = 0.0f0

# --- Feature 4: Hyperparameters ---

"""
    hyperparameters(trainer::AbstractTrainer) -> Dict{String,Any}

Return a dictionary of hyperparameters for display in the training UI.
Default: empty dict.
"""
hyperparameters(::AbstractTrainer) = Dict{String,Any}()

# --- Feature 5: Opponent selection ---

"""
    opponent(trainer::AbstractTrainer) -> Union{Player,Nothing}

Return the baseline opponent for the trainer, or `nothing` for pure self-play.
Default: `nothing`.
"""
opponent(::AbstractTrainer) = nothing

# --- Feature 6: Batch update ---

"""
    batch_size(trainer::AbstractTrainer) -> Int

Return the number of episodes the trainer prefers to run before reporting metrics.
Trainers that accumulate gradients across episodes should override this.
Default: `1`.
"""
batch_size(::AbstractTrainer) = 1

"""
    train_batch!(trainer, episode_start::Int, n::Int) -> Vector{TrainingMetrics}

Run `n` consecutive episodes. Default implementation calls `train_episode!`
sequentially. Trainers that need to accumulate gradients across the batch
should override this method.
"""
function train_batch!(trainer::AbstractTrainer, episode_start::Int, n::Int)
    return [train_episode!(trainer, episode_start + i - 1) for i in 1:n]
end

# --- Feature 1: Persistence ---

"""
    save_trainer(trainer::AbstractTrainer, path::AbstractString)

Serialize `trainer` to `path` using Julia's `Serialization` stdlib.
Trainers with framework-specific state (e.g. Flux models with GPU buffers)
should override this with a format-appropriate writer.
"""
function save_trainer(trainer::AbstractTrainer, path::AbstractString)
    open(path, "w") do io
        return Serialization.serialize(io, trainer)
    end
    return path
end

"""
    load_trainer(path::AbstractString) -> AbstractTrainer

Deserialize a trainer previously saved with `save_trainer`.
"""
function load_trainer(path::AbstractString)
    return open(Serialization.deserialize, path, "r")
end
