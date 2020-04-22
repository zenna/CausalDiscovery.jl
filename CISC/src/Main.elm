module Main exposing (..)

import Render exposing (..)
import Engine exposing (..)
import Color
import Update exposing (..)


-- Car Example

car = Box (1, 1) 3 4 Color.yellow
tank = Box (2, 2) 1 2 Color.red
scene : Scene
scene = [ObjectTag tank, ObjectTag car]
gasPumpPos = (1, 1)
gasPumpPressed computer = computer == gasPumpPos
maxGas = 3

move object x y =
  case object of
    Box (x_, y_) width height color -> Box (x + x_, y + y_) width height color
    Circle -> Circle

update computer {objects, latent} = 
  let
    tankLevel = latent
    newTank = if gasPumpPressed computer then maxGas else tankLevel - 1
    moveObjects = List.map (\o -> move o 1 1) objects
  in
  { 
    objects = moveObjects,
    latent = newTank
  }
  
main = pomdp {objects = scene, latent = maxGas} update


-- Haven't figured out messages
-- I want to visuals to change as a function of the tank