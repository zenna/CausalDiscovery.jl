include("../synthesis/full_synthesis.jl");

function inductiveleap(effect_on_clauses, transition_on_clauses)
  effect_on_clause_aexprs = map(oc -> parseautumn(oc), effect_on_clauses)
  transition_on_clause_aexprs = map(oc -> parseautumn(oc), transition_on_clauses)

  # Step 1: rewrite left/right/up/down and moveLeft/Right/Up/Down with definitions
  effect_on_clause_aexprs = map(defaultsub, effect_on_clause_aexprs)
  transition_on_clause_aexprs = map(defaultsub, transition_on_clause_aexprs)

  # Step 2: find differences across effect on-clause assignments
  effect_differences = finddifference(effect_on_clause_aexprs)

  # Step 3: construct mapping between old state values and new state values and perform 
  # replacement in effect and transition on-clauses
  effect_state_values = map(aex -> parse(Int, replace(split(aex.args[1], "== (prev globalVar1) ")[end], ")" => "")), effect_on_clause_aexprs)

  ## construct new effect on-clause
  new_effect_on_clause_aexpr = deepcopy(effect_on_clause_aexprs[1])
  new_effect_on_clause_aexpr.args[1] = new_effect_on_clause_aexpr.args[1].args[1] # the co-occurring event only, without the globalVar dependence
  new_effect_on_clause_aexpr.args[2] = parseautumn(replace(repr(new_effect_on_clause_aexpr.args[2]), effect_differences[1] => "(prev globalVar)"))

  ## construct new transition on-clauses
  new_transition_on_clause_aexprs = deepcopy(transition_on_clause_aexprs)
  new_transition_on_clause_aexprs = map(aex -> aex, new_transition_on_clause_aexprs) # TODO

  # Step 4: synthesize relationship between transition events and transition updates
  
  # Step 5: hallucination -- expand the domain of the globalVar variable based on similarities between elt's of current domain

end

# helper functions
function finddifference(aexs::Array{AExpr}) 

  
end

function defaultsub(aex::AExpr) 
  new_aex = deepcopy(aex)
  for x in [:moveLeft, :moveRight, :moveUp, :moveDown, :left, :right, :up, :down]
    new_aex = defaultsub(aex)    
  end
  new_aex
end

function defaultsub(aex::AExpr, x::Symbol)
  if x == :moveLeft 
    sub(aex, (x, function lam(a)
                    a.head = :move 
                    push!(a.args, Autumn.AutumnStandardLibrary.Position(-1, 0))
                    a
                  end))
  elseif x == :moveRight 
    sub(aex, (x, function lam(a)
                    a.head = :move 
                    push!(a.args, Autumn.AutumnStandardLibrary.Position(1, 0))
                    a
                  end))
  elseif x == :moveUp 
    sub(aex, (x, function lam(a)
                    a.head = :move 
                    push!(a.args, Autumn.AutumnStandardLibrary.Position(0, -1))
                    a
                  end))
  elseif x == :moveDown 
    sub(aex, (x, function lam(a)
                    a.head = :move 
                    push!(a.args, Autumn.AutumnStandardLibrary.Position(0, 1))
                    a
                  end))
  elseif x == :left 
    sub(aex, x => parseautumn("(== arrow (Position -1 0))"))
  elseif x == :right 
    sub(aex, x => parseautumn("(== arrow (Position 1 0))"))
  elseif x == :up 
    sub(aex, x => parseautumn("(== arrow (Position 0 -1))"))
  elseif x == :down
    sub(aex, x => parseautumn("(== arrow (Position 0 1))"))
  else 
    error("Could not defaultsub $(aex)")
  end
end

function sub(aex::AExpr, (x, v))
  arr = [aex.head, aex.args...]
  if (x isa AExpr) && ([x.head, x.args...] == arr)  
    if occursin("var", repr(typeof(v))) # v is a lambda function taking x as input
      v(x)
    else 
      v
    end
  else
    MLStyle.@match arr begin
      [:fn, args, body]                                       => AExpr(:fn, args, sub(body, x => v))
      [:if, c, t, e]                                          => AExpr(:if, sub(c, x => v), sub(t, x => v), sub(e, x => v))
      [:assign, a1, a2]                                       => AExpr(:assign, a1, sub(a2, x => v))
      [:list, args...]                                        => AExpr(:list, map(arg -> sub(arg, x => v), args)...)
      [:typedecl, args...]                                    => AExpr(:typedecl, args...)
      [:let, args...]                                         => AExpr(:let, map(arg -> sub(arg, x => v), args)...)      
      [:lambda, args, body]                                   => AExpr(:fn, args, sub(body, x => v))
      [:call, f, args...]                                     => AExpr(:call, f, map(arg -> sub(arg, x => v) , args)...)      
      [:field, o, fieldname]                                  => AExpr(:field, sub(o, x => v), fieldname)
      [:object, args...]                                      => AExpr(:object, args...)
      [:on, event, update]                                    => AExpr(:on, sub(event, x => v), sub(update, x => v))
      [args...]                                               => error(string("Invalid AExpr Head: ", expr.head))
      _                                                       => error("Could not sub $arr")
    end
  end
end
