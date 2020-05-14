module WaterPlug exposing (..)

-- import Render exposing (..)
import Engine exposing (..)
import Color
import Random
import Update exposing (..)

--Vase
drawVase = (2, 0)
drawPlug = (5, 0)
drawWater = (8,0)
startPos = (11, 0)
restartPos = (14, 0)
startButton = ObjectTag (Box startPos 0 0 Color.black)
restartButton = ObjectTag (Box restartPos 0 0 Color.red)
buttons = [vaseSpot drawVase, plugSpot drawPlug, waterSpot drawWater, startButton, restartButton]

mode = 1

modeTransition (x, y) prevMode =
  if (x, y) == drawVase then
    1
  else if (x, y) == drawPlug then
    2
  else if (x, y) == drawWater then
    3
  else if (x, y) == startPos then
    4
  else if (x, y) == restartPos then
    5
  else
    prevMode

--vasePositions = []
vasePositions = [(7, 15), (8, 15), (6, 15), (9, 15), (6, 14), (9, 14), (10, 14),
                        (5, 14), (5, 13), (10, 13), (4, 13), (11, 13), (4, 12), (11, 12), (4, 11), (11, 11)]
vaseSpot (x, y) = ObjectTag (Box (x, y) 0 0 Color.purple)
makeVase vPositions = List.map vaseSpot vPositions

addToVase (x, y) currentMode =
  if currentMode /= 1 then
    []
  else if y<2 then
    []
  else
    [(x, y)]

addToPlug (x, y) currentMode =
  if currentMode /= 2 then
    []
  else if y < 2 then
    []
  else
    [(x, y)]

addToWater (x, y) currentMode =
  if currentMode /= 3 then
    []
  else if y < 2 then
    []
  else
    [(x, y)]

--Water
--waterPositions = []
waterPositions = [(5, 12), (6, 12), (7, 12), (8, 12), (9, 12), (10, 12), (5, 11), (6, 11), (7, 11), (8, 11), (9, 11), (10, 11)]
waterSpot (x, y) = ObjectTag (Box (x, y) 0 0 Color.blue)
makeWater wPositions = List.map waterSpot wPositions
canMoveDown (x, y) waters blocks =
  let
    rowBlocksLeft = List.filter (\(x1, y1) -> (y == y1 && x1 < x)) (blocks)
    rowBlocksRight = List.filter (\(x1, y1) -> (y == y1 && x1 > x)) (blocks)
    leftBlock = List.maximum (List.map (\(x1, y1) -> x1) rowBlocksLeft)
    rightBlock = List.minimum (List.map (\(x1, y1) -> x1) rowBlocksRight)
  in
    List.length (List.filter (\(x1, y1) -> ((x1 > (Maybe.withDefault -1 leftBlock)) && (x1 < (Maybe.withDefault 16 rightBlock)) && (y1 == y + 1))) (blocks ++ waters)) /= ((Maybe.withDefault 16 rightBlock) - (Maybe.withDefault -1 leftBlock) - 1)
empty = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
pickDirection (x, y) waters blocks =
  let
    allBlocksLeft = List.filter (\(x1, y1) -> (y+1 == y1 && x1 < x)) (blocks ++ waters)
    allBlocksRight = List.filter (\(x1, y1) -> (y+1 == y1 && x1 > x)) (blocks ++ waters)
    rowBlocksLeft = List.filter (\(x1, y1) -> (y == y1 && x1 < x)) (blocks)
    rowBlocksRight = List.filter (\(x1, y1) -> (y == y1 && x1 > x)) (blocks)
    leftBlock = Maybe.withDefault -1 (List.maximum (List.map (\(x1, y1) -> x1) rowBlocksLeft))
    rightBlock = Maybe.withDefault 16 (List.minimum (List.map (\(x1, y1) -> x1) rowBlocksRight))
    leftEmpty = List.filter (\x1 -> (List.all (\(x2, y2) -> x2 /= x1) allBlocksLeft) && x1 > leftBlock && x1 < x) empty
    rightEmpty = List.filter (\x1 -> (List.all (\(x2, y2) -> x2 /= x1) allBlocksRight) && x1 < rightBlock && x1 > x) empty
    leftEmptyBlock = List.maximum leftEmpty
    rightEmptyBlock = List.minimum rightEmpty
  in
    if (Maybe.withDefault -1 leftEmptyBlock) == -1 then
      False
    else if (Maybe.withDefault 16 rightEmptyBlock) == 16 then
      True
    else if (x - (Maybe.withDefault -1 leftEmptyBlock)) < ((Maybe.withDefault 16 rightEmptyBlock) - x) then
      True
    else
      False

specialMove (x, y) waters blocks =
  let
    leftEmpty = (List.length (List.filter (\input -> input == (x - 1, y)) (waters ++ blocks))) == 0
    leftUpFilled = (List.length (List.filter (\input -> input == (x - 1, y - 1)) blocks)) /= 0
    leftWater = (List.length (List.filter (\input -> input == (x - 1, y)) waters)) /= 0
    rightWater = (List.length (List.filter (\input -> input == (x + 1, y)) waters)) /= 0
    upFilled = (List.length (List.filter (\input -> input == (x, y - 1)) blocks)) /= 0
    rightEmpty = (List.length (List.filter (\input -> input == (x + 1, y)) (waters ++ blocks))) == 0
    rightUpFilled = (List.length (List.filter (\input -> input == (x + 1, y - 1)) blocks)) /= 0
    twoRightNoWater = (List.length (List.filter (\input -> input == (x + 2, y)) waters)) == 0
    twoLeftNoWater = (List.length (List.filter (\input -> input == (x - 2, y)) waters)) == 0

  in
    if leftEmpty && leftUpFilled && rightWater then
      (x - 1, y)
    else if rightEmpty && rightUpFilled && leftWater && twoRightNoWater then
      (x+1, y)
    else
      (-1, -1)
waterMove (x, y) vase water =
  let
    left = pickDirection (x, y) water vase
    downPossible = canMoveDown (x, y) water vase
    moveDown = List.any (\input -> (x, y+1) == input) (vase ++ water) || (y+1 > 15)
    moveRight = List.any (\input -> (x+1, y) == input) (vase ++ water) || ((x + 1) > 15) || (List.any (\input -> (x+1, y-1) == input) water)
    moveLeft = List.any (\input -> (x-1, y) == input) (vase ++ water) || ((x - 1) < 0) || (List.any (\input -> (x-1, y-1) == input) water)
    moveSpecial = specialMove (x, y) water vase
  in
    if (y == 15 || not downPossible) && moveSpecial == (-1, -1) then
      (x, y)
    else if not (moveDown==True) then
      (x, y+1)
    else if not moveRight && not left && y/=15 then
      (x+1, y)
    else if not moveLeft && left && y/=15 then
      (x-1, y)
    else if moveSpecial /= (-1, -1) then
      moveSpecial
    else
      (x, y)
--Plug
--plugPositions = []
plugPositions = [(7, 14), (8, 14), (6, 13), (7, 13), (8, 13), (9, 13)]
plugSpot (x, y) = ObjectTag (Box (x, y) 0 0 Color.orange)
makePlug pPositions = List.map plugSpot pPositions

gasPumpPressed computer = computer.mouse.click
getX computer = round (computer.mouse.x/25 - 0.5)
getY computer = round (computer.mouse.y/25 - 0.5)

update computer {objects, latent} =
  let
    newMode = modeTransition (getX computer, getY computer) latent.varMode
    removePlug = (newMode == 4)
    removeAll = (newMode == 5)
    --pressedAndEmpty = gasPumpPressed computer && latent.plugPos == []
    newPlug = if (removePlug || removeAll) then [] else if gasPumpPressed computer then latent.plugPos ++ (addToPlug (getX computer, getY computer) newMode) else latent.plugPos
    newVase = if removeAll then [] else if gasPumpPressed computer then latent.vasePos ++ (addToVase (getX computer, getY computer) newMode) else latent.vasePos
    tempWater = if removeAll then [] else if gasPumpPressed computer then latent.waterPos ++ (addToWater (getX computer, getY computer) newMode) else latent.waterPos
    newWater =  (List.map (\(x, y) -> waterMove (x, y) (newVase ++ newPlug) tempWater) tempWater)    --newWater = if pressedAndEmpty then nextWater latent.vaseNumber else (List.map (\(x, y) -> waterMove (x, y) (newVase ++ newPlug) latent.waterPos latent.left) latent.waterPos)
    newScene: Scene
    newScene = (buttons) ++ (makeVase newVase) ++ (makePlug newPlug) ++ (makeWater newWater)

  in

  {
    --objects = newScene, latent = latent
    objects = newScene, latent = {varMode = newMode, vasePos = newVase, waterPos = newWater, plugPos = newPlug, left = not latent.left}
  }


main = pomdp {objects = (buttons) ++ (makeVase vasePositions) ++ (makePlug plugPositions) ++ (makeWater waterPositions), latent = {varMode = mode, plugPos = plugPositions, waterPos = waterPositions, vasePos = vasePositions, left = True}} update
