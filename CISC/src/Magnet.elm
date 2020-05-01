module Magnet exposing (..)

-- import Render exposing (..)
import Engine exposing (..)
import Color
import Update exposing (..)
import Random

fixedMagnetPlusX = 7
fixedMagnetPlusY = 7

fixedMagnetMinusX = 7
fixedMagnetMinusY = 8

moveRight = [((5,8), (4,8)), ((5,8), (5,9)), ((4,7), (5,7)), ((5,6), (5,7)), ((5,8), (5,7))]
moveLeft= [((9,6), (9,7)), ((10,7), (9,7)), ((9,8), (9,7)), ((9,8), (10,8)), ((9,8), (9,9))]
moveUp = [((7,10), (7,11)), ((7,10), (6,10)), ((7,10), (8,10))]
moveDown = [((7,4), (7,5)), ((6,5), (7,5)), ((8,5), (7,5))]

plusInvalid = [(6,7), (7,6), (8,7)]
minusInvalid = [(7,9), (6,8), (8,8)]

-- Magnet Example

objectsFromOrig (xPlus, yPlus) (xMinus, yMinus) = 
  let
    fixedMagnetPlus = Box (fixedMagnetPlusX, fixedMagnetPlusY) 0 0 Color.red
    fixedMagnetMinus = Box (fixedMagnetMinusX, fixedMagnetMinusY) 0 0 Color.blue
    mobileMagnetPlus = Box (xPlus, yPlus) 0 0 Color.red
    mobileMagnetMinus = Box (xMinus, yMinus) 0 0 Color.blue
    upBox = Box (7, 0) 0 0 Color.green
    downBox = Box (7, 15) 0 0 Color.green
    rightBox = Box (15, 7) 0 0 Color.green
    leftBox = Box (0, 7) 0 0 Color.green
  in
  [ObjectTag fixedMagnetPlus, ObjectTag fixedMagnetMinus, ObjectTag mobileMagnetPlus, ObjectTag mobileMagnetMinus, ObjectTag upBox, ObjectTag downBox, ObjectTag leftBox, ObjectTag rightBox]

initMobileMagnetPlus = (4, 7)
initMobileMagnetMinus = (4, 8)
initScene : Scene
initScene = objectsFromOrig initMobileMagnetPlus initMobileMagnetMinus

-- 

rotatePressedFunc computer = computer.mouse.click

moveObject object x y =
  case object of
    Box (x_, y_) width height color -> Box (x + x_, y + y_) width height color
    Circle -> Circle

move entity x y = 
  case entity of
    ObjectTag object -> ObjectTag (moveObject object x y)
    FieldTag field -> FieldTag field
    ParticlesTag particles -> ParticlesTag particles

update computer {objects, latent} = 
  let
  
    (mobileMagnetPlusX, mobileMagnetPlusY) = latent.mobileMagnetPlus
    (mobileMagnetMinusX, mobileMagnetMinusY) = latent.mobileMagnetMinus
    
    rotatePressed = computer.mouse.click && computer.mouse.y > 100 && computer.mouse.y < 300 && computer.mouse.x > 100 && computer.mouse.x < 300


    upPressed = computer.mouse.click && computer.mouse.y < 100 -- computer.keyboard.up
    downPressed = computer.mouse.click && computer.mouse.y > 300 -- computer.keyboard.down
    leftPressed = computer.mouse.click && computer.mouse.x < 100 -- computer.keyboard.left
    rightPressed = computer.mouse.click && computer.mouse.x > 300 -- computer.keyboard.right
    
    proposedMinusY = if (rotatePressed && (mobileMagnetMinusY /= mobileMagnetPlusY)) then 
                        mobileMagnetPlusY 
                    else if (rotatePressed && mobileMagnetMinusX > mobileMagnetPlusX) then
                        mobileMagnetPlusY - 1
                    else if (rotatePressed && mobileMagnetMinusX < mobileMagnetPlusX) then   
                        mobileMagnetPlusY + 1
                    else if upPressed then
                        mobileMagnetMinusY - 1
                    else if downPressed then
                        mobileMagnetMinusY + 1
                    else
                        mobileMagnetMinusY
                    
    
    proposedMinusX = if (rotatePressed && (mobileMagnetMinusX /= mobileMagnetPlusX)) then 
                        mobileMagnetPlusX
                    else if (rotatePressed && mobileMagnetMinusY > mobileMagnetPlusY) then
                        mobileMagnetPlusX + 1
                    else if (rotatePressed && mobileMagnetMinusY < mobileMagnetPlusY) then
                        mobileMagnetPlusX - 1
                    else if rightPressed then
                        mobileMagnetMinusX + 1
                    else if leftPressed then
                        mobileMagnetMinusX - 1
                    else
                        mobileMagnetMinusX
    
    proposedPlusY = if upPressed then
                    mobileMagnetPlusY - 1
                else if downPressed then
                    mobileMagnetPlusY + 1
                else
                    mobileMagnetPlusY


    proposedPlusX = if leftPressed then
                        mobileMagnetPlusX - 1
                    else if rightPressed then
                        mobileMagnetPlusX + 1
                    else
                        mobileMagnetPlusX

    equalsProposed a = Maybe.withDefault (((proposedPlusX, proposedPlusY), (proposedMinusX, proposedMinusY)) == a) Nothing
    equalsProposedPlus a = (proposedPlusX, proposedPlusY) == a
    equalsProposedMinus a = (proposedMinusX, proposedMinusY) == a
    
    invalid = (proposedPlusX,proposedPlusY)==(7,7) || (proposedPlusX,proposedPlusY)==(7,8)||(proposedMinusX,proposedMinusY)==(7,7)||(proposedMinusX,proposedMinusY)==(7,8)
    
    finalPlusX = if List.length(List.filter equalsProposed moveRight) /= 0 then
                    proposedPlusX + 1
                else if List.length(List.filter equalsProposed moveLeft) /= 0 then
                    proposedPlusX - 1
                else if invalid then
                    mobileMagnetPlusX
                else if List.length(List.filter equalsProposedPlus plusInvalid) > 0 then
                    mobileMagnetPlusX
                else if List.length(List.filter equalsProposedMinus minusInvalid) > 0 then
                    mobileMagnetPlusX
                else
                    proposedPlusX

    finalPlusY = if List.length(List.filter equalsProposed moveUp) /= 0 then
                    proposedPlusY - 1
                else if List.length(List.filter equalsProposed moveDown) /= 0 then
                    proposedPlusY + 1
                else if invalid then
                    mobileMagnetPlusY
                else if List.length(List.filter equalsProposedPlus plusInvalid) > 0 then
                    mobileMagnetPlusY
                else if List.length(List.filter equalsProposedMinus minusInvalid) > 0 then
                    mobileMagnetPlusY
                else
                    proposedPlusY

    finalMinusX = if List.length(List.filter equalsProposed moveRight) /= 0 then
                    proposedMinusX + 1
                else if List.length(List.filter equalsProposed moveLeft) /= 0 then
                    proposedMinusX - 1
                else if invalid then
                    mobileMagnetMinusX
                else if List.length(List.filter equalsProposedPlus plusInvalid) > 0 then
                    mobileMagnetMinusX
                else if List.length(List.filter equalsProposedMinus minusInvalid) > 0 then
                    mobileMagnetMinusX
                else
                    proposedMinusX

    finalMinusY = if List.length(List.filter equalsProposed moveUp) /= 0 then
                    proposedMinusY - 1
                else if List.length(List.filter equalsProposed moveDown) /= 0 then
                    proposedMinusY + 1
                else if invalid then
                    mobileMagnetMinusY
                else if List.length(List.filter equalsProposedPlus plusInvalid) > 0 then
                    mobileMagnetMinusY
                else if List.length(List.filter equalsProposedMinus minusInvalid) > 0 then
                    mobileMagnetMinusY
                else
                    proposedMinusY

    {-
    newPlus = (proposedPlusX, proposedPlusY)
    newMinus = (proposedMinusX, proposedMinusY)
    -}

    newPlus = (finalPlusX, finalPlusY)
    newMinus = (finalMinusX, finalMinusY)

    movedObjects = objectsFromOrig newPlus newMinus
  in
  { 
    objects = movedObjects,
    latent = {mobileMagnetPlus = newPlus, mobileMagnetMinus = newMinus}
  }
  
main = pomdp {objects = initScene, latent = {mobileMagnetPlus = initMobileMagnetPlus, mobileMagnetMinus = initMobileMagnetMinus}} update
