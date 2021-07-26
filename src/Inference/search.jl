using Random
using Autumn
include("generativemodel.jl")

a = au"""(program
      (= GRID_SIZE 16)

      (object Particle (Cell 0 0 "blue"))

      (: particles (List Particle))
      (= particles 
        (initnext (list) 
                  (updateObj (prev particles) (--> obj (Particle (uniformChoice (adjPositions (.. obj origin)))))))) 

      (on clicked (= particles (addObj (prev particles) (Particle (Position (.. click x) (.. click y))))))
      )"""

mod = eval(compiletojulia(a))

rng = MersenneTwister(0)
state = mod.init(nothing, nothing, nothing, nothing, nothing, rng);

# add particles
for i in 1:3
  global state = mod.next(state, mod.Click(rand(0:15),rand(0:15)), nothing, nothing, nothing, nothing); mod.render(state.scene)
end

# let particles move
for i in 1:5
  global state = mod.next(state, mod.Click(rand(0:15),rand(0:15)), nothing, nothing, nothing, nothing); mod.render(state.scene)
end

# render
rendering = mod.render(state.scene)

# parse scene rendering into types and objects
types_and_objects = parsescene_autumn_singlecell(rendering)

# # generate random dynamics on object decomposition (types and objects)
# println(generateprogram_given_objects(types_and_objects, group=true))