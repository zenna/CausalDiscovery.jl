using CausalDiscovery
using Test

function testvarsinscope()
  prog = au"""(program
                 (external (: exa Int))
                 (= x 3)
                 (= d (let ((= a 3) (= b 4)) (+ a b)))
                 (= y (fn (v1 v2 v3) (+ v1 v3 v3)))
                 (= z (fn (q t) (+ q t))))
              """

  subex1 = subexpr(prog, [2, 2, 2])
  subex2 = subexpr(prog, [2, 2, 1, 2])
  for subex in subexprs(prog)
    @show resolve(subex)
    @show vars_in_scope(subex)
    print("\n")
  end
  # Autumn.vars_in_scope(subex1)
end