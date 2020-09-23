using Test
using CausalDiscovery
using Random

aexpr = au"""(program
(= GRID_SIZE 16)

(object Particle (Cell 0 0 "blue"))

(: particles (List Particle))
(= particles 
   (initnext (list) 
             (updateObj (prev particles) (--> obj (Particle (uniformChoice (adjPositions (.. obj origin))))))))        

(on clicked (= particles (addObj (prev particles) (Particle (Position (.. click x) (.. click y))))))
)"""
#
mod = eval(compiletojulia(aexpr))

# time 0
state = mod.init(nothing, nothing, nothing, nothing, nothing, MersenneTwister(0))
@test mod.render(state.scene) == []

# time 1
state = mod.next(state, nothing, nothing, nothing, nothing, nothing)
@test mod.render(state.scene) == []

# time 2
state = mod.next(state, mod.Click(5,5), nothing, nothing, nothing, nothing)
@test mod.render(state.scene) == [mod.Cell(mod.Position(5, 5), "blue", 0.8)]

# time 3
state = mod.next(state, nothing, nothing, nothing, nothing, nothing)
@test mod.render(state.scene) == [mod.Cell(mod.Position(4, 5), "blue", 0.8)]

# time 4
state = mod.next(state, nothing, nothing, nothing, nothing, nothing)
@test mod.render(state.scene) == [mod.Cell(mod.Position(3, 5), "blue", 0.8)]
