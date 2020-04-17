module Main exposing (..)

import Render exposing (..)
import Engine exposing (..)
import Color

-- Car Example
car = Box (1, 1) 3 4 Color.red

tank = Box (2, 2) 1 2 Color.yellow

fakerenderpixel : Int -> Int -> Position -> Pixel
fakerenderpixel maxwidth maxheight ((x, y) as pos) =
  let
    max = maxwidth + maxheight
    val = x + y
    i = toFloat val / 10.0
  in
  { rgba = Color.rgba 1.0 0.0 i i, pos = pos }

-- A fake image
gamewidth = 8
gameheight = 8

fakeimage : Image
fakeimage =
  {
    pixels = List.map (\pos -> fakerenderpixel gamewidth gameheight pos) (grid gamewidth gameheight),
    width = gamewidth,
    height = gameheight
  }

-- Render fake image
htmlwidth = 400
htmlheight = 400
main = view fakeimage htmlwidth htmlheight
-- main = Render.main