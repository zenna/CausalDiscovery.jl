module Main exposing (..)

import List

import Html exposing (text)

-- An object is a body
type Object
  = Circle
  | Box Float (Scene -> Object)
  | Door Float (Scene -> Object)
  | Switch Bool

-- A Scalar field 
type Field = FieldA | FieldB


type alias Particles = List Float

-- An Entity is one of the many kinds of thing that can exist
type Entity = Object | Field | Partiles

-- A Scene is simply a collection of entities
type alias Scene = List Entity  

-- Render object 
render : Object -> Float
render object = 
  case object of
    Box num f -> 3.0
    Door num f -> 2.0
    Circle -> 2.1
    Switch -> 3.1


-- Update an object
updateObject : Object -> Scene -> Object
updateObject object scene =
  case object of
    Box num f -> object
    Door num f -> object
    Circle -> Circle

--- Update a scene
update msg scene = List.map updateObject scene

-- A scene is just a collection of objects
type alias Scene = List Object

-- Render a scene to an svg
-- rendertosvg : Scene -> Svg

-- Light switch model
switch = Switch True
  
car = Box {origin = (1, 1), 0.3 (\scene -> List.head scene)
car = Shape {origin = (1, 1), cells = [(0, 0), (0, 1), (0, 2), (0, 3), (1, 3), (2, 3), (2, 2), (2, 1), (2, 0), (1, 0)]}  

-- This is invalid!
type alias tank_size = Int  
tank = Box {origin = Box.origin} 0




-- Principles
-- A Scene has multiple entities
-- An entity 

main = text "Hi"
-- type alias recordName =
--     { key1 : ValueType1
--     , key2 : ValueType2
--     }

-- main : Html msg
-- main =
--   svg
--     [ viewBox "0 0 400 400"
--     , width "400"
--     , height "400"
--     ]
--     [ circle
--         [ cx "50"
--         , cy "50"
--         , r "40"
--         , fill "red"
--         , stroke "black"
--         , strokeWidth "3"
--         ]
--         []
--     , rect
--         [ x "100"
--         , y "10"
--         , width "40"
--         , height "40"
--         , fill "green"
--         , stroke "black"
--         , strokeWidth "2"
--         ]
--         []
--     , line
--         [ x1 "20"
--         , y1 "200"
--         , x2 "200"
--         , y2 "20"
--         , stroke "blue"
--         , strokeWidth "10"
--         , strokeLin
-- type alias recordName =
--     { key1 : ValueType1
--     , key2 : ValueType2
--     }

-- main : Html msg
-- main =
--   svg
--     [ viewBox "0 0 400 400"
--     , width "400"
--     , height "400"
--     ]
--     [ circle
--         [ cx "50"
--         , cy "50"
--         , r "40"
--         , fill "red"
--         , stroke "black"
--         , strokeWidth "3"
--         ]
--         []
--     , rect
--         [ x "100"
--         , y "10"
--         , width "40"
--         , height "40"
--         , fill "green"
--         , stroke "black"
--         , strokeWidth "2"
--         ]
--         []
--     , line
--         [ x1 "20"
--         , y1 "200"
--         , x2 "200"
--         , y2 "20"
--         , stroke "blue"
--         , strokeWidth "10"
--         , strokeLinecap "round"
--         ]
--         []
--     , polyline
--         [ points "200,40 240,40 240,80 280,80 280,120 320,120 320,160"
--         , fill "none"
--         , stroke "red"
--         , strokeWidth "4"
--         , strokeDasharray "20,2"
--         ]
--         []
--     , text_
--         [ x "130"
--         , y "130"
--         , fill "black"
--         , textAnchor "middle"
--         , dominantBaseline "central"
--         , transform "rotate(-45 130,130)"
--         ]
--         [ text "Welcome to Shapes Club"
--         ]
--     ]
--         []
--     , text_
--         [ x "130"
--         , y "130"
--         , fill "black"
--         , textAnchor "middle"
--         , dominantBaseline "central"
--         , transform "rotate(-45 130,130)"
--         ]
--         [ text "Welcome to Shapes Club"
--         ]
--     ]

-- There are a lot of odd things about SVG, so always try to find examples
-- to help you understand the weird stuff. Like these:
--
--   https://www.w3schools.com/graphics/svg_examples.asp
--   https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/d
--
-- If you cannot find relevant examples, make an experiment. If you push
-- through the weirdness, you can do a lot with SVG.