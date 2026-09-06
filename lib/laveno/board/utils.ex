defmodule Laveno.Board.Utils do
  import Bitwise
  require Logger

  alias Laveno.Board
  alias Laveno.Board.Attacks
  alias Laveno.Board.Maps

  @typedoc """
  This is the main data structure for piece position
  and square propery representation.

  It is a binary (a bitstring which length is divisible by 8).
  Each of the 64 bits represent any squarewise property,
  like the presence of a piece, or the squares considered -central squares-

  For example, the following bitboatd represents the position of both withe bishops (♗)
  <<36, 0, 0, 0, 0, 0, 0, 0>>.
  Each of the 8 numbers are for each row, first row "a" has a value of 36
  which is given by the bits 00100100 ~ 36
  """
  @type board :: Board.t()
  @type bitboard() :: non_neg_integer() | <<_::64>>

  @typedoc """
  Unsigned integer representation of a bitboard

  2594073385365405696
  """
  @type bitboard_int() :: non_neg_integer()

  @typedoc """
  Square name.

  e.g. "b4", "g7" ...
  """
  @type square_algebraic_notation() :: <<_::16>>

  @typedoc """
  A square represented by its single square position in a bitboard

  "a1" -> 0, "e1" -> 4, "e2" -> 8, "h8" -> 64
  """
  @type square_offset_integer() :: integer()

  @type piece_atom() :: :P | :p | :N | :n | :B | :b | :K | :k | :Q | :q | :R | :r
  @type piece_name_atom() :: :pawn | :knight | :queen | :bishop | :rook | :king

  @typedoc """
  Move in extended algebraic notation
  (explicit origin and target squares), e.g. "f2f4"
  """
  @type move() :: <<_::32>>

  @offset_row 49
  @offset_column 97
  @pieces_set [:P, :p, :N, :n, :B, :b, :K, :k, :Q, :q, :R, :r]
  @w_pieces [:P, :R, :N, :B, :K, :Q]
  @b_pieces [:p, :r, :n, :b, :k, :q]

  def initial_position_binary() do
    %{
      P: Attacks.as_int(<<0::8, 255::8, 0::48>>),
      p: Attacks.as_int(<<0::48, 255::8, 0::8>>),
      N: Attacks.as_int(<<0::1, 1::1, 0::4, 1::1, 0::57>>),
      n: Attacks.as_int(<<0::57, 1::1, 0::4, 1::1, 0::1>>),
      B: Attacks.as_int(<<0::2, 1::1, 0::2, 1::1, 0::58>>),
      b: Attacks.as_int(<<0::58, 1::1, 0::2, 1::1, 0::2>>),
      Q: Attacks.as_int(<<0::3, 1::1, 0::60>>),
      q: Attacks.as_int(<<0::59, 1::1, 0::4>>),
      K: Attacks.as_int(<<0::4, 1::1, 0::59>>),
      k: Attacks.as_int(<<0::60, 1::1, 0::3>>),
      R: Attacks.as_int(<<1::1, 0::6, 1::1, 0::56>>),
      r: Attacks.as_int(<<0::56, 1::1, 0::6, 1::1>>)
    }
  end

  def empty_position_binary() do
    %{
      P: 0,
      p: 0,
      N: 0,
      n: 0,
      B: 0,
      b: 0,
      Q: 0,
      q: 0,
      K: 0,
      k: 0,
      R: 0,
      r: 0
    }
  end

  def place_piece(%{bb: bitboard}, piece, <<c::size(8), r::size(8)>>) do
    {_row, _column, offset} = rco(r, c)
    Map.update(bitboard, piece, 0, fn bb -> Attacks.as_int(bb) ||| 1 <<< offset end)
  end

  def remove_piece(%{bb: bitboard}, piece, <<c::size(8), r::size(8)>>) do
    {_row, _column, offset} = rco(r, c)
    Map.update(bitboard, piece, 0, fn bb -> Attacks.as_int(bb) &&& ~~~(1 <<< offset) end)
  end

  def clear_square(board = %{bb: bitboard}, square = <<_c::size(8), _r::size(8)>>) do
    case which_piece?(board, square) do
      nil -> bitboard
      piece -> remove_piece(board, piece, square)
    end
  end

  @spec moves(piece_atom(), square_offset_integer()) :: bitboard_int()
  @spec moves(piece_name_atom(), square_offset_integer()) :: bitboard_int()

  @doc """
  A bitboard mask for possible piece moves
  """
  def moves(:N, square_offset), do: moves(:knight, square_offset)
  def moves(:n, square_offset), do: moves(:knight, square_offset)

  def moves(:K, square_offset), do: moves(:king, square_offset)
  def moves(:k, square_offset), do: moves(:king, square_offset)

  def moves(:R, square_offset), do: moves(:rook, square_offset)
  def moves(:r, square_offset), do: moves(:rook, square_offset)

  def moves(:B, square_offset), do: moves(:bishop, square_offset)
  def moves(:b, square_offset), do: moves(:bishop, square_offset)

  def moves(:Q, square_offset), do: moves(:queen, square_offset)
  def moves(:q, square_offset), do: moves(:queen, square_offset)

  def moves(:P, square_offset) do
    [
      <<1 <<< (square_offset - 8)::64>>,
      <<1 <<< (square_offset - 16)::64>>,
      <<1 <<< (square_offset - 8 + 1)::64>>,
      <<1 <<< (square_offset - 8 - 1)::64>>
    ]
    |> aggregate_bitboards()
  end

  def moves(:p, square_offset) do
    [
      <<1 <<< (square_offset + 8)::64>>,
      <<1 <<< (square_offset + 16)::64>>,
      <<1 <<< (square_offset + 8 + 1)::64>>,
      <<1 <<< (square_offset + 8 - 1)::64>>
    ]
    |> aggregate_bitboards()
  end

  def moves(:knight, square_offset) do
    [
      <<1 <<< (square_offset + 8 + 2)::64>>,
      <<1 <<< (square_offset + 8 - 2)::64>>,
      <<1 <<< (square_offset - 8 + 2)::64>>,
      <<1 <<< (square_offset - 8 - 2)::64>>,
      <<1 <<< (square_offset + 16 + 1)::64>>,
      <<1 <<< (square_offset + 16 - 1)::64>>,
      <<1 <<< (square_offset - 16 + 1)::64>>,
      <<1 <<< (square_offset - 16 - 1)::64>>
    ]
    |> aggregate_bitboards()
  end

  def moves(:king, square_offset) do
    [
      <<1 <<< (square_offset + 1)::64>>,
      <<1 <<< (square_offset - 1)::64>>,
      <<1 <<< (square_offset - 8 + 1)::64>>,
      <<1 <<< (square_offset - 8)::64>>,
      <<1 <<< (square_offset - 8 - 1)::64>>,
      <<1 <<< (square_offset + 8 + 1)::64>>,
      <<1 <<< (square_offset + 8)::64>>,
      <<1 <<< (square_offset + 8 - 1)::64>>
    ]
    |> aggregate_bitboards()
  end

  def moves(:rook, square_offset) do
    (Enum.map(1..7, &<<1 <<< (square_offset + &1 * 8)::64>>) ++
       Enum.map(1..7, &<<1 <<< (square_offset - &1 * 8)::64>>) ++
       [full_row(div(square_offset, 8))])
    |> aggregate_bitboards()
  end

  def moves(:bishop, square_offset) do
    (Enum.map(1..7, &<<1 <<< (square_offset + &1 + &1 * 8)::64>>) ++
       Enum.map(1..7, &<<1 <<< (square_offset - &1 + &1 * 8)::64>>) ++
       Enum.map(1..7, &<<1 <<< (square_offset + &1 - &1 * 8)::64>>) ++
       Enum.map(1..7, &<<1 <<< (square_offset - &1 - &1 * 8)::64>>))
    |> aggregate_bitboards()
  end

  def moves(:queen, square_offset) do
    moves(:rook, square_offset) ||| moves(:bishop, square_offset)
  end

  defp full_row(0), do: <<0::56, 255::8>>
  defp full_row(1), do: <<0::48, 255::8, 0::8>>
  defp full_row(2), do: <<0::40, 255::8, 0::16>>
  defp full_row(3), do: <<0::32, 255::8, 0::24>>
  defp full_row(4), do: <<0::24, 255::8, 0::32>>
  defp full_row(5), do: <<0::16, 255::8, 0::40>>
  defp full_row(6), do: <<0::8, 255::8, 0::48>>
  defp full_row(7), do: <<255::8, 0::56>>

  @spec which_piece?(map(), square_algebraic_notation()) :: piece_atom()
  @spec which_piece?(map(), square_offset_integer()) :: piece_atom()
  @doc """
  Determine which piece is on a given square
  ## Parameters

  - board: %Laveno.Board{}
  - square: String representing a square name in algebraic notation

  ## Examples

      iex> Laveno.Board.new() |> Laveno.Board.Utils.which_piece?("d8")
      :q

  """
  def which_piece?(
        board,
        <<column::size(8), row::size(8)>>
      ) do
    {_r, _c, offset} = rco(row, column)
    which_piece?(board, offset)
  end

  def which_piece?(
        %{bb: bb},
        offset_to_square
      ) do
    mask = 1 <<< offset_to_square

    Enum.find(@pieces_set, fn piece ->
      (Attacks.as_int(bb[piece]) &&& mask) != 0
    end)
  end

  def inbound?(
        bishop,
        <<c1::size(8), r1::size(8), c2::size(8), r2::size(8)>>
      )
      when bishop in [:bishop, :B, :b] do
    c1 != c2 and r1 != r2 and abs(c1 - c2) == abs(r1 - r2)
  end

  def inbound?(
        king,
        <<c1::size(8), r1::size(8), c2::size(8), r2::size(8)>>
      )
      when king in [:king, :K, :k] do
    abs(c1 - c2) < 2 and abs(r1 - r2) < 2
  end

  def inbound?(
        knight,
        <<c1::size(8), r1::size(8), c2::size(8), r2::size(8)>>
      )
      when knight in [:knight, :N, :n] do
    abs(c1 - c2) < 3 and abs(r1 - r2) < 3
  end

  def inbound?(
        _,
        <<_c1::size(8), _r1::size(8), _c2::size(8), _r2::size(8)>>
      ) do
    true
  end

  def indiagonalpawn?(
        board = %{en_passant: en_passant},
        pawn,
        <<c1::size(8), _r1::size(8), c2::size(8), r2::size(8)>>
      )
      when pawn in [:pawn, :P, :p] do
    case c2 - 1 == c1 || c2 + 1 == c1 do
      true ->
        <<c2::8, r2::8>> == en_passant || diagonal_color_take?(pawn, which_piece?(board, <<c2::8, r2::8>>))

      false ->
        true
    end
  end

  def indiagonalpawn?(
        _,
        _,
        _
      ) do
    true
  end

  def infirst?(
        pawn,
        <<_c1::size(8), r1::size(8), _c2::size(8), r2::size(8)>>
      )
      when pawn in [:pawn, :P, :p] do
    case abs(r2 - r1) > 1 do
      true -> <<r1::8>> in ["2", "7"]
      _ -> true
    end
  end

  def infirst?(_, _), do: true

  def incolor?(piece_from, piece_to) do
    color(piece_from) != color(piece_to)
  end

  def diagonal_color_take?(piece_from, piece_to) do
    with color_from <- color(piece_from),
         color_to <- color(piece_to) do
      case {color_from, color_to} do
        {:w, :b} -> true
        {:b, :w} -> true
        {_, _} -> false
      end
    end
  end

  def color(piece) when piece in @w_pieces, do: :w
  def color(piece) when piece in @b_pieces, do: :b
  def color(_), do: "-"

  @doc """
  Validate a move using file/rank geometry and path clearance
  """
  def valid_move?(board = %{castles: <<1::1, _::3>>}, <<"e1g1">>) do
    if which_piece?(board, "e1") != :K or which_piece?(board, "h1") != :R do
      false
    else
      occ = occupancy_mask(board)
      empty = square_mask("f1") ||| square_mask("g1")

      (occ &&& empty) == 0 and
        not square_attacked_by?(board, "e1", :black) and
        not square_attacked_by?(board, "f1", :black) and
        not square_attacked_by?(board, "g1", :black)
    end
  end

  def valid_move?(board = %{castles: <<_::1, 1::1, _::2>>}, <<"e1c1">>) do
    if which_piece?(board, "e1") != :K or which_piece?(board, "a1") != :R do
      false
    else
      occ = occupancy_mask(board)
      empty = square_mask("d1") ||| square_mask("c1") ||| square_mask("b1")

      (occ &&& empty) == 0 and
        not square_attacked_by?(board, "e1", :black) and
        not square_attacked_by?(board, "d1", :black) and
        not square_attacked_by?(board, "c1", :black)
    end
  end

  def valid_move?(board = %{castles: <<_::2, 1::1, _::1>>}, <<"e8g8">>) do
    if which_piece?(board, "e8") != :k or which_piece?(board, "h8") != :r do
      false
    else
      occ = occupancy_mask(board)
      empty = square_mask("f8") ||| square_mask("g8")

      (occ &&& empty) == 0 and
        not square_attacked_by?(board, "e8", :white) and
        not square_attacked_by?(board, "f8", :white) and
        not square_attacked_by?(board, "g8", :white)
    end
  end

  def valid_move?(board = %{castles: <<_::3, 1::1>>}, <<"e8c8">>) do
    if which_piece?(board, "e8") != :k or which_piece?(board, "a8") != :r do
      false
    else
      occ = occupancy_mask(board)
      empty = square_mask("d8") ||| square_mask("c8") ||| square_mask("b8")

      (occ &&& empty) == 0 and
        not square_attacked_by?(board, "e8", :white) and
        not square_attacked_by?(board, "d8", :white) and
        not square_attacked_by?(board, "c8", :white)
    end
  end

  def valid_move?(board, <<c1::8, r1::8, c2::8, r2::8, promo::8>>) do
    file_from = c1 - @offset_column
    rank_from = r1 - @offset_row
    file_to   = c2 - @offset_column
    rank_to   = r2 - @offset_row
    from = <<c1, r1>>
    to   = <<c2, r2>>
    piece = which_piece?(board, from)
    target = which_piece?(board, to)
    # Determine direction and promotion rank based on piece color
    dir = if color(piece) == :w, do: 1, else: -1
    promotion_rank = if color(piece) == :w, do: 7, else: 0
    # Promotion piece identifier must be one of q, r, b, n
    valid_promo_piece? = promo in [?q, ?r, ?b, ?n]

    if (piece in [:P, :p]) and rank_to == promotion_rank and valid_promo_piece? do
      df = file_to - file_from
      dr = rank_to - rank_from
      cond do
        # Normal forward promotion
        df == 0 and dr == dir and target == nil ->
          true
        # Capture promotion
        abs(df) == 1 and dr == dir and target != nil and color(target) != color(piece) ->
          true
        true ->
          false
      end
    else
      false
    end
  end

  def valid_move?(board, <<c1::8, r1::8, c2::8, r2::8>>) do
    file_from = c1 - @offset_column
    rank_from = r1 - @offset_row
    file_to   = c2 - @offset_column
    rank_to   = r2 - @offset_row

    if file_from == file_to and rank_from == rank_to do
      false
    else
      piece = which_piece?(board, <<c1, r1>>)
      to_square = <<c2, r2>>
      target = which_piece?(board, to_square)

      cond do
        piece == nil ->
          false

        color(piece) == color(target) ->
          false

        true ->
          do_valid_move?(board, piece, file_from, rank_from, file_to, rank_to, to_square)
      end
    end
  end

  defp do_valid_move?(board, piece, file_from, rank_from, file_to, rank_to, to_square) do
    df = file_to - file_from
    dr = rank_to - rank_from
    df_abs = abs(df)
    dr_abs = abs(dr)

    cond do
      piece == :P or piece == :p ->
        valid_pawn_move?(board, piece, file_from, rank_from, file_to, rank_to, to_square)

      piece in [:N, :n] ->
        (df_abs == 1 and dr_abs == 2) or (df_abs == 2 and dr_abs == 1)

      piece in [:K, :k] ->
        df_abs <= 1 and dr_abs <= 1

      piece in [:B, :b] ->
        df_abs == dr_abs and df_abs > 0 and path_clear_line?(board, file_from, rank_from, file_to, rank_to)

      piece in [:R, :r] ->
        ((df == 0 and dr_abs > 0) or (dr == 0 and df_abs > 0)) and path_clear_line?(board, file_from, rank_from, file_to, rank_to)

      piece in [:Q, :q] ->
        cond do
          df_abs == dr_abs and df_abs > 0 ->
            path_clear_line?(board, file_from, rank_from, file_to, rank_to)

          (df == 0 and dr_abs > 0) or (dr == 0 and df_abs > 0) ->
            path_clear_line?(board, file_from, rank_from, file_to, rank_to)

          true ->
            false
        end

      true ->
        false
    end
  end

  defp valid_pawn_move?(board, piece, file_from, rank_from, file_to, rank_to, to_square) do
    dir = if piece in @w_pieces, do: 1, else: -1
    df = file_to - file_from
    dr = rank_to - rank_from

    cond do
      df == 0 and dr == dir and which_piece?(board, to_square) == nil ->
        true

      df == 0 and dr == 2 * dir and rank_from == (if dir == 1, do: 1, else: 6) and
        which_piece?(board, <<(@offset_column + file_from)::8, (@offset_row + rank_from + dir)::8>>) == nil and
        which_piece?(board, to_square) == nil ->
        true

      abs(df) == 1 and dr == dir and
        ((target = which_piece?(board, to_square)) != nil and color(target) != color(piece)) or
          board.en_passant == to_square ->
        true

      true ->
        false
    end
  end

  defp path_clear_line?(board, file_from, rank_from, file_to, rank_to) do
    df = file_to - file_from
    dr = rank_to - rank_from

    step_file =
      cond do
        df > 0 -> 1
        df < 0 -> -1
        true -> 0
      end

    step_rank =
      cond do
        dr > 0 -> 1
        dr < 0 -> -1
        true -> 0
      end

    occ = occupancy_mask(board)
    max_delta = max(abs(df), abs(dr))

    Enum.all?(1..(max_delta - 1)//1, fn i ->
      file = file_from + step_file * i
      rank = rank_from + step_rank * i
      offset = 64 - 8 * rank - file - 1
      (occ &&& 1 <<< offset) == 0
    end)
  end

  def rco(row, column) do
    c = column - @offset_column
    r = row - @offset_row
    offset = 64 - 8 * r - c - 1

    {r, c, offset}
  end

  def aggregate_bitboards(bitboards_list) do
    Enum.reduce(
      bitboards_list,
      <<0::64>> |> :binary.decode_unsigned(),
      fn bitboard, mask ->
        mask ||| bitboard |> :binary.decode_unsigned()
      end
    )
  end

  def where_is(%{bb: bb}, piece), do: Attacks.bits(bb[piece])

  @doc """
  Pseudo-legal moves: destination masks plus validated castling. Search
  rejects moves that leave the mover in check after make.
  """
  def generate_pseudo(board = %{active_color: <<0::1>>}) do
    moves_for_pieces(board, @w_pieces) ++ castle_moves(board)
  end

  def generate_pseudo(board = %{active_color: <<1::1>>}) do
    moves_for_pieces(board, @b_pieces) ++ castle_moves(board)
  end

  def generate_moves(board) do
    select_legal(board, generate_pseudo(board))
  end

  @doc """
  Reference legality: make every pseudo-legal dest and test the king.
  Used by tests to check the pin-aware filter.
  """
  def generate_moves_by_make(board) do
    Enum.filter(generate_pseudo(board), &king_safe_after?(board, &1))
  end

  @doc """
  Captures, en passant, and promotions. Used by quiescence so it does not
  expand every quiet move.
  """
  def generate_pseudo_noisy(board = %{active_color: <<0::1>>}) do
    noisy_for_pieces(board, @w_pieces)
  end

  def generate_pseudo_noisy(board = %{active_color: <<1::1>>}) do
    noisy_for_pieces(board, @b_pieces)
  end

  def generate_noisy(board) do
    select_legal(board, generate_pseudo_noisy(board))
  end

  defp select_legal(board, moves) do
    {king, by, own} =
      case board.active_color do
        <<0::1>> -> {:K, :black, :white}
        <<1::1>> -> {:k, :white, :black}
      end

    case Attacks.bits(board.bb[king]) do
      [] ->
        []

      [king_sq | _] ->
        occ = occupancy_mask(board)
        checkers = Attacks.checkers(board.bb, occ, king_sq, by)
        pinned = Attacks.pinned(board.bb, occ, king_sq, own)
        filter_legal(board, moves, king_sq, checkers, pinned)
    end
  end

  defp filter_legal(board, moves, king_sq, checkers, pinned) do
    case Attacks.popcount(checkers) do
      n when n >= 2 ->
        Enum.filter(moves, fn mv ->
          king_move?(mv, king_sq) and king_safe_after?(board, mv)
        end)

      1 ->
        [checker] = Attacks.bits(checkers)
        blocks = Attacks.between(king_sq, checker)

        Enum.filter(moves, fn mv ->
          {from, to} = move_squares(mv)

          cond do
            from == king_sq ->
              king_safe_after?(board, mv)

            (blocks &&& 1 <<< to) == 0 and to != checker ->
              false

            (pinned &&& 1 <<< from) != 0 or ep_move?(board, mv) ->
              king_safe_after?(board, mv)

            true ->
              true
          end
        end)

      _ ->
        Enum.filter(moves, fn mv ->
          {from, _to} = move_squares(mv)

          cond do
            from == king_sq ->
              king_safe_after?(board, mv)

            (pinned &&& 1 <<< from) != 0 or ep_move?(board, mv) ->
              king_safe_after?(board, mv)

            true ->
              true
          end
        end)
    end
  end

  defp move_squares(<<c1::8, r1::8, c2::8, r2::8, _::binary>>) do
    {_r, _c, from} = rco(r1, c1)
    {_r2, _c2, to} = rco(r2, c2)
    {from, to}
  end

  defp king_move?(mv, king_sq) do
    {from, _} = move_squares(mv)
    from == king_sq
  end

  defp ep_move?(%{en_passant: ep} = board, <<c1::8, r1::8, c2::8, r2::8, _::binary>>)
       when is_binary(ep) do
    ep == <<c2, r2>> and pawn_on?(board, r1, c1)
  end

  defp ep_move?(_, _), do: false

  defp pawn_on?(board, row, column) do
    {_r, _c, offset} = rco(row, column)
    mask = 1 <<< offset
    (Attacks.as_int(board.bb[:P]) &&& mask) != 0 or (Attacks.as_int(board.bb[:p]) &&& mask) != 0
  end

  # King move masks are one square; castling must be injected separately
  # so the engine can play O-O / O-O-O in tournament games.
  defp castle_moves(%{active_color: <<0::1>>} = board) do
    Enum.filter(["e1g1", "e1c1"], &valid_move?(board, &1))
  end

  defp castle_moves(%{active_color: <<1::1>>} = board) do
    Enum.filter(["e8g8", "e8c8"], &valid_move?(board, &1))
  end

  def union_mask(%{bb: bb}, pieces) do
    Enum.reduce(pieces, 0, fn piece, union_bb ->
      union_bb ||| Attacks.as_int(bb[piece])
    end)
  end

  def diagonal_path_mask(_board, <<c1::size(8), r1::size(8), c2::size(8), r2::size(8)>>) do
    with true <- abs(c1 - c2) == abs(r1 - r2) do
      cond do
        # ↖
        c1 > c2 and r1 < r2 ->
          Enum.reduce(1..(c1 - c2)//1, [], fn delta, bits ->
            {_row, _column, offset} = rco(r1 + delta, c1 - delta)
            [<<1 <<< offset::64>> | bits]
          end)
          |> aggregate_bitboards()

        # ↘
        c1 < c2 and r1 > r2 ->
          Enum.reduce(1..(c1 - c2)//1, [], fn delta, bits ->
            {_row, _column, offset} = rco(r1 - delta, c1 + delta)
            [<<1 <<< offset::64>> | bits]
          end)
          |> aggregate_bitboards()

        # ↗
        c1 < c2 and r1 < r2 ->
          Enum.reduce(1..(c1 - c2)//1, [], fn delta, bits ->
            {_row, _column, offset} = rco(r1 + delta, c1 + delta)
            [<<1 <<< offset::64>> | bits]
          end)
          |> aggregate_bitboards()

        # ↙
        c1 > c2 and r1 > r2 ->
          Enum.reduce(1..(c1 - c2)//1, [], fn delta, bits ->
            {_row, _column, offset} = rco(r1 - delta, c1 - delta)
            [<<1 <<< offset::64>> | bits]
          end)
          |> aggregate_bitboards()

        true ->
          0
      end
    else
      _ -> 0
    end
  end

  def linear_path_mask(_board, <<c1::size(8), r1::size(8), c2::size(8), r2::size(8)>>) do
    with true <- r1 == r2 or c1 == c2 do
      cond do
        # ↑
        r1 < r2 ->
          Enum.reduce(1..(r2 - r1)//1, [], fn delta, bits ->
            {_row, _column, offset} = rco(r1 + delta, c1)
            [<<1 <<< offset::64>> | bits]
          end)
          |> aggregate_bitboards()

        # ↓
        r1 > r2 ->
          Enum.reduce(1..(r1 - r2)//1, [], fn delta, bits ->
            {_row, _column, offset} = rco(r1 - delta, c1)
            [<<1 <<< offset::64>> | bits]
          end)
          |> aggregate_bitboards()

        # ←
        c1 > c2 ->
          Enum.reduce(1..(c1 - c2)//1, [], fn delta, bits ->
            {_row, _column, offset} = rco(r1, c1 - delta)
            [<<1 <<< offset::64>> | bits]
          end)
          |> aggregate_bitboards()

        # →
        c1 < c2 ->
          Enum.reduce(1..(c2 - c1)//1, [], fn delta, bits ->
            {_row, _column, offset} = rco(r1, c1 + delta)
            [<<1 <<< offset::64>> | bits]
          end)
          |> aggregate_bitboards()

        true ->
          0
      end
    else
      _ -> 0
    end
  end

  def moves_for_pieces(board, pieces) do
    occ = occupancy_mask(board)
    own = union_mask(board, pieces)
    enemy = capturable(board, own)
    ep_bit = ep_bit(board.en_passant)

    Enum.flat_map(pieces, fn piece ->
      Enum.flat_map(Attacks.bits(board.bb[piece]), fn from ->
        dests = piece_dests(piece, from, occ, own, enemy, ep_bit)
        encode_dests(piece, from, dests)
      end)
    end)
  end

  defp capturable(board, own) do
    kings = Attacks.as_int(board.bb[:K]) ||| Attacks.as_int(board.bb[:k])
    occupancy_mask(board) &&& ~~~own &&& ~~~kings
  end

  defp noisy_for_pieces(board, pieces) do
    occ = occupancy_mask(board)
    own = union_mask(board, pieces)
    enemy = capturable(board, own)
    ep_bit = ep_bit(board.en_passant)

    Enum.flat_map(pieces, fn piece ->
      Enum.flat_map(Attacks.bits(board.bb[piece]), fn from ->
        dests = noisy_dests(piece, from, occ, own, enemy, ep_bit)
        encode_dests(piece, from, dests)
      end)
    end)
  end

  defp noisy_dests(:P, from, occ, _own, enemy, ep) do
    caps = Attacks.pawn_attacks_white(from) &&& (enemy ||| ep)

    promo_push =
      if from >= 8 and from <= 15 do
        single = 1 <<< (from - 8)
        if (occ &&& single) == 0, do: single, else: 0
      else
        0
      end

    caps ||| promo_push
  end

  defp noisy_dests(:p, from, occ, _own, enemy, ep) do
    caps = Attacks.pawn_attacks_black(from) &&& (enemy ||| ep)

    promo_push =
      if from >= 48 and from <= 55 do
        single = 1 <<< (from + 8)
        if (occ &&& single) == 0, do: single, else: 0
      else
        0
      end

    caps ||| promo_push
  end

  defp noisy_dests(piece, from, occ, own, enemy, ep) do
    piece_dests(piece, from, occ, own, enemy, ep) &&& enemy
  end

  defp ep_bit(<<c::8, r::8>>), do: square_mask(<<c, r>>)
  defp ep_bit(_), do: 0

  defp piece_dests(:N, from, _occ, own, _enemy, _ep), do: Attacks.knight_attacks(from) &&& ~~~own
  defp piece_dests(:n, from, _occ, own, _enemy, _ep), do: Attacks.knight_attacks(from) &&& ~~~own
  defp piece_dests(:K, from, _occ, own, _enemy, _ep), do: Attacks.king_attacks(from) &&& ~~~own
  defp piece_dests(:k, from, _occ, own, _enemy, _ep), do: Attacks.king_attacks(from) &&& ~~~own
  defp piece_dests(:B, from, occ, own, _enemy, _ep), do: Attacks.bishop_attacks(from, occ) &&& ~~~own
  defp piece_dests(:b, from, occ, own, _enemy, _ep), do: Attacks.bishop_attacks(from, occ) &&& ~~~own
  defp piece_dests(:R, from, occ, own, _enemy, _ep), do: Attacks.rook_attacks(from, occ) &&& ~~~own
  defp piece_dests(:r, from, occ, own, _enemy, _ep), do: Attacks.rook_attacks(from, occ) &&& ~~~own
  defp piece_dests(:Q, from, occ, own, _enemy, _ep), do: Attacks.queen_attacks(from, occ) &&& ~~~own
  defp piece_dests(:q, from, occ, own, _enemy, _ep), do: Attacks.queen_attacks(from, occ) &&& ~~~own
  defp piece_dests(:P, from, occ, _own, enemy, ep), do: white_pawn_dests(from, occ, enemy, ep)
  defp piece_dests(:p, from, occ, _own, enemy, ep), do: black_pawn_dests(from, occ, enemy, ep)
  defp piece_dests(_, _, _, _, _, _), do: 0

  defp white_pawn_dests(from, occ, enemy, ep) do
    push =
      if from >= 8 do
        single = 1 <<< (from - 8)

        if (occ &&& single) == 0 do
          double =
            if from >= 48 and from <= 55 and (occ &&& 1 <<< (from - 16)) == 0 do
              1 <<< (from - 16)
            else
              0
            end

          single ||| double
        else
          0
        end
      else
        0
      end

    push ||| (Attacks.pawn_attacks_white(from) &&& (enemy ||| ep))
  end

  defp black_pawn_dests(from, occ, enemy, ep) do
    push =
      if from <= 55 do
        single = 1 <<< (from + 8)

        if (occ &&& single) == 0 do
          double =
            if from >= 8 and from <= 15 and (occ &&& 1 <<< (from + 16)) == 0 do
              1 <<< (from + 16)
            else
              0
            end

          single ||| double
        else
          0
        end
      else
        0
      end

    push ||| (Attacks.pawn_attacks_black(from) &&& (enemy ||| ep))
  end

  defp encode_dests(piece, from, dests) do
    Enum.flat_map(Attacks.bits(dests), fn to ->
      move = Maps.offset_to_square(from) <> Maps.offset_to_square(to)

      cond do
        piece == :P and to <= 7 ->
          for promo <- [?q, ?r, ?b, ?n], do: move <> <<promo>>

        piece == :p and to >= 56 ->
          for promo <- [?q, ?r, ?b, ?n], do: move <> <<promo>>

        true ->
          [move]
      end
    end)
  end

  def pretty_squares(board, squares) do
    Enum.map(squares, fn move = <<c::8, r::8, _::16>> ->
      (which_piece?(board, <<c::8, r::8>>)
       |> piece_atom_to_unicode()) <> move
    end)
  end

  @spec piece_atom_to_unicode(atom()) :: binary()
  def piece_atom_to_unicode(:P), do: "♙"
  def piece_atom_to_unicode(:p), do: "♟"
  def piece_atom_to_unicode(:K), do: "♔"
  def piece_atom_to_unicode(:k), do: "♚"
  def piece_atom_to_unicode(:Q), do: "♕"
  def piece_atom_to_unicode(:q), do: "♛"
  def piece_atom_to_unicode(:N), do: "♘"
  def piece_atom_to_unicode(:n), do: "♞"
  def piece_atom_to_unicode(:B), do: "♗"
  def piece_atom_to_unicode(:b), do: "♝"
  def piece_atom_to_unicode(:R), do: "♖"
  def piece_atom_to_unicode(:r), do: "♜"
  def piece_atom_to_unicode(_), do: " "

  def board_to_unicode_row(board, row_number) do
    Enum.map(["a", "b", "c", "d", "e", "f", "g", "h"], fn col ->
      board
      |> which_piece?(col <> to_string(row_number))
      |> piece_atom_to_unicode()
    end)
  end

  @doc """
  Returns true if the side to move is in check.
  """
  def in_check?(board) do
    {king, by} =
      case board.active_color do
        <<0::1>> -> {:K, :black}
        <<1::1>> -> {:k, :white}
      end

    case Attacks.bits(board.bb[king]) do
      [sq | _] -> square_attacked_by?(board, sq, by)
      [] -> false
    end
  end

  @doc """
  True if the side that just moved left their king in check.
  Call after `Board.apply_search/2` (side to move already flipped).
  """
  def left_in_check?(board) do
    {king, by} =
      case board.active_color do
        <<0::1>> -> {:k, :white}
        <<1::1>> -> {:K, :black}
      end

    case Attacks.bits(board.bb[king]) do
      [sq | _] -> square_attacked_by?(board, sq, by)
      [] -> true
    end
  end

  def square_attacked_by?(board, <<c::8, r::8>>, by) do
    {_row, _col, offset} = rco(r, c)
    square_attacked_by?(board, offset, by)
  end

  def square_attacked_by?(board, offset, by) when is_integer(offset) do
    Attacks.attacked?(board.bb, occupancy_mask(board), offset, by)
  end

  # Bitboard helper: integer mask for a given square
  def square_mask(<<c::8, r::8>>) do
    {_r, _c, off} = rco(r, c)
    1 <<< off
  end

  # Mask of all occupied squares on the board
  def occupancy_mask(board) do
    union_mask(board, @w_pieces) ||| union_mask(board, @b_pieces)
  end

  # Attack mask: all squares attacked by given side pieces
  def attack_mask(board, pieces) do
    by = if pieces == @w_pieces, do: :white, else: :black
    occ = occupancy_mask(board)

    Enum.reduce(0..63, 0, fn sq, mask ->
      if Attacks.attacked?(board.bb, occ, sq, by), do: mask ||| 1 <<< sq, else: mask
    end)
  end

  defp king_safe_after?(board, move) do
    {king, by} =
      case board.active_color do
        <<0::1>> -> {:K, :black}
        <<1::1>> -> {:k, :white}
      end

    bb = apply_pseudo_bb(board, move)
    occ = occupancy_from_bb(bb)

    case Attacks.bits(bb[king]) do
      [sq | _] -> not Attacks.attacked?(bb, occ, sq, by)
      [] -> false
    end
  end

  defp occupancy_from_bb(bb) do
    Enum.reduce(@pieces_set, 0, fn piece, acc -> acc ||| Attacks.as_int(bb[piece]) end)
  end

  def apply_pseudo(board, move), do: apply_pseudo_bb(board, move)

  defp apply_pseudo_bb(board, <<"e1g1">>) do
    board.bb
    |> clear_bit(:K, square_offset("e1"))
    |> clear_bit(:R, square_offset("h1"))
    |> set_bit(:K, square_offset("g1"))
    |> set_bit(:R, square_offset("f1"))
  end

  defp apply_pseudo_bb(board, <<"e1c1">>) do
    board.bb
    |> clear_bit(:K, square_offset("e1"))
    |> clear_bit(:R, square_offset("a1"))
    |> set_bit(:K, square_offset("c1"))
    |> set_bit(:R, square_offset("d1"))
  end

  defp apply_pseudo_bb(board, <<"e8g8">>) do
    board.bb
    |> clear_bit(:k, square_offset("e8"))
    |> clear_bit(:r, square_offset("h8"))
    |> set_bit(:k, square_offset("g8"))
    |> set_bit(:r, square_offset("f8"))
  end

  defp apply_pseudo_bb(board, <<"e8c8">>) do
    board.bb
    |> clear_bit(:k, square_offset("e8"))
    |> clear_bit(:r, square_offset("a8"))
    |> set_bit(:k, square_offset("c8"))
    |> set_bit(:r, square_offset("d8"))
  end

  defp apply_pseudo_bb(board, <<c1::8, r1::8, c2::8, r2::8, promo::8>>) do
    from = square_offset(<<c1, r1>>)
    to = square_offset(<<c2, r2>>)
    pawn = which_piece_bb(board.bb, from)
    promo_piece = promo_atom(pawn, promo)

    board.bb
    |> clear_bit(pawn, from)
    |> clear_square_bb(to)
    |> set_bit(promo_piece, to)
  end

  defp apply_pseudo_bb(board, <<c1::8, r1::8, c2::8, r2::8>>) do
    from = square_offset(<<c1, r1>>)
    to = square_offset(<<c2, r2>>)
    piece = which_piece_bb(board.bb, from)

    bb =
      board.bb
      |> clear_bit(piece, from)
      |> clear_square_bb(to)
      |> set_bit(piece, to)

    if piece in [:P, :p] and board.en_passant == <<c2, r2>> do
      clear_square_bb(bb, square_offset(<<c2, r1>>))
    else
      bb
    end
  end

  defp square_offset(<<c::8, r::8>>) do
    {_row, _col, offset} = rco(r, c)
    offset
  end

  defp which_piece_bb(bb, offset) do
    mask = 1 <<< offset
    Enum.find(@pieces_set, fn piece -> (Attacks.as_int(bb[piece]) &&& mask) != 0 end)
  end

  defp set_bit(bb, nil, _offset), do: bb

  defp set_bit(bb, piece, offset) do
    Map.update(bb, piece, 0, fn x -> Attacks.as_int(x) ||| 1 <<< offset end)
  end

  defp clear_bit(bb, nil, _offset), do: bb

  defp clear_bit(bb, piece, offset) do
    Map.update(bb, piece, 0, fn x -> Attacks.as_int(x) &&& ~~~(1 <<< offset) end)
  end

  defp clear_square_bb(bb, offset) do
    case which_piece_bb(bb, offset) do
      nil -> bb
      piece -> clear_bit(bb, piece, offset)
    end
  end

  defp promo_atom(:P, ?q), do: :Q
  defp promo_atom(:P, ?r), do: :R
  defp promo_atom(:P, ?b), do: :B
  defp promo_atom(:P, ?n), do: :N
  defp promo_atom(:p, ?q), do: :q
  defp promo_atom(:p, ?r), do: :r
  defp promo_atom(:p, ?b), do: :b
  defp promo_atom(:p, ?n), do: :n
  defp promo_atom(piece, _), do: piece

end
