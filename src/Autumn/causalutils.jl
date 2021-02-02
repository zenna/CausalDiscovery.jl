function tostate(var)
  return Meta.parse("state.$(var)History[step]")
end
function tostate(var, field)
  return Meta.parse("state.$(var)History[step].$field")
end

function tostateshort(var)
  return Meta.parse("state.$(var)History")
end
