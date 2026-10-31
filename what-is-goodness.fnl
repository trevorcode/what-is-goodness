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

(local player-module
       (do
         (local jump-force -4)
         (local ground-y 110)
         (local speed 1.5)
         (local gravity 0.2)

         (fn move-player-x! [player pos?]
           (let [new-x (+ player.x (* speed (if pos? 1 -1)))]
             (tset player :x new-x)))

         (fn jump! [player]
           (when player.grounded? 
             (tset player :grounded? false)
             (tset player :y (- player.y 1))
             (tset player :vy jump-force)))

         (fn update-player! [player pos?]
           (when (< player.y ground-y)
             (set player.vy (+ player.vy gravity)))

           (when (<= ground-y player.y)
             (set player.grounded? true)
             (set player.y ground-y)
             (set player.vy 0))

           (set player.y (+ player.vy player.y)))

         (fn render-player! [player]
           (rect (round player.x) (round player.y) 16 16 12))

         (fn make-player []
           {:x 30 :y 0 :hp 3 :vx 0 :vy 0
            :grounded? false})

         {: make-player : update-player! : move-player-x!
          : jump! : render-player!}))

(fn make-boss-scene []
  (local player (player-module.make-player))

  {:input (fn []
            (when (btn 0)
              (player-module.jump! player))
            (when (btn 3)
              (player-module.move-player-x! player true))
            (when (btn 2)
              (player-module.move-player-x! player false))
            )
   :update (fn []
             (player-module.update-player! player)
             )
   :render (fn []
             (cls 8)
             (player-module.render-player! player)
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
;; 001:eccccccccc888888caaaaaaaca888888cacccccccacc0ccccacc0ccccacc0ccc
;; 002:ccccceee8888cceeaaaa0cee888a0ceeccca0ccc0cca0c0c0cca0c0c0cca0c0c
;; 003:eccccccccc888888caaaaaaaca888888cacccccccacccccccacc0ccccacc0ccc
;; 004:ccccceee8888cceeaaaa0cee888a0ceeccca0cccccca0c0c0cca0c0c0cca0c0c
;; 017:cacccccccaaaaaaacaaacaaacaaaaccccaaaaaaac8888888cc000cccecccccec
;; 018:ccca00ccaaaa0ccecaaa0ceeaaaa0ceeaaaa0cee8888ccee000cceeecccceeee
;; 019:cacccccccaaaaaaacaaacaaacaaaaccccaaaaaaac8888888cc000cccecccccec
;; 020:ccca00ccaaaa0ccecaaa0ceeaaaa0ceeaaaa0cee8888ccee000cceeecccceeee
;; </TILES>

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

