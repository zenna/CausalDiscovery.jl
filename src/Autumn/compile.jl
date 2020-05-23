"Compilation to Julia (and other targets, if you want)"
module Compile

using ..AExpressions

"Compile `aexpr` into `program::Program`"
compiletojulia(::AExpr) = 
  error("Can only compile complete Autumn programs")

function compiletojulia(::ProgramExpr)::Program
  # Do type inference
  # Get external values
  # Alot
end

function runprogram(::Program)
  initexterns = (x = 3, y = 2)
  state = init(p, initexterns)
  while true
    externs = (x = rand(3:10), y = rand(1:10))
    state = next(state, externs)
  end
  state
end

end
