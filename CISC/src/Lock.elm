module Lock exposing (..)

-- import Render exposing (..)
import Engine exposing (..)
import Color
import Update exposing (..)
import String.Conversions
import File.Download as Download
import Dict

-- Lock Example

-- Changeable Variables
lockHoleLocation = (6,12)
lockHoleWidth = 0
lockHoleLength = 2
initKeyLocation = (0,0)
initUnlockedState = False --locked


-- Objects in Scene
objectsFromOrig (x,y) unlocked = 
  let
    wallLocation = if unlocked == True then (8,-1) else (8,0)

    --MOVABLE OBJECTS
    movingWall = Box wallLocation 0 7 Color.darkGrey
    key = Box (x,y) lockHoleWidth lockHoleLength Color.lightPurple 

    --STATIONARY OBJECTS
    stationaryWall = Box (8,8) 0 7 Color.darkGrey
    lockBox = Box (5,12) 2 3 Color.lightBlue
    lockHole = Box lockHoleLocation lockHoleWidth lockHoleLength Color.white
  in
    [ObjectTag stationaryWall, ObjectTag movingWall, ObjectTag lockBox, ObjectTag lockHole, ObjectTag key]

initScene : Scene
initScene = objectsFromOrig initKeyLocation initUnlockedState

initHistory = Dict.empty

mouseClicked computer = computer.mouse.click

inXBounds proposedX = if proposedX <= 16-(lockHoleWidth+1) && proposedX >= 0 then True else False
inYBounds proposedY = if proposedY <= 16-(lockHoleLength+1) && proposedY >= 0 then True else False

moveObject object x y =
  case object of
    Box (x_, y_) width height color -> Box (x + x_, y + y_) width height color
    Circle -> Circle

move entity x y = 
  case entity of
    ObjectTag object -> ObjectTag (moveObject object x y)
    FieldTag field -> FieldTag field
    ParticlesTag particles -> ParticlesTag particles

print mytext = Download.string mytext
-- type alias Model = {objects : List Entity, latent : Int}
-- update : Computer -> Model -> Model
update computer {objects, latent} = 
  let

    -- Defining User Input
    up = computer.mouse.click && computer.mouse.y < 75
    down = computer.mouse.click && computer.mouse.y > 325
    left = computer.mouse.click && computer.mouse.x < 75
    right = computer.mouse.click && computer.mouse.x > 325

    -- Getting previous state

    (keyx, keyy) = latent.keyLocation
    time = latent.timeStep

    -- Updating current location
    newkeyy = if inYBounds (keyy+1) && down then keyy + 1 else if inYBounds (keyy-1) && up then keyy - 1 else keyy
    newkeyx = if inXBounds (keyx+1) && right then keyx + 1 else if inXBounds (keyx-1) && left then keyx - 1 else keyx
    currKeyLocation = (newkeyx, newkeyy)

    -- Updating timestep
    newtime = time + 1

    -- Updating lock status
    currLockValue = if currKeyLocation == lockHoleLocation then True else False -- CHANGE BASED ON IF YOU WANT IT TO REMAIN LOCKED OR UNLOCKED

    -- Updating collection of all objects in the scene
    movedObjects = objectsFromOrig currKeyLocation currLockValue

  in
  { 
    objects = movedObjects,
    latent = {keyLocation = currKeyLocation, unlocked = currLockValue, timeStep = newtime}
  }

loggedUpdate = updateTracker update
  
main = pomdp {objects = initScene, latent = {keyLocation = initKeyLocation, unlocked = False, timeStep = 0}, history = initHistory} loggedUpdate
