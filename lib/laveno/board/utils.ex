defmodule Laveno.Board.Utils do
  use Bitwise
  require Logger

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

  # "f2f4"
  @type move() :: <<_::32>>

  @offset_row 49
  @offset_column 97
  @pieces_set [:P, :p, :N, :n, :B, :b, :K, :k, :Q, :q, :R, :r]

  def initial_position_binary() do
    %{
      P: <<0::(8), 255::(8), 0::(48)>>,
      p: <<0::(48), 255::(8), 0::(8)>>,
      N: <<0::(1), 1::(1), 0::(4), 1::(1), 0::(57)>>,
      n: <<0::(57), 1::(1), 0::(4), 1::(1), 0::(1)>>,
      B: <<0::(2), 1::(1), 0::(2), 1::(1), 0::(58)>>,
      b: <<0::(58), 1::(1), 0::(2), 1::(1), 0::(2)>>,
      Q: <<0::(3), 1::(1), 0::(60)>>,
      q: <<0::(59), 1::(1), 0::(4)>>,
      K: <<0::(4), 1::(1), 0::(59)>>,
      k: <<0::(60), 1::(1), 0::(3)>>,
      R: <<1::(1), 0::(6), 1::(1), 0::(56)>>,
      r: <<0::(56), 1::(1), 0::(6), 1::(1)>>
    }
  end

  @spec moves(piece_atom(), square_offset_integer()) :: bitboard_int()
  @spec moves(piece_name_atom(), square_offset_integer()) :: bitboard_int()

  def moves(:N, square_offset), do: moves(:knight, square_offset)
  def moves(:n, square_offset), do: moves(:knight, square_offset)

  def moves(:knight, square_offset) do
    moves_list_binaries = [
      <<1 <<< (square_offset + 8 + 2)::(64)>>,
      <<1 <<< (square_offset + 8 - 2)::(64)>>,
      <<1 <<< (square_offset - 8 + 2)::(64)>>,
      <<1 <<< (square_offset - 8 - 2)::(64)>>,
      <<1 <<< (square_offset + 16 + 1)::(64)>>,
      <<1 <<< (square_offset + 16 - 1)::(64)>>,
      <<1 <<< (square_offset - 16 + 1)::(64)>>,
      <<1 <<< (square_offset - 16 - 1)::(64)>>
    ]

    Enum.reduce(moves_list_binaries, <<0::(64)>> |> :binary.decode_unsigned(), fn m, acc ->
      acc ||| m |> :binary.decode_unsigned()
    end)
  end

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

  def valid_move?(
        board,
        move = <<c1::size(8), r1::size(8), c2::size(8), r2::size(8)>>
      ) do
    {r_from, c_from, offset_from} = rco(r1, c1)
    {r_to, c_to, offset_to} = rco(r2, c2)

    valid_move?(board, offset_from, offset_to)
  end

  def valid_move?(board, offset_from, offset_to) do
    piece = which_piece?(board, offset_from)
    moves = moves(piece, offset_from)
    offset_to_mask = <<1 <<< offset_to::size(64)>> |> :binary.decode_unsigned()

    case (moves &&& offset_to_mask) != 0 do
      true -> true
      _ -> false
    end
  end

  defp rco(row, column) do
    c = column - @offset_column
    r = row - @offset_row
    offset = 64 - 8 * r - c - 1

    {r, c, offset}
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
end
