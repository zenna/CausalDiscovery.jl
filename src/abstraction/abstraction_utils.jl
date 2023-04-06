using MLStyle

function format_user_events(user_events)
  user_events_for_interpreter = []
  for e in user_events 
    if isnothing(e) || e == "nothing"
      push!(user_events_for_interpreter, Dict())
    elseif e == "left"
      push!(user_events_for_interpreter, Dict(:left => true))
    elseif e == "right"
      push!(user_events_for_interpreter, Dict(:right => true))
    elseif e == "up"
      push!(user_events_for_interpreter, Dict(:up => true))
    elseif e == "down"
      push!(user_events_for_interpreter, Dict(:down => true))
    else
      global x = parse(Int, split(e, " ")[2])
      global y = parse(Int, split(e, " ")[3])
      push!(user_events_for_interpreter, Dict(:click => AutumnStandardLibrary.Click(x, y)))
    end
  end
  user_events_for_interpreter
end

user_events_to_arrow = Dict(["nothing" => AutumnStandardLibrary.Position(0, 0), 
                             "left" => AutumnStandardLibrary.Position(-1, 0),
                             "right" => AutumnStandardLibrary.Position(1, 0),
                             "up" => AutumnStandardLibrary.Position(0, -1),
                             "down" => AutumnStandardLibrary.Position(0, 1),
])

function findnode(aex::AExpr, subaex, parent=nothing)
  if repr(aex) == repr(subaex)
    return parent
  else
    for i in 1:length(aex.args)
      soln = findnode(aex.args[i], subaex, aex)
      if !isnothing(soln)
        return soln
      end
    end
  end
  return nothing
end

function findnode(aex, subaex, parent=nothing)
  if repr(aex) == repr(subaex)
    parent
  else
    nothing
  end
end

function finddifference(aexs::Array{AExpr}, parents=nothing) 
  if length(unique(map(x -> repr(x), aexs))) == 1 
    return ([nothing for i in aexs], !isnothing(parents) ? parents : [nothing for i in aexs])
  elseif !(length(unique(map(x -> x.head, aexs))) == 1 && length(unique(map(x -> length(x.args), aexs))) == 1)
    return (aexs, !isnothing(parents) ? parents : [nothing for i in aexs])
  else
    for i in 1:length(aexs[1].args)
      ith_args = map(x -> x.args[i], aexs)
      arg_difference = finddifference(ith_args, aexs)
      if !isnothing(arg_difference[1][1])
        return arg_difference
      end
    end
  end
end

function finddifference(aexs, parents=nothing)
  if length(unique(map(x -> repr(x), aexs))) == 1 
    return ([nothing for i in aexs], !isnothing(parents) ? parents : [nothing for i in aexs])
  else
    return (aexs, !isnothing(parents) ? parents : [nothing for i in aexs])
  end
end

function defaultsub(aex::AExpr) 
  new_aex = deepcopy(aex)
  for x in [:moveLeft, :moveRight, :moveUp, :moveDown, :left, :right, :up, :down]
    new_aex = defaultsub(new_aex, x)    
  end
  new_aex
end

function defaultsub(aex::AExpr, x::Symbol)
  if x == :moveLeft 
    sub(aex, (x, function lam1(a)
                    a.args[1] = :move 
                    push!(a.args, parseautumn("(Position -1 0)"))
                    a
                  end))
  elseif x == :moveRight 
    sub(aex, (x, function lam2(a)
                    a.args[1] = :move 
                    push!(a.args, parseautumn("(Position 1 0)"))
                    a
                  end))
  elseif x == :moveUp 
    sub(aex, (x, function lam3(a)
                    a.args[1] = :move 
                    push!(a.args, parseautumn("(Position 0 -1)"))
                    a
                  end))
  elseif x == :moveDown 
    sub(aex, (x, function lam4(a)
                    a.args[1] = :move                   
                    push!(a.args, parseautumn("(Position 0 1)"))
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
  # println("sub 1")
  # @show aex 
  # @show x

  if (aex.args != [] && aex.args[1] == x) && (occursin("var", repr(typeof(v))) || occursin("typeof", repr(typeof(v)))) # v is a lambda function taking x as input
    new_arg = sub(aex.args[2], (x, v))
    # @show new_arg
    aex.args[2] = new_arg
    # println("here")
    # @show aex
    return v(aex)
  end

  arr = [aex.head, aex.args...]
  if (x isa AExpr) && ([x.head, x.args...] == arr)  
    v
  else
    MLStyle.@match arr begin
      [:fn, args, body]                                       => AExpr(:fn, args, sub(body, x => v))
      [:if, c, t, e]                                          => AExpr(:if, sub(c, x => v), sub(t, x => v), sub(e, x => v))
      [:assign, a1, a2]                                       => AExpr(:assign, a1, sub(a2, x => v))
      [:list, args...]                                        => AExpr(:list, map(arg -> sub(arg, x => v), args)...)
      [:typedecl, args...]                                    => AExpr(:typedecl, args...)
      [:let, args...]                                         => AExpr(:let, map(arg -> sub(arg, x => v), args)...)      
      [:lambda, args, body]                                   => AExpr(:lambda, args, sub(body, x => v))
      [:call, f, args...]                                     => AExpr(:call, f, map(arg -> sub(arg, x => v) , args)...)      
      [:field, o, fieldname]                                  => AExpr(:field, sub(o, x => v), fieldname)
      [:object, args...]                                      => AExpr(:object, args...)
      [:on, event, update]                                    => AExpr(:on, sub(event, x => v), sub(update, x => v))
      [args...]                                               => error(string("Invalid AExpr Head: ", new_state_expr.head))
      _                                                       => error("Could not sub $arr")
    end
  end
end

function sub(aex, (x, v))
  if (aex == x) && !(occursin("var", repr(typeof(v))) || occursin("typeof", repr(typeof(v))))
    v
  else
    aex
  end
end

function check_observations_equivalence(observations1, observations2)
  for i in 1:length(observations1) 
    obs1 = observations1[i]
    obs2 = observations2[i]
    obs1_tuples = sort(map(cell -> (cell.position.x, cell.position.y, cell.color), obs1), by=x -> repr(x))
    obs2_tuples = sort(map(cell -> (cell.position.x, cell.position.y, cell.color), obs2), by=x -> repr(x))
  
    # # # @show obs1_tuples 
    # # # @show obs2_tuples

    if obs1_tuples != obs2_tuples
      @show i
      @show obs1_tuples 
      @show obs2_tuples
      return false
    end
  end
  true
end