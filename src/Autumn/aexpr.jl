module AExpressions

export AExpr, ProgramExpr, TypeExpr, ExternDecl, GlobalBind,
       ITEExpr, InitNextExpr, FAppExpr, LetExpr, LambdaExpr
"""
program     := line
line        := externdecl | globalbind | typedecl

externdecl  := extern typeexpr x
globalbind  := x = expr
typedecl    := x :: typeexpr

typeexpr    :=

expr        := fexpr | lambdaexpr | iteexpr | initnextexpr | letexpr |
               this
iteexpr     := if expr then expr else expr
intextexpr  := init expr next expr
fappexpr    := expr expr
letexpr     := let x = expr in expr
lambdaexpr  := x -> expr
"""

"Autumn Expression"
abstract type AExpr end

struct ProgramExpr <: AExpr
  expr::Vector{AExpr}
end

"Type Expression"
struct TypeExpr <: AExpr
  ok
end   

"Declares external value"
struct ExternDecl <: AExpr
  x::Symbol
  τ::TypeExpr
end

"Globally bind value to variable `x = val`"
struct GlobalBind <: AExpr
  x::Symbol
  val::AExpr
end

"If Then Else expression"
struct ITEExpr <: AExpr
  i::AExpr
  t::AExpr
  e::AExpr
end

"Init Next expression"
struct InitNextExpr <: AExpr
  init::AExpr
  next::AExpr
end

"Function application expression"
struct FAppExpr <: AExpr
  f::AExpr
  arg::AExpr   # FIXME, only a single arg??
end

"Let AExpr, let `var` = `val` in `body`"
struct LetExpr <: AExpr
  var::Symbol
  val::AExpr
  body::AExpr
end

"Lambda AExpr `arg` -> `body`"
struct LambdaExpr <: AExpr
  arg::AExpr
  body::AExpr
end

end