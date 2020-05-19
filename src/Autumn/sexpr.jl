"For writing Autumn programs, prior to having an Autumn parser"
module SExpr
using SExpressions
using ..AExpressions: AExpr

export parseautumn, @au_str

rest(sexpr::SExpressions.Cons) = sexpr.cdr

"""Parse string `saexpr` into AExpr

```julia

prog = \"\"\"
(program
  (= x 3)
  (let (x 3) (+ x 3))
)
\"\"\"

"""
parseautumn(sexprstring::AbstractString) =
  parseautumn(SExpressions.Parser.parse(sexprstring))

"Parse SExpression into Autumn Expressions"
function parseautumn(sexpr::SExpressions.Cons)
  headis(s) = first(sexpr) == s
  if headis(:program)
    ProgramExpr(map(parseautumn, rest(sexpr)))
  elseif headis(:(::))
    TypeExpr()
  elseif headis(:(=))
    GlobalBind(sexpr[1], parseautumn(sexpr[2]))
  elseif headis(:if)
    ITEExpr(map(parseautumn, rest(sexpr))...)
  elseif headis(:time)
    InitNext(map(parseautumn, rest(sexpr))...)
  elseif headis(:(->))
    LambdaExpr(vars, rest)
  elseif headis(:let)
    LetExpr()
  elseif headis(:extern)
    ExternDecl()
  else
    error("Could not parse $(first(sexpr))")
  end
end

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