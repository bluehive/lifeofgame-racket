# lifeofgame-racket

This repository contains two Racket GUI programs:
1. **Conway's Game of Life** (`lifeofgame-racket.rkt`): A pure functional implementation.
2. **Breakout Game of Life** (`breakout-lifeofgame.rkt`): A breakout game where blocks are active gliders from the Game of Life.

本リポジトリには、RacketのGUIで動く2つのプログラムが含まれています。
1. **ライフゲーム** (`lifeofgame-racket.rkt`): 純粋関数型で実装されたライフゲーム。
2. **ブロック崩しライフゲーム** (`breakout-lifeofgame.rkt`): ライフゲームの生存セル（グライダー）をブロックに見立てて崩すブロック崩しゲーム。

---

## Authors / 作成者

- **Mevius** (GitHub: [@bluehive](https://github.com/bluehive)) - Learning Scheme & Racket, Requirement Definition / 企画・要件定義・学習
- **Antigravity** (AI Assistant by Google DeepMind) - Coding, Refactoring, & Explanation / 設計・実装・解説・リファクタリング

---

## English Version

### Features

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

### How to Run

Ensure you have **Racket** installed on your system. 

#### 1. Conway's Game of Life
Run the simulation directly:
```bash
racket lifeofgame-racket.rkt
```

#### 2. Breakout Game of Life
Run the breakout game (Move paddle with Left/Right arrows, press Space to shoot/restart):
```bash
racket breakout-lifeofgame.rkt
```

Alternatively, open the file `lifeofgame-racket.rkt` in **DrRacket** and click the **Run** button. A graphical window titled "Life of Game" will pop up and run the simulation automatically.

---

### Code Concepts Explained (Scheme/Functional constructs used)

- **`lambda`**: Anonymous functions created on the fly. Used for quick, local functions without global bindings.
- **`filter`**: Extracts items from a list that satisfy a predicate function. Used to clean coordinates or evaluate active cells.
- **`append-map`**: Maps a function returning lists over a list, and flattens (appends) the resulting list-of-lists. Used to collect neighbor candidates of all alive cells.
- **`remove-duplicates`**: Drops duplicate coordinate pairs to form a clean set of candidate coordinates for the next generation.
- **`for-each`**: Applies a function to all elements of a list for side-effects (e.g., drawing shapes on the GUI canvas) rather than constructing a new list.

---

## 日本語版

### 特徴

1. **純粋関数型スタイル (Scheme風)**:
   - 配列の直接更新 (`vector-set!`) などの破壊的操作を一切行いません。
   - 盤面（グリッド）の状態を、現在生きているセルの座標ペア `(x . y)` のリストのみで表現する不変（イミュータブル）な設計です。
   - 再帰およびLisp/Schemeの基本関数（`map`, `filter`, `lambda`, `for-each`）を最大限活用しています。

2. **無限平面のサポート (理論上)**:
   - 盤面の状態が「生存セルの座標の集合」として表現されるため、ライフゲームの計算コア自体はグリッドの幅や高さの制限を受けず、理論上無限の平面で計算可能です。画面外の境界チェックはGUI描画時にのみ適用されます。

3. **GUIによる可視化**:
   - Racket標準の `racket/gui/base` ライブラリを使用しています。
   - 実行すると自動的にグラフィカルウィンドウが開き、REPLやコンソール出力を汚すことなく、設定した間隔（デフォルト: 300ms）で滑らかにアニメーション表示されます。

4. **4つのグライダー初期配置**:
   - 初期状態で4つのグライダーが配置されており、それぞれが移動して衝突や安定パターンの形成を行う様子を観察できます。

---

### 実行方法

マシンに **Racket** がインストールされていることを確認し、ターミナルからスクリプトを実行します。

#### 1. ライフゲーム単体
```bash
racket lifeofgame-racket.rkt
```

#### 2. ブロック崩しライフゲーム
左右矢印キーでパドルを操作し、スペースキーでボールを発射（またはゲームオーバー時の再起動）します。
```bash
racket breakout-lifeofgame.rkt
```

または、**DrRacket** で `lifeofgame-racket.rkt` を開き、画面右上の **Run（実行）** ボタンをクリックします。「Life of Game」というタイトルのウィンドウが開き、シミュレーションが自動的に開始されます。

---

### 使用している関数の解説（Scheme/関数型の基礎概念）

- **`lambda`**: その場で使い捨てるための「無名関数」を作ります。一度しか使わない処理を一時的に定義するのに便利です。
- **`filter`**: リストから、指定した条件（真偽値を返す関数）に合致する要素だけを抽出して新しいリストを作ります。生存セルのフィルタリングなどに使用しています。
- **`append-map`**: リストの各要素に関数を適用して得られた「リストのリスト」を平坦化（flatten）して1つの平らなリストに結合します。全生存セルの周囲の座標リストを合体させるために使っています。
- **`remove-duplicates`**: リストから重複する要素を取り除き、ユニークな値のみを返します。次世代で生存/誕生の判定対象となるセルの重複を取り除くのに使っています。
- **`for-each`**: `map` に似ていますが、新しいリストを作るためではなく、画面への描画やコンソール出力といった「副作用（手続き）」をリストの要素に順番に実行するために使います。

---

## License / ライセンス

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.  
このプロジェクトはMITライセンスの下で公開されています。詳細は [LICENSE](LICENSE) ファイルをご覧ください。
