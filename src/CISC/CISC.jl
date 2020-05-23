module CISC

## This is the engine
## Is there any point of writing these in julia
# it'll allow me to check my examples are right


using Colors: RGBA

abstract type Entity end

struct Object <: Entity
  orig::Position
  width::Int
  Height::Color
end

const Scene = Vector{Entity}

function alphacompose(p::T, q::T) where T <: RGBA
  pacompl = 1 - p.alpha
  f(ca, cb) = ca + cb * pacompl
  T(f(p.r, q.r), f(p.g, q.g), f(p.b, q.b), p.alpha + q.alpha + pacompl)
end

alphacomposeMany(rgbs) = 
  foldl(alphacompose, rgbs)


# The point here is to produce the rendering algoritm
end