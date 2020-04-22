module Main exposing (..)

import Render exposing (..)
import Engine exposing (..)
import Color
import Update exposing (..)


-- A fake image
gamewidth = 8
gameheight = 8

-- fakerenderpixel : Int -> Int -> Position -> Pixel
-- fakerenderpixel maxwidth maxheight ((x, y) as pos) =
--   let
--     max = maxwidth + maxheight
--     val = x + y
--     i = toFloat val / 10.0
--   in
--   { rgba = Color.rgba 1.0 0.0 i i, pos = pos }



-- fakeimage : Image
-- fakeimage =
--   {
--     pixels = List.map (\pos -> fakerenderpixel gamewidth gameheight pos) (grid gamewidth gameheight),
--     width = gamewidth,
--     height = gameheight
--   }


-- -- Car Example
car = Box (1, 1) 3 4 Color.yellow
tank = Box (2, 2) 1 2 Color.red


scene : Scene
scene = [ObjectTag tank, ObjectTag car]
image = Engine.render scene gamewidth gameheight

main = pomdp



-- tankValue : Int
-- tankValue = 0


-- car = Box (1, 1) 3 4 Color.red

-- update scene

-- -- Move the car in a random ddirection 

-- Render fake image
htmlwidth = 400
htmlheight = 400
-- main = view image htmlwidth htmlheight

viewer computer (x,y) =
  view image htmlwidth htmlheight

update computer state =
  state

main =
  game viewer update (0,0)
-- main = Render.main