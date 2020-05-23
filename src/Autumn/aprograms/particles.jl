# 
struct Stream

"History of values"
struct History{T}
  h::T
end

function getproperty(h::History{Dict{Symbol, T}}, name::Symbol) where T
  h = getfield(h, :h)
  if name == :h
    h
  else
    h[name]
  end
end

# 

const Position = Tuple{Int, Int}
const Click = Union{Position, Nothing}

const Positiion = Alias 

struct Particle
  position::Position
end

particles = Stream(Particle[]) do h
  if h.buttonPress
    [h.particles Particle(1, 1)]
  else
    h.particles
  end
end

## Is there any need for init and next, why not just next
next fibonnaci = 

## Issues
# - Presumably I can't have a symbol for every value, I'll need some kind of index
#  This looks a lot like the same problem as omega
# - 
# - Type stability will be hard
