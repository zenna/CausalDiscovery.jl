module Render exposing (..)

import Engine exposing (..)

import Canvas exposing (..)
import Canvas.Settings exposing (..)
import Color
-- import Html exposing (Html)
-- import Html.Attributes exposing (style)

import Browser
import Browser.Events exposing (onAnimationFrameDelta)
import Canvas exposing (..)
-- import Canvas.Settings exposing (..)
import Canvas.Settings.Advanced exposing (..)
-- import Color
import Html exposing (Html, div)
import Html.Attributes exposing (style)

-- viewer image (width, height) = 
--   Canvas.toHtml (width, height)
--     [ style "border" "5px solid black" ]
--     []
--     [
--       -- list of styles
--       -- list of shapes
--       shapes []
--         [ rect (1, 1) 4 5,
--           rect (5, 6) 2 3],

--       shapes []
--         [ rect (30, 30) 20 5,
--           rect (5, 6) 2 30]
    
--     ]

-- type alias Model =
--     { count : Float }

type Msg
    = Frame Float

-- main : Program () Model Msg
-- main = view { count = 0 }
    -- Browser.element
    --     { init = \() -> ( { count = 0 }, Cmd.none )
    --     , view = view
    --     , update =
    --         \msg model ->
    --             case msg of
    --                 Frame _ ->
    --                     ( { model | count = model.count + 1 }, Cmd.none )
    --     , subscriptions = \model -> onAnimationFrameDelta Frame
    --     }



-- view : Image -> Html Msg
view image width height =
    div
        [ style "display" "flex"
        , style "justify-content" "center"
        , style "align-items" "center"
        ]
        [ Canvas.toHtml
            ( width, height )
            [ style "border" "10px solid rgba(0,0,0,0.1)" ]
            [ clearScreen width height
            , render image (toFloat width) (toFloat height)
            ]
        ]

clearScreen width height =
  shapes [ fill Color.white ] [ rect ( 0, 0 ) (toFloat width) (toFloat height) ]

render image width height =
  let
    size =
      width / 3

    centerX =
      width / 2

    centerY =
      height / 2

    x =
      -(size / 2)

    y =
      -(size / 2)
    
    widthRatio =
      width / image.width

    heightRatio =
      height / image.height
  in
  shapes
      [ transform
          [ translate centerX centerY
          -- , rotate (degrees (count * 3))
          ]
      , fill (Color.hsl 0.2 0.3 0.7)
      ]
      [ rect ( x, y ) widthRatio heightRatio
      , rect ( x + 10, y + 10) widthRatio heightRatio
      ]