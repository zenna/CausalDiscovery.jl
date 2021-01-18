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
  (on (== suzie bottle) (= broken true))

  )"""

get_a_causes = getcausal(aexpr)
println(get_a_causes)
eval(get_a_causes)

# ------------------------------Change to function------------------------------
macro test_ac(expected_true, aexpr_,  cause_a_, cause_b_)
    if expected_true
      cause = Meta.parse("@test true")
      not_cause = Meta.parse("@test false")
    else
      cause = Meta.parse("@test false")
      not_cause = Meta.parse("@test true")
    end

    return quote
      global step = 0
      aumod = eval(compiletojulia($aexpr_))
      state = aumod.init(nothing, nothing, nothing, nothing, nothing, MersenneTwister(0))
      cause_a = $cause_a_
      cause_b = $cause_b_

      while !eval(cause_b)
        if eval(cause_a)
          global cause_a = a_causes(cause_a)
        end
        global state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
        global step = step + 1
      end
    println(cause_a)
    println(cause_b)
    if !((cause_a.args[1] == cause_b.args[2] && eval(cause_a) == cause_b.args[3]) || cause_a == cause_b)
      println("A did not cause B")
      println(cause_a)
      $not_cause
    else
      println("A did cause B")
      $cause
    end
  end
end
# ------------------------------Suzie Test---------------------------------------
#cause((suzie == 1), (broken == true))
a = :(state.suzieHistory[step] == 1)
b = :(state.brokenHistory[step] == true)
@test_ac(true, aexpr, a, b)


# -------------------------------Billy Test---------------------------------------
#cause((billy == 0), (broken == true))
a = :(state.billyHistory[step] == 0)
b = :(state.brokenHistory[step] == true)
@test_ac(false, aexpr, a, b)

# #------------------------------Current Assumptions-------------------------------
# # cause and event are both in the form x == y
#
# #-------------------------------Julia Questions---------------------------------
# # Switch from compiler to interpreter?
# # Clean up code and add documentation
# # Look at notion
# # What should occur if the variable isnt actually related
#   #on (suzie < infinity or suzie > infinity) something
