defmodule Laveno.Board do
  alias Laveno.Board.Utils

  defstruct pieces: %{},
            castles: <<15::size(4)>>,
            bb: %{},
            active_color: <<0::1>>,
            en_passant: nil,
            halfmove_clock: 0,
            fullmove_number: 0,
            game_over: false,
            moves: []

  @type t :: %__MODULE__{
          pieces: any(),
          castles: bitstring(),
          bb: map(),
          active_color: bitstring(),
          en_passant: nil | bitstring(),
          halfmove_clock: integer(),
          fullmove_number: integer(),
          game_over: bool(),
          moves: list(bitstring())
        }

  use Bitwise
  require Logger

  @offset_row 49
  @offset_column 97
  @pieces_set [:P, :p, :N, :n, :B, :b, :K, :k, :Q, :q, :R, :r]
  @w_pieces [:P, :R, :N, :B, :K, :Q]
  @b_pieces [:p, :r, :n, :b, :k, :q]

  @doc "Create a board with the standard initial position"
  def new() do
    %__MODULE__{bb: Utils.initial_position_binary()}
  end

  @doc "Create an empty board with no pieces"
  def new(:empty) do
    %__MODULE__{
      bb: Utils.empty_position_binary()
    }
  end

  def place_piece(board, piece, square) do
    Map.put(board, :bb, Utils.place_piece(board, piece, square))
  end

  def clear_square(board, square) do
    Map.put(board, :bb, Utils.clear_square(board, square))
  end

  def log_move(%{moves: moves} = board, move) do
    Map.put(board, :moves, moves ++ [move])
  end

  # Special-case castling moves to move both king and rook and clear castling rights
  def move(board = %__MODULE__{}, <<"e1g1">> = move) do
    board
    |> proc_castle(:K)
    |> clear_square("e1")
    |> clear_square("h1")
    |> place_piece(:K, "g1")
    |> place_piece(:R, "f1")
    |> proc_en_passant(:K, move)
    |> increment_count()
    |> flip_active_color()
    |> log_move(move)
  end

  def move(board = %__MODULE__{}, <<"e1c1">> = move) do
    board
    |> proc_castle(:K)
    |> clear_square("e1")
    |> clear_square("a1")
    |> place_piece(:K, "c1")
    |> place_piece(:R, "d1")
    |> proc_en_passant(:K, move)
    |> increment_count()
    |> flip_active_color()
    |> log_move(move)
  end

  def move(board = %__MODULE__{}, <<"e8g8">> = move) do
    board
    |> proc_castle(:k)
    |> clear_square("e8")
    |> clear_square("h8")
    |> place_piece(:k, "g8")
    |> place_piece(:r, "f8")
    |> proc_en_passant(:k, move)
    |> increment_count()
    |> flip_active_color()
    |> log_move(move)
  end

  def move(board = %__MODULE__{}, <<"e8c8">> = move) do
    board
    |> proc_castle(:k)
    |> clear_square("e8")
    |> clear_square("a8")
    |> place_piece(:k, "c8")
    |> place_piece(:r, "d8")
    |> proc_en_passant(:k, move)
    |> increment_count()
    |> flip_active_color()
    |> log_move(move)
  end

  # Special-case pawn promotion moves with explicit promotion piece
  def move(board, <<c1::8, r1::8, c2::8, r2::8, promo::8>> = move) do
    from_square = <<c1::8, r1::8>>
    to_square   = <<c2::8, r2::8>>
    piece = Utils.which_piece?(board, from_square)

    with true <- Utils.valid_move?(board, move),
         true <- right_turn?(board, piece) do
      promo_piece = case {piece, promo} do
        {:P, ?q} -> :Q
        {:P, ?r} -> :R
        {:P, ?b} -> :B
        {:P, ?n} -> :N
        {:p, ?q} -> :q
        {:p, ?r} -> :r
        {:p, ?b} -> :b
        {:p, ?n} -> :n
        _ -> piece
      end

      board
      |> clear_square(from_square)
      |> clear_square(to_square)
      |> place_piece(promo_piece, to_square)
      |> proc_castle(piece)
      |> proc_en_passant(piece, move)
      |> reset_halfmove_clock()
      |> flip_active_color()
      |> log_move(move)
    else
      _ -> {:error, "invalid move"}
    end
  end

  def move(
        board = %__MODULE__{bb: bb},
        move = <<c1::size(8), r1::size(8), c2::size(8), r2::size(8)>>
      ) do
    with true <- Utils.valid_move?(board, move),
         from_square <- <<c1::8, r1::8>>,
         to_square <- <<c2::8, r2::8>>,
         piece <- Utils.which_piece?(board, from_square),
         true <- right_turn?(board, piece) do
      # Check if this is a capture or pawn move
      is_capture = Utils.which_piece?(board, to_square) != nil
      is_pawn_move = piece in [:P, :p]

      board
      |> clear_square(from_square)
      |> clear_square(to_square)
      |> place_piece(piece, to_square)
      |> proc_castle(piece)
      |> proc_en_passant(piece, move)
      |> (if is_pawn_move or is_capture, do: &reset_halfmove_clock/1, else: &increment_count/1).()
      |> flip_active_color()
      |> log_move(move)
    else
      _ -> {:error, "invalid move"}
    end
  end

  def right_turn?(%{active_color: <<0::1>>}, piece)
      when piece in @w_pieces,
      do: true

  def right_turn?(%{active_color: <<1::1>>}, piece)
      when piece in @b_pieces,
      do: true

  def right_turn?(_, _), do: false

  def increment_count(board = %{halfmove_clock: 0}) do
    %{board | halfmove_clock: 1}
  end

  def increment_count(board = %{halfmove_clock: 1, fullmove_number: fullmn}) do
    %{board | halfmove_clock: 0, fullmove_number: fullmn + 1}
  end

  def reset_halfmove_clock(board = %{halfmove_clock: 0, fullmove_number: fullmn}) do
    %{board | fullmove_number: fullmn + 1}
  end

  def reset_halfmove_clock(board = %{halfmove_clock: 1, fullmove_number: fullmn}) do
    %{board | halfmove_clock: 0, fullmove_number: fullmn + 1}
  end

  def proc_castle(board = %{castles: <<_::2, kq::2>>}, :K) do
    %{board | castles: <<0::2, kq::2>>}
  end

  def proc_castle(board = %{castles: <<kq::2, _::2>>}, :k) do
    %{board | castles: <<kq::2, 0::2>>}
  end

  def proc_castle(board, _), do: board

  def proc_en_passant(
        board,
        pawn,
        move = <<c1::8, r1::8, c2::8, r2::8>>
      )
      when pawn in [:P, :p] do
    case abs(r2 - r1) == 2 do
      true ->
        case r1 do
          50 -> board |> set_en_passant(<<c2::8, r1 + 1::8>>)
          55 -> board |> set_en_passant(<<c2::8, r1 - 1::8>>)
          # fallback for unexpected ranks: clear en passant
          _  -> %{board | en_passant: nil}
        end

      false ->
        %{board | en_passant: nil}
    end
  end

  def proc_en_passant(board, _piece, _move), do: %{board | en_passant: nil}

  def set_en_passant(board = %__MODULE__{}, en_passant = <<_::16>>) do
    %{board | en_passant: en_passant}
  end

  def set_castle(board = %__MODULE__{castles: <<_::1, qkq::3>>}, "K") do
    %{board | castles: <<1::1, qkq::3>>}
  end

  def set_castle(board = %__MODULE__{castles: <<k::1, _::1, kq::2>>}, "Q") do
    %{board | castles: <<k::1, 1::1, kq::2>>}
  end

  def set_castle(board = %__MODULE__{castles: <<kq::2, _::1, q::1>>}, "k") do
    %{board | castles: <<kq::2, 1::1, q::1>>}
  end

  def set_castle(board = %__MODULE__{castles: <<kqk::3, _::1>>}, "q") do
    %{board | castles: <<kqk::3, 1::1>>}
  end

  def set_active_color(board = %__MODULE__{}, active_color) do
    Map.put(board, :active_color, to_bit_color(active_color))
  end

  def to_bit_color("w"), do: <<0::1>>
  def to_bit_color("b"), do: <<1::1>>

  def flip_active_color(
        board = %{
          active_color: <<0::1>>
        }
      ),
      do: %{board | active_color: <<1::1>>}

  def flip_active_color(
        board = %{
          active_color: <<1::1>>
        }
      ),
      do: %{board | active_color: <<0::1>>}
end
