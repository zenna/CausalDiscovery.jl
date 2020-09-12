using Test
using CausalDiscovery
using Random
using MLStyle

aexpr = au"""(program
(= GRID_SIZE 16)

(object Particle (Cell 0 0 "blue"))

(: particles (List Particle))
(= particles 
   (initnext (list) 
             (updateObj (prev particles) (--> obj (Particle (uniformChoice (adjPositions (.. obj origin))))))))        

(on clicked (= particles (addObj (prev particles) (Particle (Position (.. click x) (.. click y))))))
)"""

aumod = eval(compiletojulia(aexpr))

# time 0
state = aumod.init(nothing, nothing, nothing, nothing, nothing, MersenneTwister(0))
@test aumod.render(state.scene) == []

# time 1
state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
@test aumod.render(state.scene) == []

# time 2
state = aumod.next(state, aumod.Click(5,5), nothing, nothing, nothing, nothing)
@test aumod.render(state.scene) == [aumod.Cell(aumod.Position(5, 5), "blue", 0.8)]

# time 3
state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
@test aumod.render(state.scene) == [aumod.Cell(aumod.Position(4, 5), "blue", 0.8)]

# time 4
state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
@test aumod.render(state.scene) == [aumod.Cell(aumod.Position(3, 5), "blue", 0.8)]
