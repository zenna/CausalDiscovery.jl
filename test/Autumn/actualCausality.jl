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

  aexpr2 = au"""(program
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

aexpr3 = au"""(program
  (= GRID_SIZE 16)

  (object Suzie (: timeTillThrow Integer) (Cell 0 0 "blue"))

  (: suzieThrew Bool)
  (= suzieThrew (initnext false (prev suzieThrew)))

  (: suzie Suzie)
  (= suzie (initnext (Suzie 3 (Position 0 0))
    (updateObj (prev suzie) "timeTillThrow" (- (.. (prev suzie) timeTillThrow) 1))))

  (on (== (.. suzie timeTillThrow) 0) (= suzieThrew true))

  )"""

function tostate(var)
  return Meta.parse("state.$(var)History[step]")
end

function tostate(var, field)
  return Meta.parse("state.$(var)History[step].$field")
end

function tostateshort(var)
  return Meta.parse("state.$(var)History")
end

function isfield(var)
  (length(split(string(var), "].")) > 1 || length(split(string(var), ").")) > 1)
end

function reducenoeval(var)
  strvar = replace(string(var), "(" => "")
  strvar = replace(strvar, ")" => "")
  split_ = split(strvar, "[")
  Meta.parse(split_[1])
end

function pushbyfield(var, val)
  if isfield(a.args[2])
    eval(Expr(:(=), a.args[2], val))
  else
    push!(reduce(a.args[2]), step =>val)
  end
end

function fakereduce(var)
  Meta.parse(string(var))
end

function reduce(var)
  strvar = replace(string(var), "(" => "")
  strvar = replace(strvar, ")" => "")
  split_ = split(strvar, "[")
  eval(Meta.parse(split_[1]))
end

function getstep(var)
  split_1 = split(string(var), "[")
  split_2 = split(split_1[2], "]")
  index = eval(Meta.parse(split_2[1]))
end

function increment(var::Expr)
  split_1 = split(string(var), "[")
  split_2 = split(split_1[2], "]")
  index = eval(Meta.parse(split_2[1]))
  if index == :step
    return eval(Meta.parse(join([split_1[1], "[step]", split_2[2]])))
  end
  return Meta.parse(join([split_1[1], "[", string(index + 1), "]", split_2[2]]))
end

restrictedvalues = Dict(:(state.suzieHistory) => [0, 1, 2, 3, 4, 5, 6])

function possvals(val::Bool)
  [true, false]
end

function possvals(val::Union{BigInt, Int64})
  [-2^4:1:(2^4);]
end

function possvals(val)
  throw(AutumnError(string("Invalid variable type: ", typeof(val))))
end

function possiblevalues(var::Expr, val)
  if reducenoeval(var) in keys(restrictedvalues)
    return restrictedvalues[reducenoeval(var)]
  end
  possvals(eval(val))
end

function tryb(cause_b)
  try
    return eval(cause_b)
  catch e
    println(e)
    return false
  end
end

function acaused(cause_a::Expr, cause_b::Expr)
  if eval(cause_a)
    varstore = eval(cause_a.args[2])
    short = eval(reduce(cause_a.args[2]))
    index = getstep(cause_a.args[2])
    for val in possiblevalues(cause_a.args[2], cause_a.args[3])
      push!(reduce(cause_a.args[2]), step =>val)
      if !(eval(cause_b))
        push!(reduce(cause_a.args[2]), step =>varstore)
        return true
        break
      end
    end
    push!(reduce(cause_a.args[2]), step =>varstore)
  end
  false
end
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
      # println(get_a_causes)
      eval(get_a_causes)
      aumod = eval(compiletojulia($aexpr_))
      state = aumod.init(nothing, nothing, nothing, nothing, nothing, MersenneTwister(0))
      causes = [$cause_a_]
      cause_b = $cause_b_

      while !tryb(cause_b) && length(causes) > 0
        new_causes = []
        println(causes)
        for cause_a in causes
          try
            if eval(cause_a)
              append!(new_causes, a_causes(cause_a))
            elseif ()
              append!(new_causes, cause_a)
            end
          catch e
            println(e)
            append!(new_causes, [cause_a])
          end
        end
        global causes = new_causes
        global state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
        global step = step + 1
      end
    for cause_a in causes
      if acaused(cause_a, cause_b)
        println("A did cause B")
        println("a path")
        println(cause_a)
        println("b path")
        println(cause_b)
        $cause
        return
      end
    end
    println("A did not cause B")
    println("causes")
    println(causes)
    println("cause b")
    println(cause_b)
    $not_cause
  end
end
# ------------------------------Suzie Test---------------------------------------
# cause((suzie == 1), (broken == true))
a = :(state.suzieHistory[step] == 1)
b = :(state.brokenHistory[step] == true)
@test_ac(true, aexpr, a, b)
#
# a = :(state.suzieHistory[0] == 1)
# b = :(state.brokenHistory[5] == true)
# @test_ac(true, aexpr, a, b)
#
# a = :(state.suzieHistory[2] == 1)
# b = :(state.brokenHistory[step] == true)
# @test_ac(false, aexpr, a, b)
#
# # -------------------------------Billy Test---------------------------------------
# # cause((billy == 0), (broken == true))
# a = :(state.billyHistory[step] == 0)
# b = :(state.brokenHistory[step] == true)
# @test_ac(false, aexpr, a, b)
#
# # cause((billy == 0), (broken == true))
# a = :(state.billyHistory[0] == 1)
# b = :(state.brokenHistory[step] == true)
# @test_ac(false, aexpr, a, b)
#
# # cause((billy == 0), (broken == true))
# a = :(state.billyHistory[1] == 1)
# b = :(state.brokenHistory[step] == true)
# @test_ac(false, aexpr, a, b)
# #
# # ------------------------------Suzie Test---------------------------------------
# #cause((suzie == 1), (broken == true))
# a = :(state.suzieHistory[step] == 1)
# b = :(state.brokenHistory[step] == true)
# @test_ac(true, aexpr2, a, b)
#
# # -------------------------------Billy Test---------------------------------------
# # cause((billy == 0), (broken == true))
# a = :(state.billyHistory[step] == 0)
# b = :(state.brokenHistory[step] == true)
# @test_ac(false, aexpr2, a, b)
#
# # # -----------------------------Advanced Suzie Test No Rock-----------------------
# a = :(state.suzieHistory[step].timeTillThrow == 3)
# b = :(state.suzieThrewHistory[step] == true)
# @test_ac(true, aexpr3, a, b)
#
# a = :(state.suzieHistory[step].timeTillThrow == 2)
# b = :(state.suzieThrewHistory[step] == true)
# @test_ac(true, aexpr3, a, b)
#
# a = :(state.suzieHistory[2].timeTillThrow == 3)
# b = :(state.suzieThrewHistory[step] == true)
# @test_ac(false, aexpr3, a, b)
#
# # # -----------------------------Advanced Billy Test No Rock-----------------------
# a = :(state.suzieHistory[step].timeTillThrow == 4)
# b = :(state.suzieThrewHistory[step] == true)
# @test_ac(false, aexpr3, a, b)
#
# a = :(state.suzieHistory[0].timeTillThrow == 4)
# b = :(state.suzieThrewHistory[step] == true)
# @test_ac(false, aexpr3, a, b)

# # -------------------------------Advanced Suzie Test---------------------------------------
a = :(state.suzieHistory[step].timeTillThrow == 3)
b = :(state.broeknHistory[step] == true)
@test_ac(true, aexpr3, a, b)

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

    (: billy Billy)
    (= suzie (initnext (Billy 4 (Position 0 0))
      (updateObj (prev billy) "timeTillThrow" (- (.. (prev billy) timeTillThrow) 1))))

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

    (on (intersects (prev bottleSpot) (prev rocks)) (= bottle (nextBottle (prev bottle) (prev rocks) (prev bottleSpot))))
  )"""

#syntactic pattern matching but its not necessarily syntactic thing
#what to do if non trivial
#in my set of causes
#instead of checking syntax check if changing the value changes the next value
#maybe split the ors then do that?
#remove it


#Now it removes the variable and if it errors or becomes false then it determines that it is related
#Need to think about or statements/and statements where it is always true
#(but for the a < 100 or a >99 wouldnt a not existing prevent this from being true and would therefore be the cause?)
#Need to handle more syntax things like the sub fields

#changes from always true to maybe true
#find some p that makes it false
#execute abstractly
#abstraction problem
#abstract interpretation take program redefine operations to work with values (replace numbers with intervals)


#changed model where change what we currently have
#suppose that suzie throws and if its close then it breaks
#except for some tiny location think about it and solve it
#add to the question
#prove that there are no counter examples
