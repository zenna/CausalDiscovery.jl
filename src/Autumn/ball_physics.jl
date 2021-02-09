#direction is 1-8 representing up, up/right, right, down/right, down, down/left, left, up/left

  barrier = au"""(program
    (= GRID_SIZE 16)

    (object Goal (Cell 0 0 "green"))
    (: goal Goal)
    (= goal (initnext (Goal (Position 0 10)) (prev goal)))

    (object Ball (: direction Integer) (: color String) (Cell 0 0 color))
    (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))

    (: wall Wall)
    (= wall (initnext (Wall true (Position 4 9)) (prev wall)))

    (= nextBall (fn (ball)
      (if (== (.. ball direction) 1)
        then (updateObj ball "origin"
               (Position (.. (.. ball origin) x) (- (.. (.. ball origin) y) 1)))
     else
      (if (== (.. ball direction) 2)
        then (updateObj ball "origin"
               (Position (+ (.. (.. ball origin) x) 1) (- (.. (.. ball origin) y) 1)))
     else
      (if (== (.. ball direction) 3)
        then (updateObj ball "origin"
               (Position (+ (.. (.. ball origin) x) 1) (.. (.. ball origin) y)))
     else
      (if (== (.. ball direction) 4)
        then (updateObj ball "origin"
               (Position (+ (.. (.. ball origin) x) 1) (+ (.. (.. ball origin) y) 1)))
     else
      (if (== (.. ball direction) 5)
        then (updateObj ball "origin"
               (Position (.. (.. ball origin) x) (+ (.. (.. ball origin) y) 1)))
      else
        (if (== (.. ball direction) 6)
          then (updateObj ball "origin"
                 (Position (- (.. (.. ball origin) x) 1) (+ (.. (.. ball origin) y) 1)))
      else
        (if (== (.. ball direction) 7)
              then (updateObj ball "origin"
                     (Position (- (.. (.. ball origin) x) 1) (.. (.. ball origin) y)))
      else
        (if (== (.. ball direction) 8)
            then (updateObj ball "origin"
                   (Position (- (.. (.. ball origin) x) 1) (- (.. (.. ball origin) y) 1)))
        else ball))))))))))


    (on (clicked wall) (= wall (updateObj wall "visible" (! (.. wall visible)))))

    (= wallintersect (fn (ball)
      (if (& (== (.. ball direction) 4) (== (.. (.. ball origin) y) 15)) then 2 else
      (if (& (== (.. ball direction) 5) (== (.. (.. ball origin) y) 15)) then 1 else
      (if (& (== (.. ball direction) 6) (== (.. (.. ball origin) y) 15)) then 8 else
      (if (& (== (.. ball direction) 6) (== (.. (.. ball origin) x) 0)) then 4 else
      (if (& (== (.. ball direction) 7) (== (.. (.. ball origin) x) 0)) then 3 else
      (if (& (== (.. ball direction) 8) (== (.. (.. ball origin) x) 0)) then 2 else
      (if (& (== (.. ball direction) 2) (== (.. (.. ball origin) x) 15)) then 8 else
      (if (& (== (.. ball direction) 3) (== (.. (.. ball origin) x) 15)) then 7 else
      (if (& (== (.. ball direction) 4) (== (.. (.. ball origin) x) 15)) then 6 else
      (if (& (== (.. ball direction) 8) (== (.. (.. ball origin) y) 0)) then 6 else
      (if (& (== (.. ball direction) 1) (== (.. (.. ball origin) y) 0)) then 5 else
      (if (& (== (.. ball direction) 2) (== (.. (.. ball origin) y) 0)) then 4 else

    (.. ball direction)))))))))))))))


    (: ball_a Ball)
    (= ball_a (initnext (Ball 7 "blue" (Position 15 10)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" 6)) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

    (: ball_b Ball)
    (= ball_b (initnext (Ball 6 "red" (Position 15 5)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" 2)) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
  )"""



  doesnt_work = """(program
      (= GRID_SIZE 16)

      (object Ball (: direction Integer) (Cell 0 0 "blue"))


    	(= nextBall (fn (ball) (if (== (.. ball direction) 7)
            then (updateObj ball "origin"
                   (Position (- (.. (.. ball origin) x) 1) (.. (.. ball origin) y)))
            else ball)))

      (: ball_a Ball)
      (= ball_a (initnext (Ball 7 (Position 15 7)) (nextBall (prev ball_a))))
    )"""

    works = """(program
        (= GRID_SIZE 16)

        (object Ball (: direction Integer) (Cell 0 0 "blue"))


        (= nextBall (fn (ball) (if (== (.. ball direction) 7)
              then (updateObj ball "origin"
                     (Position (- (.. (.. ball origin) x) 1) (.. (.. ball origin) y)))
              else ball)))

        (on clicked (= ball_a (updateObj ball_a "direction" 7)))
        (: ball_a Ball)
        (= ball_a (initnext (Ball 7 (Position 15 7)) (nextBall (prev ball_a))))
      )"""


      barrier = au"""(program
        (= GRID_SIZE 16)

        (object Goal (Cell 0 0 "green"))
        (: goal Goal)
        (= goal (initnext (Goal (Position 0 10)) (prev goal)))

        (object Ball (: direction Integer) (: color String) (Cell 0 0 color))
        (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))

        (: wall Wall)
        (= wall (initnext (Wall true (Position 4 9)) (prev wall)))

        (= nextBall (fn (ball)
          (if (< (.. ball direction) 45)
            then (updateObj ball "origin"
                   (Position (.. (.. ball origin) x) (- (.. (.. ball origin) y) 1)))
         else
          (if (< (.. ball direction) 90)
            then (updateObj ball "origin"
                   (Position (+ (.. (.. ball origin) x) 1) (- (.. (.. ball origin) y) 1)))
         else
          (if (< (.. ball direction) 135)
            then (updateObj ball "origin"
                   (Position (+ (.. (.. ball origin) x) 1) (.. (.. ball origin) y)))
         else
          (if (< (.. ball direction) 180)
            then (updateObj ball "origin"
                   (Position (+ (.. (.. ball origin) x) 1) (+ (.. (.. ball origin) y) 1)))
         else
          (if (< (.. ball direction) 225)
            then (updateObj ball "origin"
                   (Position (.. (.. ball origin) x) (+ (.. (.. ball origin) y) 1)))
          else
            (if (< (.. ball direction) 270)
              then (updateObj ball "origin"
                     (Position (- (.. (.. ball origin) x) 1) (+ (.. (.. ball origin) y) 1)))
          else
            (if (< (.. ball direction) 315)
                  then (updateObj ball "origin"
                         (Position (- (.. (.. ball origin) x) 1) (.. (.. ball origin) y)))
          else
            (if (< (.. ball direction) 360)
                then (updateObj ball "origin"
                       (Position (- (.. (.. ball origin) x) 1) (- (.. (.. ball origin) y) 1)))
            else ball))))))))))


        (on (clicked wall) (= wall (updateObj wall "visible" (! (.. wall visible)))))

        (= wallintersect (fn (ball)
          (if (& (< (.. ball direction) 180) (== (.. (.. ball origin) y) 15)) then (- 180 (.. ball direction)) else
          (if (& (== (.. ball direction) 180) (== (.. (.. ball origin) y) 15)) then 0 else
          (if (& (> (.. ball direction) 180) (== (.. (.. ball origin) y) 15)) then (+ 90 (.. ball direction)) else
          (if (& (& (< (.. ball direction) 270) (> (.. ball direction) 180)) (== (.. (.. ball origin) x) 0)) then (- 360 (.. ball direction)) else
          (if (& (== (.. ball direction) 270) (== (.. (.. ball origin) x) 0)) then 90 else
          (if (& (> (.. ball direction) 270) (== (.. (.. ball origin) x) 0)) then (- 360 (.. ball direction)) else
          (if (& (< (.. ball direction) 90) (== (.. (.. ball origin) x) 15)) then (+ 270 (.. ball direction)) else
          (if (& (== (.. ball direction) 90) (== (.. (.. ball origin) x) 15)) then 270 else
          (if (& (> (.. ball direction) 90) (== (.. (.. ball origin) x) 15)) then (+ 90 (.. ball direction)) else
          (if (& (> (.. ball direction) 180) (== (.. (.. ball origin) y) 0)) then (- 520 (.. ball direction)) else
          (if (& (== (.. ball direction) 45) (== (.. (.. ball origin) y) 0)) then 180 else
          (if (& (< (.. ball direction) 180) (== (.. (.. ball origin) y) 0)) then (- 180 (.. ball direction)) else

        (.. ball direction)))))))))))))))

        (= ballcollision (fn (ball1 ball2)
          (/ (+ (.. ball1 direction) (.. ball2 direction)) 2)
        ))


        (: ball_a Ball)
        (= ball_a (initnext (Ball 0 "blue" (Position 14 10)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

        (: ball_b Ball)
        (= ball_b (initnext (Ball 180 "red" (Position 14 5)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" 361)) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
      )"""

      causalchain1 = au"""(program
        (= GRID_SIZE 16)

        (object Goal (Cell 0 0 "green"))
        (: goal Goal)
        (= goal (initnext (Goal (Position 0 10)) (prev goal)))

        (object Ball (: direction Integer) (: color String) (Cell 0 0 color))

        (= nextBall (fn (ball)
          (if (< (.. ball direction) 45)
            then (updateObj ball "origin"
                   (Position (.. (.. ball origin) x) (- (.. (.. ball origin) y) 1)))
         else
          (if (< (.. ball direction) 90)
            then (updateObj ball "origin"
                   (Position (+ (.. (.. ball origin) x) 1) (- (.. (.. ball origin) y) 1)))
         else
          (if (< (.. ball direction) 135)
            then (updateObj ball "origin"
                   (Position (+ (.. (.. ball origin) x) 1) (.. (.. ball origin) y)))
         else
          (if (< (.. ball direction) 180)
            then (updateObj ball "origin"
                   (Position (+ (.. (.. ball origin) x) 1) (+ (.. (.. ball origin) y) 1)))
         else
          (if (< (.. ball direction) 225)
            then (updateObj ball "origin"
                   (Position (.. (.. ball origin) x) (+ (.. (.. ball origin) y) 1)))
          else
            (if (< (.. ball direction) 270)
              then (updateObj ball "origin"
                     (Position (- (.. (.. ball origin) x) 1) (+ (.. (.. ball origin) y) 1)))
          else
            (if (< (.. ball direction) 315)
                  then (updateObj ball "origin"
                         (Position (- (.. (.. ball origin) x) 1) (.. (.. ball origin) y)))
          else
            (if (< (.. ball direction) 360)
                then (updateObj ball "origin"
                       (Position (- (.. (.. ball origin) x) 1) (- (.. (.. ball origin) y) 1)))
            else ball))))))))))


        (on (clicked goal) (= goal (prev goal)))

        (= wallintersect (fn (ball)
          (if (& (< (.. ball direction) 180) (== (.. (.. ball origin) y) 15)) then (- 180 (.. ball direction)) else
          (if (& (== (.. ball direction) 180) (== (.. (.. ball origin) y) 15)) then 0 else
          (if (& (> (.. ball direction) 180) (== (.. (.. ball origin) y) 15)) then (+ 90 (.. ball direction)) else
          (if (& (& (< (.. ball direction) 270) (> (.. ball direction) 180)) (== (.. (.. ball origin) x) 0)) then (- 360 (.. ball direction)) else
          (if (& (== (.. ball direction) 270) (== (.. (.. ball origin) x) 0)) then 90 else
          (if (& (> (.. ball direction) 270) (== (.. (.. ball origin) x) 0)) then (- 360 (.. ball direction)) else
          (if (& (< (.. ball direction) 90) (== (.. (.. ball origin) x) 15)) then (+ 270 (.. ball direction)) else
          (if (& (== (.. ball direction) 90) (== (.. (.. ball origin) x) 15)) then 270 else
          (if (& (> (.. ball direction) 90) (== (.. (.. ball origin) x) 15)) then (+ 90 (.. ball direction)) else
          (if (& (> (.. ball direction) 180) (== (.. (.. ball origin) y) 0)) then (- 520 (.. ball direction)) else
          (if (& (== (.. ball direction) 45) (== (.. (.. ball origin) y) 0)) then 180 else
          (if (& (< (.. ball direction) 180) (== (.. (.. ball origin) y) 0)) then (- 180 (.. ball direction)) else
        (.. ball direction)))))))))))))))

        (= ballcollision (fn (ball1 ball2)
          (.. ball2 direction)
        ))

        (: ball_a Ball)
        (= ball_a (initnext (Ball 361 "blue" (Position 6 10)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

        (: ball_b Ball)
        (= ball_b (initnext (Ball 361 "red" (Position 10 10)) (if (intersects ball_b ball_c) then (nextBall (updateObj (prev ball_b) "direction" (ballcollision (prev ball_b) (prev ball_c)))) else (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" 361)) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b))))))))

        (: ball_c Ball)
        (= ball_c (initnext (Ball 270 "purple" (Position 14 10)) (if (intersects (prev ball_b) ball_c) then (nextBall (updateObj (prev ball_c) "direction" 361)) else (nextBall (updateObj (prev ball_c) "direction" (wallintersect (prev ball_c)))))))

      )"""
