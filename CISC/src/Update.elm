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

type Msg
  = KeyChanged Bool String
  | Tick Time.Posix
  -- | GotViewport Dom.Viewport
  -- | Resized Int Int
  -- | VisibilityChanged E.Visibility
  | MouseMove Float Float
  | MouseClick
  | MouseButton Bool

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
    -- , E.onClick (D.succeed MouseClick)
    , E.onMouseDown (D.succeed (MouseButton True))
    , E.onMouseUp (D.succeed (MouseButton False))
    , E.onMouseMove (D.map2 MouseMove (D.field "pageX" D.float) (D.field "pageY" D.float))
    ]

-- Observation function

observe {latent, objects} =
  let
    image = Engine.render objects gamewidth gameheight
  in
  Render.view image htmlwidth htmlheight


-- pomdpUpdate : (Computer -> memory -> memory) -> Msg -> Game memory -> Game memory
pomdpUpdate updateMemory msg (Game vis memory computer) =
  case msg of
    Tick time ->
      Game vis (updateMemory computer memory) <|
        if computer.mouse.click
        then { computer | time = Time time, mouse = mouseClick False computer.mouse }
        else { computer | time = Time time }

    GotViewport {viewport} ->
      Game vis memory { computer | screen = toScreen viewport.width viewport.height }

    Resized w h ->
      Game vis memory { computer | screen = toScreen (toFloat w) (toFloat h) }

    KeyChanged isDown key ->
      Game vis memory { computer | keyboard = updateKeyboard isDown key computer.keyboard }

    MouseMove pageX pageY ->
      let
        x = computer.screen.left + pageX
        y = computer.screen.top - pageY
      in
      Game vis memory { computer | mouse = mouseMove x y computer.mouse }

    MouseClick ->
      Game vis memory { computer | mouse = mouseClick True computer.mouse }

    MouseButton isDown ->
      Game vis memory { computer | mouse = mouseDown isDown computer.mouse }

    VisibilityChanged visibility ->
      Game visibility memory
        { computer
            | keyboard = emptyKeyboard
            , mouse = Mouse computer.mouse.x computer.mouse.y False False
        }


subscriptions model =
  Sub.none  

-- A POMDP 
pomdp ({objects, latent} as scene) dynamics =
  let
    init () = 
      (scene, Cmd.none)

    update msg model =
      ( pomdpUpdate scene msg model
      , Cmd.none
      )
  in
  Browser.element
  { init = init
  , update = update
  , subscriptions = pomdpSubscriptions
  , view = observe
  }