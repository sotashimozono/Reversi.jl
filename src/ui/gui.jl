# ---------------------------------------------------------------------------
# GUI stubs
#
# GUIPlayer is defined here so it is always available as a concrete type
# (e.g. for dispatch and for play_game calls).
#
# The actual windows (launch_gui / launch_replay_gui) are provided by
# the package extension  ext/ReversiMakieExt/, which triggers on Makie rather
# than on a backend: nothing in it names a GLMakie symbol, so it also loads
# with no backend at all, which is what lets CI build the layout. Showing a
# window still needs one:
#
#   using GLMakie   # or any other Makie backend
#   using Reversi
# ---------------------------------------------------------------------------
# (GUIPlayer has been merged into HumanPlayer in core/player.jl)

"""
    launch_gui([backend=:makie], [black, white]; kwargs...)

Open an interactive Reversi window. Supports multiple backends via package extensions.

## Backends
- `:makie` (default): GLMakie-based native window. Requires `using GLMakie`.
- `:web`: React-based web interface. Requires `using Oxygen, DefaultApplication, HTTP, JSON3`.

## Examples
```julia
using GLMakie, Reversi
launch_gui()                            # human (black) vs random AI (Makie)

using Oxygen, DefaultApplication, HTTP, JSON3, Reversi
launch_gui(:web; port=8081)             # start web server on port 8081
```
"""
function launch_gui end

# Convenience methods to dispatch Symbol backends to Val-based implementations
function launch_gui(backend::Symbol, args...; kwargs...)
    return launch_gui(Val(backend), args...; kwargs...)
end

# Default to :makie if no backend is specified
launch_gui(args...; kwargs...) = launch_gui(:makie, args...; kwargs...)

"""
    launch_replay_gui(record_or_moves; title="Game Replay")

Open a read-only GLMakie replay window for a recorded game.

**Requires GLMakie to be loaded first:**
```julia
using GLMakie, Reversi
rec = load_game("mygame.txt")
launch_replay_gui(rec)
```
"""
function launch_replay_gui end

"""
    kifu_row_y(n::Integer) -> Float32

Y coordinate of the top-anchored move-list row `n`, so row `n` covers the
half-open band `[kifu_row_y(n), kifu_row_y(n + 1))`.

Forms a set with `kifu_row_at` and `kifu_row_limits`, which only mean anything
together: a backend that draws with one convention, hit-tests with another, or
sizes its axis to a third silently mis-selects moves or clips a row. The offsets
themselves are free to change — the panel is tuned by eye — as long as all three
move with them.
"""
kifu_row_y(n::Integer) = Float32(n - 1)

"""
    kifu_row_at(y::Real) -> Int

Row lying under the y coordinate `y`, the inverse of `kifu_row_y`. A result
outside `1:n_rows` means the point is off the list; callers must reject it,
nothing is clamped here.
"""
kifu_row_at(y::Real) = floor(Int, y) + 1

"""
    kifu_row_limits(n_rows::Integer) -> Tuple{Float32,Float32}

Axis range showing all `n_rows` rows with half a row of padding, high value
first so the list reads downwards. Pass straight to `ylims!`.
"""
kifu_row_limits(n_rows::Integer) = (kifu_row_y(n_rows + 1) + 0.5f0, kifu_row_y(1) - 0.5f0)
