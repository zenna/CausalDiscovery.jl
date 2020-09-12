using OmegaCore
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

ω = defω()

# time 0
state = aumod.init(nothing, nothing, nothing, nothing, nothing, ω)
state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
state = aumod.next(state, aumod.Click(5,5), nothing, nothing, nothing, nothing)
state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)

@test aumod.render(state.scene) == []