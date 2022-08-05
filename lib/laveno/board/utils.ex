defmodule Laveno.Board.Utils do
  use Bitwise

  @offset_row 49
  @offset_column 97
  @pieces_set [:P, :p, :N, :n, :B, :b, :K, :k, :Q, :q, :R, :r]

  def initial_position_binary() do
    %{
      P: <<0::size(8), 255::size(8), 0::size(48)>>,
      p: <<0::size(48), 255::size(8), 0::size(8)>>,
      N: <<0::size(1), 1::size(1), 0::size(4), 1::size(1), 0::size(57)>>,
      n: <<0::size(57), 1::size(1), 0::size(4), 1::size(1), 0::size(1)>>,
      B: <<0::size(2), 1::size(1), 0::size(2), 1::size(1), 0::size(58)>>,
      b: <<0::size(58), 1::size(1), 0::size(2), 1::size(1), 0::size(2)>>,
      Q: <<0::size(3), 1::size(1), 0::size(60)>>,
      q: <<0::size(59), 1::size(1), 0::size(4)>>,
      K: <<0::size(4), 1::size(1), 0::size(59)>>,
      k: <<0::size(60), 1::size(1), 0::size(3)>>,
      R: <<1::size(1), 0::size(6), 1::size(1), 0::size(56)>>,
      r: <<0::size(56), 1::size(1), 0::size(6), 1::size(1)>>
    }
  end

  def moves(:N, square_offset), do: moves(:knight, square_offset)
  def moves(:n, square_offset), do: moves(:knight, square_offset)


  def moves(:knight, square_offset) do
    [
      <<(1 <<< (square_offset + 8 + 2))::size(64)>>,
      <<(1 <<< (square_offset + 8 - 2))::size(64)>>,
      <<(1 <<< (square_offset - 8 + 2))::size(64)>>,
      <<(1 <<< (square_offset - 8 - 2))::size(64)>>,
      <<(1 <<< (square_offset + 16 + 1))::size(64)>>,
      <<(1 <<< (square_offset + 16 - 1))::size(64)>>,
      <<(1 <<< (square_offset - 16 + 1))::size(64)>>,
      <<(1 <<< (square_offset - 16 - 1))::size(64)>>,
    ]
  end

  def which_piece?(
        board = %{bb: bb},
        square = <<column::size(8), row::size(8)>>
      ) do
    c = column - @offset_column
    r = row - @offset_row
    offset = 64 - 8 * r - c - 1
    mask = <<1 <<< offset::size(64)>> |> :binary.decode_unsigned()

    piece =
      Enum.find(
        @pieces_set,
        &((bb[&1] |> :binary.decode_unsigned() &&& mask) != 0)
      )

    piece
  end

  def valid_move?(board, offset_from, offset_to) do
    false
  end
end
