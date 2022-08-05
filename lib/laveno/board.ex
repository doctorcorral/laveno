defmodule Laveno.Board do
  alias Laveno.Board.Utils

  defstruct pieces: %{},
            castles: <<8::size(4)>>,
            bb: Utils.initial_position_binary()

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

    board

    {:ok, board}
  end

  @doc """
  Determine which piece is on a given square
  ## Parameters

  - board: %Laveno.Board{}
  - square: String representing a square name in algebraic notation

  ## Examples

      iex> Board.new() |> Board.which_piece?("d8")
      :q

  """


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
