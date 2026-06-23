#lang racket
;; Copyright (c) 2026 mevius
;; Licensed under the MIT License.
;; See LICENSE file in the project root for full license text.

(require rackunit
         "lifeofgame-racket.rkt")

;; -------------------------------------------------------------
;; ユニットテスト (最低10個のテストケース)
;; -------------------------------------------------------------

;; テスト用のセルパターン定義
(define test-cells-glider
  '((3 . 2) (4 . 3) (2 . 4) (3 . 4) (4 . 4)))

(define test-cells-block
  '((10 . 10) (11 . 10)
    (10 . 11) (11 . 11)))

(define test-cells-blinker-horiz
  '((5 . 5) (6 . 5) (7 . 5)))

(define test-cells-blinker-vert
  '((6 . 4) (6 . 5) (6 . 6)))

;; 座標ペアの比較関数 (ソート用)
(define (cell<? a b)
  (if (= (car a) (car b))
      (< (cdr a) (cdr b))
      (< (car a) (car b))))

;; --- Test 1: alive? - 空のグリッドでの生存判定 ---
(check-false (alive? '() '(1 . 1))
             "空のグリッドではどのセルも死んでいるべき")

;; --- Test 2: alive? - 生存しているセルの判定 ---
(check-true (alive? test-cells-glider '(3 . 2))
            "リストに存在するセルは生きているべき")

;; --- Test 3: alive? - 死んでいるセルの判定 ---
(check-false (alive? test-cells-glider '(0 . 0))
             "リストに存在しないセルは死んでいるべき")

;; --- Test 4: cell-neighbors - 周囲のセルの個数が8個であること ---
(check-equal? (length (cell-neighbors '(0 . 0))) 8
              "任意のセルの隣接セルは常に8個であるべき")

;; --- Test 5: cell-neighbors - 正確な座標リストが取得できること ---
(check-equal? (cell-neighbors '(0 . 0))
              '((-1 . -1) (0 . -1) (1 . -1)
                (-1 .  0)           (1 .  0)
                (-1 .  1) (0 .  1) (1 .  1))
              "周囲8マスの相対座標ペアリストが正しく生成されるべき")

;; --- Test 6: count-alive-neighbors - 周囲に生きているセルがいないケース ---
(check-equal? (count-alive-neighbors '() '(5 . 5)) 0
              "生存セルがいない場合、隣接生存数は0であるべき")

;; --- Test 7: count-alive-neighbors - 生存セルが隣接しているケース ---
(check-equal? (count-alive-neighbors test-cells-blinker-horiz '(6 . 5)) 2
              "横三連の真ん中のセルは、左右に2つの隣接生存セルを持つべき")

;; --- Test 8: next-generation - ルール1: 過疎 (生存セルが隣接1以下で死滅) ---
(check-false (alive? (next-generation '((5 . 5) (6 . 5))) '(5 . 5))
             "隣接する生存セルが1つしかない生存セルは、過疎により次の世代で死滅すべき")

;; --- Test 9: next-generation - ルール2: 生存 (生存セルが隣接2または3で生存) ---
(check-true (alive? (next-generation test-cells-blinker-horiz) '(6 . 5))
            "隣接する生存セルが2つある生存セルは、次の世代でも生存し続けるべき")

;; --- Test 10: next-generation - ルール3: 過密 (生存セルが隣接4以上で死滅) ---
;; 中央のセル (1 . 1) に 5 個のセルが隣接している状態
(define overpopulated-cells '((1 . 1) (0 . 0) (1 . 0) (2 . 0) (0 . 1) (2 . 1)))
(check-false (alive? (next-generation overpopulated-cells) '(1 . 1))
             "隣接する生存セルが4つ以上ある生存セルは、過密により次の世代で死滅すべき")

;; --- Test 11: next-generation - ルール4: 誕生 (死滅セルが隣接3で誕生) ---
(check-true (alive? (next-generation test-cells-blinker-horiz) '(6 . 4))
            "周囲に3つの生存セルを持つ死滅セルは、次の世代で誕生すべき")

;; --- Test 12: next-generation - 固定パターン (Block) の不変性 ---
(check-equal? (sort (next-generation test-cells-block) cell<?)
              (sort test-cells-block cell<?)
              "2x2のブロックは次の世代でも同一の形状を維持すべき")

;; --- Test 13: next-generation - 振動パターン (Blinker) の一周期の遷移 ---
(define next-blinker (next-generation test-cells-blinker-horiz))
;; 横棒 blinker -> 縦棒 blinker
(check-equal? (sort next-blinker cell<?)
              (sort test-cells-blinker-vert cell<?)
              "横に並んだ3マスのバーは、次の世代で縦に並んだバーに変遷すべき")

(exit)
