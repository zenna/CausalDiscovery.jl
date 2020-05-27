using Distributions

# --- types ---
struct Position
  x1::Int
  x2::Int
end

struct Click
  x1::Int
  x2::Int
end

struct Particle
  x1::Position
  id::Int # based on global counter variable
end

# --- global variables ---
const GRID_SIZE = 16
particles = []

# --- helper functions ---
function nparticles
  length(particles)
end

function isFree(position::Position)::Bool
  length(filter(particle -> particle.x1 == position, particles)) == 0
end

function isWithinBounds(position::Position)::Bool
  if (position.x1 >= 0 && position.x1 < GRID_SIZE && position.x2 >= 0 && position.x2 < GRID_SIZE)  
    true
  else
    false
  end
end

function adjacentPositions(position::Position)
  x = position.x1
  y = position.x2
  positions = [Position(x + 1, y), Position(x - 1, y), Position(x, y + 1), Position(x, y - 1)]
  filter(isWithinBounds, positions)
end

function nextParticle(particle::Particle)::Position
  freePositions = filter(isFree, adjacentPositions(particle.x1))
  if freePositions == []
    particle
  else
    newPosition = freePositions[rand(Categorical(ones(length(freePositions))/length(freePositions)))]
    Particle(newPosition, particle.id)
  end
end

function particleGen(position::Position)::Particle

end

# history dictionary, keyed by index


#=""
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
=#