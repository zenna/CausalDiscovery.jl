module Update exposing (..)
import Browser
import Html exposing (Html, text, pre)
import Render
import Engine
import Time
import Browser.Events as E
import Json.Decode as D

htmlwidth = 400
htmlheight = 400
gamewidth = 8
gameheight = 8

-- SUBSCRIPTIONS

type Msg =
  -- = KeyChanged Bool String
  Tick Time.Posix
  -- | GotViewport Dom.Viewport
  -- | Resized Int Int
  -- | VisibilityChanged E.Visibility
  | MouseMove Float Float
  | MouseClick
  -- | MouseButton Bool

pomdpSubscriptions : Sub Msg
pomdpSubscriptions =
  Sub.batch
    -- [ E.onResize Resized
    [
    --   E.onKeyUp (D.map (KeyChanged False) (D.field "key" D.string))
    -- , E.onKeyDown (D.map (KeyChanged True) (D.field "key" D.string))
    -- , 
      E.onAnimationFrame Tick
    -- , E.onVisibilityChange VisibilityChanged
    , E.onClick (D.succeed MouseClick)
    -- , E.onMouseDown (D.succeed (MouseButton True))
    -- , E.onMouseUp (D.succeed (MouseButton False))
    , E.onMouseMove (D.map2 MouseMove (D.field "pageX" D.float) (D.field "pageY" D.float))
    ]

-- Observation function

observe {latent, objects} =
  let
    image = Engine.render objects gamewidth gameheight
  in
  Render.view image htmlwidth htmlheight

mouseClick : Bool -> Mouse -> Mouse
mouseClick bool mouse =
  { mouse | click = bool }

mouseMove : Float -> Float -> Mouse -> Mouse
mouseMove x y mouse =
  { mouse | x = x, y = y }


-- pomdpUpdate : (Computer -> memory -> memory) -> Msg -> Game memory -> Game memory
pomdpUpdate updateMemory msg (POMDP memory computer) =
  case msg of
    Tick time ->
      -- POMDP computer memory 
      POMDP (updateMemory computer memory) <|
        if computer.mouse.click
        then { computer | time = Time time, mouse = mouseClick False computer.mouse }
        else { computer | time = Time time }

    -- GotViewport {viewport} ->
    --   Game vis memory { computer | screen = toScreen viewport.width viewport.height }

    -- Resized w h ->
    --   Game vis memory { computer | screen = toScreen (toFloat w) (toFloat h) }

    -- KeyChanged isDown key ->
    --   Game vis memory { computer | keyboard = updateKeyboard isDown key computer.keyboard }

    MouseMove pageX pageY ->
      let
        -- x = computer.screen.left + pageX
        -- y = computer.screen.top - pageY
        x = pageX
        y = pageY
      in
      POMDP memory { computer | mouse = mouseMove x y computer.mouse }

    MouseClick ->
      POMDP memory { computer | mouse = mouseClick True computer.mouse }

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

    update msg model =
      ( 
        pomdpUpdate dynamics msg model
      , Cmd.none
      )
    
    view_ (POMDP memory computer) =
      observe memory

    subscriptions (POMDP _ _) =
      pomdpSubscriptions
  in
  Browser.element
  { init = init
  , update = update
  , subscriptions = subscriptions
  , view = view_
  }