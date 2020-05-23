"For writing Autumn programs, prior to having an Autumn parser"
module SExpr
using Rematch
using SExpressions
using ..AExpressions: AExpr

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
parseau(sexprstring::AbstractString) =
  parseau(array(SExpressions.Parser.parse(sexprstring)))

"Parse SExpression into Autumn Expressions"
function parseau(sexpr::AbstractArray)
  headis(s) = first(sexpr) == s
  nargs(expr, n) = length(rest(expr)) == n

  Rematch.@match sexpr begin
    [:program, lines...]              => ProgramExpr(map(parseau, lines))
    [:if, c, t, e]                    => ITEExpr(parseau(c, parseau(t), parseau(e)))
    [:init, i, n]                     => ITEExpr(parseau(i), parseau(n))
    # [:let, ]                           => parse_letexpr(sexpr)
    [:(=), x::Symbol, y]              => GlobalBind(parseau(y))
    [:(::), v::Symbol, τ]             => TypeDecl(v, parsetypeau(τ))
    [:external, [:(::), v::Symbol, τ]]=> ExternalDecl(TypeDecl(v, parsetypeau(τ)))
    # [:->, x, y]                       => LambdaExpr(x, y)
    # [:type, ...]                      => parse_typeexpr(sexpr)
  end
end

function parsetypeau(sexpr::AbstractArray)
  Rematch.@match sexpr begin
    τ where istypesymbol(τ)                                           => TypeSymbol(I)
    [τ, tvs...]  where (istypesymbol(τ) && all(istypevarsymbol.(tvs)))  => ParamTypeExpr(τ, tvs)
    [:->, τ1, τ2]                                                     => FunctionTypeExpr(τ1, τ2)
    [:×, τs...]                                                       => ProductTypeExpr(map(parsetypepau, τs))
  end
end

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
  QuoteNode(parseau(x))
end


end