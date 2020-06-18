module CompiledProgram
export init, next
using Distributions

""" ----- built-in ----- """
struct Click
  x::Int
  y::Int
end

function occurred(click)
  click !== nothing
end

uniformChoice = function (freePositions)
  freePositions[rand(Categorical(ones(length(freePositions)) / length(freePositions)))]
end

""" ----- custom types ----- """
struct Position
  x::Int
  y::Int
end

struct Particle
  position::Position
end

""" ----- global variables --- """
const GRID_SIZE = 16
click = nothing
particles = nothing
nparticles = nothing
time = 0

# history-related 
clickHistory = Dict{Int64, Click}()
particlesHistory = Dict{Int64, Array{Particle}}()
nparticlesHistory = Dict{Int64, Array{Int64}}()

""" ----- prev functions --- """
clickPrev = function(n::Int)
  clickHistory[time - n]
end

particlesPrev = function(n::Int)
  particlesHistory[time - n]
end

nparticlesPrev = function(n::Int)
  nparticlesHistory[time - n]
end

""" ----- helper functions ----- """
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

    nextParticle
  end
end

function particleGen(initPosition::Position)::Particle
  Particle(initPosition)
end

""" ----- INIT and NEXT functions ----- """

function init(initPosition::Position)::Particle
  global particles = []
  global nparticles = length(particles)

  clickHistory[time] = deepcopy(click)
  particlesHistory[time] = deepcopy(particles)
  nparticlesHistory[time] = deepcopy(nparticles)

end

function next(click::Union{Click, Nothing})
  global time += 1
  global particles = if occurred(click)
              push!(particlesPrev(), particleGen(1, 1))
          else
              map(nextParticle, particles)
          end
  global nparticles = length(particles)

  clickHistory[time] = deepcopy(click)
  particlesHistory[time] = deepcopy(particles)
  nparticlesHistory[time] = deepcopy(nparticles)
end

end