module Main exposing (..)

import Browser
import Html exposing (Html, button, div, text)
import Html.Events exposing (onClick)
import Svg exposing (..)
import Svg.Attributes exposing (width, height, x, y, viewBox, xlinkHref)

-- MAIN
main =
  Browser.sandbox {init = init, update = update, view = view}

alarm = image [xlinkHref "data/alarm.svg", 
        width "200", height "200", x "130", y "0"][]
silence = svg[][]

--EDIT THIS LOGIC FOR DIFF CASES
-- Currently implementing one-cause condition w/ Yellow Block
playAlarm blicket=
  if blicket == "none" then
    silence
  else if blicket == "boxAndCylinder" then
    alarm
  else if blicket == "yellowBox" then
    alarm
  else if blicket == "blueCylinder" then
    silence
  else
    silence

--Images of blickets being placed on sensor
sensor = svg [ width "500"
          , height "500"
          , viewBox "0 0 500 500"
          ] [
            image [
                xlinkHref "data/sensor.svg", 
                width "300", height "300", x "75", y "120"][]
            , playAlarm "none"
          ]
yellowBox = svg [ width "500"
          , height "500"
          , viewBox "0 0 500 500"
          ] [
            image [
                xlinkHref "data/sensor.svg", 
                width "300", height "300", x "75", y "120"][]
            , image [
                xlinkHref "data/yellowbox.svg", 
                width "100", height "100", x "180", y "130"][]
            , playAlarm "yellowBox"     
          ]

blueCylinder =  svg [ width "500"
          , height "500"
          , viewBox "0 0 500 500"
          ] [
            image [
                xlinkHref "data/sensor.svg", 
                width "300", height "300", x "75", y "120"][],
            image [
                xlinkHref "data/bluecylinder.svg", 
                width "100", height "100", x "180", y "130"][]
            , playAlarm "blueCylinder"     
          ]

boxAndCylinder = svg [ width "500"
          , height "500"
          , viewBox "0 0 500 500"
          ] [
            image [
                xlinkHref "data/sensor.svg", 
                width "300", height "300", x "75", y "120"][],
            image [
                xlinkHref "data/bluecylinder.svg", 
                width "100", height "100", x "120", y "130"][],
            image [
                xlinkHref "data/yellowbox.svg", 
                width "100", height "100", x "250", y "130"][]
            , playAlarm "boxAndCylinder"     
          ]

-- MODEL
type alias Model = Html Msg 
init : Model

init = sensor

--VIEW

view : Model -> Html Msg 

view model =
  div [][
    div [] [
      button [onClick Original] [ Html.text "Original"],
      button [onClick Cylinder] [Html.text "Blue Cylinder"],
      button [onClick Box] [Html.text "Yellow Box"],
      button [onClick Both] [Html.text "Both"]
    ],
    div [][model]
  ]

-- UPDATE

type Msg = Original | Cylinder | Box | Both

update: Msg -> Model -> Model

update msg model = 
  case msg of
    Original -> sensor
    Cylinder -> blueCylinder
    Box -> yellowBox
    Both -> boxAndCylinder

