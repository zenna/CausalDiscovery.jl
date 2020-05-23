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

particles = Stream(Particle[]) do h
  if h.buttonPress
    h.particles
  else
    h.particles
  end
end