module Engine exposing (..)

import List

-- An object is a body
type Object
  = Circle
  | Box Pos Int Int RGBA -- Origin Width Height Color (Scene -> Object)

-- A Scalar field 
type Field = FieldA | FieldB

type alias Particles = List Float

-- An Entity is one of the many kinds of thing that can exist
type Entity = ObjectTag Object | FieldTag Field | ParticlesTag Particles

-- A Scene is simply a collection of entities
type alias Scene = List Entity

-- Premultiplied RGBA (red, green, blue, alpha)
-- type alias RGBA = (Float, Float64, Float64, Float64)
type alias RGBA = { r : Float, g : Float, b : Float, a : Float }

transparent = {r = 0.0, g = 0.0, b = 0.0, a = 0.0}
red = {r = 1.0, g = 0.0, b = 0.0, a = 1.0}
green = {r = 0.0, g = 1.0, b = 0.0, a = 1.0}
blue = {r = 0.0, g = 0.0, b = 1.0, a = 1.0}
type alias Pixel = { rgba : RGBA, pos : Position }

alphacompose : RGBA -> RGBA -> RGBA
alphacompose p q = 
  let
    pacompl = 1 - p.a
    f = \ca cb -> ca + cb * pacompl
  in
  {
    r = f p.r q.r,
    g = f p.g q.g,
    b = f p.b q.b,
    a = p.a + q.b * pacompl
  }
  

-- Alpha composition of multiple objects
alphacomposeMany : List RGBA -> RGBA
alphacomposeMany rgbs = 
  case rgbs of
    [] -> transparent
    [x] -> x
    [x1, x2] -> alphacompose x1 x2
    a::b::c -> List.foldl alphacompose a (b::c)

-- An Image is a collection of Pixels
type alias Image = List Pixel

type alias Width = Int
type alias Height = Int

-- Cartesian product
cartesian : List a -> List b -> List (a, b)
cartesian xs ys =
  List.concatMap
    (\x -> List.map ( \y -> (x, y) ) ys )
    xs

-- Render object 
render : Scene -> Width -> Height -> Image 
render scene width height = 
  List.map (\pos -> renderpixel scene pos) (cartesian (List.range 0 width) (List.range 0 height))

-- A Position is an (x, y) pair
type alias Position = (Int, Int)

field : Entity -> Position -> RGBA
field entity pos =
  case entity of
    ObjectTag object -> fieldObject object pos
    FieldTag fieldtag -> transparent
    ParticlesTag particletag -> transparent

fieldObject : Object -> Position -> RGBA
fieldObject object (x, y) = 
  case object of
    Box orig boxx boxy color -> transparent
    Circle -> red
      

renderpixel : Scene -> Position -> Pixel
renderpixel scene pos =
  let
    colors = List.map (\entity -> field entity pos) scene
  in
    { 
      rgba = alphacomposeMany colors,
      pos = pos
    }


 

-- Update an object
-- updateObject : Object -> Scene -> Object
-- updateObject object scene =
--   case object of
--     Box num f -> object
--     Door num f -> object
--     Circle -> Circle
--     Switch t -> Circle

-- --- Update a scene
-- update msg scene = List.map updateObject scene

-- Render a scene to an svg
-- rendertosvg : Scene -> Svg

-- Car Example
car = Box (1, 1) 3 4 red
tank = Box (2, 2) 1 2 yellow

-- Questions
-- How can the tank origin be tied to the box origin?
-- Where to store internal state?
-- How to make the shape a function of the internal state

-- Light switch model
-- switch = Switch True
  
-- car = Box {origin = (1, 1), 0.3 (\scene -> List.head scene)
-- car = Shape {origin = (1, 1), cells = [(0, 0), (0, 1), (0, 2), (0, 3), (1, 3), (2, 3), (2, 2), (2, 1), (2, 0), (1, 0)]}  

-- -- This is invalid!
-- type alias tank_size = Int  
-- tank = Box {origin = Box.origin} 0
