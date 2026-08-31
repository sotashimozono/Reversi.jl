using Reversi

# parse_color ----------------------------------------------------------------

@testset "parse_color RGB" begin
    r, g, b = Reversi.parse_color("#0a6b21")
    @test r ≈ 0x0a / 255.0f0
    @test g ≈ 0x6b / 255.0f0
    @test b ≈ 0x21 / 255.0f0
end

@testset "parse_color RGBA" begin
    r, g, b, a = Reversi.parse_color("#0a6b218c")
    @test r ≈ 0x0a / 255.0f0
    @test a ≈ 0x8c / 255.0f0
end

@testset "parse_color fallback" begin
    result = Reversi.parse_color("invalid")
    @test result == (0.0f0, 0.0f0, 0.0f0)
end

@testset "parse_color black and white" begin
    @test Reversi.parse_color("#000000") == (0.0f0, 0.0f0, 0.0f0)
    r, g, b = Reversi.parse_color("#ffffff")
    @test r ≈ 1.0f0 && g ≈ 1.0f0 && b ≈ 1.0f0
end

# load_config ----------------------------------------------------------------

@testset "load_config returns GUIConfig" begin
    config = load_config()
    @test config isa GUIConfig
    @test config.window_width > 0
    @test config.window_height > 0
    @test config.fontsize > 0
    @test config.sidebar_width > 0
    @test config.colors isa Dict
end

@testset "load_config color keys present" begin
    config = load_config()
    for key in (
        "board",
        "grid",
        "text",
        "background",
        "hint",
        "black_piece",
        "white_piece",
        "last_move",
        "accent_black",
        "accent_white",
        "panel",
        "text_dim",
    )
        @test haskey(config.colors, key)
    end
end

@testset "load_config player defaults" begin
    config = load_config()
    @test config.black_player isa String
    @test config.white_player isa String
    @test !isempty(config.black_player)
    @test !isempty(config.white_player)
end
