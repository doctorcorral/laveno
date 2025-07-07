defmodule Laveno.Board.Utils do
  use Bitwise
  require Logger

  alias Laveno.Board
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
  @type bitboard() :: <<_::64>>

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

  @all_pieces @w_pieces ++ @b_pieces

  def initial_position_binary() do
    %{
      P: <<0::8, 255::8, 0::48>>,
      p: <<0::48, 255::8, 0::8>>,
      N: <<0::1, 1::1, 0::4, 1::1, 0::57>>,
      n: <<0::57, 1::1, 0::4, 1::1, 0::1>>,
      B: <<0::2, 1::1, 0::2, 1::1, 0::58>>,
      b: <<0::58, 1::1, 0::2, 1::1, 0::2>>,
      Q: <<0::3, 1::1, 0::60>>,
      q: <<0::59, 1::1, 0::4>>,
      K: <<0::4, 1::1, 0::59>>,
      k: <<0::60, 1::1, 0::3>>,
      R: <<1::1, 0::6, 1::1, 0::56>>,
      r: <<0::56, 1::1, 0::6, 1::1>>
    }
  end

  def empty_position_binary() do
    %{
      P: <<0::64>>,
      p: <<0::64>>,
      N: <<0::64>>,
      n: <<0::64>>,
      B: <<0::64>>,
      b: <<0::64>>,
      Q: <<0::64>>,
      q: <<0::64>>,
      K: <<0::64>>,
      k: <<0::64>>,
      R: <<0::64>>,
      r: <<0::64>>
    }
  end

  #  @sec place_piece(board, piece_atom, square_algebraic_notation()) :: board
  def place_piece(%{bb: bitboard}, piece, square = <<c::size(8), r::size(8)>>) do
    {_row, _column, offset} = rco(r, c)
    existing_piece_bb_decoded = bitboard[piece] |> :binary.decode_unsigned()
    new_piece_bb_decoded = <<1 <<< offset::64>> |> :binary.decode_unsigned()
    updated_bb = existing_piece_bb_decoded ||| new_piece_bb_decoded
    Map.update(bitboard, piece, <<0::64>>, fn bb -> <<updated_bb::64>> end)
  end

  def remove_piece(
        %{bb: bitboard},
        piece,
        <<c::size(8), r::size(8)>>
      ) do
    {_row, _column, offset} = rco(r, c)
    existing_piece_bb_decoded = bitboard[piece] |> :binary.decode_unsigned()
    no_piece_bb_decoded = <<1 <<< offset::64>> |> :binary.decode_unsigned()
    updated_bb = existing_piece_bb_decoded - no_piece_bb_decoded

    new_bitboard =
      Map.update(
        bitboard,
        piece,
        <<0::64>>,
        fn bb -> <<updated_bb::64>> end
      )
  end

  def clear_square(board = %{bb: bitboard}, square = <<c::size(8), r::size(8)>>) do
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
        board = %{bb: bb},
        square = <<column::size(8), row::size(8)>>
      ) do
    {r, c, offset} = rco(row, column)
    which_piece?(board, offset)
  end

  def which_piece?(
        board = %{bb: bb},
        offset_to_square
      ) do
    mask =
      <<1 <<< offset_to_square::size(64)>>
      |> :binary.decode_unsigned()

    Enum.find(
      @pieces_set,
      &((bb[&1] |> :binary.decode_unsigned() &&& mask) != 0)
    )
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
        move = <<c1::size(8), r1::size(8), c2::size(8), r2::size(8)>>
      ) do
    true
  end

  def indiagonalpawn?(
        board = %{en_passant: en_passant},
        pawn,
        <<c1::size(8), r1::size(8), c2::size(8), r2::size(8)>>
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
        <<c1::size(8), r1::size(8), c2::size(8), r2::size(8)>>
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
    # require a white king on e1 and a white rook on h1
    if which_piece?(board, "e1") != :K or which_piece?(board, "h1") != :R do
      false
    else
      occ    = occupancy_mask(board)
      empty  = square_mask("f1") ||| square_mask("g1")
      attack = attack_mask(board, @b_pieces)
      # mask for e1,f1,g1 bitboard = square_mask("e1") ||| square_mask("f1") ||| square_mask("g1")
      mask_e1_f1_g1 = 0x0E00000000000000
      (occ &&& empty) == 0 and
      (attack &&& mask_e1_f1_g1) == 0
    end
  end

  def valid_move?(board = %{castles: <<_::1,1::1,_::2>>}, <<"e1c1">>) do
    # require a white king on e1 and a white rook on a1
    if which_piece?(board, "e1") != :K or which_piece?(board, "a1") != :R do
      false
    else
      occ    = occupancy_mask(board)
      empty  = square_mask("d1") ||| square_mask("c1") ||| square_mask("b1")
      attack = attack_mask(board, @b_pieces)
      # mask for e1,d1,c1 bitboard = square_mask("e1") ||| square_mask("d1") ||| square_mask("c1")
      mask_e1_d1_c1 = 0x3800000000000000
      (occ &&& empty) == 0 and
      (attack &&& mask_e1_d1_c1) == 0
    end
  end

  def valid_move?(board = %{castles: <<_::2,1::1,_::1>>}, <<"e8g8">>) do
    # require a black king on e8 and a black rook on h8
    if which_piece?(board, "e8") != :k or which_piece?(board, "h8") != :r do
      false
    else
      occ    = occupancy_mask(board)
      empty  = square_mask("f8") ||| square_mask("g8")
      attack = attack_mask(board, @w_pieces)
      # mask for e8,f8,g8 bitboard = square_mask("e8") ||| square_mask("f8") ||| square_mask("g8")
      mask_e8_f8_g8 = 0x0E
      (occ &&& empty) == 0 and
      (attack &&& mask_e8_f8_g8) == 0
    end
  end

  def valid_move?(board = %{castles: <<_::3,1::1>>}, <<"e8c8">>) do
    # require a black king on e8 and a black rook on a1? a8
    if which_piece?(board, "e8") != :k or which_piece?(board, "a8") != :r do
      false
    else
      occ    = occupancy_mask(board)
      empty  = square_mask("d8") ||| square_mask("c8") ||| square_mask("b8")
      attack = attack_mask(board, @w_pieces)
      # mask for e8,d8,c8 bitboard = square_mask("e8") ||| square_mask("d8") ||| square_mask("c8")
      mask_e8_d8_c8 = 0x38
      (occ &&& empty) == 0 and
      (attack &&& mask_e8_d8_c8) == 0
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

  def valid_move?(board, move = <<c1::8, r1::8, c2::8, r2::8>>) do
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
    step_file = cond do
      df > 0 -> 1
      df < 0 -> -1
      true -> 0
    end

    step_rank = cond do
      dr > 0 -> 1
      dr < 0 -> -1
      true -> 0
    end

    max_delta = max(abs(df), abs(dr))
    # when max_delta < 2, the range is empty
    Enum.all?(1..(max_delta - 1)//1, fn i ->
      file = file_from + step_file * i
      rank = rank_from + step_rank * i
      square = <<(@offset_column + file)::8, (@offset_row + rank)::8>>
      which_piece?(board, square) == nil
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

  def where_is(%{bb: %{Q: <<0::64>>}}, :Q), do: []
  def where_is(%{bb: %{q: <<0::64>>}}, :q), do: []
  def where_is(%{bb: %{N: <<0::64>>}}, :N), do: []
  def where_is(%{bb: %{n: <<0::64>>}}, :n), do: []
  def where_is(%{bb: %{B: <<0::64>>}}, :B), do: []
  def where_is(%{bb: %{b: <<0::64>>}}, :b), do: []
  def where_is(%{bb: %{P: <<0::64>>}}, :P), do: []
  def where_is(%{bb: %{p: <<0::64>>}}, :p), do: []
  def where_is(%{bb: %{R: <<0::64>>}}, :R), do: []
  def where_is(%{bb: %{r: <<0::64>>}}, :r), do: []

  def where_is(%{bb: bb}, piece) do
    Enum.reduce(0..63, [], fn
      offset, offset_positions ->
        case :binary.decode_unsigned(<<1 <<< offset::64>>) &&&
               :binary.decode_unsigned(bb[piece]) do
          0 ->
            offset_positions

          _ ->
            [offset | offset_positions]
        end
    end)
  end

  def generate_moves(board = %{active_color: <<0::1>>}) do
    # Only keep moves that do not leave white king in check
    moves_for_pieces(board, @w_pieces)
    |> expand_promotions(board)
    |> Enum.filter(fn move ->
      case Board.move(board, move) do
        %Board{} = new_board ->
          # new_board.active_color is opponent; reset to mover to test king safety
          board_after = %{new_board | active_color: board.active_color}
          not in_check?(board_after)
        _ ->
          false
      end
    end)
  end

  def generate_moves(board = %{active_color: <<1::1>>}) do
    # Only keep moves that do not leave black king in check
    moves_for_pieces(board, @b_pieces)
    |> expand_promotions(board)
    |> Enum.filter(fn move ->
      case Board.move(board, move) do
        %Board{} = new_board ->
          board_after = %{new_board | active_color: board.active_color}
          not in_check?(board_after)
        _ ->
          false
      end
    end)
  end

  def union_mask(%{bb: bb}, pieces) do
    Enum.reduce(
      pieces,
      :binary.decode_unsigned(<<0::64>>),
      fn piece, union_bb ->
        union_bb ||| bb[piece] |> :binary.decode_unsigned()
      end
    )
  end

  def diagonal_path_mask(board, <<c1::size(8), r1::size(8), c2::size(8), r2::size(8)>>) do
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

  def linear_path_mask(board, <<c1::size(8), r1::size(8), c2::size(8), r2::size(8)>>) do
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
    Enum.map(pieces, fn piece ->
      Enum.map(where_is(board, piece), fn piece_offset ->
        with full_moves_mask <- moves(piece, piece_offset),
             self_union_mask <- union_mask(board, pieces),
             moves_mask <- full_moves_mask &&& ~~~self_union_mask do
          Enum.reduce(0..63, [], fn to_offset, acc_moves ->
            if (:binary.decode_unsigned(<<1 <<< to_offset::64>>) &&& moves_mask) != 0 do
              sq1 = Maps.offset_to_square(piece_offset)
              sq2 = Maps.offset_to_square(to_offset)
              move = sq1 <> sq2
              # Only block own pieces, allow captures on target
              if (diagonal_path_mask(board, move) &&& self_union_mask) == 0 and
                 (linear_path_mask(board, move) &&& self_union_mask) == 0 and
                 valid_move?(board, move) do
                [move | acc_moves]
              else
                acc_moves
              end
            else
              acc_moves
            end
          end)
        end
      end)
    end)
    |> List.flatten()
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
  Returns true if the side to move is in check. We generate opponent moves and see if any can capture the king of side to move.
  """
  def in_check?(board) do
    # Attacker moves are from the opponent
    attacker_moves = case board.active_color do
      <<0::1>> -> moves_for_pieces(board, @b_pieces)
      <<1::1>> -> moves_for_pieces(board, @w_pieces)
    end

    # Defender king is of side to move
    defender_king = case board.active_color do
      <<0::1>> -> :K
      <<1::1>> -> :k
    end

    # King square(s)
    king_sqs = where_is(board, defender_king) |> Enum.map(&Maps.offset_to_square/1)

    # If any attacker move targets the king square, it's check
    Enum.any?(attacker_moves, fn <<_::16, c2::8, r2::8>> ->
      <<c2, r2>> in king_sqs
    end)
  end

  # Bitboard helper: integer mask for a given square
  def square_mask(<<c::8, r::8>>) do
    {_,_,off} = rco(r, c)
    1 <<< off
  end

  # Mask of all occupied squares on the board
  def occupancy_mask(board) do
    union_mask(board, @w_pieces) ||| union_mask(board, @b_pieces)
  end

  # Attack mask: all squares attacked by given side pieces
  def attack_mask(board, pieces) do
    moves_for_pieces(board, pieces)
    |> Enum.reduce(0, fn <<_::16, c2::8, r2::8>>, mask ->
      {_,_,off} = rco(r2, c2)
      mask ||| (1 <<< off)
    end)
  end

  # Expand simple 4-byte pawn moves that reach last rank into promotion moves
  defp expand_promotions(moves, board) do
    Enum.flat_map(moves, fn
      move = <<c1::8, r1::8, c2::8, r2::8>> ->
        piece = which_piece?(board, <<c1, r1>>)
        cond do
          piece == :P and r2 == ?8 ->
            for promo <- [?q, ?r, ?b, ?n], do: <<c1::8, r1::8, c2::8, r2::8, promo>>
          piece == :p and r2 == ?1 ->
            for promo <- [?q, ?r, ?b, ?n], do: <<c1::8, r1::8, c2::8, r2::8, promo>>
          true ->
            [move]
        end
      other ->
        [other]
    end)
  end
end
