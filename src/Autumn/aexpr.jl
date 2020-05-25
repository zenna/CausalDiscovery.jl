"Autum Expressions"
module AExpressions

using MLStyle
export AExpr

export istypesymbol,
       istypevarsymbol,
       args,
       arg

const autumngrammar = """
program     := line 
line        := externaldecl | assignexpr | typedecl | typedef

typedef     := type fields
fields      := field | fields field
field       := constructor | constructor typesymbol*
cosntructor := typesymbol


externaldecl  := external typeexpr x
assignexpr  := x = expr
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
struct AExpr
  expr::Expr
end

AExpr(xs...) = AExpr(Expr(xs...))

function getindex(::AExpr, name::Symbol)
  if name == :expr
    aexpr.expr
  elseif name == :head
    aexpr.expr.head
  elseif name == :args
    aexpr.expr.args
  else
    error("no property $name of AExpr")
  end
end

"Arguements of expression"
function args end


"Expr in ith location in arg"
arg(aexpr, i) = args(aexpr)[i]

# Expression types

"Pretty print"
function showstring(expr::Expr)
  @match expr begin
    Expr(:program, statements...) => join(map(showstring, expr.args), "\n")
    Expr(:producttype, ts) => join(map(showstring, ts), "×")
    Expr(:functiontype, int, outt) => "$(showstring(int)) -> $(showstring(outt))"
    Expr(:typedecl, x, val) => "$x : $(showstring(val))"
    Expr(:externaldecl, x, val) => "external $x : $(showstring(val))"
    Expr(:assign, x, val) => "$x = $(showstring(val))"
    Expr(:if, i, t, e) => "if $(showstring(i)) then $(showstring(t)) else $(showstring(e))"
    Expr(:initnext, i, n) => "init $(showstring(i)) next $(showstring(n))"
    Expr(:call, f, args...) => join(map(showstring, [f ; args]), " ")
    x                       => "Fail $x"

    # Expr(:let, x)
    # Parametric types
    # type def
    # Lambda expression
  end
end

showstring(aexpr::AExpr) = showstring(aexpr.expr)
showstring(s::Union{Symbol, Integer}) = s

"Is `sym` a type symbol"
istypesymbol(sym) = (q = string(q); length(q) > 0 && isuppercase(q[1]))
istypevarsymbol(sym) = (q = string(q); length(q) > 0 && islowercase(q[1]))

# # # Methods
# # "Number of nodes in expression tree"
# # nnodes(aexpr::AExpr) = 1 + reduce(+nnodes, args(aexpr))
# # nnodes(_) = 1

end