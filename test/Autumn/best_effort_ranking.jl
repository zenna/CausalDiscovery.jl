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

aexpr2 = au"""(program
(= GRID_SIZE 16)

(object Particle (Cell 0 0 "blue"))

(: particles (List Particle))
(= particles
(initnext (list)
(updateObj (prev particles) (--> obj (Particle (uniformChoice (adjPositions (.. obj origin))))))))

(on clicked (= particles (addObj (prev particles) (Particle (Position (.. click x) (.. click y))))))
)"""

aexpr3 = au"""(program
(= GRID_SIZE 16)

(object Particle (Cell 0 0 "red"))

(: particles (List Particle))
(= particles
(initnext (list)
(updateObj (prev particles) (--> obj (Particle (uniformChoice (adjPositions (.. obj origin))))))))

(on clicked (= particles (addObj (prev particles) (Particle (Position (.. click x) (.. click y))))))
)"""

aumod = eval(compiletojulia(aexpr))
state = aumod.init(nothing, nothing, nothing, nothing, nothing, MersenneTwister(0))
state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
state = aumod.next(state, aumod.Click(5,5), nothing, nothing, nothing, nothing)

# p = eval(compiletojulia(aexpr))
aumod2 = eval(compiletojulia(aexpr2))

e = [(aum -> [aum.Cell(aum.Position(5, 5), "blue", 0.8)],
[[nothing, nothing, nothing, nothing, nothing, MersenneTwister(0)],
[nothing, nothing, nothing, nothing, nothing],
[aumod2.Click(5,5), nothing, nothing, nothing, nothing]]),
(aum -> [aum.Cell(aum.Position(6, 6), "blue", 0.8), aum.Cell(aum.Position(8, 8), "red", 0.8), aum.Cell(aum.Position(5, 5), "blue", 0.8)],
[[nothing, nothing, nothing, nothing, nothing, MersenneTwister(0)],
[nothing, nothing, nothing, nothing, nothing],
[aumod2.Click(5,4), nothing, nothing, nothing, nothing]])]

@inferred get_fitness(aumod2, e, aexpr2)
fitness_p1 = get_fitness(aumod2, e, aexpr2)

e = [(aum -> [aum.Cell(aum.Position(5, 5), "blue", 0.8)],
[[nothing, nothing, nothing, nothing, nothing, MersenneTwister(0)],
[nothing, nothing, nothing, nothing, nothing],
[aumod2.Click(5,5), nothing, nothing, nothing, nothing]])]

@inferred get_fitness(aumod2, e, aexpr2)
fitness_p2 = get_fitness(aumod2, e, aexpr2)

@test fitness_p1 > fitness_p2

aumod3 = eval(compiletojulia(aexpr3))

e = [(aum -> [aum.Cell(aum.Position(5, 5), "blue", 0.8)],
[[nothing, nothing, nothing, nothing, nothing, MersenneTwister(0)],
[nothing, nothing, nothing, nothing, nothing],
[aumod3.Click(5,5), nothing, nothing, nothing, nothing]])]

@inferred get_fitness(aumod3, e, aexpr3)
fitness_p3 = get_fitness(aumod3, e, aexpr3)

@test fitness_p3 > fitness_p1
@test fitness_p3 > fitness_p2
