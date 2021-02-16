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

    (on (clicked wall) (= wall (updateObj wall "visible" (! (.. wall visible)))))


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

        (on (clicked wall) (= wall (updateObj wall "visible" (! (.. wall visible)))))

        (: ball_a Ball)
        (= ball_a (initnext (Ball 270 "blue" (Position 15 10)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

        (: ball_b Ball)
        (= ball_b (initnext (Ball 225 "red" (Position 15 5)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" 361)) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
      )"""

      causalchain1 = au"""(program
        (= GRID_SIZE 16)

        (object Goal (Cell 0 0 "green"))
        (: goal Goal)
        (= goal (initnext (Goal (Position 0 10)) (prev goal)))

        (object Ball (: direction Integer) (: color String) (Cell 0 0 color))

        (on (clicked goal) (= goal (prev goal)))

        (: ball_a Ball)
        (= ball_a (initnext (Ball 361 "blue" (Position 6 10)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

        (: ball_b Ball)
        (= ball_b (initnext (Ball 361 "red" (Position 10 10)) (if (intersects ball_b ball_c) then (nextBall (updateObj (prev ball_b) "direction" (ballcollision (prev ball_b) (prev ball_c)))) else (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" 361)) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b))))))))

        (: ball_c Ball)
        (= ball_c (initnext (Ball 270 "purple" (Position 14 10)) (if (intersects (prev ball_b) ball_c) then (nextBall (updateObj (prev ball_c) "direction" 361)) else (nextBall (updateObj (prev ball_c) "direction" (wallintersect (prev ball_c)))))))

        (on (intersects ball_a goal) (= ball_a (updateObj ball_a "direction" 361)))
      )"""

      #counterfactual miss actual miss
      cmam = au"""(program
        (= GRID_SIZE 16)

        (object Goal (Cell 0 0 "green"))
        (: goal Goal)
        (= goal (initnext (Goal (Position 0 7)) (prev goal)))
        (: goal2 Goal)
        (= goal2 (initnext (Goal (Position 0 8)) (prev goal2)))

        (object Ball (: direction Integer) (: color String) (Cell 0 0 color))
        (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))

        (on (== 0 (.. (.. ball_a origin) x)) (= ball_a (updateObj ball_a "direction" 361)))

        (: ball_a Ball)
        (= ball_a (initnext (Ball 225 "blue" (Position 15 0)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

        (: ball_b Ball)
        (= ball_b (initnext (Ball 315 "red" (Position 15 14)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" (ballcollision (prev ball_b) (prev ball_a)))) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
      )"""

      #counterfactual miss actual close
      cmac = au"""(program
        (= GRID_SIZE 16)

        (object Goal (Cell 0 0 "green"))
        (: goal Goal)
        (= goal (initnext (Goal (Position 0 7)) (prev goal)))
        (: goal2 Goal)
        (= goal2 (initnext (Goal (Position 0 8)) (prev goal2)))

        (object Ball (: direction Integer) (: color String) (Cell 0 0 color))
        (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))

        (on (== 0 (.. (.. ball_a origin) x)) (= ball_a (updateObj ball_a "direction" 361)))

        (: ball_a Ball)
        (= ball_a (initnext (Ball 225 "blue" (Position 11 3)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

        (: ball_b Ball)
        (= ball_b (initnext (Ball 315 "red" (Position 11 15)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" (ballcollision (prev ball_b) (prev ball_a)))) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
      )"""


      #counterfactual miss actual hit
      cmah = au"""(program
        (= GRID_SIZE 16)

        (object Goal (Cell 0 0 "green"))
        (: goal Goal)
        (= goal (initnext (Goal (Position 0 7)) (prev goal)))
        (: goal2 Goal)
        (= goal2 (initnext (Goal (Position 0 8)) (prev goal2)))

        (object Ball (: direction Integer) (: color String) (Cell 0 0 color))
        (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))

        (on (intersects goal ball_a) (= ball_a (updateObj ball_a "direction" 361)))

        (: ball_a Ball)
        (= ball_a (initnext (Ball 270 "blue" (Position 15 5)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

        (: ball_b Ball)
        (= ball_b (initnext (Ball 315 "red" (Position 15 8)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" 361)) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
      )"""

      #counterfactual close actual miss
      ccam = au"""(program
        (= GRID_SIZE 16)

        (object Goal (Cell 0 0 "green"))
        (: goal Goal)
        (= goal (initnext (Goal (Position 0 7)) (prev goal)))
        (: goal2 Goal)
        (= goal2 (initnext (Goal (Position 0 8)) (prev goal2)))

        (object Ball (: direction Integer) (: color String) (Cell 0 0 color))
        (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))

        (on (== 0 (.. (.. ball_a origin) x)) (= ball_a (updateObj ball_a "direction" 361)))

        (: ball_a Ball)
        (= ball_a (initnext (Ball 225 "blue" (Position 10 0)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

        (: ball_b Ball)
        (= ball_b (initnext (Ball 315 "red" (Position 10 10)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" (ballcollision (prev ball_b) (prev ball_a)))) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
      )"""

      #counterfactual close actual close
      ccac = au"""(program
        (= GRID_SIZE 16)

        (object Goal (Cell 0 0 "green"))
        (: goal Goal)
        (= goal (initnext (Goal (Position 0 7)) (prev goal)))
        (: goal2 Goal)
        (= goal2 (initnext (Goal (Position 0 8)) (prev goal2)))

        (object Ball (: direction Integer) (: color String) (Cell 0 0 color))
        (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))

        (on (== 0 (.. (.. ball_a origin) x)) (= ball_a (updateObj ball_a "direction" 361)))

        (: ball_a Ball)
        (= ball_a (initnext (Ball 225 "blue" (Position 9 1)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

        (: ball_b Ball)
        (= ball_b (initnext (Ball 315 "red" (Position 9 15)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" (ballcollision (prev ball_b) (prev ball_a)))) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
      )"""

      #counterfactual close actual hit
      ccah = au"""(program
        (= GRID_SIZE 16)

        (object Goal (Cell 0 0 "green"))
        (: goal Goal)
        (= goal (initnext (Goal (Position 0 7)) (prev goal)))
        (: goal2 Goal)
        (= goal2 (initnext (Goal (Position 0 8)) (prev goal2)))

        (object Ball (: direction Integer) (: color String) (Cell 0 0 color))
        (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))

        (on (== 0 (.. (.. ball_a origin) x)) (= ball_a (updateObj ball_a "direction" 361)))

        (: ball_a Ball)
        (= ball_a (initnext (Ball 225 "blue" (Position 8 1)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

        (: ball_b Ball)
        (= ball_b (initnext (Ball 315 "red" (Position 8 15)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" (ballcollision (prev ball_b) (prev ball_a)))) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
      )"""

      #counterfactual hit actual miss
      cham = au"""(program
        (= GRID_SIZE 16)

        (object Goal (Cell 0 0 "green"))
        (: goal Goal)
        (= goal (initnext (Goal (Position 0 7)) (prev goal)))
        (: goal2 Goal)
        (= goal2 (initnext (Goal (Position 0 8)) (prev goal2)))

        (object Ball (: direction Integer) (: color String) (Cell 0 0 color))
        (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))

        (on (== 0 (.. (.. ball_a origin) x)) (= ball_a (updateObj ball_a "direction" 361)))

        (: ball_a Ball)
        (= ball_a (initnext (Ball 270 "blue" (Position 15 7)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

        (: ball_b Ball)
        (= ball_b (initnext (Ball 225 "red" (Position 15 0)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" 361)) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
      )
      """

      #chac counterfactual hit actual close
      chac = au"""(program
        (= GRID_SIZE 16)

        (object Goal (Cell 0 0 "green"))
        (: goal Goal)
        (= goal (initnext (Goal (Position 0 7)) (prev goal)))
        (: goal2 Goal)
        (= goal2 (initnext (Goal (Position 0 8)) (prev goal2)))

        (object Ball (: direction Integer) (: color String) (Cell 0 0 color))
        (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))

        (on (== 0 (.. (.. ball_a origin) x)) (= ball_a (updateObj ball_a "direction" 361)))

        (: ball_a Ball)
        (= ball_a (initnext (Ball 270 "blue" (Position 10 7)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

        (: ball_b Ball)
        (= ball_b (initnext (Ball 315 "red" (Position 10 0)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" 361)) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
      )"""

      #counterfactual hit actual hit
      chah = au"""(program
        (= GRID_SIZE 16)

        (object Goal (Cell 0 0 "green"))
        (: goal Goal)
        (= goal (initnext (Goal (Position 0 7)) (prev goal)))
        (: goal2 Goal)
        (= goal2 (initnext (Goal (Position 0 8)) (prev goal2)))

        (object Ball (: direction Integer) (: color String) (Cell 0 0 color))
        (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))

        (on (== 0 (.. (.. ball_a origin) x)) (= ball_a (updateObj ball_a "direction" 361)))

        (: ball_a Ball)
        (= ball_a (initnext (Ball 361 "blue" (Position 12 7)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

        (: ball_b Ball)
        (= ball_b (initnext (Ball 270 "red" (Position 15 7)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" (ballcollision (prev ball_b) (prev ball_a)))) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
      )"""
