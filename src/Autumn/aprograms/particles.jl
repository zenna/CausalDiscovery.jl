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
global_count = 0
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

    particle
  end
end

function particleGen(initPosition::Position)::Particle
  particle = Particle(initPosition, global_count)
  
  # BEGIN HISTORY HANDLING
  global_count += 1
  history[global_count] = Dict([(time, particle)])
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
    particleGen(initPosition)
  end
  map(nextParticle, particles)
end