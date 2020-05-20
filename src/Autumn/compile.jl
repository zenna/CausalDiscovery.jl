"Compilation to Julia (and other targets, if you want)"
module Compile

using ..AExpressions

"Compile `aexpr` into `program::Program`"
compiletojulia(::AExpr) = 
  error("Can only compile complete Autumn programs")

function compiletojulia(::ProgramExpr)
  # Do type inference
  # Get external values
  # Alot
end

end
