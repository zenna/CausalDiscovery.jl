using Test
using CausalDiscovery.Autumn

@testset begin
  prog = au"""
  (program
    (: x Int)
    (= x 3)
    (= y (initnext (+ 1 2) (/ 3 this)))
  )
  """
end

@testset begin
  prog = au"""
  (program
    (: x Int)
    (= x 3)
    (= y (initnext (+ 1 2) (/ 3 this)))
  )
  """
end