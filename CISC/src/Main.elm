module Main exposing (..)

import Render exposing (..)
import Engine exposing (..)
import Color

-- Car Example
car = Box (1, 1) 3 4 (Color.toRgba Color.red)

tank = Box (2, 2) 1 2 (Color.toRgba Color.yellow)


fakerenderpixel : Int -> Int -> Position -> Image
fakerenderpixel maxwidth maxheight ((x, y) as pos) =
  let
    max = maxwidth + maxheight
    val = x + y
    intensity = toFloat val / toFloat max
  in
  { rgba = (Color.rgba intensity), pos = pos }

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