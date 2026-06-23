#lang racket
;; Copyright (c) 2026 mevius
;; Licensed under the MIT License.
;; See LICENSE file in the project root for full license text.

(require racket/gui/base)

;; -------------------------------------------------------------
;; 定数と画面設定
;; -------------------------------------------------------------
(define WIDTH 40)          ;; グリッドの列数
(define HEIGHT 30)         ;; グリッドの行数
(define CELL-SIZE 16)      ;; 1セルのピクセルサイズ
(define SCREEN-WIDTH (* WIDTH CELL-SIZE))   ;; 640ピクセル
(define SCREEN-HEIGHT (* HEIGHT CELL-SIZE))  ;; 480ピクセル

(define BALL-SIZE 12)
(define PADDLE-WIDTH 100)
(define PADDLE-HEIGHT 12)
(define PADDLE-Y (- SCREEN-HEIGHT PADDLE-HEIGHT 15))

;; -------------------------------------------------------------
;; ライフゲームのコアロジック (不変リストスタイル)
;; -------------------------------------------------------------

;; あるセルが生存セルリストに含まれているか判定する
(define (alive? cells cell)
  (and (member cell cells) #t))

;; あるセルの周囲8方向の座標ペアリストを返す
(define (cell-neighbors cell)
  (let ([x (car cell)] [y (cdr cell)])
    (list (cons (- x 1) (- y 1)) (cons x (- y 1)) (cons (+ x 1) (- y 1))
          (cons (- x 1) y)                        (cons (+ x 1) y)
          (cons (- x 1) (+ y 1)) (cons x (+ y 1)) (cons (+ x 1) (+ y 1)))))

;; あるセルの周囲にある生存セルの個数をカウントする
(define (count-alive-neighbors cells cell)
  (length (filter (lambda (n) (alive? cells n)) (cell-neighbors cell))))

;; 次の世代の生存セルリストを計算する
(define (next-generation cells)
  (let* ([all-neighbors (append-map cell-neighbors cells)]
         [candidates (remove-duplicates (append cells all-neighbors))]
         [next-alive?
          (lambda (cell)
            (let ([currently-alive? (alive? cells cell)]
                  [neighbors-count (count-alive-neighbors cells cell)])
              (if currently-alive?
                  (or (= neighbors-count 2) (= neighbors-count 3))
                  (= neighbors-count 3))))])
    (filter next-alive? candidates)))

;; 初期状態の生存セルリスト (4つのグライダーを上部に配置)
(define (init-cells)
  (append
   ;; 1つ目のグライダー (左上)
   '((5 . 4) (6 . 5) (4 . 6) (5 . 6) (6 . 6))
   ;; 2つ目のグライダー (中央左)
   '((15 . 5) (16 . 6) (14 . 7) (15 . 7) (16 . 7))
   ;; 3つ目のグライダー (中央右)
   '((25 . 4) (26 . 5) (24 . 6) (25 . 6) (26 . 6))
   ;; 4つ目のグライダー (右下へ降下する配置)
   '((10 . 12) (11 . 13) (9 . 14) (10 . 14) (11 . 14))))

;; -------------------------------------------------------------
;; ゲーム状態変数
;; -------------------------------------------------------------
(define current-cells '())
(define ball-x 0)
(define ball-y 0)
(define ball-vx 0)
(define ball-vy 0)
(define ball-active? #f)
(define paddle-x 0)
(define paddle-vx 0)
(define lives 3)
(define score 0)
(define game-over? #f)

;; -------------------------------------------------------------
;; 物理演算と衝突判定
;; -------------------------------------------------------------

;; 2つの矩形が重なっているか判定する (AABB衝突判定)
(define (rect-overlap? x1 y1 w1 h1 x2 y2 w2 h2)
  (and (< x1 (+ x2 w2))
       (> (+ x1 w1) x2)
       (< y1 (+ y2 h2))
       (> (+ y1 h1) y2)))

;; ボールをパドルの上に戻す
(define (reset-ball)
  (set! ball-active? #f)
  (set! ball-x (+ paddle-x (/ PADDLE-WIDTH 2) (- (/ BALL-SIZE 2))))
  (set! ball-y (- PADDLE-Y BALL-SIZE 2))
  (set! ball-vx 0)
  (set! ball-vy 0))

;; ゲーム全体の初期化
(define (init-game)
  (set! current-cells (init-cells))
  (set! paddle-x (/ (- SCREEN-WIDTH PADDLE-WIDTH) 2))
  (set! paddle-vx 0)
  (set! lives 3)
  (set! score 0)
  (set! game-over? #f)
  (reset-ball))

;; ボールの射出 (スペースキー)
(define (shoot-ball)
  (unless ball-active?
    (set! ball-active? #t)
    (set! ball-x (+ paddle-x (/ PADDLE-WIDTH 2) (- (/ BALL-SIZE 2))))
    (set! ball-y (- PADDLE-Y BALL-SIZE 2))
    (set! ball-vx (if (> (random) 0.5) 4 -4))
    (set! ball-vy -5)))

;; ボールの物理挙動と壁との反射
(define (update-ball-physics)
  (when ball-active?
    (set! ball-x (+ ball-x ball-vx))
    (set! ball-y (+ ball-y ball-vy))
    
    ;; 左右の壁での反射
    (when (<= ball-x 0)
      (set! ball-x 0)
      (set! ball-vx (- ball-vx)))
    (when (>= (+ ball-x BALL-SIZE) SCREEN-WIDTH)
      (set! ball-x (- SCREEN-WIDTH BALL-SIZE))
      (set! ball-vx (- ball-vx)))
    
    ;; 天井での反射
    (when (<= ball-y 0)
      (set! ball-y 0)
      (set! ball-vy (- ball-vy)))
    
    ;; 画面底（ミス判定）
    (when (>= ball-y SCREEN-HEIGHT)
      (set! lives (- lives 1))
      (if (<= lives 0)
          (set! game-over? #t)
          (reset-ball)))))

;; パドルとの衝突判定と反射
(define (check-paddle-collision)
  (when (rect-overlap? ball-x ball-y BALL-SIZE BALL-SIZE paddle-x PADDLE-Y PADDLE-WIDTH PADDLE-HEIGHT)
    ;; 常に上方向へ跳ね返す
    (set! ball-vy (- (abs ball-vy)))
    ;; パドルの当たる位置（中心からのずれ）によってボールの左右速度を変更
    (let* ([hit-pos (- (+ ball-x (/ BALL-SIZE 2)) paddle-x)]
           [relative-hit (/ hit-pos PADDLE-WIDTH)]    ;; 0.0 〜 1.0
           [angle-factor (- (* relative-hit 2.0) 1.0)]) ;; -1.0 〜 1.0 (左端〜右端)
      (set! ball-vx (* angle-factor 6.0)))))

;; 生存セル（ブロック）との衝突判定と反射
(define (check-cell-collisions)
  (let loop ([cells current-cells] [acc '()])
    (cond
      [(null? cells) 
       (set! current-cells (reverse acc))]
      [else
       (let* ([cell (car cells)]
              [cx (car cell)]
              [cy (cdr cell)]
              [bx (* cx CELL-SIZE)]
              [by (* cy CELL-SIZE)])
         (if (rect-overlap? ball-x ball-y BALL-SIZE BALL-SIZE bx by CELL-SIZE CELL-SIZE)
             ;; 衝突を検知した場合
             (begin
               (set! score (+ score 10))
               ;; 簡易反射物理: 衝突した中心の差分から反射方向を決定
               (let* ([ball-center-x (+ ball-x (/ BALL-SIZE 2))]
                      [ball-center-y (+ ball-y (/ BALL-SIZE 2))]
                      [block-center-x (+ bx (/ CELL-SIZE 2))]
                      [block-center-y (+ by (/ CELL-SIZE 2))]
                      [dx (- ball-center-x block-center-x)]
                      [dy (- ball-center-y block-center-y)])
                 (if (> (abs dx) (abs dy))
                     (set! ball-vx (- ball-vx))   ;; 左右側面からの衝突
                     (set! ball-vy (- ball-vy))))  ;; 上下面からの衝突
               ;; 衝突したセルを消去し、ループを抜ける（1フレームにつき1個の衝突）
               (set! current-cells (append (reverse acc) (cdr cells))))
             ;; 衝突していない場合はリストを保持して次を走査
             (loop (cdr cells) (cons cell acc))))])))

;; -------------------------------------------------------------
;; GUIとイベントハンドリング
;; -------------------------------------------------------------
(define frame
  (new frame%
       [label "Breakout Game of Life"]
       [width SCREEN-WIDTH]
       [height SCREEN-HEIGHT]
       [style '(no-resize-border)]))

;; カスタムキャンバスクラスでキー入力イベントをオーバーライド
(define game-canvas%
  (class canvas%
    (super-new)
    ;; キーボード操作
    (define/override (on-char event)
      (let ([code (send event get-key-code)]
            [release-code (send event get-key-release-code)])
        (cond
          ;; 左移動開始
          [(eq? code 'left) (set! paddle-vx -7)]
          ;; 右移動開始
          [(eq? code 'right) (set! paddle-vx 7)]
          ;; スペースでボール射出、またはゲームオーバー時に再スタート
          [(eq? code #\space)
           (if game-over?
               (init-game)
               (shoot-ball))]
          ;; キーを離した際の減速
          [(eq? code 'release)
           (cond
             [(or (eq? release-code 'left) (eq? release-code 'right))
              (set! paddle-vx 0)])])))))

(define canvas
  (new game-canvas%
       [parent frame]
       [paint-callback
        (lambda (canvas dc)
          ;; ダブルバッファによる描画処理
          (send dc set-background (make-object color% "white"))
          (send dc clear)
          
          ;; 1. 生存セル（ブロック）の描画
          (send dc set-brush (make-object color% "black") 'solid)
          (send dc set-pen (make-object color% "black") 1 'solid)
          (for-each
           (lambda (cell)
             (let ([x (car cell)] [y (cdr cell)])
               (when (and (<= 0 x (- WIDTH 1))
                          (<= 0 y (- HEIGHT 1)))
                 (send dc draw-rectangle
                       (* x CELL-SIZE)
                       (* y CELL-SIZE)
                       CELL-SIZE
                       CELL-SIZE))))
           current-cells)
          
          ;; 2. パドルの描画
          (send dc set-brush (make-object color% "blue") 'solid)
          (send dc set-pen (make-object color% "blue") 1 'solid)
          (send dc draw-rectangle paddle-x PADDLE-Y PADDLE-WIDTH PADDLE-HEIGHT)
          
          ;; 3. ボールの描画
          (send dc set-brush (make-object color% "red") 'solid)
          (send dc set-pen (make-object color% "red") 1 'solid)
          (send dc draw-rectangle ball-x ball-y BALL-SIZE BALL-SIZE)
          
          ;; 4. スコア、ライフ、ステータスの描画
          (send dc set-text-foreground (make-object color% "black"))
          (send dc draw-text (string-append "SCORE: " (number->string score)) 10 10)
          (send dc draw-text (string-append "LIVES: " (number->string lives)) 120 10)
          
          ;; ゲームオーバー表示
          (when game-over?
            (send dc set-text-foreground (make-object color% "red"))
            (send dc draw-text "GAME OVER - Press SPACE to Restart"
                  (- (/ SCREEN-WIDTH 2) 110)
                  (- (/ SCREEN-HEIGHT 2) 10))))]))

;; -------------------------------------------------------------
;; メインゲームループ
;; -------------------------------------------------------------
(define frame-counter 0)

(define (game-tick)
  (unless game-over?
    ;; 1. パドルの移動と画面端でのクリッピング
    (set! paddle-x (+ paddle-x paddle-vx))
    (when (< paddle-x 0) (set! paddle-x 0))
    (when (> paddle-x (- SCREEN-WIDTH PADDLE-WIDTH))
      (set! paddle-x (- SCREEN-WIDTH PADDLE-WIDTH)))
    
    ;; 2. ボール非アクティブ時はパドル中央に追従
    (unless ball-active?
      (set! ball-x (+ paddle-x (/ PADDLE-WIDTH 2) (- (/ BALL-SIZE 2))))
      (set! ball-y (- PADDLE-Y BALL-SIZE 2)))
    
    ;; 3. 物理演算と衝突判定の更新
    (update-ball-physics)
    (check-paddle-collision)
    (check-cell-collisions)
    
    ;; 4. ライフゲームの世代交代 (約320ms / 20フレームごと)
    (set! frame-counter (+ frame-counter 1))
    (when (>= frame-counter 20)
      (set! frame-counter 0)
      (set! current-cells (next-generation current-cells)))
    
    ;; 生存セルが全て消滅した場合はグライダーを再生成
    (when (null? current-cells)
      (set! current-cells (init-cells))
      (reset-ball)))
  
  ;; 画面のリフレッシュ
  (send canvas refresh))

;; 60 FPS (16ms 間隔) で動作するメインタイマー
(define timer
  (new timer%
       [notify-callback game-tick]
       [interval 16]))

;; -------------------------------------------------------------
;; 実行開始
;; -------------------------------------------------------------
(init-game)
(send frame show #t)
(send timer start 16)
