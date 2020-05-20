using Test
using CausalDiscoveries.Autumn

@testset begin
  prog = au"""
  (program
    (= x 3)
    (let (x 3) (+ x 3))
  )
  """
end