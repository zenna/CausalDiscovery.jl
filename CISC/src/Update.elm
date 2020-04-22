module Update exposing (..)
import Browser
import Html exposing (Html, text, pre)
-- import Http
import Render
import Engine

-- So the choice is either :
-- 1. rejig it to use playground
-- 2. implement dynamics myself


-- Why not just use playground?
-- Not sure how rendering works, when translating to julia ll have to copy what he did

-- pros of it
-- he has a ince interface for time, keyboard,
htmlwidth = 400
htmlheight = 400
gamewidth = 8
gameheight = 8

observe computer state =
  let
    image = Engine.render state gamewidth gameheight
  in
  Render.view image htmlwidth htmlheight


-- A POMDP 
pomdp observeF updateF initF = 
  Browser.element
  { init = init
  , update = update
  , subscriptions = subscriptions
  , view = observeF
  }