module Ant exposing (..)

-- import Render exposing (..)
import Engine exposing (..)
import Color
import Update exposing (..)
import Random
import Array

food_start_positions = [[(7, 7, True), (8, 7, True), (7, 8, True), (8, 8, True)], [(10, 10, True), (7,6, True), (14,3, True), (15,15, True)], [(4, 10, True), (1,3, True), (5,6, True), (1,15, True)], [(7, 4, True), (7,6, True), (12,9, True), (1,1, True)], [(0, 10, True), (6,10, True), (3,3, True), (11,8, True)], [(0, 0, True), (8,8, True), (9,9, True), (10,10, True)]]
current_food_position_index = 0

init_food_position = Maybe.withDefault [(0,0, True), (0,0, True), (0,0, True), (0,0, True)] (Array.get current_food_position_index (Array.fromList food_start_positions))

ant_start_positions = [(-1, 0, False), (15, -1, False), (16, 15, False), (0, 16, False)]
-- ant_start_positions = [(0, 0), (1, 0), (2, 0), (3, 0)]

createAntBox : (Int, Int, Bool) -> Entity
createAntBox (ant_x, ant_y, _) = ObjectTag (Box (ant_x, ant_y) 0 0 (Color.brown))

createFoodBox : (Int, Int, Bool) -> Entity
createFoodBox (food_x, food_y, _) = ObjectTag (Box (food_x, food_y) 0 0 (Color.red))

objectsFromPositions : List (Int, Int, Bool) -> List (Int, Int, Bool) -> List (Entity)
objectsFromPositions ant_positions food_positions = 
  let 
    ant_boxes = List.map createAntBox ant_positions
    food_boxes = List.map createFoodBox food_positions
    boxes = List.concat [ant_boxes, food_boxes]
    in
    boxes

initScene : Scene
initScene = objectsFromPositions ant_start_positions init_food_position

checkWithinBoundary : (Int, Int) -> Bool
checkWithinBoundary (x, y) = if (x >= 0 && x <= 15 && y >= 0 && y <= 15) then
                                    True
                                else
                                    False


checkWithinBoundaryFood : (Int, Int, Bool) -> Bool
checkWithinBoundaryFood (x, y, _) = if (x >= 0 && x <= 15 && y >= 0 && y <= 15) then
                                    True
                                else
                                    False

closestBoundaryToPoint : (Int, Int) -> (Int, Int)
closestBoundaryToPoint (x, y) = if (x < (15 - x) && y < (15 - y) && x <= y) then
                                        (-1, 0)
                                    else if (x < (15 - x) && y < (15 - y) && x > y) then
                                        (0, -1)
                                    else if (x < (15 - x) && y > (15 - y) && x <= 15 - y) then
                                        (-1, 0)
                                    else if (x < (15 - x) && y > (15 - y) && x > 15 - y) then
                                        (0, 1)
                                    else if (x > (15 - x) && y < (15 - y) && 15 - x <= y) then
                                        (1, 0)
                                    else if (x > (15 - x) && y < (15 - y) && 15 - x > y) then
                                        (0, -1)
                                    else if (x > (15 - x) && y > (15 - y) && 15 - x <= 15 - y) then
                                        (1, 0)
                                    else if (x > (15 - x) && y > (15 - y) && 15 - x > 15 - y) then
                                        (0, 1)
                                    else 
                                        (0,0)

manhattanDistance (x1, y1) (x2, y2) = (abs (x1 - x2)) + (abs (y1 - y2))

manhattanDistanceFood (x1, y1) (x2, y2, _) = (abs (x1 - x2)) + (abs (y1 - y2))

foodIsUnclaimed : (Int, Int, Bool) -> Bool
foodIsUnclaimed (x, y, unclaimed) = unclaimed

nextAntPosition : List (Int, Int, Bool) -> (Int, Int, Bool) -> (Int, Int, Bool)
nextAntPosition food_positions (x,y, hasFood) = 
    let
        unclaimedFood = List.filter foodIsUnclaimed food_positions
        noFoodLeft = (List.length unclaimedFood == 0)

        localManhattanDistance = manhattanDistanceFood (x, y) 
        closestDistance = Maybe.withDefault -1 (List.minimum (List.map localManhattanDistance unclaimedFood)) 

        closestFoodPositions = List.filter (\n -> localManhattanDistance n == closestDistance) unclaimedFood

        (foodX, foodY, _) = if (List.length unclaimedFood == 0) then
                            (-1,-1,False)
                        else
                            Maybe.withDefault (-1, -1, False) (List.head closestFoodPositions)                 
        
        (deltaX, deltaY) = if hasFood == True || (foodX == -1 && foodY == -1) then
                                closestBoundaryToPoint (x, y)
                           else if (foodX - x) == 0 && (foodY - y) == 0 then
                                (foodX - x, foodY - y)
                           else if (foodX - x) == 0 && (foodY - y) /= 0 then
                                (foodX - x, (foodY - y)//(abs (foodY - y)))
                           else if (foodX - x ) /= 0 && (foodY - y) == 0 then
                                ((foodX - x)//(abs (foodX - x)), foodY - y)
                           else 
                                ((foodX - x)//(abs (foodX - x)), 0)

        nextHasFood = if closestDistance == 0 then
                    True
                  else
                    False

        (nextX, nextY) = (x + deltaX, y + deltaY)                        
    in  
    (nextX, nextY, nextHasFood)


nextFoodPosition : List (Int, Int, Bool) -> (Int, Int, Bool) -> (Int, Int, Bool)
nextFoodPosition ant_positions (x, y, unclaimed)  =
    let
        localManhattanDistance = manhattanDistanceFood (x, y)
        (deltaX, deltaY) =  if (List.length (List.filter (\n -> localManhattanDistance n == 0) ant_positions) /= 0) then
                                closestBoundaryToPoint (x, y)
                            else
                                (0, 0)
        nextUnclaimed = if (List.length (List.filter (\n -> (localManhattanDistance n) == 0) ant_positions) /= 0) then
                            False
                        else
                            True
        nextX = x + deltaX
        nextY = y + deltaY
    in
    (nextX, nextY, nextUnclaimed)

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
    localNextAntPosition = nextAntPosition latent.food_positions

    nextAntPositions = List.map localNextAntPosition latent.ant_positions
    
    localNextFoodPosition = nextFoodPosition latent.ant_positions

    nextFoodPositions = if computer.mouse.click && (List.length (List.filter checkWithinBoundaryFood latent.food_positions) == 0) then
                            Maybe.withDefault [(0,0,False),(0,0, False),(0,0, False),(0,0, False)] (Array.get (modBy 6 (latent.index + 1)) (Array.fromList food_start_positions))
                        else
                            List.map localNextFoodPosition latent.food_positions
    nextIndex = if computer.mouse.click && (List.length (List.filter checkWithinBoundaryFood latent.food_positions) == 0) then
                    latent.index + 1
                else
                    latent.index

    movedObjects = objectsFromPositions nextAntPositions nextFoodPositions
  in
  { 
    objects = movedObjects,
    latent = {ant_positions = nextAntPositions, food_positions = nextFoodPositions, index = nextIndex}
  }
  
main = pomdp {objects = initScene, latent = {ant_positions = ant_start_positions, food_positions = init_food_position, index = 0}} update