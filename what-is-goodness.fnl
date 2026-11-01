;; title:   game title
;; author:  game developer, email, etc.
;; desc:    short description
;; site:    website link
;; license: MIT License (change this to your license of choice)
;; version: 0.1
;; script:  fennel
;; strict:  true

(macro module [name & body]
  `(local ,name
    (do
      ,(unpack body))))

(var current-scene nil)

(fn round [x]
  (math.floor (+ x 0.5)))

(fn intersects [a b]
  (and (< a.x (+ b.x b.width))
       (< a.y (+ b.y b.height))
       (< b.x (+ a.x a.width))
       (< b.y (+ a.y a.height))))

;; "frames, width height, frame-duration in number of frames, loop"
(fn make-animation [frames w h frame-duration loop?] 
  [frames w h frame-duration loop?])

(fn make-animator [init-animation]
  {:frame 0
   :frame-timer 0
   :animation init-animation
   :finished? false})

(fn animator-frame-id [animator]
  (. (. animator.animation 1) (+ 1 animator.frame)))

(fn set-animation! [animator animation]
  (doto animator
    (tset :frame 0)
    (tset :frame-timer 0)
    (tset :animation animation)
    (tset :finished? false)))

(fn update-animation! [animator]
  (when (and (not animator.finished?) animator.animation)
    (let [[frames _ _ frame-duration loop] animator.animation]
      (when (<= frame-duration animator.frame-timer)
        (do
          (set animator.frame-timer 0)
          (if (and (not loop) (= (+ animator.frame 1) (length frames)))
              (set animator.finished? true)
              (set animator.frame (% (+ animator.frame 1) (length frames))))))

      (set animator.frame-timer (+ 1 animator.frame-timer))
      animator)))

(module worlds
  (local list-to-remove [])

  (fn add [world entity]
    (set entity.world world)
    (set entity.id (+ 1 (length world.entities)))
    (table.insert world.entities entity))

  (fn remove [world entity-id]
    (table.insert list-to-remove entity-id))

  (fn delete-tagged [world]
    (each [i eid (ipairs list-to-remove)]
      (table.remove world.entities eid)
      (table.remove list-to-remove i)))

  {: add : remove : delete-tagged})

(module scenes
  (var scenes [])
  (var scene-pop-counter 0)

  (fn push-scene! [scene]
    (table.insert scenes 1 scene)
    (when scene.init
      (scene.init)))

  (fn pop-scene! []
    (set scene-pop-counter (+ 1 scene-pop-counter)))

  (fn set-scene! [scene]
    (set scenes [scene]) 
    (when scene.init
      (scene.init)))

  (fn swap-root-scene! [new-scene]
    (when new-scene.init
      (new-scene.init))
    (tset scenes 2 new-scene))

  (fn run-scenes! []
    (when (> (length scenes) 0)
      (let [top (. scenes 1)]
        (top.input)
        (top.update)
        (for [i (length scenes) 1 -1]
          (let [s (. scenes i)]
            (s.render)))))

    (for [i 1 scene-pop-counter]
      (table.remove scenes 1))
    (set scene-pop-counter 0))

  {: push-scene! : pop-scene! : set-scene!
   : swap-root-scene! : run-scenes!})

(module boss
  (local run-animation (make-animation [1 3] 2 2 20 true))
  (local shield-animation (make-animation [2] 2 2 20 true))
  (local speed 1)
  (var current-strategy nil)

  (fn wait [frames]
    (fn [boss]
      (for [i 1 frames]
        (coroutine.yield))))

  (fn move! [x]
    (fn [boss]
      (while (not= boss.x x)
        (let [dir (if (< boss.x x) :right :left)]
          (set boss.x (+ boss.x (* speed (if (= dir :right) 1 -1))))
          (coroutine.yield)))))

  (fn shield [boss]
    (set-animation! boss.animator shield-animation)
    (set boss.shielding? true)
    ((wait 200) boss)
    (set boss.shielding? false))

  (fn fw-bw-move! [boss]
    (set-animation! boss.animator run-animation)
    ((move! 50) boss)
    ((wait 50) boss)
    ((move! 200) boss))

  (fn wait-30-frames [boss]
    ((wait 30) boss))

  (local ability-list [fw-bw-move! shield wait-30-frames])

  (fn damage [boss]
    (when (and (not boss.invulnerable)
               (not boss.shielding?))
      (set boss.health (- boss.health 1))
      (set boss.invulnerable 30)))

  (fn update [boss]
    (update-animation! boss.animator)
    (when boss.invulnerable
      (set boss.invulnerable (- boss.invulnerable 1))
      (when (= boss.invulnerable 0)
        (set boss.invulnerable nil)))

    (each [_ e (ipairs boss.world.entities)]
      (when (and (= e.type :player-slash)
                 (intersects e boss))
        (damage boss)))

    (when (or (not current-strategy)
              (= :dead (coroutine.status current-strategy)))
      (let [random-ability (. ability-list (math.random (length ability-list)))]
        (set current-strategy (coroutine.create random-ability))))

    (coroutine.resume current-strategy boss))

  (fn render [boss]
    (let [animator boss.animator
          [frames w h] animator.animation
          frame-id (animator-frame-id animator)]
      (if (and boss.invulnerable (= 0 (% (// boss.invulnerable 5) 2))) 
        nil
        (spr frame-id boss.x boss.y 0 1 (if (= boss.direction :left) 0 1) 0 w h)))

    (when boss.shielding?
      (circb (+ boss.x 7) (+ boss.y 7) 12 14)))

  (fn make-boss []
    {:x 200 :y 110
     :type :boss
     :width 16 :height 16
     :direction :left
     :update update
     :render render
     :health 10
     :phases-left 6
     :animator (make-animator run-animation)})

  {: make-boss})

(module player-module
  (local jump-force -4)
  (local ground-y 110)
  (local speed 1.5)
  (local gravity 0.2)
  (local roll-speed 3)
  (local run-animation (make-animation [1 3] 2 2 20 true))
  (local block-animation (make-animation [5] 2 2 20 false))
  (local roll-animation (make-animation [7 9 11 1] 2 2 5 true))
  (local slash-animation (make-animation [256 257 258 259 260 261 262] 1 2 1 false))
  (var current-routine nil)

  (fn cutscene-move! [x f]
    (set current-routine
         (coroutine.create
          (fn [player]
            (while (not (< (- x 2) player.x (+ x 2)))
              (let [dir (if (< player.x x) :right :left)]
                (set player.x (+ player.x (* speed (if (= dir :right) 1 -1))))
                (coroutine.yield)))
            (set current-routine nil)
            (f)))))

  (fn spawn-slash [player]
    (worlds.add player.world
                {:update (fn [self]
                           (update-animation! self.animator)
                           (when self.animator.finished?
                             (worlds.remove player.world self.id)))
      :render (fn [self]
                (let [animator self.animator
                      [frames w h] animator.animation
                      frame-id (animator-frame-id animator)]
                  ;;(rect self.x self.y self.width self.height 13)
                  (spr frame-id
                       (- self.x 4)
                       self.y 0 2
                       (if (= self.direction :right) 0 1)
                       0 w h))

                )
      :direction player.direction
      :animator (make-animator slash-animation)
      :x (+ (if (= player.direction :right) 16 -8) player.x)
      :y (- player.y 8)
      :height 32 :width 8
      :type :player-slash}))

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
    (when (and (not player.blocking?)
               (not player.rolling?))
      (if roll?
          (let [roll-dir roll?]
            (set-animation! player.animator roll-animation)
            (doto player 
              (tset :rolling? [roll-dir 25])
              (tset :vy -0.5)))
          
          (do 
            (set player.blocking? 40)
            (set-animation! player.animator block-animation)))))

  (fn attack! [player]
    (when (and (not player.blocking?)
               (not player.rolling?))
      (set player.attacking? true)
      (spawn-slash player)))

  (fn update-player! [player pos?]
    (when current-routine
      (coroutine.resume current-routine player))

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
        (set player.x (+ player.x (if (= dir :left) (- roll-speed) roll-speed)))
        (when (= time 0)
          (set player.rolling? nil)
          (set-animation! player.animator run-animation))))

    (update-animation! player.animator)
    (set player.y (+ player.vy player.y)))

  (fn render-player! [player]
    (let [animator player.animator
          [frames w h] animator.animation
          frame-id (animator-frame-id animator)]
      (spr frame-id player.x player.y 0 1 (if (= player.direction :right) 0 1) 0 w h)))

  (fn make-player []
    {:x -30 :y 110 :hp 3 :vx 0 :vy 0
     :type :player
     :width 16 :height 16
     :direction :right :grounded? false
     :animator (make-animator run-animation)
     :update update-player!
     :render render-player!})

  {: make-player : move-player-x! : jump! : attack! : dodge-roll!
   : cutscene-move!})

(module dialogue
  (local script {:phase1
                 [[:player "Do you know the way?"]
                  [:boss "I do not know the way"]
                  [:boss "Teh way"]
                  [:player "Teh way..."]]})

  (fn draw-bubble [x y]
    (rect x y 24 8 7)
    (print ". . ." x y 1))

  (fn make-dialogue-scene [phase close-fn]
    (var current-line 1)
    (var current-char 1)
    {:input (fn []
              (when (btnp 4)
                (when (= current-line (length (. script phase)))
                  (scenes.pop-scene!)
                  (close-fn))
                (set current-line (math.min (length (. script phase)) (+ current-line 1)))
                (set current-char 1)))
     :update (fn [] (set current-char (+ current-char 1)))
     :render (fn []
               (let [[speaker text] (. script phase current-line)]
                 (if (= speaker :player)
                     (draw-bubble 40 90)
                     (draw-bubble 200 80)
                     )
                 (rect 0 0 240 30 7)
                 (print (string.sub text 0 current-char) 0 0 1)))})

  {: make-dialogue-scene})

(fn make-boss-scene []
  (local player (player-module.make-player))
  (local boss (boss.make-boss))
  (local world {:entities []
                :boss boss
                :player player})
  (worlds.add world player)
  (worlds.add world boss)
  (var fight-start? false)

  {:input (fn []
            (when fight-start? 
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

                    (player-module.dodge-roll! player nil)))))
   :init (fn []
           (player-module.cutscene-move!
            50
            (fn []
              (scenes.push-scene! (dialogue.make-dialogue-scene
                                   :phase1
                                   (fn [] (set fight-start? true))))))
           )
   :update (fn []
             (if fight-start?
                 (each [_ e (ipairs world.entities)]
                   (e:update))
                 (world.player:update))

             (worlds.delete-tagged world))
   :render (fn []
             (cls 5)
             (each [_ e (ipairs world.entities)]
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
;; 005:0111111111555555188888881855555518191111181191111811791918117111
;; 006:1111100055551100888821005558210019182111911821017118210171182101
;; 007:0111111111588888125888811258888112588181115818810158188111581881
;; 008:1111111088888811111158511111585177115851111158511111585111115851
;; 009:0000111100011222001155550012888800128888001288810112888811228111
;; 010:1011111011122211555555518888888111188881888188818888888111111181
;; 011:0000111100001000011111111122222215888888158511111585111115851177
;; 012:1000000011000000211111002222211088888511188885211888852118188521
;; 017:1811111118888888188818881888811118888888155555551122211101111101
;; 018:1118221188882110188821008888210088882100555511002221100011110000
;; 019:1811111118888888188818881888811118888888155555551122211101111101
;; 020:1118221188882110188821008888210088882100555511002221100011110000
;; 021:1811111118888888188818881888811118888888155555551122211101111101
;; 022:1118221188882110188821008888210088882100555511002221100011110000
;; 023:1258818112588881125888811158888801122222001111120000001100000001
;; 024:7711585111115851111158518888885122222211111111100001000011110000
;; 025:1012811710128117101281111112811100128555001288880011555500011111
;; 026:1117118111171181111111811111118155555581888888815555551111111110
;; 027:1585111115851111158511111585117715851111158511111188888801111111
;; 028:1881851118818510188185111818852118888521188885218888851111111110
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

