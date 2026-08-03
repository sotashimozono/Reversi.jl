using Reversi
using Reversi: EMPTY, BLACK, WHITE, IN_PROGRESS
using Reversi: compute_full_hash, make_move!, valid_moves, pass!, count_pieces
using Reversi: GameRecord, save_game, load_game, replay_game, validate_record
using Test

# ---------------------------------------------------------------------------
# GameRecord construction
# ---------------------------------------------------------------------------

@testset "GameRecord – defaults" begin
    rec = GameRecord(["d3", "c3"])
    @test rec.moves == ["d3", "c3"]
    @test rec.result == IN_PROGRESS
end

# ---------------------------------------------------------------------------
# save_game / load_game round-trips
# ---------------------------------------------------------------------------

@testset "save/load – BLACK wins" begin
    rec = GameRecord(["d3", "c3", "b3"], BLACK)
    tmp = tempname() * ".txt"
    try
        save_game(rec, tmp)
        got = load_game(tmp)
        @test got.moves == rec.moves
        @test got.result == BLACK
    finally
        isfile(tmp) && rm(tmp)
    end
end

@testset "save/load – WHITE wins" begin
    rec = GameRecord(["d3"], WHITE)
    tmp = tempname() * ".txt"
    try
        save_game(rec, tmp)
        got = load_game(tmp)
        @test got.result == WHITE
    finally
        isfile(tmp) && rm(tmp)
    end
end

@testset "save/load – draw" begin
    rec = GameRecord(["d3"], EMPTY)
    tmp = tempname() * ".txt"
    try
        save_game(rec, tmp)
        got = load_game(tmp)
        @test got.result == EMPTY
    finally
        isfile(tmp) && rm(tmp)
    end
end

@testset "save/load – IN_PROGRESS" begin
    rec = GameRecord(["d3"])   # result defaults to IN_PROGRESS
    tmp = tempname() * ".txt"
    try
        save_game(rec, tmp)
        got = load_game(tmp)
        @test got.result == IN_PROGRESS
    finally
        isfile(tmp) && rm(tmp)
    end
end

@testset "save/load – empty move list" begin
    rec = GameRecord(String[], BLACK)
    tmp = tempname() * ".txt"
    try
        save_game(rec, tmp)
        got = load_game(tmp)
        @test isempty(got.moves)
        @test got.result == BLACK
    finally
        isfile(tmp) && rm(tmp)
    end
end

# ---------------------------------------------------------------------------
# load_game error handling
# ---------------------------------------------------------------------------

@testset "load_game – file not found" begin
    @test_throws ArgumentError load_game("/no/such/file.txt")
end

@testset "load_game – missing MOVES line" begin
    tmp = tempname() * ".txt"
    try
        write(tmp, "RESULT: BLACK\n")
        @test_throws ArgumentError load_game(tmp)
    finally
        isfile(tmp) && rm(tmp)
    end
end

@testset "load_game – missing RESULT line" begin
    tmp = tempname() * ".txt"
    try
        write(tmp, "MOVES: d3 c3\n")
        @test_throws ArgumentError load_game(tmp)
    finally
        isfile(tmp) && rm(tmp)
    end
end

@testset "load_game – unrecognised RESULT value" begin
    tmp = tempname() * ".txt"
    try
        write(tmp, "MOVES: d3\nRESULT: GARBAGE\n")
        @test_throws ArgumentError load_game(tmp)
    finally
        isfile(tmp) && rm(tmp)
    end
end

# ---------------------------------------------------------------------------
# validate_record
# ---------------------------------------------------------------------------

@testset "validate_record – valid sequence" begin
    rec = GameRecord(["d3", "c3", "b3"], BLACK)
    @test validate_record(rec) === nothing
end

@testset "validate_record – invalid move" begin
    rec = GameRecord(["a1"])   # a1 is never valid at start
    err = validate_record(rec)
    @test err isa String
    @test occursin("a1", err)
end

@testset "validate_record – illegal pass" begin
    # Passing at start when moves exist is illegal
    rec = GameRecord(["pass"])
    err = validate_record(rec)
    @test err isa String
    @test occursin("pass", err)
end

# ---------------------------------------------------------------------------
# replay_game
# ---------------------------------------------------------------------------

@testset "replay_game – basic" begin
    moves = ["d3", "c3", "b3"]
    rec = GameRecord(moves, IN_PROGRESS)
    replayed = replay_game(rec)

    ref = ReversiGame()
    for m in moves
        make_move!(ref, m)
    end

    @test replayed.black == ref.black
    @test replayed.white == ref.white
    @test replayed.current_player == ref.current_player
    @test replayed.hash == ref.hash
end

@testset "replay_game – hash stays consistent" begin
    rec = GameRecord(["d3", "c4", "f5", "f4"])
    g = replay_game(rec)
    @test g.hash == compute_full_hash(g)
end

@testset "replay_game – strict=false ignores invalid move" begin
    # With strict=false (default) an invalid move is silently skipped
    rec = GameRecord(["d3", "a1"])  # a1 is invalid after d3
    g = replay_game(rec; strict=false)
    # The game should have applied d3 and skipped a1
    @test g.current_player == WHITE   # after d3 it is WHITE's turn (a1 skipped)
end

@testset "replay_game – strict=true throws on invalid move" begin
    rec = GameRecord(["d3", "a1"])
    @test_throws ArgumentError replay_game(rec; strict=true)
end

# ---------------------------------------------------------------------------
# play_game integration (RandomPlayer vs RandomPlayer)
# ---------------------------------------------------------------------------

@testset "play_game – save and reload record" begin
    tmp = tempname() * ".txt"
    try
        winner = play_game(
            RandomPlayer(), RandomPlayer(); verbose=false, save_record=true, record_path=tmp
        )
        @test winner in [BLACK, WHITE, EMPTY]
        @test isfile(tmp)

        rec = load_game(tmp)
        replayed = replay_game(rec; strict=true)
        @test replayed.hash == compute_full_hash(replayed)
        @test validate_record(rec) === nothing
    finally
        isfile(tmp) && rm(tmp)
    end
end
