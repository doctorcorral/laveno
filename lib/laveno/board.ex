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

  def clear_castles(board), do: %{board | castles: <<0::size(4)>>}

  def place_piece(board, piece, square) do
    Map.put(board, :bb, Utils.place_piece(board, piece, square))
  end

  def clear_square(board, square) do
    Map.put(board, :bb, Utils.clear_square(board, square))
  end

  def log_move(%{moves: moves} = board, move) do
    Map.put(board, :moves, moves ++ [move])
  end

  # Special-case castling only when the king and rook are still on the home squares.
  # Otherwise fall through so a two-square king walk is not forced as O-O / O-O-O.
  def move(board = %__MODULE__{}, <<"e1g1">> = move) do
    if Utils.which_piece?(board, "e1") == :K and Utils.which_piece?(board, "h1") == :R do
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
    else
      do_normal_move(board, move)
    end
  end

  def move(board = %__MODULE__{}, <<"e1c1">> = move) do
    if Utils.which_piece?(board, "e1") == :K and Utils.which_piece?(board, "a1") == :R do
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
    else
      do_normal_move(board, move)
    end
  end

  def move(board = %__MODULE__{}, <<"e8g8">> = move) do
    if Utils.which_piece?(board, "e8") == :k and Utils.which_piece?(board, "h8") == :r do
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
    else
      do_normal_move(board, move)
    end
  end

  def move(board = %__MODULE__{}, <<"e8c8">> = move) do
    if Utils.which_piece?(board, "e8") == :k and Utils.which_piece?(board, "a8") == :r do
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
    else
      do_normal_move(board, move)
    end
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
      |> update_castling_rights(piece, from_square, to_square)
      |> clear_square(from_square)
      |> clear_square(to_square)
      |> place_piece(promo_piece, to_square)
      |> proc_en_passant(piece, move)
      |> reset_halfmove_clock()
      |> flip_active_color()
      |> log_move(move)
    else
      _ -> {:error, "invalid move"}
    end
  end

  def move(
        board = %__MODULE__{bb: _bb},
        move = <<_c1::size(8), _r1::size(8), _c2::size(8), _r2::size(8)>>
      ) do
    do_normal_move(board, move)
  end

  defp do_normal_move(
         board,
         move = <<c1::size(8), r1::size(8), c2::size(8), r2::size(8)>>
       ) do
    with true <- Utils.valid_move?(board, move),
         from_square <- <<c1::8, r1::8>>,
         to_square <- <<c2::8, r2::8>>,
         piece <- Utils.which_piece?(board, from_square),
         true <- right_turn?(board, piece) do
      is_capture = Utils.which_piece?(board, to_square) != nil
      is_ep = piece in [:P, :p] and board.en_passant == to_square
      is_pawn_move = piece in [:P, :p]

      board
      |> update_castling_rights(piece, from_square, to_square)
      |> then(fn b -> if is_ep, do: clear_square(b, <<c2, r1>>), else: b end)
      |> clear_square(from_square)
      |> clear_square(to_square)
      |> place_piece(piece, to_square)
      |> proc_en_passant(piece, move)
      |> (if is_pawn_move or is_capture, do: &reset_halfmove_clock/1, else: &increment_count/1).()
      |> flip_active_color()
      |> log_move(move)
    else
      _ -> {:error, "invalid move"}
    end
  end

  @doc """
  Apply a movegen move without `valid_move?` or move-history logging.
  Search uses this; UCI position still goes through `move/2`.
  """
  def apply_search(board = %__MODULE__{}, <<c1::8, r1::8, c2::8, r2::8, _::binary>> = move) do
    from = <<c1, r1>>
    to = <<c2, r2>>
    piece = Utils.which_piece?(board, from)

    if piece == nil do
      {:error, "invalid move"}
    else
      is_capture =
        Utils.which_piece?(board, to) != nil or
          (piece in [:P, :p] and board.en_passant == to)

      board
      |> update_castling_rights(piece, from, to)
      |> Map.put(:bb, Utils.apply_pseudo(board, move))
      |> proc_en_passant(piece, move)
      |> then(
        if piece in [:P, :p] or is_capture,
          do: &reset_halfmove_clock/1,
          else: &increment_count/1
      )
      |> flip_active_color()
    end
  end

  def apply_search(_, _), do: {:error, "invalid move"}

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

  # Clear the matching rights when a rook moves or a rook is captured.
  defp update_castling_rights(board, piece, from, to) do
    board
    |> proc_castle(piece)
    |> clear_rook_rights(piece, from)
    |> clear_rights_on_square(to)
  end

  defp clear_rook_rights(board, :R, "a1"), do: clear_castle(board, "Q")
  defp clear_rook_rights(board, :R, "h1"), do: clear_castle(board, "K")
  defp clear_rook_rights(board, :r, "a8"), do: clear_castle(board, "q")
  defp clear_rook_rights(board, :r, "h8"), do: clear_castle(board, "k")
  defp clear_rook_rights(board, _, _), do: board

  defp clear_rights_on_square(board, "a1"), do: clear_castle(board, "Q")
  defp clear_rights_on_square(board, "h1"), do: clear_castle(board, "K")
  defp clear_rights_on_square(board, "a8"), do: clear_castle(board, "q")
  defp clear_rights_on_square(board, "h8"), do: clear_castle(board, "k")
  defp clear_rights_on_square(board, _), do: board

  def clear_castle(%{castles: <<_k::1, q::1, kq::2>>} = board, "K") do
    %{board | castles: <<0::1, q::1, kq::2>>}
  end

  def clear_castle(%{castles: <<k::1, _q::1, kq::2>>} = board, "Q") do
    %{board | castles: <<k::1, 0::1, kq::2>>}
  end

  def clear_castle(%{castles: <<kq::2, _k::1, q::1>>} = board, "k") do
    %{board | castles: <<kq::2, 0::1, q::1>>}
  end

  def clear_castle(%{castles: <<kqk::3, _q::1>>} = board, "q") do
    %{board | castles: <<kqk::3, 0::1>>}
  end

  def clear_castle(board, _), do: board

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
