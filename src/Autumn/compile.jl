"Compilation to Julia (and other targets, if you want)"
module Compile

using ..AExpressions
using ..Program

"Compile `aexpr` into `program::Program`"
function compiletojulia(::AExpr)::AProgram
  # Do type inference
  # Get external values
  # Alot
end

"Run `prog` forever"
function runprogram(prog::AProgram)
  initexterns = (x = 3, y = 2)
  state = init(p, initexterns)
  while true
    externs = (x = rand(3:10), y = rand(1:10))
    state = next(state, externs)
  end
  state
end

end
