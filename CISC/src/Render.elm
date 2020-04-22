module Render exposing (..)

import Engine exposing (..)
import Canvas exposing (..)
import Canvas.Settings exposing (..)
import Canvas.Settings.Advanced exposing (..)
import Color
import Browser.Events exposing (onAnimationFrameDelta)
import Html exposing (Html, div)
import Html.Attributes exposing (style)

view : Image -> Int -> Int -> Html msg
view image width height =
    div
        [ style "display" "flex"
        , style "justify-content" "center"
        , style "align-items" "center"
        ]
        [ Canvas.toHtml
            ( width, height )
            [ ]
            (clearScreen width height :: render image width height)
        ]

clearScreen width height =
  shapes [ fill Color.white ] [ rect ( 0, 0 ) (toFloat width) (toFloat height) ]

rectAtPos {rgba, pos} width height = 
  shapes [ fill rgba, stroke Color.black ] [ rect (toFloat (Tuple.first pos) * width, toFloat (Tuple.second pos) * height) width height ]

render image width height =
  let
    widthRatio =
      toFloat width / toFloat image.width

    heightRatio =
      toFloat height / toFloat image.height
    
  in
  (List.map (\pixel -> rectAtPos pixel widthRatio heightRatio) image.pixels)