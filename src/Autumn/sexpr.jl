"For writing Autumn programs, prior to having an Autumn parser"
module SExpr
# using Rematch
using MLStyle
using SExpressions
using ..AExpressions

export parseau, @au_str

#fix map
#fix = in type
#fix BigInt
prog = au"""
    (program
    (external (: z Int))
    (: x Int)
    (= x 3)
    (: y Int)
    (= y (initnext (+ 1 2) (/ 3 this)))
    (: map (-> (-> a b) (List a) (List b)))
    (= xs [1 2 3])
    (: f (-> Int Int))
    (= f (fn (x) (+ x x)))
    (= ys (map f xs))
    (type Particle a (Particle a) (Dog Float64 Float64))
    (: g (-> (Particle a) (Int)))
    (= g (fn (particle)
            (case particle
                  (=> (Particle a_) 4)
                  (=> (Dog a_ b_) 5))))
    (: o Int)
    (= o (let (q 3 d 12) (+ q d)))
    (--> x (+ x 1))
  )
  """

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

#map is wrong
#shouldnt say BigInt
#symbol list should be parsed
#fn (x) incorrect
#particle is incorrect
# (: map (-> (-> a b) (List a) (List b)))
"Parse SExpression into Autumn Expressions"
function parseau(sexpr::AbstractArray)
  print(typeof(sexpr))
  print("\n")
  print("\n")
  res = MLStyle.@match sexpr begin
    [:program, lines...]              => AExpr(:program, map(parseau, lines)...)
    [:if, c, t, e]                    => AExpr(:if, parseau(c), parseau(t), parseau(e))
    [:initnext, i, n]                 => AExpr(:initnext, parseau(i), parseau(n))
    # [:let, ]                           => parse_letexpr(sexpr)
    [:(=), x::Symbol, y]              => AExpr(:assign, x, parseau(y))
    [:(:), v::Symbol, τ]              => AExpr(:typedecl, v, parsetypeau(τ))
    [:typedecl, v::Symbol, τ]         => AExpr(:typedecl, v, parsetypeau(τ))
    [:external, tdef]                 => AExpr(:external, parseau(tdef))
    [:let, vars, todo]                => AExpr(:let, parseletvars(vars)..., parseau(todo))
    [:case, type, cases...]           => AExpr(:case, type, map(parseau, cases)...)
    [:(=>), type, value]              => AExpr(:casevalue, parsecase(type), value)
    [:type, values...]                => AExpr(:type, map(parsecase, values)...)
    [:fn, name, func]                 => AExpr(:fn, parseau(name), parseau(func))
    [:(-->), var, val]                => AExpr(:lambda, parseau(var), parseau(val))
    [f, xs...]                        => AExpr(:call, parseau(f), map(parseau, xs)...)
  end
end

function parsecase(sym::Symbol)
  sym
end

function parsecase(list::Array{})
  Expr(:casetype, list...)
end
#(: map (-> (-> a b) (List a) (List b)))
function parsetypeau(sexpr::AbstractArray)
  MLStyle.@match sexpr begin
    [τ, tvs...]  && if (istypesymbol(τ) && all(istypevarsymbol.(tvs)))  end => AExpr(:paramtype, τ, tvs...)
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
