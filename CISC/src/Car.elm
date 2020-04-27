module Car exposing (..)

-- import Render exposing (..)
import Engine exposing (..)
import Color
import Update exposing (..)


-- Car Example

objectsFromOrig (x, y) tankLevel = 
  let
    car = Box (x, y) 2 4 Color.green
    tank = Box (x + 1, y + 1) 0 2 Color.white
    gas = Box (x + 1, y + 1) 0 (tankLevel - 1) Color.yellow
  in
  [ObjectTag gas, ObjectTag tank, ObjectTag car]

maxGas = 3
initGas = maxGas
initOrig = (1, 1)
initScene : Scene
initScene = objectsFromOrig initOrig maxGas

-- Gas Pump

gasPumpPos = (1, 1)
gasPumpPressed computer = computer.mouse.click

moveObject object x y =
  case object of
    Box (x_, y_) width height color -> Box (x + x_, y + y_) width height color
    Circle -> Circle

move entity x y = 
  case entity of
    ObjectTag object -> ObjectTag (moveObject object x y)
    FieldTag field -> FieldTag field
    ParticlesTag particles -> ParticlesTag particles

-- type alias Model = {objects : List Entity, latent : Int}
-- update : Computer -> Model -> Model
update computer {objects, latent} = 
  let
    tankLevel = latent.tankLevel
    (carOrigx, carOrigy) = latent.carOrig
    newTank = if gasPumpPressed computer then maxGas else tankLevel - 1
    newOrig = if tankLevel > 0 then (carOrigx + 1, carOrigy + 1) else latent.carOrig  
    movedObjects = objectsFromOrig newOrig newTank
  in
  { 
    objects = movedObjects,
    latent = {carOrig = newOrig, tankLevel = newTank}
  }
  
main = pomdp {objects = initScene, latent = {carOrig = initOrig, tankLevel = initGas}} update
