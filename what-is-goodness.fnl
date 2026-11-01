;; title:   game title
;; author:  game developer, email, etc.
;; desc:    short description
;; site:    website link
;; license: MIT License (change this to your license of choice)
;; version: 0.1
;; script:  fennel
;; strict:  true

(var current-scene nil)

(fn round [x]
  (math.floor (+ x 0.5)))

(local scenes
  (do
    (var scenes [])

    (fn push-scene! [scene]
      (table.insert scenes 1 scene))

    (fn pop-scene! []
      (table.remove scenes 1))

    (fn set-scene! [scene]
      (set scenes [scene]))

    (fn swap-root-scene! [new-scene]
      (tset scenes 2 new-scene))

    (fn run-scenes! []
      (when (> (length scenes) 0)
        (let [top (. scenes 1)]
          (top.input)
          (top.update)
          (for [i (length scenes) 1 -1]
            (let [s (. scenes i)]
              (s.render))))))

    {: push-scene! : pop-scene! : set-scene!
     : swap-root-scene! : run-scenes!}))

;; "frames, width height, frame-duration in number of frames, loop"
(fn make-animation [frames w h frame-duration loop?] 
  [frames w h frame-duration loop?])

(fn make-animator [init-animation]
  {:frame 0
   :frame-timer 0
   :animation init-animation
   :finished? false})

(fn set-animation! [animator animation]
  (doto animator
    (tset :frame 0)
    (tset :frame-timer 0)
    (tset :animation animation)
    (tset :finished? false)))

(fn update-animation! [animator]
  (when (not animator.finished?)
    (let [[frames _ _ frame-duration loop] animator.animation]
      (when (<= frame-duration animator.frame-timer)
        (do
          (set animator.frame-timer 0)
          (if (and (not loop) (= (+ animator.frame 1) (length frames)))
              (set animator.finished? true)
              (set animator.frame (% (+ animator.frame 1) (length frames))))))

      (set animator.frame-timer (+ 1 animator.frame-timer))
      animator)))

(local player-module
       (do
         (local jump-force -4)
         (local ground-y 110)
         (local speed 1.5)
         (local gravity 0.2)
         (local run-animation (make-animation [1 3] 2 2 20 true))
         (local block-animation (make-animation [2 4] 2 2 20 false))
         (local slash-animation (make-animation [256 257 258 259 260 261 262] 1 2 1 false))

         (fn move-player-x! [player pos?]
           (when (and (not player.blocking?)
                      (not player.rolling?))
             (let [new-x (+ player.x (* speed (if pos? 1 -1)))]
               (tset player :direction (if pos? :right :left))
               (tset player :x new-x))))

         (fn jump! [player]
           (when (and player.grounded?
                      (not player.blocking?)
                      (not player.rolling?)) 
             (tset player :grounded? false)
             (tset player :y (- player.y 1))
             (tset player :vy jump-force)))

         (fn dodge-roll! [player roll?]
           (if roll?
               (let [roll-dir roll?]
                 (set-animation! player.animator block-animation)
                 (doto player 
                   (tset :rolling? [roll-dir 30])
                   (tset :vy -0.5)))
               
               (do 
                 (set player.blocking? 40)
                 (set-animation! player.animator block-animation))))

         (fn attack! [player]
           (set player.attacking? true)
           (set-animation! player.slash-animator slash-animation))

         (fn update-player! [player pos?]
           (when (< player.y ground-y)
             (set player.vy (+ player.vy gravity)))

           (when (<= ground-y player.y)
             (set player.grounded? true)
             (set player.y ground-y)
             (set player.vy 0))

           (when player.blocking?
             (set player.blocking? (- player.blocking? 1))
             (when (= player.blocking? 0)
               (set player.blocking? nil)
               (set-animation! player.animator run-animation)))

           (when player.rolling?
             (let [rolling player.rolling?
                   [dir time] rolling]
               (set (. rolling 2) (- time 1))
               (set player.x (+ player.x (if (= dir :left) -2 2)))
               (when (= time 0)
                 (set player.rolling? nil)
                 (set-animation! player.animator run-animation))))

           (update-animation! player.animator)
           (update-animation! player.slash-animator)
           (set player.y (+ player.vy player.y)))

         (fn render-player! [player]
           (let [animator player.animator
                 [frames w h] animator.animation
                 frame-id (. frames (+ 1 animator.frame))]
             (spr frame-id player.x player.y 0 1 (if (= player.direction :right) 0 1) 0 w h))

           (let [animator player.slash-animator
                 [frames w h] animator.animation
                 frame-id (. frames (+ 1 animator.frame))]
             (spr frame-id (+ player.x
                              (if (= player.direction :right) 16 -16))
                  (- player.y 8) 0 2
                  (if (= player.direction :right) 0 1)
                  0 w h))

           )

         (fn make-slash [x y]
           {:x x :y y}

           )

         (fn make-player []
           {:x 30 :y 0 :hp 3 :vx 0 :vy 0
            :direction :right :grounded? false
            :animator (make-animator run-animation)
            :slash-animator (make-animator slash-animation)
            :update update-player!
            :render render-player!})

         {: make-player : move-player-x! : jump! : attack! : dodge-roll!}))

(fn make-boss-scene []
  (local entities [])
  (local player (player-module.make-player))
  (table.insert entities player)

  {:input (fn []
            (when (btn 0)
              (player-module.jump! player))
            (when (btn 3)
              (player-module.move-player-x! player true))
            (when (btn 2)
              (player-module.move-player-x! player false))
            (when (btnp 4)
              (player-module.attack! player))
            (when (btnp 5)
              (if (btn 2)
                  (player-module.dodge-roll! player :left)

                  (btn 3)
                  (player-module.dodge-roll! player :right)

                  (player-module.dodge-roll! player nil)))
            )
   :update (fn []
             (each [_ e (ipairs entities)]
               (e:update)))
   :render (fn []
             (cls 5)
             (each [_ e (ipairs entities)]
               (e:render))
             (print "Hello world" 20 20 8 false 2))})

(local main-menu
       {:input (fn [] true)
        :update (fn [] true)
        :render (fn []
                  (cls 1)
                  (print "Hello world" 20 20 8 false 2))})

(scenes.push-scene! (make-boss-scene))

(fn _G.TIC []
  (scenes.run-scenes!))

;; <TILES>
;; 001:0111111111555555188888881855555518111111181171111811711118117111
;; 002:1111100055551100888821005558210011182111711821017118210171182101
;; 003:0111111111555555188888881855555518111111181111111811711118117111
;; 004:1111100055551100888821005558210011182111111821017118210171182101
;; 017:1811111118888888188818881888811118888888155555551122211101111101
;; 018:1118221188882110188821008888210088882100555511002221100011110000
;; 019:1811111118888888188818881888811118888888155555551122211101111101
;; 020:1118221188882110188821008888210088882100555511002221100011110000
;; </TILES>

;; <SPRITES>
;; 000:0000000008800000008800000008800000000000000000000000000000000000
;; 001:0000000008800000008800000008800000008000000080000000800000000000
;; 002:0000000008800000008800000008800000008800000088000000880000008800
;; 003:0000000000800000008800000008800000008800000088000000880000008800
;; 004:0000000000000000000000000000000000000000000000000000800000008800
;; 018:0000880000008800000088000008800000088000000000000000000000000000
;; 019:0000880000008800000088000008800000088000008800000880000000000000
;; 020:0000880000008000000080000008800000080000008800000880000000000000
;; 021:0000000000000000000000000008800000080000008800000880000000000000
;; </SPRITES>

;; <WAVES>
;; 000:00000000ffffffff00000000ffffffff
;; 001:0123456789abcdeffedcba9876543210
;; 002:0123456789abcdef0123456789abcdef
;; </WAVES>

;; <SFX>
;; 000:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000304000000000
;; </SFX>

;; <TRACKS>
;; 000:100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
;; </TRACKS>

;; <PALETTE>
;; 000:1aeaf2000000333333555555777777999999bbbbbbddddddffffffc63430ce8d28dada302c9d2c2069c2891cbe753c57
;; </PALETTE>

