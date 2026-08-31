struct NamedPlayerEntry
    name::String
    factory::Function
end

const _BUILTIN_PLAYERS = [
    NamedPlayerEntry("Human", () -> HumanPlayer()),
    NamedPlayerEntry("Random AI", () -> RandomPlayer()),
    NamedPlayerEntry("Greedy AI", () -> GreedyPlayer()),
]

function _get_player_by_name(name::String)
    idx = findfirst(e -> e.name == name, _BUILTIN_PLAYERS)
    return isnothing(idx) ? HumanPlayer() : _BUILTIN_PLAYERS[idx].factory()
end

function _selected_player(menu::Menu, registry::Vector{NamedPlayerEntry})
    idx = clamp(menu.i_selected[], 1, length(registry))
    return registry[idx].factory()
end

# ---------------------------------------------------------------------------
# Async wrapper for GUI (connects Reversi.game_loop! to Makie Observables)
# ---------------------------------------------------------------------------

function run_game!(
    game_ref::Ref{ReversiGame},
    kifu_ref::Ref{Vector{Tuple{Int,Int,String}}},
    players::Ref{Dict{Int,Player}},
    game_obs::Observable,
    kifu_obs::Observable,
    last_move_obs::Observable,
    game_over_obs::Observable{Bool};
    stop_check::Function=() -> false,   # returns true → cancel this task
)
    try
        move_num = Ref(0)
        game_loop!(
            game_ref[],
            players[];
            on_move=(game, color, notation) -> begin
                yield()
                move_num[] += 1
                push!(kifu_ref[], (move_num[], color, notation))
                last_move_obs[] = notation == "pass" ? nothing : Position(notation)
                kifu_obs[] = copy(kifu_ref[])
                game_obs[] = deepcopy(game)
            end,
            on_done=(_) -> (game_over_obs[] = true),
        )
    catch e
        e isa InvalidStateException && return nothing   # channel closed intentionally
        @error "Error in game task" exception=(e, catch_backtrace())
    end
end
