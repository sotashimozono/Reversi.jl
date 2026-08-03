using TOML
using Dates

"""
    GUIConfig

A structure to hold GUI configuration settings.
"""
mutable struct GUIConfig
    window_title::String
    window_width::Int
    window_height::Int

    colors::Dict{String,Any}

    show_hints::Bool
    show_last_move::Bool
    show_kifu::Bool
    show_eval::Bool
    fontsize::Int
    sidebar_width::Int

    black_player::String
    white_player::String
end

const DEFAULT_CONFIG_PATH = joinpath(
    dirname(dirname(@__DIR__)), "config", "default_config.toml"
)
const USER_CONFIG_PATH = joinpath(homedir(), ".reversirc.toml")
const SESSION_CONFIG_PATH = joinpath(tempdir(), "reversi_session_config.toml")

function load_config()
    # 1. Start with default config
    config_dict = TOML.parsefile(DEFAULT_CONFIG_PATH)

    # 2. Merge with user config if exists
    if isfile(USER_CONFIG_PATH)
        user_config = TOML.parsefile(USER_CONFIG_PATH)
        _merge!(config_dict, user_config)
    end

    # 3. Merge with session config (e.g. from tmp) if exists
    if isfile(SESSION_CONFIG_PATH)
        session_config = TOML.parsefile(SESSION_CONFIG_PATH)
        _merge!(config_dict, session_config)
    end

    # 4. Merge with environment variables
    # Format: REVERSI_SECTION_KEY (e.g. REVERSI_COLORS_BOARD)
    for (env_key, env_val) in ENV
        if startswith(env_key, "REVERSI_")
            parts = split(env_key, "_")
            if length(parts) >= 3
                section = lowercase(parts[2])
                name = join(lowercase.(parts[3:end]), "_")
                if haskey(config_dict, section)
                    # Try to match the type of the existing value if possible
                    if haskey(config_dict[section], name)
                        config_dict[section][name] = _try_parse_val(
                            config_dict[section][name], env_val
                        )
                    else
                        config_dict[section][name] = env_val
                    end
                end
            end
        end
    end

    # Map to GUIConfig struct
    return GUIConfig(
        get(config_dict["window"], "title", "Reversi.jl"),
        get(config_dict["window"], "width", 820),
        get(config_dict["window"], "height", 760),
        config_dict["colors"],
        get(config_dict["ui"], "show_hints", true),
        get(config_dict["ui"], "show_last_move", false),
        get(config_dict["ui"], "show_kifu", true),
        get(config_dict["ui"], "show_eval", false),
        get(config_dict["ui"], "fontsize", 14),
        get(config_dict["ui"], "sidebar_width", 230),
        get(config_dict["players"], "black", "Human"),
        get(config_dict["players"], "white", "Random AI"),
    )
end

function _merge!(dst::AbstractDict, src::AbstractDict)
    for (k, v) in src
        if haskey(dst, k) && dst[k] isa AbstractDict && v isa AbstractDict
            _merge!(dst[k], v)
        else
            dst[k] = v
        end
    end
    return dst
end

function _try_parse_val(existing_val, new_str::String)
    existing_val isa Int && return parse(Int, new_str)
    existing_val isa Bool && return lowercase(new_str) in ("true", "yes", "1")
    return new_str
end

function save_session_config(config::GUIConfig)
    config_dict = Dict(
        "window" => Dict(
            "title" => config.window_title,
            "width" => config.window_width,
            "height" => config.window_height,
        ),
        "colors" => config.colors,
        "ui" => Dict(
            "show_hints" => config.show_hints,
            "show_last_move" => config.show_last_move,
            "show_kifu" => config.show_kifu,
            "show_eval" => config.show_eval,
            "fontsize" => config.fontsize,
            "sidebar_width" => config.sidebar_width,
        ),
        "players" => Dict("black" => config.black_player, "white" => config.white_player),
    )
    open(SESSION_CONFIG_PATH, "w") do io
        return TOML.print(io, config_dict)
    end
end

"""
    parse_color(hex::String)

Parse a hex color string (e.g. "#RRGGBB" or "#RRGGBBAA") into a GLMakie color.
Returns a tuple of (r, g, b) or (r, g, b, a) normalized to 0.0-1.0.
"""
function parse_color(hex::String)
    hex = lstrip(hex, '#')
    if length(hex) == 6
        r = parse(Int, hex[1:2]; base=16) / 255.0
        g = parse(Int, hex[3:4]; base=16) / 255.0
        b = parse(Int, hex[5:6]; base=16) / 255.0
        return (Float32(r), Float32(g), Float32(b))
    elseif length(hex) == 8
        r = parse(Int, hex[1:2]; base=16) / 255.0
        g = parse(Int, hex[3:4]; base=16) / 255.0
        b = parse(Int, hex[5:6]; base=16) / 255.0
        a = parse(Int, hex[7:8]; base=16) / 255.0
        return (Float32(r), Float32(g), Float32(b), Float32(a))
    end
    return (0.0f0, 0.0f0, 0.0f0) # Fallback
end
