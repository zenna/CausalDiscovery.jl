type alias Position = (Int, Int)

-- A mouse click is a position that might occur
type Click = Event (Int, Int)
external click : Click

type Particle = Particle position:Position

particles : [Particle]
init particles = []
next particles = if buttonPress
                 then particles :: Particle (1, 1)
                 else particles

-- Lifted (automatically)
nparticles = length particles

isfree : Position -> Bool
isfree position = not (all (map \particle -> particle in position particles))

-- At every time step, look for a free space around me and try to move into it
nextPosition : Particle -> Position
nextPosition particle =
  let
    freePositions = filter isfree (adjacentPositions particle.position)
  in
    case freePositions
      [] -> particle
      _ -> uniformChoice freePositions

particleGen position = Paricle position 

-- Here's a particular particule
aParticle : Particle
init aParticle = Particle (1, 1)
next aParticle = nextPosition (prev aParticle)

-- Maps an initial position to a particle that chooses its next position
-- using nextPosition, which depends on `particles`
particleGen initPosition = 
  {{Particle initPosition, nextPosition this}}