#lang racket
;; Copyright (c) 2026 mevius
;; Licensed under the MIT License.
;; See LICENSE file in the project root for full license text.

(require racket/gui/base)

;; -------------------------------------------------------------
;; カラー設定 (Color Configuration)
;; -------------------------------------------------------------
(define COLOR-BACKGROUND "white")    ;; 画面の背景色
(define COLOR-CELL "black")          ;; 生存セル（ブロック）の色
(define COLOR-PADDLE "orange")       ;; パドルの色（視認性の高いオレンジ）
(define COLOR-BALL "red")            ;; ボールの色
(define COLOR-TEXT "black")          ;; スコア・ライフ表示の文字色
(define COLOR-GAMEOVER "red")        ;; ゲームオーバー表示の文字色

;; -------------------------------------------------------------
;; 定数と画面設定（以前の1.5倍の解像度に調整）
;; -------------------------------------------------------------
(define WIDTH 40)          ;; ライフゲームのグリッド列数（横幅方向のセル数）
(define HEIGHT 30)         ;; ライフゲームのグリッド行数（縦幅方向のセル数）
(define CELL-SIZE 24)      ;; 1セルのピクセルサイズ（1.5倍に拡大：16 -> 24）
(define SCREEN-WIDTH (* WIDTH CELL-SIZE))   ;; GUI画面全体の幅（960ピクセル）
(define SCREEN-HEIGHT (* HEIGHT CELL-SIZE))  ;; GUI画面全体の高さ（720ピクセル）

(define BALL-SIZE 16)      ;; ボールのサイズ（画面拡大に合わせて調整）
(define PADDLE-WIDTH 150)  ;; パドルの幅（画面拡大に合わせて調整）
(define PADDLE-HEIGHT 15)  ;; パドルの高さ（画面拡大に合わせて調整）
;; パドルをGUI画面下部から少し離した位置（下から50ピクセル上）に配置
(define PADDLE-Y (- SCREEN-HEIGHT PADDLE-HEIGHT 50))

(define PADDLE-SPEED 11)   ;; パドルの移動速度（元の速度 9 の 1.2倍： 10.8 -> 11）

;; -------------------------------------------------------------
;; ライフゲームのコアロジック (不変リストスタイル)
;; -------------------------------------------------------------

;; あるセルが生存セルリストに含まれているか判定する（#t または #f を返す）
(define (alive? cells cell)
  (and (member cell cells) #t))

;; 指定されたセルの周囲8方向（隣接マス）の座標ペアリストを返す
(define (cell-neighbors cell)
  (let ([x (car cell)] [y (cdr cell)])
    (list (cons (- x 1) (- y 1)) (cons x (- y 1)) (cons (+ x 1) (- y 1))
          (cons (- x 1) y)                        (cons (+ x 1) y)
          (cons (- x 1) (+ y 1)) (cons x (+ y 1)) (cons (+ x 1) (+ y 1)))))

;; 指定されたセルの周囲に存在する生存セルの個数をカウントする
(define (count-alive-neighbors cells cell)
  (length (filter (lambda (n) (alive? cells n)) (cell-neighbors cell))))

;; 次の世代の生存セルリストを計算する（ライフゲームのメイン遷移規則）
(define (next-generation cells)
  ;; 生存候補となるのは「現在生きているセル」および「生きているセルの隣接セル」のみ
  (let* ([all-neighbors (append-map cell-neighbors cells)]
         [candidates (remove-duplicates (append cells all-neighbors))]
         [next-alive?
          (lambda (cell)
            (let ([currently-alive? (alive? cells cell)]
                  [neighbors-count (count-alive-neighbors cells cell)])
              (if currently-alive?
                  ;; 生存条件: 隣接する生存セルが2個または3個
                  (or (= neighbors-count 2) (= neighbors-count 3))
                  ;; 誕生条件: 隣接する生存セルがちょうど3個
                  (= neighbors-count 3))))])
    (filter next-alive? candidates)))

;; 初期状態の生存セルリスト (4つのグライダーを画面上部に配置)
(define (init-cells)
  (append
   ;; 1つ目のグライダー (左上)
   '((5 . 4) (6 . 5) (4 . 6) (5 . 6) (6 . 6))
   ;; 2つ目のグライダー (中央左)
   '((15 . 5) (16 . 6) (14 . 7) (15 . 7) (16 . 7))
   ;; 3つ目のグライダー (中央右)
   '((25 . 4) (26 . 5) (24 . 6) (25 . 6) (26 . 6))
   ;; 4つ目のグライダー (中央下側)
   '((10 . 12) (11 . 13) (9 . 14) (10 . 14) (11 . 14))))

;; -------------------------------------------------------------
;; ゲーム状態変数
;; -------------------------------------------------------------
(define current-cells '())  ;; 現在生存しているセルの座標リスト
(define ball-x 0)           ;; ボールのX座標（ピクセル）
(define ball-y 0)           ;; ボールのY座標（ピクセル）
(define ball-vx 0)          ;; ボールのX方向の移動速度（ピクセル/フレーム）
(define ball-vy 0)          ;; ボールのY方向の移動速度（ピクセル/フレーム）
(define ball-active? #f)    ;; ボールが発射されて動いているかどうか
(define paddle-x 0)         ;; パドルの左端のX座標
(define paddle-vx 0)        ;; パドルの現在の移動速度
(define lives 3)            ;; プレイヤーの残機（ライフ）
(define score 0)            ;; プレイヤーの獲得スコア
(define game-over? #f)      ;; ゲームオーバー状態のフラグ

;; -------------------------------------------------------------
;; 物理演算と衝突判定
;; -------------------------------------------------------------

;; 2つの矩形（四角形）が重なっているか判定する (AABB衝突判定アルゴリズム)
(define (rect-overlap? x1 y1 w1 h1 x2 y2 w2 h2)
  (and (< x1 (+ x2 w2))
       (> (+ x1 w1) x2)
       (< y1 (+ y2 h2))
       (> (+ y1 h1) y2)))

;; ボールの状態をリセットし、パドルの上の初期位置に配置する
(define (reset-ball)
  (set! ball-active? #f)
  (set! ball-x (+ paddle-x (/ PADDLE-WIDTH 2) (- (/ BALL-SIZE 2))))
  (set! ball-y (- PADDLE-Y BALL-SIZE 2))
  (set! ball-vx 0)
  (set! ball-vy 0))

;; ゲーム全体の状態を完全に初期化（ゲーム開始時・リスタート時）
(define (init-game)
  (set! current-cells (init-cells))
  (set! paddle-x (/ (- SCREEN-WIDTH PADDLE-WIDTH) 2))
  (set! paddle-vx 0)
  (set! lives 3)
  (set! score 0)
  (set! game-over? #f)
  (reset-ball))

;; ボールを発射する (スペースキー押下時)
(define (shoot-ball)
  (unless ball-active?
    (set! ball-active? #t)
    (set! ball-x (+ paddle-x (/ PADDLE-WIDTH 2) (- (/ BALL-SIZE 2))))
    (set! ball-y (- PADDLE-Y BALL-SIZE 2))
    ;; ランダムな左右の初速と、上方向への初速を設定（画面拡大に合わせて速度調整）
    (set! ball-vx (if (> (random) 0.5) 5 -5))
    (set! ball-vy -7)))

;; ボールの移動および画面の上下左右の境界（壁）との反射処理
(define (update-ball-physics)
  (when ball-active?
    (set! ball-x (+ ball-x ball-vx))
    (set! ball-y (+ ball-y ball-vy))
    
    ;; 左右の壁に衝突した場合は反発させる
    (when (<= ball-x 0)
      (set! ball-x 0)
      (set! ball-vx (- ball-vx)))
    (when (>= (+ ball-x BALL-SIZE) SCREEN-WIDTH)
      (set! ball-x (- SCREEN-WIDTH BALL-SIZE))
      (set! ball-vx (- ball-vx)))
    
    ;; 天井に衝突した場合は反発させる
    (when (<= ball-y 0)
      (set! ball-y 0)
      (set! ball-vy (- ball-vy)))
    
    ;; 画面底に落ちた場合（ミス判定）
    (when (>= ball-y SCREEN-HEIGHT)
      (set! lives (- lives 1))
      (if (<= lives 0)
          (set! game-over? #t)
          (reset-ball)))))

;; パドルとボールの衝突判定および反発（当たる位置による反射角の変化）
(define (check-paddle-collision)
  (when (rect-overlap? ball-x ball-y BALL-SIZE BALL-SIZE paddle-x PADDLE-Y PADDLE-WIDTH PADDLE-HEIGHT)
    ;; パドル上面に当たったので、Y方向の速度を常に上方向（マイナス）へ反転
    (set! ball-vy (- (abs ball-vy)))
    ;; パドルのどの位置（中心からどれだけ離れているか）にボールが当たったかを計算
    (let* ([hit-pos (- (+ ball-x (/ BALL-SIZE 2)) paddle-x)]
           [relative-hit (/ hit-pos PADDLE-WIDTH)]    ;; 0.0（左端） 〜 1.0（右端）
           [angle-factor (- (* relative-hit 2.0) 1.0)]) ;; -1.0 〜 1.0 にスケーリング
      ;; 当たった位置によってX方向の反射速度（曲がり具合）を動的に決定
      (set! ball-vx (* angle-factor 7.0)))))

;; 生存セル（ブロック）とボールの衝突判定、セルの破壊、および反射
(define (check-cell-collisions)
  ;; リストを順次走査して衝突したセルを見つけるループ
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
             ;; 衝突を検知した場合の処理
             (begin
               (set! score (+ score 10))
               ;; 衝突面（上下か左右か）を決定し、反射ベクトルを計算
               (let* ([ball-center-x (+ ball-x (/ BALL-SIZE 2))]
                      [ball-center-y (+ ball-y (/ BALL-SIZE 2))]
                      [block-center-x (+ bx (/ CELL-SIZE 2))]
                      [block-center-y (+ by (/ CELL-SIZE 2))]
                      [dx (- ball-center-x block-center-x)]
                      [dy (- ball-center-y block-center-y)])
                 (if (> (abs dx) (abs dy))
                     (set! ball-vx (- ball-vx))   ;; 左右の側面から当たった場合はX速度を反転
                     (set! ball-vy (- ball-vy))))  ;; 上下の面から当たった場合はY速度を反転
               ;; 当たったセルをリストから除外し、このフレームの衝突処理を終了（貫通バグ防止）
               (set! current-cells (append (reverse acc) (cdr cells))))
             ;; 衝突していないセルはアキュムレータに蓄積してループを継続
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

;; キーボード入力を受け取るためのカスタムキャンバスクラス
(define game-canvas%
  (class canvas%
    (super-new)
    ;; キーイベントハンドラ
    (define/override (on-char event)
      (let ([code (send event get-key-code)]
            [release-code (send event get-key-release-code)])
        (cond
          ;; 左矢印キーで左方向への移動速度を設定
          [(eq? code 'left) (set! paddle-vx (- PADDLE-SPEED))]
          ;; 右矢印キーで右方向への移動速度を設定
          [(eq? code 'right) (set! paddle-vx PADDLE-SPEED)]
          ;; スペースキーで発射、またはゲームオーバー時のリスタート
          [(eq? code #\space)
           (if game-over?
               (init-game)
               (shoot-ball))]
          ;; キーが離された場合はパドルの速度を停止する
          [(eq? code 'release)
           (cond
             [(or (eq? release-code 'left) (eq? release-code 'right))
              (set! paddle-vx 0)])])))))

(define canvas
  (new game-canvas%
       [parent frame]
       [paint-callback
        (lambda (canvas dc)
          ;; チラつき防止（ダブルバッファ）を利用した描画処理
          (send dc set-background (make-object color% COLOR-BACKGROUND))
          (send dc clear)
          
          ;; 1. 生存セル（ブロック）の描画（指定色）
          (send dc set-brush (make-object color% COLOR-CELL) 'solid)
          (send dc set-pen (make-object color% COLOR-CELL) 1 'solid)
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
          
          ;; 2. パドルの描画（指定色）
          (send dc set-brush (make-object color% COLOR-PADDLE) 'solid)
          (send dc set-pen (make-object color% COLOR-PADDLE) 1 'solid)
          (send dc draw-rectangle paddle-x PADDLE-Y PADDLE-WIDTH PADDLE-HEIGHT)
          
          ;; 3. ボールの描画（指定色）
          (send dc set-brush (make-object color% COLOR-BALL) 'solid)
          (send dc set-pen (make-object color% COLOR-BALL) 1 'solid)
          (send dc draw-rectangle ball-x ball-y BALL-SIZE BALL-SIZE)
          
          ;; 4. スコア、ライフ、操作情報の描画
          (send dc set-text-foreground (make-object color% COLOR-TEXT))
          (send dc draw-text (string-append "SCORE: " (number->string score)) 15 15)
          (send dc draw-text (string-append "LIVES: " (number->string lives)) 150 15)
          
          ;; ゲームオーバー状態のテキスト表示
          (when game-over?
            (send dc set-text-foreground (make-object color% COLOR-GAMEOVER))
            (send dc draw-text "GAME OVER - Press SPACE to Restart"
                  (- (/ SCREEN-WIDTH 2) 130)
                  (- (/ SCREEN-HEIGHT 2) 10))))]))

;; -------------------------------------------------------------
;; メインゲームループ
;; -------------------------------------------------------------
(define frame-counter 0)

;; 毎フレーム（16ms）実行される状態更新処理
(define (game-tick)
  (unless game-over?
    ;; 1. パドルの移動と画面左右端でのクリッピング（はみ出し防止）
    (set! paddle-x (+ paddle-x paddle-vx))
    (when (< paddle-x 0) (set! paddle-x 0))
    (when (> paddle-x (- SCREEN-WIDTH PADDLE-WIDTH))
      (set! paddle-x (- SCREEN-WIDTH PADDLE-WIDTH)))
    
    ;; 2. ボール未発射時はパドルの上部に追従させる
    (unless ball-active?
      (set! ball-x (+ paddle-x (/ PADDLE-WIDTH 2) (- (/ BALL-SIZE 2))))
      (set! ball-y (- PADDLE-Y BALL-SIZE 2)))
    
    ;; 3. 各種物理演算と衝突判定の更新
    (update-ball-physics)
    (check-paddle-collision)
    (check-cell-collisions)
    
    ;; 4. ライフゲームの世代交代（20フレーム = 約320msごとに実行）
    (set! frame-counter (+ frame-counter 1))
    (when (>= frame-counter 20)
      (set! frame-counter 0)
      (set! current-cells (next-generation current-cells)))
    
    ;; すべてのセルを壊した場合は、ステージクリアとしてグライダーを再生成
    (when (null? current-cells)
      (set! current-cells (init-cells))
      (reset-ball)))
  
  ;; 画面描画の再要求（paint-callback が呼び出される）
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
