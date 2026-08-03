"""
    RandomTrainer <: AbstractTrainer

Dummy trainer that plays RandomPlayer vs RandomPlayer.
Useful for validating the training pipeline without any ML dependencies.
"""
struct RandomTrainer <: AbstractTrainer end

function train_episode!(trainer::RandomTrainer, episode::Int)
    game = ReversiGame()
    players = Dict{Int,Player}(BLACK => RandomPlayer(), WHITE => RandomPlayer())

    # Collect move positions for the policy heatmap
    policy = zeros(Float32, 8, 8)

    game_loop!(
        game,
        players;
        on_move=(g, color, notation) -> begin
            if notation != "pass"
                pos = Position(notation)
                policy[pos.row, pos.col] += 1.0f0
            end
        end,
    )

    # Normalize policy to frequencies
    total = sum(policy)
    if total > 0
        policy ./= total
    end

    winner = get_winner(game)
    b_count, w_count = count_pieces(game)
    black_won = winner == BLACK ? 1.0 : 0.0

    return TrainingMetrics(;
        episode=episode,
        winner=winner,
        black_score=b_count,
        white_score=w_count,
        win_rate=black_won,
        policy=policy,
    )
end

# Hyperparameters: nothing meaningful for a random baseline
function hyperparameters(::RandomTrainer)
    return Dict{String,Any}("name" => "RandomTrainer", "stochastic" => true)
end
