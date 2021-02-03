function tostate(var)
  return Meta.parse("state.$(var)History[step]")
end
function tostate(var, field)
  return Meta.parse("state.$(var)History[step].$field")
end

function tostateshort(var)
  return Meta.parse("state.$(var)History")
end

function reducenoeval(var)
  if "." in string(var)
    return var
  end
  println("reduce")
  println(string(var))
  split_ = split(string(var), "[")
  println(split_)
  Meta.parse(split_[1])
end

restrictedvalues = Dict(:(state.suzieHistory) => [1, 2, 3, 4, 5])

function possiblevalues(var::Expr, val)
  if reducenoeval(var) in keys(restrictedvalues)
    return restrictedvalues[reducenoeval(var)]
  end
  possvals(val)
end
