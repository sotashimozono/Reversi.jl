using Reversi

# kifu list layout -----------------------------------------------------------

@testset "kifu_row_at inverts kifu_row_y across the whole row band" begin
    # Probe the band, not the anchor: `floor(y + 0.5) + 1` agrees at every anchor
    # and is off by half a row everywhere else, so an anchor-only sweep is vacuous.
    for n in 1:6, delta in (0.0, 0.25, 0.5, 0.75, 0.999)
        @test Reversi.kifu_row_at(Reversi.kifu_row_y(n) + delta) == n
    end
end

@testset "kifu_row_at row boundaries" begin
    @test Reversi.kifu_row_at(Reversi.kifu_row_y(3) + 1.0) == 4   # next anchor, next row
    @test Reversi.kifu_row_at(-0.25) == 0                         # above row 1, rejected
end
