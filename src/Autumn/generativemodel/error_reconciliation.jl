function error_correction_solution_non_iterative()

end

function error_correction_solution_iterative()

end

"""
To Do:
- fix bug in Autumn compiler where default behavior is not applied to list elements when only some elements of the list have on-clauses applied
- mapping/parsing fixes:
  - DONE bias later frame decompositions with object types from earlier, to avoid issues like the Ice-parsing problem
  - DONE switch between singlecell and non-singlecell parsing versions when observation trace has overlaps
  - DONE support object types having a color field, at least in the multi-cellular case
  - POSTPONE supporting rotations for object types, i.e. not defining new object types for shapes that have just been rotated
- dynamics matrix parsing 
  - generating event predicates via genBool
  - augmenting dynamics matrix with abstractions of atomic update rules (i.e. abstracting concrete function parameters via gen[Position, Int, Bool])
  - implementing non-iterative and iterative parsing algorithms:
    - non-iterative approach
      - eliminating elements of dynamics matrix cells that are redundant
      - finding the simplest object to handle inside each type (i.e. fewest possibilities, most single-update rule cells)
      - minimizing the number of update function changes (dynamic programming?)
    - iterative approach
      - 
"""