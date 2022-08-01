defmodule Laveno.Board do
  defstruct pieces: %{},
            castles: <<8::size(4)>>,
            bb: %{
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

  @type t :: %__MODULE__{
          pieces: any(),
          castles: bitstring(),
          bb: map()
        }

  use Bitwise
  require Logger

  @offset_row 49
  @offset_column 97
  @pieces_set [:P, :p, :N, :n, :B, :b, :K, :k, :Q, :q, :R, :r]

  def new(), do: %__MODULE__{}

  def move(
        board = %__MODULE__{bb: bb},
        square = <<c1::size(8), r1::size(8), c2::size(8), r2::size(8)>>
      ) do
    :ok
  end

  @doc """
  Get the piece on a given square
  ## Parameters

  - board: %Laveno.Board{}
  - square: String representing a square name in algebraic notation

  ## Examples

      iex> Board.new() |> Board.which_piece?("d8")
      :q

  """
  def which_piece?(
        board = %__MODULE__{bb: bb},
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

  def print_rank(rank_num) do
    offset = rem(rank_num, 2)

    Enum.map((1 + offset)..(8 + offset), fn n ->
      case rem(n, 2) do
        0 -> IO.ANSI.format_fragment([:cyan_background, "   "], true) ++ IO.ANSI.reset()
        _ -> IO.ANSI.format_fragment([:white_background, "   "], true) ++ IO.ANSI.reset()
      end
    end)
  end

  def print_rank(pieces, rank_num) do
    offset = rem(rank_num, 2)

    Enum.zip([(1 + offset)..(8 + offset), pieces])
    |> Enum.map(fn {n, piece} ->
      case rem(n, 2) do
        0 -> IO.ANSI.format_fragment([:cyan_background, piece], true) ++ IO.ANSI.reset()
        _ -> IO.ANSI.format_fragment([:white_background, piece], true) ++ IO.ANSI.reset()
      end
    end)
  end

  def print_board() do
    print_rank([" ♜ ", " ♞ ", " ♝ ", " ♛ ", " ♚ ", " ♝ ", " ♞ ", " ♜ "], 8)
    |> Enum.join("")
    |> IO.puts()

    print_rank([" ♟ ", " ♟ ", " ♟ ", " ♟ ", " ♟ ", " ♟ ", " ♟ ", " ♟ "], 7)
    |> Enum.join("")
    |> IO.puts()

    print_rank(6) |> Enum.join("") |> IO.puts()
    print_rank(5) |> Enum.join("") |> IO.puts()
    print_rank(4) |> Enum.join("") |> IO.puts()
    print_rank(3) |> Enum.join("") |> IO.puts()

    print_rank([" ♙ ", " ♙ ", " ♙ ", " ♙ ", " ♙ ", " ♙ ", " ♙ ", " ♙ "], 2)
    |> Enum.join("")
    |> IO.puts()

    print_rank([" ♖ ", " ♘ ", " ♗ ", " ♕ ", " ♔ ", " ♗ ", " ♘ ", " ♖ "], 1)
    |> Enum.join("")
    |> IO.puts()
  end
end
