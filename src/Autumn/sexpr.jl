"For writing Autumn programs, prior to having an Autumn parser"
module SExpr
# using Rematch
using MLStyle
using SExpressions
using ..AExpressions

export parseau, @au_str


fg(s) = s
fg(s::Cons) = array(s)
"Convert an `SExpression` into nested Array{Any}"
array(s::SExpression) = [map(fg, s)...]

@inline rest(sexpr::SExpressions.Cons) = sexpr.cdr
@inline rest2(sexpr::SExpressions.Cons) = rest(rest(sexpr))
"""Parse string `saexpr` into AExpr

```julia

prog = \"\"\"
(program
  (external (:: x Int))
  (:: y Float64)
  (group Thing (:: position Int) (:: alpha Bool))
  (= y 1.2)
  (= f 
    (-> (x y)
        (let (z (+ x y))
              (* z y)))
)
\"\"\"

"""
parseautumn(sexprstring::AbstractString) =
  parseau(array(SExpressions.Parser.parse(sexprstring)))

"Parse SExpression into Autumn Expressions"
function parseau(sexpr::AbstractArray)
  res = MLStyle.@match sexpr begin
    [:program, lines...]              => AExpr(:program, map(parseau, lines)...)
    [:if, c, t, e]                    => AExpr(:if, parseau(c), parseau(t), parseau(e))
    [:initnext, i, n]                 => AExpr(:initnext, parseau(i), parseau(n))
    # [:let, ]                           => parse_letexpr(sexpr)
    [:(=), x::Symbol, y]              => AExpr(:assign, x, parseau(y))
    [:(:), v::Symbol, τ]              => AExpr(:typedecl, v, parsetypeau(τ))
    [:external, tdef]                 => AExpr(:external, parseau(τ))
    [f, xs...]                        => AExpr(:call, parseau(f), map(parseau, xs)...)
    # [:->, x, y]                       => LambdaExpr(x, y)
    # [:type, ...]                      => parse_typeexpr(sexpr)
  end
end

function parsetypeau(sexpr::AbstractArray)
  MLStyle.@match sexpr begin
    τ && if istypesymbol(τ) end                                             => τ
    [τ, tvs...]  && if (istypesymbol(τ) && all(istypevarsymbol.(tvs)))  end => AExpr(:paramtype, τ, tvs...)
    [:->, τ1, τ2]                                                           => AExpr(:functiontype, parsetypeau(τ1), parsetypeau(τ2))
    [:×, τs...]                                                             => AExpr(:producttype, map(parsetypepau, τs)...)
  end
end
parsetypeau(s::Symbol) = s
parseau(s::Symbol) = s
parseau(s::Union{Number, String}) = s

# parse_programexpr(expr) = ProgramExpr(map(parseau, rest(sexpr)))
# parse_typeexpr(expr) = ... @match
# parse_typesymbol(sexpr) = TypeSymbol(sexpr)
# parse_typevar(sexpr) = TypeVar(sexpr)
# parse_iteexpr(sexpr) = ITEExpr(parseau(sexpr[2], parseau(sexpr[3]), parseau(sexpr[3])))
# parse_initnext(sexpr) = ITEExpr(parseau(sexpr[2], parseau(sexpr[3])))
# parse_letexpr(sexpr)  = LetExpr()
# parse_lambdaexpr(sexpr) = LambdaExpr()
# "(Event a)"
# parse_paramtypeexpr(sexpr) = TypeVar(sexpr[1], )
# parse_globalbind(sexpr) = GlobalBind()
# parse_typedecl(sexpr) = .;.

# :(--> τ1 τ2)
# parse_functiontypeexpr(sexpr) = ParamTypeExpr

"""
Macro for parsing autumn
au\"\"\"
(program
  (= x 3)
  (let (x 3) (+ x 3))
)
\"\"\"
"""
macro au_str(x::String)
  QuoteNode(parseautumn(x))
end


end