# Laveno Chess Engine - API Documentation

## Overview

Laveno is a pure Elixir chess engine that provides a complete chess game implementation with UCI (Universal Chess Interface) support. It includes board representation, game state management, move generation, position evaluation, and search algorithms.

## Table of Contents

1. [Main Entry Points](#main-entry-points)
2. [Board Module](#board-module)
3. [FEN Module](#fen-module)
4. [Board Utils Module](#board-utils-module)
5. [Board Render Module](#board-render-module)
6. [Evaluation Modules](#evaluation-modules)
7. [Search/Finder Modules](#searchfinder-modules)
8. [UCI Module](#uci-module)
9. [Usage Examples](#usage-examples)
10. [Type Definitions](#type-definitions)

---

## Main Entry Points

### Laveno Module

The main module provides the entry point for the chess engine.

```elixir
# Create a new chess engine instance
Laveno.start()
```

### Laveno.Application

The OTP application that manages the chess engine lifecycle.

**Functions:**
- `start/2` - Starts the application supervision tree

**Example:**
```elixir
# The application is started automatically when running the engine
# It initializes ETS tables for search optimization
{:ok, _pid} = Laveno.Application.start(:normal, [])
```

---

## Board Module

The core board representation and game state management.

### Types

```elixir
@type t :: %Laveno.Board{
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
```

### Functions

#### `new/0`
Creates a new board with the standard initial chess position.

**Returns:** `%Laveno.Board{}`

**Example:**
```elixir
board = Laveno.Board.new()
# Creates a board with pieces in starting positions
```

#### `new(:empty)`
Creates an empty board with no pieces.

**Returns:** `%Laveno.Board{}`

**Example:**
```elixir
empty_board = Laveno.Board.new(:empty)
# Creates a board with no pieces for custom setup
```

#### `move/2`
Executes a move on the board.

**Parameters:**
- `board` - The current board state
- `move` - Move in algebraic notation (e.g., "e2e4")

**Returns:** `%Laveno.Board{}` or `{:error, "invalid move"}`

**Example:**
```elixir
board = Laveno.Board.new()
new_board = Laveno.Board.move(board, "e2e4")
# Moves pawn from e2 to e4

# Castling moves
king_side_castle = Laveno.Board.move(board, "e1g1")
queen_side_castle = Laveno.Board.move(board, "e1c1")

# Promotion moves
promoted_board = Laveno.Board.move(board, "e7e8q")
```

#### `place_piece/3`
Places a piece on a specific square.

**Parameters:**
- `board` - The current board state
- `piece` - Piece atom (`:P`, `:p`, `:N`, `:n`, `:B`, `:b`, `:R`, `:r`, `:Q`, `:q`, `:K`, `:k`)
- `square` - Square in algebraic notation (e.g., "e4")

**Returns:** `%Laveno.Board{}`

**Example:**
```elixir
board = Laveno.Board.new(:empty)
board_with_king = Laveno.Board.place_piece(board, :K, "e1")
```

#### `clear_square/2`
Removes any piece from a square.

**Parameters:**
- `board` - The current board state
- `square` - Square in algebraic notation

**Returns:** `%Laveno.Board{}`

**Example:**
```elixir
board = Laveno.Board.new()
board_cleared = Laveno.Board.clear_square(board, "e2")
```

#### `set_active_color/2`
Sets the active color to move.

**Parameters:**
- `board` - The current board state
- `color` - Color string ("w" or "b")

**Returns:** `%Laveno.Board{}`

**Example:**
```elixir
board = Laveno.Board.new()
black_to_move = Laveno.Board.set_active_color(board, "b")
```

---

## FEN Module

Handles FEN (Forsyth-Edwards Notation) parsing and loading.

### Functions

#### `load/1`
Parses a FEN string and creates a board state.

**Parameters:**
- `fen_string` - FEN notation string

**Returns:** `{fen_state, %Laveno.Board{}}`

**Example:**
```elixir
# Standard starting position
{fen_state, board} = Laveno.Fen.load("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

# Custom position
{fen_state, board} = Laveno.Fen.load("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
```

#### `new_state/0`
Creates a new FEN parsing state.

**Returns:** `%{step: 1, rank: 8, column: 1, ...}`

**Example:**
```elixir
initial_state = Laveno.Fen.new_state()
```

---

## Board Utils Module

Comprehensive utilities for board operations, move generation, and validation.

### Types

```elixir
@type bitboard() :: <<_::64>>
@type square_algebraic_notation() :: <<_::16>>
@type square_offset_integer() :: integer()
@type piece_atom() :: :P | :p | :N | :n | :B | :b | :K | :k | :Q | :q | :R | :r
@type move() :: <<_::32>>
```

### Functions

#### `which_piece?/2`
Determines which piece is on a given square.

**Parameters:**
- `board` - Board state
- `square` - Square in algebraic notation or offset integer

**Returns:** `piece_atom()` or `nil`

**Example:**
```elixir
board = Laveno.Board.new()
piece = Laveno.Board.Utils.which_piece?(board, "e1")
# Returns :K (white king)

piece = Laveno.Board.Utils.which_piece?(board, "d8")
# Returns :q (black queen)
```

#### `valid_move?/2`
Validates if a move is legal according to chess rules.

**Parameters:**
- `board` - Board state
- `move` - Move in algebraic notation

**Returns:** `boolean()`

**Example:**
```elixir
board = Laveno.Board.new()
valid = Laveno.Board.Utils.valid_move?(board, "e2e4")
# Returns true

invalid = Laveno.Board.Utils.valid_move?(board, "e2e5")
# Returns false
```

#### `generate_moves/1`
Generates all legal moves for the current position.

**Parameters:**
- `board` - Board state

**Returns:** `[move()]`

**Example:**
```elixir
board = Laveno.Board.new()
moves = Laveno.Board.Utils.generate_moves(board)
# Returns list of all legal moves like ["a2a3", "a2a4", "b1c3", ...]
```

#### `in_check?/1`
Determines if the side to move is in check.

**Parameters:**
- `board` - Board state

**Returns:** `boolean()`

**Example:**
```elixir
board = Laveno.Board.new()
in_check = Laveno.Board.Utils.in_check?(board)
# Returns false for starting position
```

#### `where_is/2`
Finds all squares where a specific piece type is located.

**Parameters:**
- `board` - Board state
- `piece` - Piece atom

**Returns:** `[square_offset_integer()]`

**Example:**
```elixir
board = Laveno.Board.new()
white_pawns = Laveno.Board.Utils.where_is(board, :P)
# Returns list of offsets where white pawns are located
```

#### `moves/2`
Generates possible moves for a piece type from a given square.

**Parameters:**
- `piece` - Piece atom or piece name atom
- `square_offset` - Square offset integer

**Returns:** `bitboard_int()`

**Example:**
```elixir
knight_moves = Laveno.Board.Utils.moves(:N, 28)
# Returns bitboard of possible knight moves from square 28
```

---

## Board Render Module

Handles visual representation of the chess board.

### Functions

#### `print_board/0`
Prints the initial chess position to console.

**Example:**
```elixir
Laveno.Board.Render.print_board()
# Prints colored chess board to console
```

#### `print_board/1`
Prints a specific board state to console.

**Parameters:**
- `board` - Board state

**Example:**
```elixir
board = Laveno.Board.new()
board = Laveno.Board.move(board, "e2e4")
Laveno.Board.Render.print_board(board)
```

#### `print_board/2`
Prints a board with a specific color theme.

**Parameters:**
- `board` - Board state
- `theme` - Color theme (`:red`, `:blue`, `:green`, `:yellow`, `:bw`)

**Example:**
```elixir
board = Laveno.Board.new()
Laveno.Board.Render.print_board(board, :blue)
```

---

## Evaluation Modules

Position evaluation system with multiple evaluation components.

### Laveno.Evaluation.Evaluator

Main evaluation coordinator that combines multiple evaluation components.

#### `eval/1`
Evaluates a board position from white's perspective.

**Parameters:**
- `board` - Board state

**Returns:** `float()` - Evaluation in centipawns

**Example:**
```elixir
board = Laveno.Board.new()
evaluation = Laveno.Evaluation.Evaluator.eval(board)
# Returns 0.0 for starting position
```

### Laveno.Evaluation.Material

Evaluates material balance using piece values.

#### `eval/1`
Evaluates material balance (white - black).

**Parameters:**
- `board` - Board state

**Returns:** `integer()` - Material difference in centipawns

**Example:**
```elixir
board = Laveno.Board.new()
material = Laveno.Evaluation.Material.eval(board)
# Returns 0 for equal material
```

#### `piece_value/1`
Gets the centipawn value for a piece.

**Parameters:**
- `piece` - Piece atom

**Returns:** `integer()`

**Example:**
```elixir
queen_value = Laveno.Evaluation.Material.piece_value(:Q)
# Returns 900
```

### Laveno.Evaluation.Placement

Evaluates piece placement and center control.

#### `eval/1`
Evaluates positional factors based on piece placement.

**Parameters:**
- `board` - Board state

**Returns:** `float()` - Positional evaluation

**Example:**
```elixir
board = Laveno.Board.new()
placement = Laveno.Evaluation.Placement.eval(board)
```

### Laveno.Evaluation.Check

Evaluates check and checkmate situations.

#### `eval/1`
Evaluates check and checkmate bonuses.

**Parameters:**
- `board` - Board state

**Returns:** `integer()` - Check/checkmate bonus

**Example:**
```elixir
board = Laveno.Board.new()
check_bonus = Laveno.Evaluation.Check.eval(board)
# Returns 0 for no check situation
```

---

## Search/Finder Modules

Search algorithms for finding the best moves.

### Laveno.Finders.Minimax

Basic minimax algorithm implementation.

#### `find/2`
Finds the best move using minimax search.

**Parameters:**
- `board` - Board state
- `depth` - Search depth

**Returns:** `integer()` - Position evaluation

**Example:**
```elixir
board = Laveno.Board.new()
evaluation = Laveno.Finders.Minimax.find(board, 3)
```

#### `find/4`
Finds the best move with alpha-beta bounds.

**Parameters:**
- `board` - Board state
- `depth` - Search depth
- `alpha` - Alpha value
- `beta` - Beta value

**Returns:** `{integer(), %Laveno.Board{}}`

**Example:**
```elixir
board = Laveno.Board.new()
{eval, new_board} = Laveno.Finders.Minimax.find(board, 3, -90, 90)
```

### Other Finder Modules

- `Laveno.Finders.MinimaxABPruning` - Alpha-beta pruning
- `Laveno.Finders.MinimaxABPruningETS` - Alpha-beta with ETS optimization
- `Laveno.Finders.MinimaxABPruningNegamaxETS` - Negamax with ETS

All follow similar API patterns with `find/4` functions.

---

## UCI Module

Universal Chess Interface implementation for GUI compatibility.

### Functions

#### `main/1`
Main entry point for UCI protocol.

**Parameters:**
- `args` - Command line arguments

**Example:**
```elixir
# Start UCI engine with alpha-beta search
Laveno.UCI.main(["--finder", "alphabeta"])
```

#### Supported Finder Options

- `"random"` - Random move selection
- `"minimax"` - Basic minimax
- `"alphabeta"` - Alpha-beta pruning
- `"alphabeta-simple"` - Simple alpha-beta
- `"alphabeta-ets"` - ETS-optimized alpha-beta
- `"alphabeta-negamax-ets"` - Negamax with ETS (default)

---

## Usage Examples

### Basic Game Setup

```elixir
# Create a new game
board = Laveno.Board.new()

# Make some moves
board = Laveno.Board.move(board, "e2e4")
board = Laveno.Board.move(board, "e7e5")
board = Laveno.Board.move(board, "g1f3")

# Display the board
Laveno.Board.Render.print_board(board)
```

### FEN Position Loading

```elixir
# Load a specific position
fen = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
{fen_state, board} = Laveno.Fen.load(fen)

# Generate legal moves
moves = Laveno.Board.Utils.generate_moves(board)
```

### Engine Analysis

```elixir
# Analyze a position
board = Laveno.Board.new()
evaluation = Laveno.Evaluation.Evaluator.eval(board)

# Find best move
{best_eval, best_board} = Laveno.Finders.MinimaxABPruning.find(board, 4, -90, 90)
best_move = List.last(best_board.moves)
```

### UCI Engine Usage

```bash
# Build the executable
mix escript.build

# Start engine with specific finder
./laveno --finder alphabeta-negamax-ets

# Send UCI commands
echo "uci" | ./laveno
echo "isready" | ./laveno
echo "position startpos moves e2e4" | ./laveno
echo "go depth 4" | ./laveno
```

### Custom Board Setup

```elixir
# Create empty board
board = Laveno.Board.new(:empty)

# Place pieces
board = Laveno.Board.place_piece(board, :K, "e1")
board = Laveno.Board.place_piece(board, :k, "e8")
board = Laveno.Board.place_piece(board, :Q, "d1")
board = Laveno.Board.place_piece(board, :q, "d8")

# Set active color
board = Laveno.Board.set_active_color(board, "w")
```

---

## Type Definitions

### Core Types

```elixir
# Board representation
@type board :: %Laveno.Board{}

# Bitboard for piece positions
@type bitboard :: <<_::64>>

# Square notation
@type square :: <<_::16>>  # e.g., "e4"

# Move notation
@type move :: <<_::32>>    # e.g., "e2e4"

# Piece types
@type piece_atom :: :P | :p | :N | :n | :B | :b | :K | :k | :Q | :q | :R | :r

# Colors
@type color :: :w | :b

# Evaluation score
@type evaluation :: integer()  # centipawns
```

### Search Types

```elixir
# Search result
@type search_result :: {evaluation(), board()}

# Search bounds
@type alpha :: integer()
@type beta :: integer()

# Search depth
@type depth :: non_neg_integer()
```

---

## Error Handling

The engine handles various error conditions:

### Move Validation Errors

```elixir
# Invalid move returns error tuple
case Laveno.Board.move(board, "e2e5") do
  %Laveno.Board{} = new_board -> {:ok, new_board}
  {:error, reason} -> {:error, reason}
end
```

### UCI Protocol Errors

The UCI module includes error handling for:
- Invalid commands
- Broken pipe errors
- Unexpected exceptions (logged to `crash.log`)

### Safety Features

- Move validation prevents illegal moves
- Check detection prevents moving into check
- Castling validation ensures legal castling
- En passant validation for proper pawn captures

---

This documentation covers all major public APIs and functions in the Laveno chess engine. For implementation details and private functions, refer to the source code comments and module documentation.