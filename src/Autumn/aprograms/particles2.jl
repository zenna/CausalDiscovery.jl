using Distributions

""" ----- custom types ----- """
struct Position
  x::Int
  y::Int
end

struct Click
  x::Int
  y::Int
end

struct Particle
  position::Position
  id::Int # based on global counter variable
end

""" ----- global variables --- """
GRID_SIZE = 16
particles = []

# history-related 
history = Dict{Int64, Any}
time = 0

""" ----- helper functions ----- """
function nparticles
  length(particles)
end

function isFree(position::Position)::Bool
  length(filter(particle -> particle.position == position, particles)) == 0
end

function isWithinBounds(position::Position)::Bool
  (position.x >= 0 && position.x < GRID_SIZE && position.y >= 0 && position.y < GRID_SIZE)  
end

function adjacentPositions(position::Position)
  x = position.x
  y = position.y
  positions = filter(isWithinBounds, [Position(x + 1, y), Position(x - 1, y), Position(x, y + 1), Position(x, y - 1)])
  positions
end

function nextParticle(particle::Particle)::Particle
  freePositions = filter(isFree, adjacentPositions(particle.position))
  if freePositions == []
    particle
  else
    newPosition = freePositions[rand(Categorical(ones(length(freePositions))/length(freePositions)))]
    nextParticle = Particle(newPosition, particle.id)

    # BEGIN HISTORY HANDLING
    history[nextParticle.id][time] = nextParticle
    # END HISTORY HANDLING

    nextParticle
  end
end

function particleGen(initPosition::Position)::Particle
  particle = Particle(initPosition, length(particles))
  
  # BEGIN HISTORY HANDLING
  history[particle.id] = Dict([(time, particle)])
  # END HISTORY HANDLING

  particle
end

""" ----- INIT and NEXT functions ----- """

function init(initPosition::Position)::Particle
  particles = []
end

function next(click::Union{Click, Nothing})
  time += 1
  if click != Nothing
    particleGen(1,1)
  end
  map(nextParticle, particles)
end





""" ----- zenna's original code ----- """
#= 

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

=#