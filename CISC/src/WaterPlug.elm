module WaterPlug exposing (..)

-- import Render exposing (..)
import Engine exposing (..)
import Color
import Random
import Update exposing (..)

--Vase
vasePositions = [(7, 15), (8, 15), (6, 15), (9, 15), (6, 14), (9, 14), (10, 14),
                        (5, 14), (5, 13), (10, 13), (4, 13), (11, 13), (4, 12), (11, 12), (4, 11), (11, 11)]
vaseSpot (x, y) = ObjectTag (Box (x, y) 0 0 Color.purple)
makeVase vPositions = List.map vaseSpot vPositions
nextVase vaseNum =
  if vaseNum == 1 then
  [(7, 15), (8, 15), (6, 15), (9, 15), (6, 14), (9, 14), (10, 14),
                        (5, 14), (4, 14), (3, 14), (3, 13), (3, 12), (3, 11), (3, 10), (3, 9), (3, 8), (3, 9),
                         (10, 13),  (11, 13), (4, 12), (11, 12), (4, 11), (11, 11), (11, 10), (11, 9), (11, 8), (11, 7)]

  else
    vasePositions
--Water
waterPositions = [(5, 12), (6, 12), (7, 12), (8, 12), (9, 12), (10, 12), (5, 11), (6, 11), (7, 11), (8, 11), (9, 11), (10, 11)]
waterSpot (x, y) = ObjectTag (Box (x, y) 0 0 Color.blue)
makeWater wPositions = List.map waterSpot wPositions

nextWater waterNum =
  if waterNum == 1 then
    [(4, 9), (4, 10), (5, 9), (5, 10), (5, 11), (5, 12), (5, 13), (6, 9), (6, 10), (6, 11), (6, 12), (6, 13), (6, 14),
      (7, 9), (7, 10), (7, 11), (7, 12), (7, 13), (7, 14), (8, 9), (8, 10), (8, 11), (9, 9), (9, 10), (10, 9), (10, 10),
      (10, 11), (10, 12)]
  else
    waterPositions

waterMove (x, y) vase water left =
  let
    moveDown = List.any (\input -> (x, y+1) == input) (vase ++ water)
    moveRight = List.any (\input -> (x+1, y) == input) (vase ++ water) || ((x + 1) > 15) || (List.any (\input -> (x+1, y-1) == input) water)
    moveLeft = List.any (\input -> (x-1, y) == input) (vase ++ water) || ((x - 1) < 0) || (List.any (\input -> (x-1, y-1) == input) water)
  in
    if not (moveDown==True) then
      (x, y+1)
    else if not moveRight && not left then
      (x+1, y)
    else if not moveLeft && left then
      (x-1, y)
    else
      (x, y)
--Plug
plugPositions = [(7, 14), (8, 14), (6, 13), (7, 13), (8, 13), (9, 13)]
plugSpot (x, y) = ObjectTag (Box (x, y) 0 0 Color.orange)
makePlug pPositions = List.map plugSpot pPositions

nextPlug plugNum =
  if plugNum == 1 then
    [(7, 14), (8, 14), (8, 13) , (8, 12), (9, 12), (9, 11)]
  else
    plugPositions

nextNumber num =
  if num == 1 then
    2
  else
    1
gasPumpPressed computer = computer.mouse.click

update computer {objects, latent} =
  let
    pressedAndEmpty = gasPumpPressed computer && latent.plugPos == []
    newPlug = if pressedAndEmpty then nextPlug latent.vaseNumber else if gasPumpPressed computer then [] else latent.plugPos
    newVase = if pressedAndEmpty then nextVase latent.vaseNumber else latent.vasePos
    newWater = if pressedAndEmpty then nextWater latent.vaseNumber else (List.map (\(x, y) -> waterMove (x, y) (newVase ++ newPlug) latent.waterPos latent.left) latent.waterPos)
    newVaseNumber = if pressedAndEmpty then nextNumber latent.vaseNumber else latent.vaseNumber
    newScene = (makeVase newVase) ++ (makePlug newPlug) ++ (makeWater newWater)

  in

  {
    objects = newScene, latent = {vasePos = newVase, waterPos = newWater, plugPos = newPlug, left = not latent.left, vaseNumber = newVaseNumber}
  }


main = pomdp {objects = (makeVase vasePositions) ++ (makePlug plugPositions) ++ (makeWater waterPositions), latent = {plugPos = plugPositions, waterPos = waterPositions, vasePos = vasePositions, left = True, vaseNumber = 1}} update
