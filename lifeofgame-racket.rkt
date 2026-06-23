#lang racket
(require racket/gui/base)

;; グリッドのサイズ
(define WIDTH 30)
(define HEIGHT 20)
(define CELL-SIZE 15) ;; 1セルのピクセルサイズ

;; -------------------------------------------------------------
;; ライフゲームのコアロジック (純粋関数型 / Schemeスタイル)
;; -------------------------------------------------------------

;; セルは (x . y) のペアで表現され、グリッドの状態は生存セルのリストで表される。
;; 例: '((3 . 2) (4 . 3) ...)

;; あるセルが生存セルリストに含まれているか判定する
(define (alive? cells cell)
  (and (member cell cells) #t))

;; あるセルの周囲8方向 of 座標ペアリストを返す
(define (cell-neighbors cell)
  (let ([x (car cell)] [y (cdr cell)])
    (list (cons (- x 1) (- y 1)) (cons x (- y 1)) (cons (+ x 1) (- y 1))
          (cons (- x 1) y)                        (cons (+ x 1) y)
          (cons (- x 1) (+ y 1)) (cons x (+ y 1)) (cons (+ x 1) (+ y 1)))))

;; あるセルの周囲にある生存セルの個数をカウントする
(define (count-alive-neighbors cells cell)
  ;; 【解説】
  ;; - lambda: 「名前のない使い捨ての関数」をその場で作る（ここでは引数 n を受け取って生存判定する）。
  ;; - filter: リストから条件に合う（関数が真を返す）要素だけを抽出して新しいリストを作る。
  ;; ここでは周囲8マスのリストから「生存しているセル」だけを抽出し、その length (長さ) を数えている。
  (length (filter (lambda (n) (alive? cells n)) (cell-neighbors cell))))

;; 次の世代の生存セルリストを計算する
(define (next-generation cells)
  ;; 生存候補となるのは「現在生きているセル」および「生きているセルの隣接セル」のみ
  (let* (;; 【解説】
         ;; - append-map: map を実行したあと、返ってきた「リストのリスト」を平らに繋ぎ合わせる (フラット化)。
         ;; ここでは全生存セルの周囲8マスのリストをそれぞれ求め、それらを1つの平らなリストに結合している。
         [all-neighbors (append-map cell-neighbors cells)]
         
         ;; 【解説】
         ;; - remove-duplicates: リストから重複する要素を取り除き、ユニークな要素だけのリストを返す。
         ;; ここでは「生存セル」と「全隣接セル」を結合したリストから重複を除き、次世代の判定候補の全座標を作っている。
         [candidates (remove-duplicates (append cells all-neighbors))]
         
         [next-alive?
          (lambda (cell)
            (let ([currently-alive? (alive? cells cell)]
                  [neighbors-count (count-alive-neighbors cells cell)])
              (if currently-alive?
                  (or (= neighbors-count 2) (= neighbors-count 3))
                  (= neighbors-count 3))))])
    (filter next-alive? candidates)))

;; 初期状態の生存セルリスト (4つのグライダーを配置)
(define (init-cells)
  (append
   ;; 1つ目のグライダー
   '((3 . 2) (4 . 3) (2 . 4) (3 . 4) (4 . 4))
   ;; 2つ目のグライダー
   '((12 . 4) (13 . 5) (11 . 6) (12 . 6) (13 . 6))
   ;; 3つ目のグライダー
   '((21 . 2) (22 . 3) (20 . 4) (21 . 4) (22 . 4))
   ;; 4つ目のグライダー
   '((6 . 9) (7 . 10) (5 . 11) (6 . 11) (7 . 11))))

;; -------------------------------------------------------------
;; GUIとイベントループ
;; -------------------------------------------------------------

;; 現在の生存セルリスト
(define current-cells (init-cells))

;; GUIのセットアップ
(define frame
  (new frame%
       [label "Life of Game"]
       [width (* WIDTH CELL-SIZE)]
       [height (* HEIGHT CELL-SIZE)]))

(define canvas
  (new canvas%
       [parent frame]
       [paint-callback
        (lambda (canvas dc)
          ;; 背景をクリア (白)
          (send dc set-background (make-object color% "white"))
          (send dc clear)
          ;; セルの描画 (黒)
          (send dc set-brush (make-object color% "black") 'solid)
          (send dc set-pen (make-object color% "black") 1 'solid)
          
          ;; 【解説】
          ;; - for-each: map に似ているが、新しいリストを返すのではなく、
          ;;   リストの各要素に対して順番に関数を適用して「描画」や「出力」などの副作用を実行する。
          ;; 生存しているセルを順に取り出し、それぞれの位置に四角形を描画する。
          (for-each
           (lambda (cell)
             (let ([x (car cell)] [y (cdr cell)])
               ;; 画面の境界内にあるセルのみ描画
               (when (and (<= 0 x (- WIDTH 1))
                          (<= 0 y (- HEIGHT 1)))
                 (send dc draw-rectangle
                       (* x CELL-SIZE)
                       (* y CELL-SIZE)
                       CELL-SIZE
                       CELL-SIZE))))
           current-cells))]))

;; タイマーによる定期的な更新 (300ms間隔)
(define timer
  (new timer%
       [notify-callback
        (lambda ()
          (set! current-cells (next-generation current-cells))
          (send canvas refresh))]
       [interval 300]))

;; 実行開始
(send frame show #t)
(send timer start 300)
