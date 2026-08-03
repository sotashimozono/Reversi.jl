# ---------------------------------------------------------------------------
# GUI stubs
#
# GUIPlayer is defined here so it is always available as a concrete type
# (e.g. for dispatch and for play_game calls).
#
# The actual windows (launch_gui / launch_replay_gui) are provided by
# the package extension  ext/ReversiGLMakieExt.jl  and become available
# only after GLMakie has been loaded:
#
#   using GLMakie   # must be loaded before or alongside Reversi
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
