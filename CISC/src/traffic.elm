module Traffic exposing (..)

-- import Render exposing (..)
import Engine exposing (..)
import Color
import Random
import Update exposing (..)

-- Traffic Example
car (x, y) = ObjectTag (Box (x, y) 0 0 Color.green)

objectsFromOrig cars barrier = cars ++ barrier
carPoss = [(0,15)]

moveCar (x, y) positions =
    let
      moveUp = List.any (\input -> (round x, round y-1) == input) positions
      moveRight = List.any (\input -> (round x+1, round y) == input) positions || ((x + 1) > 15) || (List.any (\input -> (round x+1, round y+1) == input) positions)
      moveLeft = List.any (\input -> (round x-1, round y) == input) positions || ((x - 1) < 0) || (List.any (\input -> (round x-1, round y+1) == input) positions)
    in
      if not (moveUp==True) then
        (round x, round y-1)
      else if not moveRight then
        (round x+1, round y)
      else if not moveLeft then
        (round x-1, round y)
      else
        (round x, round y)


carList = List.map car carPoss

barrierOrig = (7, 4)
makeBarrier (x, y) = ObjectTag (Box (x, y) 1 0 Color.red)
barrierList = [makeBarrier barrierOrig]

getBarrierPositions (x, y) = [(x, y), (x+1, y)]
initScene : Scene
initScene = objectsFromOrig carList barrierList
carPos = (0, 15)
barrierPoss = [(7, 4), (8, 4)]
-- Barrier

origSeed = Random.initialSeed 42
newBarrier (x, y) =
  if (x, y) == (7, 4) then
    (2, 3)
  else if (x, y) == (2, 3) then
    (13, 12)
  else if (x, y) == (13, 12) then
    (1, 1)
  else if (x, y) == (1, 1) then
    (8, 9)
  else if (x, y) == (8, 9) then
    (14, 6)
  else if (x, y) ==(14, 6) then
    (7, 4)
  else
    (7,4)

yPos seed =
  Random.step (Random.int 0 15) seed


getX computer = round (computer.mouse.x/25 - 0.5)
getY computer = round (computer.mouse.y/25 - 0.5)

gasPumpPressed computer = computer.mouse.click

update computer {objects, latent} =
  let

    (carOrigx, carOrigy) = latent.carOrig
    (newBarrierX, newBarrierY) = if gasPumpPressed computer then (toFloat (getX computer), toFloat (getY computer)) else latent.barrierOrigin
    newBarrierOrig = (round newBarrierX, round newBarrierY)
    newBarrierPositions = getBarrierPositions newBarrierOrig
    newBarrierList = [makeBarrier (round newBarrierX, round newBarrierY)]

    (newX1, newSeed1) = yPos latent.randSeed
    newOrig = (newX1, 15)
    newCar1 = car newOrig

    (newX2, newSeed2)  = yPos newSeed1
    newOrig2 = (newX2, 15)
    newCar2 = car newOrig2

    (newX3, newSeed3) = yPos newSeed2
    newOrig3 = (newX3, 15)
    newCar3 = car newOrig3

    (newX4, newSeed4) = yPos newSeed3
    newOrig4 = (newX4, 15)
    newCar4 = car newOrig4


    movedCars = List.filter (\(x, y) -> y > -1) (List.map (\(x, y) -> moveCar (toFloat x, toFloat y) (latent.carPositions ++ latent.barrierPositions)) latent.carPositions)
    allCarPos = movedCars ++ [newOrig, newOrig2, newOrig3, newOrig4]
    movedCarObjects = List.map car movedCars
    newCarList = movedCarObjects ++ [newCar1, newCar2, newCar3, newCar4]
    movedObjects = objectsFromOrig newCarList newBarrierList
  in
  {
    objects = movedObjects,
    latent = {carPositions = allCarPos, carOrig = newOrig2, barrierPositions = newBarrierPositions, barrierOrigin = (newBarrierX, newBarrierY), randSeed = newSeed4}
  }

main = pomdp {objects = initScene, latent = {barrierPositions = barrierPoss, carPositions = carPoss, carOrig = carPos, barrierOrigin = barrierOrig, randSeed = origSeed}} update
