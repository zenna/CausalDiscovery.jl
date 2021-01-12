using Test
using CausalDiscovery
using Random
using MLStyle

#
# (: broken Bool)
# (: suzie Int)
# (: billy Int)
# (: bottle Int)

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

  #on (suzie < infinity or suzie > infinity) something


  # (object CauseButton (: broken Int) (Cell 0 0 (if (== broken 0) then "grey" else (if (== broken 1) then "green" else "red"))))
  # (: causeB CauseButton)
  # (= causeB (initnext (CauseButton 0 (Position 0 0)) (prev causeB)))
  # (on (== broken true) (= causeB (updateObj causeB "broken" true)))
  # )"""
# function a_causes(a)
#   if a.args[1] == :(==)
#     if (eval(state.billyHistory[step] == state.bottleHistory[step]))
#       return :(state.brokenHistory[step] = 1 == 1)
#     end
#     if (eval(state.suzieHistory[step] == state.bottleHistory[step]))
#       return :(state.brokenHistory[step] = 1 == 1)
#     end
#   end
#   return a
# end

#key is figuring out how to turn autumn program into this
  # function a_causes(a, b)
  #   if a.args[3] == eval(b) #if suzie == bottle
  #     return Expr(:call, :(==), :(state.brokenHistory[step]), true)
  #   end
  #   Expr(:call, a.args[1], a.args[2], a.args[3]+1)
  # end

get_a_causes = getcausal(aexpr)
println(get_a_causes)
eval(get_a_causes)

# ------------------------------Suzie Test---------------------------------------
#cause((suzie == 1), (broken == true))
step = 0
aumod = eval(compiletojulia(aexpr))
state = aumod.init(nothing, nothing, nothing, nothing, nothing, MersenneTwister(0))
cause_a = :(state.suzieHistory[step] == 1)
cause_b = :(state.brokenHistory[step] == true)

while !eval(cause_b)
  global step
  global state
  global cause_a
  println(cause_a)
  if eval(cause_a)
    cause_a = a_causes(cause_a)
  end
  state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  step += 1
end
println(cause_a)
println(cause_b)
if !((cause_a.args[1] == cause_b.args[2] && eval(cause_a) == cause_b.args[3]) || cause_a == cause_b)
  println("A did not cause B")
  println(cause_a)
  @test false
else
  println("A did cause B")
  @test true
  @test step == 5
end

# -------------------------------Billy Test---------------------------------------
  #cause((billy == 0), (broken == true))
  step = 0
  aumod = eval(compiletojulia(aexpr))
  state = aumod.init(nothing, nothing, nothing, nothing, nothing, MersenneTwister(0))
  cause_a = :(state.billyHistory[step] == 0)
  cause_b = :(state.brokenHistory[step] == true)

  while !eval(cause_b)
    global step
    global state
    global cause_a
    println(cause_a)
    if eval(cause_a)
      cause_a = a_causes(cause_a)
    end
    state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
    step += 1
  end
  println(cause_a)
  println(cause_b)
  if !((cause_a.args[1] == cause_b.args[2] && eval(cause_a) == cause_b.args[3]) || cause_a == cause_b)#       println("A did not cause B")
    @test !false
    @test step == 5
  else
    println("A did cause B")
    @test !true
  end

#------------------------------Current Assumptions-------------------------------
# cause and event are both in the form x == y


#-------------------------------Julia Questions---------------------------------
# How do i make this into like a function?
# Fixing the world age issue
# Switch from compiler to interpreter?
# Fix the hard ocded part
# Clean up code and add documentation
# Look at notion
# What should occur if the variable isnt actually related
