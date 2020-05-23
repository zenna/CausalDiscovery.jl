module AExpressions

export AExpr, ProgramExpr, TypeDef, TypeExpr, ExternalDecl, GlobalBind,
       ITEExpr, InitNextExpr, FAppExpr, LetExpr, LambdaExpr

export istypesymbol,
       istypevarsymbol,
       args

const autumngrammar = """
program     := line
line        := externaldecl | globalbind | typedecl | typedef

typedef     := type fields
fields      := field | fields field
field       := constructor | constructor typesymbol*
cosntructor := typesymbol


externaldecl  := external typeexpr x
globalbind  := x = expr
typedecl    := x :: typeexpr

typeexpr    := typesymbol | paramtype | typevar | functiontype
funtype     := typeexpr -> typeexpr
producttype := typeexpr × typexexpr × ...
typesymbol  := primtype | customtype
primtype    := Int | Bool | Float
custontype  := :A | :B | ... | :Aa | ...

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

"A full program"
struct ProgramExpr <: AExpr
  expr::Vector{AExpr}
end
args(aexpr::ProgramExpr) = aexpr.expr

# # Expression Types
abstract type TypeExpr <: AExpr end

"Is `sym` a type symbol"
istypesymbol(sym) = (q = string(q); length(q) > 0 && isuppercase(q[1]))
istypevarsymbol(sym) = (q = string(q); length(q) > 0 && islowercase(q[1]))

"Type Expression"
struct TypeSymbol <: TypeExpr
  name::Symbol
  function TypeSymbol(name::Symbol)
    istypesymbol(name) || error("Symbol is not type symbol")
    new(name)
  end
end

struct TypeVar <: TypeExpr
  name::Symbol
  function TypeVar(name::Symbol)
    !istypevarsymbol(name) || error("Symbol is not type variable")
    new(name)
  end
end

"Parametric Type Expression, e.g. Maybe a"
struct ParamTypeExpr <: TypeExpr
  basename::TypeSymbol
  typevars::Vector{TypeVar}
end

"Function type `A -> B`"
struct FunctionTypeExpr <: TypeExpr
  intype::TypeExpr
  outtype::TypeExpr
end

"Product type `A × B × ⋯`"
struct ProductTypeExpr <: TypeExpr
  components::Vector{TypeExpr}
end

"Type Declaration `f: τ`"
struct TypeDecl <: TypeExpr
  name::Symbol
  type::TypeExpr
end

"Declares external value `external x : τ`"
struct ExternalDeclExpr <: AExpr
  x::Symbol
  typedecl::TypeDecl
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
  args::Vector{AExpr}   # FIXME, only a single arg??
end

"Let AExpr, let `var` = `val` in `body`"
struct LetExpr <: AExpr
  var::Symbol
  val::AExpr
  body::AExpr
end

"Lambda AExpr `arg` -> `body`"
struct LambdaExpr <: AExpr
  args::AExpr
  body::AExpr
end
args(aexpr::LambdaExpr) = [aexpr.args aexpr.body]

# # Methods
"Number of nodes in expression tree"
nnodes(aexpr::AExpr) = 1 + reduce(+nnodes, args(aexpr))
nnodes(_) = 1

end