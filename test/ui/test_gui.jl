using Reversi

# kifu list layout -----------------------------------------------------------
#
# The frame, whatever offsets the panel is eventually tuned to: every drawn row
# is clickable and maps to itself, the axis shows all of them, and a point off
# the list reads as off the list. Nothing here pins a chosen offset, so moving
# the whole layout is free as long as the three functions move together.

@testset "every point of a row maps back to that row" begin
    # Probe the band, not the anchor: `floor(y + 0.5) + 1` agrees at every anchor
    # and is off by half a row everywhere else, so an anchor-only sweep is vacuous.
    for n in 1:6, frac in (0.0, 0.25, 0.5, 0.75, 0.999)
        height = Reversi.kifu_row_y(n + 1) - Reversi.kifu_row_y(n)
        @test Reversi.kifu_row_at(Reversi.kifu_row_y(n) + frac * height) == n
    end
end

@testset "the axis shows every row" begin
    for n_rows in (1, 5, 20)
        hi, lo = Reversi.kifu_row_limits(n_rows)
        @test hi > lo                              # reversed: the list reads down
        @test lo < Reversi.kifu_row_y(1)               # first row inside, with padding
        @test hi > Reversi.kifu_row_y(n_rows + 1)      # last row's band inside too
    end
end

@testset "a point off the list reads as off the list" begin
    n_rows = 5
    @test Reversi.kifu_row_at(Reversi.kifu_row_y(1) - 0.25) < 1
    @test Reversi.kifu_row_at(Reversi.kifu_row_y(n_rows + 1)) > n_rows
end
