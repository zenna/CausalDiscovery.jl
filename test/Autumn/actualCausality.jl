using Test
using CausalDiscovery
using Random
using MLStyle
import Base.Cartesian.lreplace

aexpr = au"""(program
  (= GRID_SIZE 16)

  (: broken Bool)
  (= broken (initnext false (prev broken)))

  (: suzie Int)
  (= suzie (initnext 1 (+ (prev suzie) 1)))

  (: billy Int)
  (= billy (initnext 0 (+ (prev billy) 1)))

  (: bottle Int)
  (= bottle (initnext 5 (prev bottle)))

  (on (== billy bottle) (= broken true))

  (on (== (- suzie bottle) 0) (= broken true))

  )"""

aexpr2 = au"""(program
  (= GRID_SIZE 16)

  (object Suzie (: timeTillThrow Integer) (Cell 0 0 "blue"))

  (: suzieThrew Bool)
  (= suzieThrew (initnext false (prev suzieThrew)))

  (: suzie Suzie)
  (= suzie (initnext (Suzie 3 (Position 0 0))
    (updateObj (prev suzie) "timeTillThrow" (- (.. (prev suzie) timeTillThrow) 1))))

  (on (== (.. suzie timeTillThrow) 0) (= suzieThrew true))

  )"""

# ------------------------------Change to function------------------------------
macro test_ac(expected_true, aexpr_,  cause_a_, cause_b_)
    if expected_true
      cause = Meta.parse("@test true")
      not_cause = Meta.parse("@test false")
    else
      cause = Meta.parse("@test false")
      not_cause = Meta.parse("@test true")
    end
    global step = 0
    return quote
      global step = 0
      get_a_causes = getcausal($aexpr_)
      println(get_a_causes)
      eval(get_a_causes)
      aumod = eval(compiletojulia($aexpr_))
      state = aumod.init(nothing, nothing, nothing, nothing, nothing, MersenneTwister(0))
      causes = [$cause_a_]
      cause_b = $cause_b_

      while !eval(cause_b)
        new_causes = []
        for cause_a in causes
          if eval(cause_a)
            append!(new_causes, a_causes(cause_a))
          end
        end
        global causes = new_causes
        global state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
        global step = step + 1
      end
    for cause_a in causes
      if ((cause_a.args[1] == cause_b.args[2] && eval(cause_a) == cause_b.args[3]) || cause_a == cause_b)
        println("A did cause B")
        println("a path")
        println("b path")
        println(cause_b)
        println(cause_a)
        $cause
        return
      end
    end
    println("A did not cause B")
    println(causes)
    $not_cause
  end
end
# ------------------------------Suzie Test---------------------------------------
#cause((suzie == 1), (broken == true))
a = :(state.suzieHistory[step] == 1)
b = :(state.brokenHistory[step] == true)
@test_ac(true, aexpr, a, b)


# -------------------------------Billy Test---------------------------------------
# cause((billy == 0), (broken == true))
a = :(state.billyHistory[step] == 0)
b = :(state.brokenHistory[step] == true)
@test_ac(false, aexpr, a, b)

# -------------------------------Advanced Suzie Test---------------------------------------
a = :(state.suzieHistory[step].timeTillThrow == 3)
b = :(state.suzieThrewHistory[step] == true)
@test_ac(true, aexpr2, a, b)

# #------------------------------Current Assumptions-------------------------------
# # cause and event are both in the form x == y
#
# #-------------------------------Julia Questions---------------------------------
# # Switch from compiler to interpreter?
# # Clean up code and add documentation
# # Look at notion
# # What should occur if the variable isnt actually related
#   #on (suzie < infinity or suzie > infinity) something



  aexpr3 = au"""(program
    (= GRID_SIZE 16)
    (object Suzie (: timeTillThrow Integer) (Cell 0 0 "blue"))
    (object Billy (: timeTillThrow Integer) (Cell 0 0 "red"))

    (object Bottle (: broken Bool) (list (Cell 0 0 (if broken then "yellow" else "white"))
                                          (Cell 0 1 (if broken then "white" else "yellow"))
                                          (Cell 0 2 (if broken then "gray" else "yellow"))
                                          (Cell 0 3 (if broken then "white" else "yellow"))
                                          (Cell 0 4 (if broken then "yellow" else "white"))))

    (object BottleSpot (Cell 0 0 "white"))
    (object Rock (Cell 0 0 "black"))


    (: suzie Suzie)
    (= suzie (initnext (Suzie 3 (Position 0 0))
      (updateObj (prev suzie) "timeTillThrow" (- (.. (prev suzie) timeTillThrow) 1))))

    (: bottleSpot BottleSpot)
    (= bottleSpot (initnext (BottleSpot (Position 15 7)) (BottleSpot (Position 15 7))))

    (: broken Bool)
    (= broken (initnext false (prev broken)))

    (: rocks (List Rock))
    (= rocks
       (initnext (list)
                 (updateObj (prev rocks) (--> obj
                                (if (intersects bottleSpot obj) then (removeObj obj)
                                  else (move obj (unitVector obj bottleSpot)))))))
    (= nextBottle (fn (bot rockst bottleSpott) (if (intersects bottleSpott rockst) then (updateObj bot "broken" true) else bot)))

    (: bottle Bottle)
    (= bottle (initnext (Bottle false (Position 15 5)) (nextBottle (prev bottle) (prev rocks) (prev bottleSpot))))

    (on (== (.. suzie timeTillThrow) 0) (= rocks (addObj (prev rocks) (Rock (Position 0 0)))))
    (on (intersects bottleSpot rocks) (= broken true))
  )"""
  # aumod = eval(compiletojulia(aexpr3))
  # state = aumod.init(nothing, nothing, nothing, nothing, nothing, MersenneTwister(0))
  #
  # i = 0
  # while i < 30
  #   global state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  #   global i += 1
  # end
  # println(state.suzieHistory[29])
  # println(state.rocksHistory[29])
  # println(state.brokenHistory)


#syntactic pattern matching but its not necessarily syntactic thing
#what to do if non trivial
#in my set of causes
#instead of checking syntax check if changing the value changes the next value
#maybe split the ors then do that?
#remove it
