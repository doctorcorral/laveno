defmodule Laveno.Fen do
  @moduledoc """
  Parse Forsyth–Edwards Notation used by UCI `position fen` commands.

  TCEC and CCC opening books always send a FEN (often with partial or no
  castling rights, and en passant on any file including g and h). The previous
  character-by-character loader started from a board that already had all
  castling rights set and only recognized en-passant files a–f.
  """
  alias Laveno.Board

  @start_fen "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

  def new_state do
    %{
      fen: @start_fen,
      active_color: "w",
      castling: "-",
      en_passant_target_square: "-",
      halfmove_clock: 0,
      fullmove_number: 1
    }
  end

  @doc "Load a FEN string. Extra tokens after the six fields (e.g. `moves`) are ignored."
  def load(fen_string) when is_binary(fen_string) do
    fields =
      fen_string
      |> String.trim()
      |> String.split(~r/\s+/, parts: 6)

    placement = Enum.at(fields, 0, "")
    active = Enum.at(fields, 1, "w")
    castling = Enum.at(fields, 2, "-")
    ep = Enum.at(fields, 3, "-")
    half = parse_int(Enum.at(fields, 4), 0)
    full = parse_int(Enum.at(fields, 5), 1)

    board =
      Board.new(:empty)
      |> Board.clear_castles()
      |> apply_placement(placement)
      |> Board.set_active_color(normalize_color(active))
      |> apply_castling(castling)
      |> apply_en_passant(ep)
      |> Map.put(:halfmove_clock, rem(max(half, 0), 2))
      |> Map.put(:fullmove_number, max(full, 1))

    state = %{
      fen: String.trim(fen_string),
      active_color: normalize_color(active),
      castling: castling,
      en_passant_target_square: ep,
      halfmove_clock: half,
      fullmove_number: full
    }

    {state, board}
  end

  defp normalize_color("b"), do: "b"
  defp normalize_color("B"), do: "b"
  defp normalize_color(_), do: "w"

  defp parse_int(nil, default), do: default

  defp parse_int(str, default) do
    case Integer.parse(to_string(str)) do
      {n, _} -> n
      :error -> default
    end
  end

  defp apply_placement(board, placement) do
    placement
    |> String.split("/")
    |> Enum.take(8)
    |> Enum.with_index()
    |> Enum.reduce(board, fn {rank_str, idx}, acc ->
      apply_rank(acc, rank_str, 8 - idx)
    end)
  end

  defp apply_rank(board, rank_str, rank) do
    {board, _file} =
      rank_str
      |> String.graphemes()
      |> Enum.reduce({board, 0}, fn ch, {acc, file} ->
        cond do
          ch in ~w(1 2 3 4 5 6 7 8) ->
            {acc, file + String.to_integer(ch)}

          file > 7 ->
            {acc, file}

          true ->
            square = <<(?a + file), (?0 + rank)>>
            {Board.place_piece(acc, String.to_atom(ch), square), file + 1}
        end
      end)

    board
  end

  # Standard KQkq plus Shredder-FEN A/H (standard rook files) so book FENs
  # that use Chess960-style letters for a classical setup still load.
  defp apply_castling(board, "-"), do: board

  defp apply_castling(board, rights) do
    rights
    |> String.graphemes()
    |> Enum.reduce(board, fn letter, acc ->
      case letter do
        l when l in ["K", "Q", "k", "q"] -> Board.set_castle(acc, l)
        "H" -> Board.set_castle(acc, "K")
        "A" -> Board.set_castle(acc, "Q")
        "h" -> Board.set_castle(acc, "k")
        "a" -> Board.set_castle(acc, "q")
        _ -> acc
      end
    end)
  end

  defp apply_en_passant(board, "-"), do: board
  defp apply_en_passant(board, ""), do: board

  defp apply_en_passant(board, <<file::8, rank::8>>)
       when file >= ?a and file <= ?h and rank >= ?1 and rank <= ?8 do
    Board.set_en_passant(board, <<file, rank>>)
  end

  defp apply_en_passant(board, ep) when is_binary(ep) do
    case String.downcase(ep) do
      <<file::8, rank::8>> when file >= ?a and file <= ?h and rank >= ?1 and rank <= ?8 ->
        Board.set_en_passant(board, <<file, rank>>)

      _ ->
        board
    end
  end

  defp apply_en_passant(board, _), do: board
end
