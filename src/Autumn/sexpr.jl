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
    [:(=), x::Symbol, y]              => AExpr(:assign, x, parseau(y))
    [:(:), v::Symbol, τ]              => AExpr(:typedecl, v, parsetypeau(τ))
    [:typedecl, v::Symbol, τ]         => AExpr(:typedecl, v, parsetypeau(τ))
    [:external, tdef]                 => AExpr(:external, parseau(tdef))
    [:let, vars, todo]                => AExpr(:let, parseletvars(vars)..., parseau(todo))
    [:case, type, cases...]           => AExpr(:case, type, map(parseau, cases)...)
    [:(=>), type, value]              => AExpr(:casevalue, parsecase(type), value)
    [:fn, name, func]                 => AExpr(:fn, parseau(name), parseau(func))
    [:(-->), var, val]                => AExpr(:lambda, parseau(var), parseau(val))
    [:(->), first, second]            => AExpr(:functiontype, parseau(first), parseau(second))
    [:list, vars...]                  => AExpr(:list, map(parseau, vars)...)
    [f, xs...]                        => AExpr(:call, parseau(f), map(parseau, xs)...)
  end
end

function parsealias(expr)
  AExpr(:list, expr...)
end

function parsecase(sym::Symbol)
  if sym == :emptylist
    []
  else
    sym
  end
end

function parsecase(list::Array{})
  Expr(:casetype, map(parseau, list)...)
end
#(: map (-> (-> a b) (List a) (List b)))
function parsetypeau(sexpr::AbstractArray)
  MLStyle.@match sexpr begin
    [τ, tvs...]  && if (istypesymbol(τ) && all(istypevarsymbol.(tvs)))  end => AExpr(:paramtype, τ, tvs...)
    [τ, tvs] && if istypesymbol(τ) end                                      => AExpr(:paramtype, τ, parseau(tvs))
    [:->, τ1, τ2]                                                           => AExpr(:functiontype, parsetypeau(τ1), parsetypeau(τ2))
    [:×, τs...]                                                             => AExpr(:producttype, map(parsetypepau, τs)...)
    [:->, τs...]                                                            => AExpr(:functiontype, map(parsetypeau, τs)...)
    τ && if istypesymbol(τ) end                                             => τ

  end
end

function parseletvars(list::Array{})
  result = []
  i = 1
  while i < length(list)
    append!(result, [Expr(:assign, parseau(list[i]), parseau(list[i+1]))])
    i += 2
  end
  result
end

parseau(list::Array{BigInt, 1}) = list
parsetypeau(s::Symbol) = s
parseau(s::Symbol) = parsecase(s)
parseau(s::Union{Number, String}) = s

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
