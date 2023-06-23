# AutumnSynth.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://zenna.github.io/CausalDiscovery.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://zenna.github.io/CausalDiscovery.jl/dev)
[![Codecov](https://codecov.io/gh/zenna/CausalDiscovery.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/zenna/CausalDiscovery.jl)

Code for the paper [Combining Functional and Automata Synthesis to Discover Causal Reactive Programs](https://dspace.mit.edu/bitstream/handle/1721.1/147690/3571249.pdf?sequence=1&isAllowed=y).

# Installation

Install Julia 1.5.4 from [older releases](https://julialang.org/downloads/oldreleases/) and [Python 3](https://www.python.org/downloads/).

Clone repository:
```
git clone https://github.com/zenna/CausalDiscovery.jl.git
```

Install Python dependencies:
``` 
cd CausalDiscovery.jl
pip install -r requirements.txt
```

Install [Autumn.jl](https://github.com/riadas/Autumn.jl):
```
shell> julia
julia> ] activate .
(@v1.5) pkg> rm Autumn
(@v1.5) pkg> add https://github.com/riadas/Autumn.jl#cs-eachindex
```

# Quick Start
CISC:
``` 
julia> ] activate .
julia> include("src/synthesis/cisc/cisc.jl")
julia> @timed sols = run_model("ice", "heuristic")
julia> println(sols[1])
```
<details>
  <summary>Console output (expand)</summary>
  
  ```clojure
  
  (program
  (= GRID_SIZE 8)
  (= background "white")
  (object ObjType1 (: color String) (list (Cell 0 -1 color) (Cell 0 0 color) (Cell 1 -1 color) (Cell 1 0 color)))
  (object ObjType2  (list (Cell -1 0  "gray" ) (Cell 0 0  "gray" ) (Cell 1 0  "gray" )))
  (object ObjType3 (: color String) (list (Cell 0 0 color)))

  (: obj1 ObjType1)
  (: obj2 ObjType2)

  (: addedObjType1List (List ObjType1))
  (: addedObjType2List (List ObjType2))
  (: addedObjType3List (List ObjType3))

  (= obj1 (initnext (ObjType1  "gold"  (Position 0 1)) (prev obj1)))
  (= obj2 (initnext (ObjType2  (Position 4 0)) (prev obj2)))
  
  (= addedObjType1List (initnext (list) (prev addedObjType1List)))
  (= addedObjType2List (initnext (list) (prev addedObjType2List)))
  (= addedObjType3List (initnext (list) (prev addedObjType3List)))


  (: time Int)
  (= time (initnext 0 (+ time 1))) 

  (on left
(= obj2 (moveLeft (prev obj2))))
  (on right
(= obj2 (moveRight (prev obj2))))
  (on true
(= addedObjType3List (updateObj addedObjType3List (--> obj (nextLiquid (prev obj))) (--> obj true))))
  (on (== (.. (prev obj1) color) "gray")
(= addedObjType3List (updateObj addedObjType3List (--> obj (moveDownNoCollision (prev obj))) (--> obj true))))
  (on true
(= addedObjType3List (updateObj addedObjType3List (--> obj (updateObj (prev obj) "color" "blue")) (--> obj (& clicked (! (intersects (list "blue") (map (--> obj (.. obj color)) (list (prev obj))))))))))
  (on true
(= addedObjType3List (updateObj addedObjType3List (--> obj (updateObj (prev obj) "color" "lightblue")) (--> obj (& (& (== (.. (prev obj1) color) "gold") clicked) (! (intersects (list "lightblue") (map (--> obj (.. obj color)) (list (prev obj))))))))))
  (on (& clicked (!= (.. (prev obj1) color) "gold"))
(= obj1 (updateObj (prev obj1) "color" "gold")))
  (on (& (& clicked (== (.. (prev obj1) color) "gold")) (!= (.. (prev obj1) color) "gray"))
(= obj1 (updateObj (prev obj1) "color" "gray")))
  (on (& down (== (.. (prev obj1) color) "gold"))
(= addedObjType3List (addObj addedObjType3List (ObjType3  "blue"  (move (.. (prev obj2) origin) (Position 0 1))))))
  (on (& down (== (.. (prev obj1) color) "gray"))
(= addedObjType3List (addObj addedObjType3List (ObjType3  "lightblue"  (move (.. (prev obj2) origin) (Position 0 1)))))))
  
  ```
</details>

EMPA:
``` 
julia> ] activate .
julia> include("src/synthesis/empa/empa.jl")
julia> @timed sols = run_model("Bait", "heuristic")
julia> println(sols[1])
```

<details>
  <summary>Console output (expand)</summary>
  
  ```clojure
  
  (program
  (= GRID_SIZE (list 50 60))
  (= background "white")
  (object ObjType1  (map (--> pos (Cell pos  "darkgray" )) (rect (Position -9 -4) (Position 0 5))))
  (object ObjType2  (map (--> pos (Cell pos  "green" )) (rect (Position -9 -4) (Position 0 5))))
  (object ObjType3  (map (--> pos (Cell pos  "brown" )) (rect (Position -9 -4) (Position 0 5))))
  (object ObjType4  (map (--> pos (Cell pos  "darkblue" )) (rect (Position -9 -4) (Position 0 5))))
  (object ObjType5  (map (--> pos (Cell pos  "orange" )) (rect (Position -9 -4) (Position 0 5))))

  (: addedObjType1List (List ObjType1))
  (: obj22 ObjType2)
  (: addedObjType3List (List ObjType3))
  (: obj25 ObjType4)
  (: obj26 ObjType5)

  (: addedObjType2List (List ObjType2))
  (: addedObjType4List (List ObjType4))
  (: addedObjType5List (List ObjType5))

  (= addedObjType1List (initnext (list (ObjType1  (Position 9 34)) (ObjType1  (Position 9 44)) (ObjType1  (Position 9 4)) (ObjType1  (Position 39 54)) (ObjType1  (Position 9 24)) (ObjType1  (Position 39 14)) (ObjType1  (Position 49 24)) (ObjType1  (Position 19 44)) (ObjType1  (Position 49 44)) (ObjType1  (Position 19 4)) (ObjType1  (Position 29 4)) (ObjType1  (Position 9 54)) (ObjType1  (Position 49 14)) (ObjType1  (Position 19 24)) (ObjType1  (Position 9 14)) (ObjType1  (Position 19 54)) (ObjType1  (Position 39 4)) (ObjType1  (Position 49 4)) (ObjType1  (Position 49 34)) (ObjType1  (Position 29 54)) (ObjType1  (Position 49 54))) (prev addedObjType1List)))
  (= obj22 (initnext (ObjType2  (Position 19 14)) (prev obj22)))
  (= addedObjType3List (initnext (list (ObjType3  (Position 29 34)) (ObjType3  (Position 39 34))) (prev addedObjType3List)))
  (= obj25 (initnext (ObjType4  (Position 29 14)) (prev obj25)))
  (= obj26 (initnext (ObjType5  (Position 29 44)) (prev obj26)))

  (= addedObjType2List (initnext (list) (prev addedObjType2List)))
  (= addedObjType4List (initnext (list) (prev addedObjType4List)))
  (= addedObjType5List (initnext (list) (prev addedObjType5List)))

         (: globalVar1 Int)
         (= globalVar1 (initnext 2 (prev globalVar1)))

  (: arrow Position)
  (= arrow (initnext (Position 0 0) (prev arrow)))
  (on true
(= arrow (if left then (Position -10 0) else (if right then (Position 10 0) else (if up then (Position 0 -10) else (if down then (Position 0 10) else (Position 0 0)))))))

  (: time Int)
  (= time (initnext 0 (+ time 1)))

  (on (| (| (pushConfiguration arrow (prev obj25) (prev addedObjType3List)) (isFree (.. (move (prev obj25) arrow) origin))) (moveIntersects arrow (prev obj25) (prev obj26)))
(= obj25 (moveNoCollisionColor (prev obj25) (.. arrow x) (.. arrow y) "darkgray")))
  (on (& (== (prev globalVar1) 1) left)
(= obj22 (removeObj (prev obj22))))
  (on true
(= addedObjType3List (updateObj addedObjType3List (--> obj (moveNoCollisionColor (prev obj) (.. arrow x) (.. arrow y) "darkgray")) (--> obj (pushConfiguration arrow (prev obj25) (list (prev obj)))))))
  (on (moveIntersects arrow (prev obj25) (prev obj26))
(= obj26 (removeObj (prev obj26))))
  (on (isOutsideBounds (move (prev obj25) 0 20))
(= globalVar1 1)))
  
  ```
</details>

# Under the Hood
CISC:
```
julia> include("src/synthesis/cisc/cisc.jl")
julia> model_name = "ice"
julia> observations, user_events, grid_size = generate_observations(model_name)
julia> matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=false, pedro=false)
julia> global_event_vector_dict = Dict(); redundant_events_set = Set()
julia> solutions = generate_on_clauses_GLOBAL(model_name, false, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size)
julia> program = full_program_given_on_clauses(solutions[1]..., grid_size, matrix)
julia> println(program)
```
EMPA: 
```
julia> include("src/synthesis/empa/empa.jl")
julia> model_name = "Bait"
julia> observations, user_events, grid_size = generate_observations_empa(model_name)
julia> matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=true, pedro=true)
julia> global_event_vector_dict = Dict(); redundant_events_set = Set()
julia> solutions = generate_on_clauses_GLOBAL(model_name, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, state_synthesis_algorithm="heuristic", symmetry=true)
julia> program = full_program_given_on_clauses(solutions[1]..., grid_size, matrix, unformatted_matrix, user_events)
julia> println(program)
```
# Web Interface
[Autumnal.js (live link in README)](https://github.com/riadas/Autumnal.js)
