using Distributions

""" ----- custom types ----- """
struct Position
  x::Int
  y::Int
end

struct Particle
  position::Position
  color::String
  render::Bool
end
  
struct Click
  x::Int
  y::Int
end

""" ----- global variables --- """
GRID_SIZE = 16
particles = []
noFoodRemaining = false
time = 0

# history-related 
particlesHistory = Dict{Int64, Any}
clickHistory = Dict{Int64, Any}
noFoodRemainingHistory = Dict{Int64, Any}

""" ----- helper functions ----- """

# compute Manhattan distance between two particles
function manhattanDistance(particle1::Particle, particle2::Particle)
    (abs(particle1.position.x - particle2.position.x)) + (abs(particle1.position.y - particle2.position.y))
end

# create single ant particle at given position
function createAnt(initPosition::Position)::Particle
    Particle(initPosition, "gray", true)
end

# create single food particle at given position
function createFood(initPosition::Position)::Particle
    Particle(initPosition, "red", true)
end

# create multiple ant particles at random positions
function antGen(count)
    xCoords = rand(Categorical(ones(length(collect(0:(GRID_SIZE - 1))))/length(collect(0:(GRID_SIZE - 1)))), count)
    yCoords = rand(Categorical(ones(length(collect(0:(GRID_SIZE - 1))))/length(collect(0:(GRID_SIZE - 1)))), count)

    positions = [] # FIX ME
    ants = map(createAnt, positions)
    ants
end

# create multiple food particles at random positions
function foodGen(count)
    xCoords = rand(Categorical(ones(length(collect(0:(GRID_SIZE - 1))))/length(collect(0:(GRID_SIZE - 1)))), count)
    yCoords = rand(Categorical(ones(length(collect(0:(GRID_SIZE - 1))))/length(collect(0:(GRID_SIZE - 1)))), count)

    positions = [] # FIX ME
    food = map(createFood, positions)
end

# determine particle state at next time step
function nextParticle(particle::Particle)::Particle
    if particle.color == "gray"
        nextAntParticle(particle)
    else    
        nextFoodParticle(particle)
    end

end

# determine ant state at next time step
function nextAntParticle(ant::Particle)::Particle
    x = ant.position.x
    y = ant.position.y

    foods = filter(particle -> particle.color == "red" && particle.render && particle.position != ant.position, particles)
    if length(foods) == 0
        closestDistance = -1
    else
        closestDistance = min(map(manhattanDistance, foods)...)
    closestFoods = filter(n -> manhattanDistance(n), foods)

    if (length(closestFoods) == 0)
        (foodX, foodY) = (-1, -1)
    else
        (foodX, foodY) = (closestFoods[1].position.x, closestFoods[1].position.y)

    if (foodX == -1 && foodY == -1)
        (deltaX, deltaY) = (0, 0)
    elseif (foodX - x) == 0 && (foodY - y) == 0
        (deltaX, deltaY) = (foodX - x, foodY - y)
    elseif (foodX - x) == 0 && (foodY - y) /= 0 
        (deltaX, deltaY) = (foodX - x, (foodY - y)//(abs(foodY - y)))
    elseif (foodX - x ) /= 0 && (foodY - y) == 0 
        (deltaX, deltaY) = ((foodX - x)//(abs(foodX - x)), foodY - y)
    else 
        (deltaX, deltaY) = ((foodX - x)//(abs(foodX - x)), 0)
    
    nextPosition = Position(x + deltaX, y + deltaY)
    Particle(nextPosition, ant.color, ant.render)
end

# determine food state at next time step
function nextFoodParticle(food::Particle)::Particle
  antsWithSamePosition = filter(particle -> particle.color == "gray" && particle.position == food.position, particles)
  if length antsWithSamePosition == 0
    newFood = food
  else
    newFood = Particle(food.position, food.color, false)
  end
  newFood
end

""" ----- INIT and NEXT functions ----- """

function init(initPosition::Position)::Particle
  particles = []
end

function next(click::Union{Click, Nothing})
  time += 1
  if click != Nothing && noFoodRemaining
    particles = vcat(particles, foodGen(1,1))
  end
  particles = map(nextParticle, particles)
  noFoodRemaining = length(filter(particle -> particle.color == "red" && particle.render, particles)) == 0
  
  particlesHistory[time] = deepcopy(particles)
  clickHistory[time] = click
  noFoodRemainingHistory[time] = noFoodRemaining
end
