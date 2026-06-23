# lifeofgame-racket

A pure functional, GUI-based implementation of **Conway's Game of Life** written in Racket.

## Features

1. **Pure Functional Style (Scheme-like)**:
   - Avoids mutable arrays or arrays updates (`vector-set!`).
   - Represents the grid state as an immutable list of coordinate pairs `(x . y)` representing only the currently alive cells.
   - Leverages recursion and standard functional programming constructs (`map`, `filter`, `lambda`, `for-each`).

2. **Theoretical Infinite Grid**:
   - Because the state is represented by coordinate sets rather than a fixed-size 2D vector, the core calculation engine can theoretically run on an infinite plane. Boundary clipping is only applied at the GUI rendering step.

3. **GUI Visualization**:
   - Implemented using Racket's native `racket/gui/base` library.
   - Automatically opens a graphical window where cells are rendered smoothly (with double-buffering) at a customizable interval (default: 300ms) without polluting the REPL/terminal console output.

4. **Multi-Glider Setup**:
   - The initial configuration features 4 gliders positioned to travel and eventually collide or form stable patterns.

---

## How to Run

Ensure you have **Racket** installed on your system. Run the script directly from your terminal or command prompt:

```bash
racket lifeofgame-racket.rkt
```

Alternatively, open the file `lifeofgame-racket.rkt` in **DrRacket** and click the **Run** button. A graphical window titled "Life of Game" will pop up and run the simulation automatically.

---

## Code Concepts Explained (Scheme/Functional constructs used)

- **`lambda`**: Anonymous functions created on the fly. Used for quick, local functions without global bindings.
- **`filter`**: Extracts items from a list that satisfy a predicate function. Used to clean coordinates or evaluate active cells.
- **`append-map`**: Maps a function returning lists over a list, and flattens (appends) the resulting list-of-lists. Used to collect neighbor candidates of all alive cells.
- **`remove-duplicates`**: Drops duplicate coordinate pairs to form a clean set of candidate coordinates for the next generation.
- **`for-each`**: Applies a function to all elements of a list for side-effects (e.g., drawing shapes on the GUI canvas) rather than constructing a new list.
