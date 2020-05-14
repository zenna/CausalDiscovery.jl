module Lock exposing (..)

-- import Render exposing (..)
import Engine exposing (..)
import Color
import Update exposing (..)
import String.Conversions
import File.Download as Download
import Dict
import Time


-- Lock Example

-- Changeable Variables
lockHoleLocation = (6,12)
lockHoleWidth = 0
lockHoleLength = 2
initKeyLocation = (0,0)
initUnlockedState = False --locked
replay = True


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
update computer {objects, latent, init} = 
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
    latent = {keyLocation = currKeyLocation, unlocked = currLockValue, timeStep = newtime},
    init = init
  }

loggedUpdate = updateTracker update

-- Fake History for Replay Functionality

fakeHistory1 = Dict.insert 0 (Dict.fromList [("Click", 0), ("Click X", 0), ("Click Y", 0)]) initHistory
fakeHistory2 = Dict.insert 1 (Dict.fromList [("Click", 1), ("Click X", 345), ("Click Y", 189)]) fakeHistory1
fakeHistory3 = Dict.insert 2 (Dict.fromList [("Click", 1), ("Click X", 345), ("Click Y", 189)]) fakeHistory2
fakeHistory4 = Dict.insert 3 (Dict.fromList [("Click", 1), ("Click X", 345), ("Click Y", 189)]) fakeHistory3
fakeHistory5 = Dict.insert 4 (Dict.fromList [("Click", 1), ("Click X", 345), ("Click Y", 189)]) fakeHistory4
fakeHistory6 = Dict.insert 5 (Dict.fromList [("Click", 1), ("Click X", 345), ("Click Y", 189)]) fakeHistory5
fakeHistory7 = Dict.insert 6 (Dict.fromList [("Click", 1), ("Click X", 345), ("Click Y", 189)]) fakeHistory6
fakeHistory8 = Dict.insert 7 (Dict.fromList [("Click", 1), ("Click X", 280), ("Click Y", 360)]) fakeHistory7
fakeHistory9 = Dict.insert 8 (Dict.fromList [("Click", 1), ("Click X", 280), ("Click Y", 360)]) fakeHistory8
fakeHistory10 = Dict.insert 9 (Dict.fromList [("Click", 1), ("Click X", 280), ("Click Y", 360)]) fakeHistory9
fakeHistory11 = Dict.insert 10 (Dict.fromList [("Click", 1), ("Click X", 280), ("Click Y", 360)]) fakeHistory10
fakeHistory12 = Dict.insert 11 (Dict.fromList [("Click", 1), ("Click X", 280), ("Click Y", 360)]) fakeHistory11
fakeHistory13 = Dict.insert 12 (Dict.fromList [("Click", 1), ("Click X", 280), ("Click Y", 360)]) fakeHistory12
fakeHistory14 = Dict.insert 13 (Dict.fromList [("Click", 1), ("Click X", 280), ("Click Y", 360)]) fakeHistory13
fakeHistory15 = Dict.insert 14 (Dict.fromList [("Click", 1), ("Click X", 280), ("Click Y", 360)]) fakeHistory14
fakeHistory16 = Dict.insert 15 (Dict.fromList [("Click", 1), ("Click X", 280), ("Click Y", 360)]) fakeHistory15
fakeHistory17 = Dict.insert 16 (Dict.fromList [("Click", 1), ("Click X", 280), ("Click Y", 360)]) fakeHistory16
fakeHistory18 = Dict.insert 17 (Dict.fromList [("Click", 1), ("Click X", 280), ("Click Y", 360)]) fakeHistory17
fakeHistory19 = Dict.insert 18 (Dict.fromList [("Click", 1), ("Click X", 280), ("Click Y", 360)]) fakeHistory18
fakeHistory20 = Dict.insert 19 (Dict.fromList [("Click", 0), ("Click X", 280), ("Click Y", 0)]) fakeHistory19
fakeHistory21 = Dict.insert 20 (Dict.fromList [("Click", 0), ("Click X", 280), ("Click Y", 0)]) fakeHistory20
fakeHistory22 = Dict.insert 21 (Dict.fromList [("Click", 1), ("Click X", 280), ("Click Y", 0)]) fakeHistory21


finalFakeHistory = fakeHistory22


--Replay Default Values
defaultObjects = []
defaultLatent = Latent (-1,-1) False -1
initLatent = Latent (0,0) False 0

defaultInput0 = Dict.singleton "Click" 0
defaultInput1 = Dict.insert "Click X" 0 defaultInput0
defaultInput2 = Dict.insert "Click Y" 0 defaultInput1

defaultInput = defaultInput2


defaultEvent = Event initScene defaultLatent


--Replay an old history
replayer : Computer -> LoggedEvent -> LoggedEvent
replayer computer {objects, latent, history, init} = 
  let

    --Update timestep
    time = latent.timeStep

    --Create fake computer with input
    currInput = Maybe.withDefault defaultInput (Dict.get time history)
    loggedClickInt = Maybe.withDefault 0 (Dict.get "Click" currInput)
    loggedClick = if loggedClickInt == 1 then True else False
    loggedX = Maybe.withDefault 0 (Dict.get "Click X" currInput)
    loggedY = Maybe.withDefault 0 (Dict.get "Click Y" currInput)

    fakeMouse = {
                  x = loggedX
                  , y = loggedY
                  , down = False
                  , click = loggedClick
                }
    comp = { 
            mouse = fakeMouse
            , time = Time (Time.millisToPosix 0)
      }

    -- Run Update Function and get new state
    stateOut = update comp (Event objects latent init)
    newObjects = stateOut.objects
    newLatent = stateOut.latent
  in
  { 
    objects = newObjects
    , latent =  newLatent
    , history = history
    , init = init
  }

main = if replay == True then 
         pomdp {objects = initScene, latent = initLatent, history = initHistory, init = {objects = initScene, latent = initLatent}} replayer 
       else 
         pomdp {objects = initScene, latent = initLatent, history = initHistory, init = {objects = initScene, latent = initLatent}} loggedUpdate