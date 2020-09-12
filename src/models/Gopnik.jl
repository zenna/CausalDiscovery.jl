module Gopnik

# But I need to figure this out
# I will provide a DSL and a grammar for the language
# And you wil provide a probabilistic grammar and and a proposal proposal distribution
# Start with simple expressions

  

using Signals

"An object that goes on a `Machine`"
abstract type Object end

struct Box <: Object
  color
  position
end

struct Cylinder <: Object
  color
  position
end

S = Signal(val;strict_push = false)

"Vizualise a scene"
function view(scene)

end

"A machine that alarms"
struct Machine{F}
  alarm::F
end
S = Signal(f,args...)


# # Examples
Machine(scene -> length(scene) > 0)


end