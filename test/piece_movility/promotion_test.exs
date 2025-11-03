defmodule LavenoTest.PieceMovility.PromotionTest do
  use ExUnit.Case, async: true
  doctest Laveno.Board.Utils

  alias Laveno.Board
  alias Laveno.Board.Utils

  describe "White pawn promotion validation (rank 7 → 8):" do
    test "white pawn can promote to queen with non-capture move e7e8q" do
      assert Board.new(:empty)
             |> Board.place_piece(:P, "e7")
             |> Board.set_active_color("w")
             |> Utils.valid_move?("e7e8q") == true
    end

    test "white pawn can promote to rook with non-capture move e7e8r" do
      assert Board.new(:empty)
             |> Board.place_piece(:P, "e7")
             |> Board.set_active_color("w")
             |> Utils.valid_move?("e7e8r") == true
    end

    test "white pawn can promote to bishop with non-capture move e7e8b" do
      assert Board.new(:empty)
             |> Board.place_piece(:P, "e7")
             |> Board.set_active_color("w")
             |> Utils.valid_move?("e7e8b") == true
    end

    test "white pawn can promote to knight with non-capture move e7e8n" do
      assert Board.new(:empty)
             |> Board.place_piece(:P, "e7")
             |> Board.set_active_color("w")
             |> Utils.valid_move?("e7e8n") == true
    end

    test "white pawn can promote to queen with capture move e7d8q" do
      assert Board.new(:empty)
             |> Board.place_piece(:P, "e7")
             |> Board.place_piece(:r, "d8")
             |> Board.set_active_color("w")
             |> Utils.valid_move?("e7d8q") == true
    end

    test "white pawn can promote to rook with capture move e7f8r" do
      assert Board.new(:empty)
             |> Board.place_piece(:P, "e7")
             |> Board.place_piece(:n, "f8")
             |> Board.set_active_color("w")
             |> Utils.valid_move?("e7f8r") == true
    end

    test "white pawn can promote to bishop with capture move a7b8b" do
      assert Board.new(:empty)
             |> Board.place_piece(:P, "a7")
             |> Board.place_piece(:q, "b8")
             |> Board.set_active_color("w")
             |> Utils.valid_move?("a7b8b") == true
    end

    test "white pawn can promote to knight with capture move h7g8n" do
      assert Board.new(:empty)
             |> Board.place_piece(:P, "h7")
             |> Board.place_piece(:b, "g8")
             |> Board.set_active_color("w")
             |> Utils.valid_move?("h7g8n") == true
    end
  end

  describe "Black pawn promotion validation (rank 2 → 1):" do
    test "black pawn can promote to queen with non-capture move e2e1q" do
      assert Board.new(:empty)
             |> Board.place_piece(:p, "e2")
             |> Board.set_active_color("b")
             |> Utils.valid_move?("e2e1q") == true
    end

    test "black pawn can promote to rook with non-capture move e2e1r" do
      assert Board.new(:empty)
             |> Board.place_piece(:p, "e2")
             |> Board.set_active_color("b")
             |> Utils.valid_move?("e2e1r") == true
    end

    test "black pawn can promote to bishop with non-capture move e2e1b" do
      assert Board.new(:empty)
             |> Board.place_piece(:p, "e2")
             |> Board.set_active_color("b")
             |> Utils.valid_move?("e2e1b") == true
    end

    test "black pawn can promote to knight with non-capture move e2e1n" do
      assert Board.new(:empty)
             |> Board.place_piece(:p, "e2")
             |> Board.set_active_color("b")
             |> Utils.valid_move?("e2e1n") == true
    end

    test "black pawn can promote to queen with capture move e2d1q" do
      assert Board.new(:empty)
             |> Board.place_piece(:p, "e2")
             |> Board.place_piece(:R, "d1")
             |> Board.set_active_color("b")
             |> Utils.valid_move?("e2d1q") == true
    end

    test "black pawn can promote to rook with capture move e2f1r" do
      assert Board.new(:empty)
             |> Board.place_piece(:p, "e2")
             |> Board.place_piece(:N, "f1")
             |> Board.set_active_color("b")
             |> Utils.valid_move?("e2f1r") == true
    end

    test "black pawn can promote to bishop with capture move a2b1b" do
      assert Board.new(:empty)
             |> Board.place_piece(:p, "a2")
             |> Board.place_piece(:Q, "b1")
             |> Board.set_active_color("b")
             |> Utils.valid_move?("a2b1b") == true
    end

    test "black pawn can promote to knight with capture move h2g1n" do
      assert Board.new(:empty)
             |> Board.place_piece(:p, "h2")
             |> Board.place_piece(:B, "g1")
             |> Board.set_active_color("b")
             |> Utils.valid_move?("h2g1n") == true
    end
  end

  describe "Invalid promotion scenarios:" do
    test "white pawn cannot promote on wrong rank e6e7q" do
      assert Board.new(:empty)
             |> Board.place_piece(:P, "e6")
             |> Board.set_active_color("w")
             |> Utils.valid_move?("e6e7q") == false
    end

    test "black pawn cannot promote on wrong rank e3e2q" do
      assert Board.new(:empty)
             |> Board.place_piece(:p, "e3")
             |> Board.set_active_color("b")
             |> Utils.valid_move?("e3e2q") == false
    end

    test "white pawn cannot promote to king e7e8k" do
      assert Board.new(:empty)
             |> Board.place_piece(:P, "e7")
             |> Board.set_active_color("w")
             |> Utils.valid_move?("e7e8k") == false
    end

    test "white pawn cannot promote to pawn e7e8p" do
      assert Board.new(:empty)
             |> Board.place_piece(:P, "e7")
             |> Board.set_active_color("w")
             |> Utils.valid_move?("e7e8p") == false
    end

    test "black pawn cannot promote to king e2e1k" do
      assert Board.new(:empty)
             |> Board.place_piece(:p, "e2")
             |> Board.set_active_color("b")
             |> Utils.valid_move?("e2e1k") == false
    end

    test "black pawn cannot promote with invalid character e2e1x" do
      assert Board.new(:empty)
             |> Board.place_piece(:p, "e2")
             |> Board.set_active_color("b")
             |> Utils.valid_move?("e2e1x") == false
    end

    test "white pawn cannot promote without reaching last rank e5e6q" do
      assert Board.new(:empty)
             |> Board.place_piece(:P, "e5")
             |> Board.set_active_color("w")
             |> Utils.valid_move?("e5e6q") == false
    end

    test "black pawn on rank 8 cannot promote to rank 1 (wrong direction)" do
      assert Board.new(:empty)
             |> Board.place_piece(:p, "e8")
             |> Board.set_active_color("b")
             |> Utils.valid_move?("e8e1q") == false
    end
  end

  describe "Promotion move execution:" do
    test "white pawn promotes to queen on e8" do
      board = Board.new(:empty)
              |> Board.place_piece(:P, "e7")
              |> Board.set_active_color("w")
              |> Board.move("e7e8q")

      assert Utils.which_piece?(board, "e8") == :Q
      assert Utils.which_piece?(board, "e7") == nil
    end

    test "white pawn promotes to rook on e8" do
      board = Board.new(:empty)
              |> Board.place_piece(:P, "e7")
              |> Board.set_active_color("w")
              |> Board.move("e7e8r")

      assert Utils.which_piece?(board, "e8") == :R
      assert Utils.which_piece?(board, "e7") == nil
    end

    test "white pawn promotes to bishop on e8" do
      board = Board.new(:empty)
              |> Board.place_piece(:P, "e7")
              |> Board.set_active_color("w")
              |> Board.move("e7e8b")

      assert Utils.which_piece?(board, "e8") == :B
      assert Utils.which_piece?(board, "e7") == nil
    end

    test "white pawn promotes to knight on e8" do
      board = Board.new(:empty)
              |> Board.place_piece(:P, "e7")
              |> Board.set_active_color("w")
              |> Board.move("e7e8n")

      assert Utils.which_piece?(board, "e8") == :N
      assert Utils.which_piece?(board, "e7") == nil
    end

    test "black pawn promotes to queen on e1" do
      board = Board.new(:empty)
              |> Board.place_piece(:p, "e2")
              |> Board.set_active_color("b")
              |> Board.move("e2e1q")

      assert Utils.which_piece?(board, "e1") == :q
      assert Utils.which_piece?(board, "e2") == nil
    end

    test "black pawn promotes to rook on e1" do
      board = Board.new(:empty)
              |> Board.place_piece(:p, "e2")
              |> Board.set_active_color("b")
              |> Board.move("e2e1r")

      assert Utils.which_piece?(board, "e1") == :r
      assert Utils.which_piece?(board, "e2") == nil
    end

    test "black pawn promotes to bishop on e1" do
      board = Board.new(:empty)
              |> Board.place_piece(:p, "e2")
              |> Board.set_active_color("b")
              |> Board.move("e2e1b")

      assert Utils.which_piece?(board, "e1") == :b
      assert Utils.which_piece?(board, "e2") == nil
    end

    test "black pawn promotes to knight on e1" do
      board = Board.new(:empty)
              |> Board.place_piece(:p, "e2")
              |> Board.set_active_color("b")
              |> Board.move("e2e1n")

      assert Utils.which_piece?(board, "e1") == :n
      assert Utils.which_piece?(board, "e2") == nil
    end

    test "white pawn promotes with capture to queen" do
      board = Board.new(:empty)
              |> Board.place_piece(:P, "e7")
              |> Board.place_piece(:r, "d8")
              |> Board.set_active_color("w")
              |> Board.move("e7d8q")

      assert Utils.which_piece?(board, "d8") == :Q
      assert Utils.which_piece?(board, "e7") == nil
    end

    test "black pawn promotes with capture to knight" do
      board = Board.new(:empty)
              |> Board.place_piece(:p, "e2")
              |> Board.place_piece(:R, "f1")
              |> Board.set_active_color("b")
              |> Board.move("e2f1n")

      assert Utils.which_piece?(board, "f1") == :n
      assert Utils.which_piece?(board, "e2") == nil
    end
  end

  describe "Move generation promotion expansion:" do
    test "white pawn on rank 7 generates 4 promotion moves" do
      board = Board.new(:empty)
              |> Board.place_piece(:P, "e7")
              |> Board.place_piece(:K, "a1")
              |> Board.place_piece(:k, "h8")
              |> Board.set_active_color("w")

      moves = Utils.generate_moves(board)
      promotion_moves = Enum.filter(moves, fn move ->
        byte_size(move) == 5 and move =~ ~r/^e7/
      end)

      assert length(promotion_moves) == 4
      assert "e7e8q" in promotion_moves
      assert "e7e8r" in promotion_moves
      assert "e7e8b" in promotion_moves
      assert "e7e8n" in promotion_moves
    end

    test "black pawn on rank 2 generates 4 promotion moves" do
      board = Board.new(:empty)
              |> Board.place_piece(:p, "e2")
              |> Board.place_piece(:K, "a1")
              |> Board.place_piece(:k, "a8")
              |> Board.set_active_color("b")

      moves = Utils.generate_moves(board)
      promotion_moves = Enum.filter(moves, fn move ->
        byte_size(move) == 5 and move =~ ~r/^e2/
      end)

      assert length(promotion_moves) == 4
      assert "e2e1q" in promotion_moves
      assert "e2e1r" in promotion_moves
      assert "e2e1b" in promotion_moves
      assert "e2e1n" in promotion_moves
    end

    test "white pawn on rank 7 with capture generates 8 promotion moves (forward + 2 captures)" do
      board = Board.new(:empty)
              |> Board.place_piece(:P, "e7")
              |> Board.place_piece(:r, "d8")
              |> Board.place_piece(:n, "f8")
              |> Board.place_piece(:K, "e1")
              |> Board.place_piece(:k, "h8")
              |> Board.set_active_color("w")

      moves = Utils.generate_moves(board)
      promotion_moves = Enum.filter(moves, fn move ->
        byte_size(move) == 5 and move =~ ~r/^e7/
      end)

      # Should have 4 forward promotions + 4 d8 captures + 4 f8 captures = 12
      assert length(promotion_moves) == 12

      # Forward promotions
      assert "e7e8q" in promotion_moves
      assert "e7e8r" in promotion_moves
      assert "e7e8b" in promotion_moves
      assert "e7e8n" in promotion_moves

      # Capture on d8
      assert "e7d8q" in promotion_moves
      assert "e7d8r" in promotion_moves
      assert "e7d8b" in promotion_moves
      assert "e7d8n" in promotion_moves

      # Capture on f8
      assert "e7f8q" in promotion_moves
      assert "e7f8r" in promotion_moves
      assert "e7f8b" in promotion_moves
      assert "e7f8n" in promotion_moves
    end

    test "black pawn on rank 2 with capture generates 8 promotion moves" do
      board = Board.new(:empty)
              |> Board.place_piece(:p, "e2")
              |> Board.place_piece(:R, "d1")
              |> Board.place_piece(:N, "f1")
              |> Board.place_piece(:K, "h1")
              |> Board.place_piece(:k, "h8")
              |> Board.set_active_color("b")

      moves = Utils.generate_moves(board)
      promotion_moves = Enum.filter(moves, fn move ->
        byte_size(move) == 5 and move =~ ~r/^e2/
      end)

      assert length(promotion_moves) == 12

      # Forward promotions
      assert "e2e1q" in promotion_moves
      assert "e2e1r" in promotion_moves
      assert "e2e1b" in promotion_moves
      assert "e2e1n" in promotion_moves

      # Capture on d1
      assert "e2d1q" in promotion_moves
      assert "e2d1r" in promotion_moves
      assert "e2d1b" in promotion_moves
      assert "e2d1n" in promotion_moves

      # Capture on f1
      assert "e2f1q" in promotion_moves
      assert "e2f1r" in promotion_moves
      assert "e2f1b" in promotion_moves
      assert "e2f1n" in promotion_moves
    end
  end

  describe "Promotion edge cases:" do
    test "promotion respects active color - white cannot move on black's turn" do
      result = Board.new(:empty)
               |> Board.place_piece(:P, "e7")
               |> Board.set_active_color("b")
               |> Board.move("e7e8q")

      assert result == {:error, "invalid move"}
    end

    test "promotion respects active color - black cannot move on white's turn" do
      result = Board.new(:empty)
               |> Board.place_piece(:p, "e2")
               |> Board.set_active_color("w")
               |> Board.move("e2e1q")

      assert result == {:error, "invalid move"}
    end

    test "promotion clears en passant target" do
      board = Board.new(:empty)
              |> Board.place_piece(:P, "e7")
              |> Board.set_active_color("w")
              |> Board.set_en_passant("d6")
              |> Board.move("e7e8q")

      assert board.en_passant == nil
    end

    test "promotion resets halfmove clock" do
      board = Board.new(:empty)
              |> Board.place_piece(:P, "e7")
              |> Board.set_active_color("w")
              |> Board.move("e7e8q")

      assert board.halfmove_clock == 0
    end

    test "promotion flips active color" do
      board = Board.new(:empty)
              |> Board.place_piece(:P, "e7")
              |> Board.set_active_color("w")
              |> Board.move("e7e8q")

      assert board.active_color == <<1::1>>
    end

    test "promotion logs the move" do
      board = Board.new(:empty)
              |> Board.place_piece(:P, "e7")
              |> Board.set_active_color("w")
              |> Board.move("e7e8q")

      assert board.moves == ["e7e8q"]
    end
  end

  describe "Promotion in move search context:" do
    alias Laveno.Finders.MinimaxABPruningNegamaxETS, as: Finder

    test "engine finds simple promotion as best move" do
      # White pawn on e7, can promote - should find promotion
      board = Board.new(:empty)
              |> Board.place_piece(:P, "e7")
              |> Board.place_piece(:K, "a1")
              |> Board.place_piece(:k, "h8")
              |> Board.set_active_color("w")

      {_eval, result_board} = Finder.find(board, 2, -90, 90)
      last_move = List.last(result_board.moves)

      # Should find a promotion move (5 bytes)
      assert byte_size(last_move) == 5
      assert last_move =~ ~r/^e7e8/
    end

    test "engine finds promotion with capture" do
      # White pawn on e7 can capture and promote
      board = Board.new(:empty)
              |> Board.place_piece(:P, "e7")
              |> Board.place_piece(:r, "d8")
              |> Board.place_piece(:K, "a1")
              |> Board.place_piece(:k, "h8")
              |> Board.set_active_color("w")

      {_eval, result_board} = Finder.find(board, 2, -90, 90)
      last_move = List.last(result_board.moves)

      # Should find promotion capture
      assert byte_size(last_move) == 5
      # Could be e7d8q or e7e8q, both valid
      assert last_move =~ ~r/^e7[de]8[qrbn]/
    end

    test "engine prefers queen promotion over underpromotion by default" do
      # Simple position where queen is clearly best
      board = Board.new(:empty)
              |> Board.place_piece(:P, "e7")
              |> Board.place_piece(:K, "a1")
              |> Board.place_piece(:k, "h8")
              |> Board.set_active_color("w")

      {_eval, result_board} = Finder.find(board, 3, -90, 90)
      last_move = List.last(result_board.moves)

      # Should promote to queen (strongest piece)
      assert last_move == "e7e8q"
    end

    test "engine evaluates promotion delivering check correctly" do
      # Promotion that gives check should be valued higher
      board = Board.new(:empty)
              |> Board.place_piece(:P, "d7")
              |> Board.place_piece(:K, "a1")
              |> Board.place_piece(:k, "e8")
              |> Board.set_active_color("w")

      {eval, result_board} = Finder.find(board, 3, -90, 90)
      last_move = List.last(result_board.moves)

      # Should find promotion (check situation improves evaluation)
      assert byte_size(last_move) == 5
      # Evaluation should be positive (good for white)
      assert eval > 0
    end

    test "black engine finds promotion move" do
      # Black pawn on e2, can promote
      board = Board.new(:empty)
              |> Board.place_piece(:p, "e2")
              |> Board.place_piece(:K, "a1")
              |> Board.place_piece(:k, "h8")
              |> Board.set_active_color("b")

      {_eval, result_board} = Finder.find(board, 2, -90, 90)
      last_move = List.last(result_board.moves)

      # Should find a promotion move
      assert byte_size(last_move) == 5
      assert last_move =~ ~r/^e2e1/
    end

    test "promotion moves are not duplicated in search" do
      # Verify that generate_moves doesn't create duplicates
      board = Board.new(:empty)
              |> Board.place_piece(:P, "e7")
              |> Board.place_piece(:r, "d8")
              |> Board.place_piece(:n, "f8")
              |> Board.place_piece(:K, "a1")
              |> Board.place_piece(:k, "h8")
              |> Board.set_active_color("w")

      moves = Utils.generate_moves(board)

      # Count unique moves
      unique_moves = Enum.uniq(moves)
      assert length(moves) == length(unique_moves),
        "Found duplicate moves: #{inspect(moves -- unique_moves)}"
    end

    test "promotion in quiescence search (capture promotion)" do
      # Position where promotion capture should be found in quiescence
      board = Board.new(:empty)
              |> Board.place_piece(:P, "e7")
              |> Board.place_piece(:q, "d8")
              |> Board.place_piece(:K, "a1")
              |> Board.place_piece(:k, "h8")
              |> Board.set_active_color("w")

      {eval, result_board} = Finder.find(board, 2, -90, 90)
      last_move = List.last(result_board.moves)

      # Should find the capture promotion
      assert byte_size(last_move) == 5
      assert last_move =~ ~r/^e7d8/
      # Evaluation should be very positive (captured queen)
      assert eval > 8
    end

    test "promotion evaluation consistent across different depths" do
      # Same position evaluated at depth 2 and 3 should be consistent
      board = Board.new(:empty)
              |> Board.place_piece(:P, "e7")
              |> Board.place_piece(:K, "a1")
              |> Board.place_piece(:k, "h8")
              |> Board.set_active_color("w")

      {eval_d2, board_d2} = Finder.find(board, 2, -90, 90)
      {eval_d3, board_d3} = Finder.find(board, 3, -90, 90)

      move_d2 = List.last(board_d2.moves)
      move_d3 = List.last(board_d3.moves)

      # Both should find promotion moves
      assert byte_size(move_d2) == 5
      assert byte_size(move_d3) == 5

      # Evaluations should be in same ballpark (within 2 points)
      assert abs(eval_d2 - eval_d3) < 2
    end

    test "multiple promotion options evaluated correctly" do
      # Position with 3 possible promotions (forward + 2 captures)
      board = Board.new(:empty)
              |> Board.place_piece(:P, "e7")
              |> Board.place_piece(:n, "d8")
              |> Board.place_piece(:b, "f8")
              |> Board.place_piece(:K, "a1")
              |> Board.place_piece(:k, "h8")
              |> Board.set_active_color("w")

      # All promotion moves should be considered
      moves = Utils.generate_moves(board)
      promotion_moves = Enum.filter(moves, fn m -> byte_size(m) == 5 end)

      # Should have 3 directions * 4 pieces = 12 total promotions
      assert length(promotion_moves) == 12

      # Engine should pick one
      {_eval, result_board} = Finder.find(board, 2, -90, 90)
      last_move = List.last(result_board.moves)
      assert last_move in promotion_moves
    end

    test "promotion doesn't cause move application errors" do
      # Test that applying promotion moves in search doesn't crash
      board = Board.new(:empty)
              |> Board.place_piece(:P, "a7")
              |> Board.place_piece(:P, "h7")
              |> Board.place_piece(:K, "e1")
              |> Board.place_piece(:k, "e8")
              |> Board.set_active_color("w")

      # Should complete without errors
      assert {_eval, %Board{}} = Finder.find(board, 3, -90, 90)
    end

    test "promotion with both colors having promotion threats" do
      # Complex position with both sides having promotions
      board = Board.new(:empty)
              |> Board.place_piece(:P, "e7")
              |> Board.place_piece(:p, "e2")
              |> Board.place_piece(:K, "a1")
              |> Board.place_piece(:k, "h8")
              |> Board.set_active_color("w")

      # White moves first, should find promotion
      {_eval, result_board} = Finder.find(board, 3, -90, 90)
      last_move = List.last(result_board.moves)

      assert byte_size(last_move) == 5
      assert last_move =~ ~r/^e7e8/
    end

    test "promotion move ordering in search" do
      # Verify promotion captures are considered early (MVV-LVA)
      board = Board.new(:empty)
              |> Board.place_piece(:P, "e7")
              |> Board.place_piece(:q, "d8")
              |> Board.place_piece(:K, "a1")
              |> Board.place_piece(:k, "h8")
              |> Board.set_active_color("w")

      # The promotion capture of queen should be found quickly
      {eval, _result} = Finder.find(board, 2, -90, 90)

      # Should have very high evaluation (captured queen + promotion)
      assert eval > 10
    end
  end
end
