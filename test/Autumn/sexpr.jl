using Test
using CausalDiscovery.Autumn

@testset begin
  prog = au"""
    (program
    (external (: z Int))
    (: x Int)
    (= x 3)
    (: y Int)
    (= y (initnext (+ 1 2) (/ 3 this)))
    (: map (-> (-> a b) (List a) (List b)))
    (= xs [1 2 3])
    (: f (-> Int Int))
    (= f (fn (x) (+ x x)))
    (= ys (map f xs))
    (type Particle a (Particle a) (Dog Float64 Float64))
    (: g (-> (Particle a) (Int)))
    (= g (fn (particle)
            (case particle
                  (=> (Particle a_) 4)
                  (=> (Dog a_ b_) 5))))
    (: o Int)
    (= o (let (q 3 d 12) (+ q d)))
  )
  """
end

## Should parse to
  """
  external z : Int
  x : Int
  x = 3
  y : Int
  y = init 1 + 2 next 3 / this
  map : (a -> b) -> List a -> List b
  xs = [1 2 3]
  f : Int -> Int
  f x = + x z
  ys = map f xs
  type Particle a = Particle a | Dog Float64 Float64
  g : Particle
  > g : Particle a -> Int
  g particle = 
    case particle of
      (Particle a_) -> 4 
      (Dog a_ b_) -> 5
  o : Int
  o = let
        q = 3
        d = 12
      in
        q + d
  """