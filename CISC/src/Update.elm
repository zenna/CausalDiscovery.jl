module Update exposing (..)
import Browser
import Debug
import Html exposing (Html, text, pre)
import String.Conversions

-- import Render
import Engine exposing (..)
import Time
import Browser.Events as E
import Json.Decode as Decode
import Html.Events.Extra.Mouse as Mouse

import Canvas exposing (..)
import Canvas.Settings exposing (..)
import Canvas.Settings.Advanced exposing (..)
import Color
import Dict exposing (Dict)
import Dict.Extra
import Browser.Events exposing (onAnimationFrameDelta)
import Html exposing (Html, div, text, button)
import Html.Attributes exposing (style)
import String
import Html.Events.Extra.Mouse as Mouse
import File exposing (File)
import File.Download as Download
import File.Select as Select
import Html.Events exposing (onClick)
import Json.Encode as Encode
import Task

htmlwidth = 400
htmlheight = 400
gamewidth = 16
gameheight = 16

-- SUBSCRIPTIONS

type Msg =
  -- = KeyChanged Bool String
  Tick Time.Posix
  -- | GotViewport Dom.Viewport
  -- | Resized Int Int
  -- | VisibilityChanged E.Visibility
  -- | MouseMove Float Float
  | MouseClick
  | StartAt (Float, Float)
  | Download
  | Upload
  | JsonSelected File
  | JsonLoaded String
  | PlayerMode
  | ReplayMode
  -- | MouseButton Bool

pomdpSubscriptions : Sub Msg
pomdpSubscriptions =
  Sub.batch
    -- [ E.onResize Resized
    [
    --   E.onKeyUp (D.map (KeyChanged False) (D.field "key" D.string))
    -- , E.onKeyDown (D.map (KeyChanged True) (D.field "key" D.string))
    -- ,
      Time.every 100.0 Tick
      -- E.onAnimationFrame Tick
    -- , E.onVisibilityChange VisibilityChanged
    , E.onClick (Decode.succeed MouseClick)
    -- , E.onMouseDown (D.succeed (MouseButton True))
    -- , E.onMouseUp (D.succeed (MouseButton False))
    -- , E.onMouseMove (D.map2 MouseMove (D.field "pageX" D.float) (D.field "pageY" D.float))
    ]

-- Observation function

mouseClick : Bool -> Mouse -> Mouse
mouseClick bool mouse =
  { mouse | click = bool }

mouseMove : Float -> Float -> Mouse -> Mouse
mouseMove x y mouse =
  { mouse | x = x, y = y }

mouseX computer =
  computer.mouse.x

mouseY computer =
  computer.mouse.y


-- Download and Upload
downloadLog fileName history =
  (Download.string "record.json" "application/json" (Encode.encode 2 (Encode.dict String.fromInt inputDictToJson history)))

toIntWithDefault str =
  Maybe.withDefault 0 (String.toInt str)

-- pomdpUpdate : (Computer -> memory -> memory) -> Msg -> Game memory -> Game memory
pomdpUpdate updateMemory msg (POMDP memory computer) =
  
  case msg of
    Tick time ->
      -- POMDP computer memory 
      (POMDP (updateMemory computer memory) <|
        if computer.mouse.click
        then { computer | time = Time time, mouse = mouseClick False computer.mouse }
        else { computer | time = Time time }, Cmd.none)

    -- GotViewport {viewport} ->
    --   Game vis memory { computer | screen = toScreen viewport.width viewport.height }

    -- Resized w h ->
    --   Game vis memory { computer | screen = toScreen (toFloat w) (toFloat h) }

    -- KeyChanged isDown key ->
    --   Game vis memory { computer | keyboard = updateKeyboard isDown key computer.keyboard }

    -- MouseMove pageX pageY ->
    --   let
    --     -- x = computer.screen.left + pageX
    --     -- y = computer.screen.top - pageY
    --     x = pageX
    --     y = pageY
    --   in
    --   POMDP memory { computer | mouse = mouseMove x y computer.mouse }

    MouseClick ->
      (POMDP memory { computer | mouse = mouseClick True computer.mouse }, Cmd.none)

    StartAt (x, y) ->
      (POMDP memory { computer | mouse = mouseMove x y computer.mouse}, Cmd.none)

    Download ->
      (POMDP memory computer, downloadLog "clickHistory.json" memory.history)

    Upload ->
      (POMDP memory computer, Select.file ["application/json"] JsonSelected)

    JsonSelected file ->
      (POMDP memory computer, Task.perform JsonLoaded (File.toString file))

    JsonLoaded content ->
      let
        historyDict = Result.withDefault Dict.empty (Decode.decodeString (Decode.dict (Decode.dict Decode.float)) content)
        -- convert keys from string to int
        fixedHistoryDict = historyDict |> Dict.Extra.mapKeys toIntWithDefault
        newLatent = memory.init.latent
        newestLatent = {newLatent | playerMode = False}
        newMemory = {memory | objects = memory.init.objects, latent = newestLatent, history = fixedHistoryDict}
      in 
        (POMDP newMemory computer, Cmd.none)

    PlayerMode ->
      let 
        newLatent = memory.init.latent
        newestLatent = {newLatent | playerMode = True, timeStep = 0}
        updatedMemory = {memory | latent = newestLatent, objects = memory.init.objects, history = Dict.empty}
        fakeMouse = {x = 0, y = 0, down = False, click = False}
        newComputer = {computer | mouse = fakeMouse}
      in
        (POMDP updatedMemory newComputer, Cmd.none)
    
    ReplayMode ->
      let
        newLatent = memory.init.latent
        newestLatent = {newLatent | playerMode = False}
        updatedMemory = {memory | latent = newestLatent, history = Dict.empty, objects = memory.init.objects}
      in
        (POMDP updatedMemory computer, Cmd.none)



    -- MouseButton isDown ->
    --   Game vis memory { computer | mouse = mouseDown isDown computer.mouse }

    -- VisibilityChanged visibility ->
    --   Game visibility memory
    --     { computer
    --         | keyboard = emptyKeyboard
    --         , mouse = Mouse computer.mouse.x computer.mouse.y False False
    --     }

type alias Mouse =
  { x : Float
  , y : Float
  , down : Bool
  , click : Bool
  }

type alias Computer =
  { mouse : Mouse
  -- , screen : Screen
  , time : Time
  }

initialComputer : Computer
initialComputer =
  { mouse = Mouse 0 0 False False
  -- , keyboard = emptyKeyboard
  -- , screen = toScreen 600 600
  , time = Time (Time.millisToPosix 0)
  }

type Time = Time Time.Posix

type POMDP state =
  POMDP state Computer

-- A POMDP 
pomdp ({objects, latent} as scene) dynamics =
  let
    init () = 
      (
        POMDP scene initialComputer,
        Cmd.none
      )

    update msg model = pomdpUpdate dynamics msg model
    
    view_ (POMDP scene_ computer) =
      let
        image = Engine.render scene_.objects gamewidth gameheight
      in
      view image htmlwidth htmlheight computer

    subscriptions (POMDP _ _) =
      pomdpSubscriptions
  in
  Browser.element
  { init = init
  , update = update
  , subscriptions = subscriptions
  , view = view_
  }

  --  Rendering

-- view : Image -> Int -> Int -> m -> Html msg
view image width height computer =
    div
        [ style "display" "flex"
        , style "justify-content" "center"
        , style "align-items" "center"
        ]
        [ div []
            [button [onClick PlayerMode]
                    [Html.text "Player Mode"],
              button [onClick Download]
                    [Html.text "Download Log"],
              button [onClick ReplayMode]
                    [Html.text "Replay Mode"],
             button [onClick Upload]
                    [Html.text "Upload Log"],
             div [][Html.text (String.append "Mouse X: " (String.fromFloat (mouseX computer)))],
             div [][Html.text (String.append "Mouse Y: " (String.fromFloat (mouseY computer)))]],
          Canvas.toHtml
            ( width, height )
            [ Mouse.onDown (.offsetPos >> StartAt) ]
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

inputDictToJson: Input -> Encode.Value
inputDictToJson input = (Encode.dict identity Encode.float input)

type alias Latent = {keyLocation : (Int, Int), unlocked : Bool, timeStep : Int, playerMode : Bool}
type alias Event = {objects : List Entity, latent : Latent, init: {objects : List Entity, latent : Latent}}
type alias Input = Dict String Float 
type alias LoggedEvent = {objects : List Entity, latent : Latent, history : Dict Int Input, init: {objects : List Entity, latent : Latent}}
--updateTracker : (Computer -> Event -> Event) -> (Computer -> LoggedEvent -> LoggedEvent)
updateTracker updateFunction =
  let
    newUpdate computer state =
      let
        stateOut = updateFunction computer (Event state.objects state.latent state.init)
        timeStep = stateOut.latent.timeStep

        input = Dict.singleton "Click" (if computer.mouse.click then 1 else 0)
        input2 = Dict.insert "Click Y" computer.mouse.y input
        input3 = Dict.insert "Click X" computer.mouse.x input2

        newHistory = Dict.insert timeStep input3 state.history
      in
        LoggedEvent stateOut.objects stateOut.latent newHistory stateOut.init
  in
    newUpdate
