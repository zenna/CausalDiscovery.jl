include("OptimalDesignExperiment.jl")
using .OptimalDesign, Test
#all experiment sequences
experiments = [[1,1,1,1],[1,1,1,0],[1,1,0,1],[1,1,0,0],[1,0,1,1],[1,0,1,0],
[1,0,0,1],[1,0,0,0],[0,1,1,1],[0,1,1,0],[0,1,0,1],[0,1,0,0],[0,0,1,1],[0,0,1,0],
[0,0,0,1],[0,0,0,0]]
"""
biased model, from paper
"""
function biasedfunc(exp)
  if sum(exp) == 4
    phead = 5/6
  elseif sum(exp) == 3
    phead = 2/3
  elseif sum(exp) == 2
    phead = 1/2
  elseif sum(exp) == 1
    phead = 1/3
  else
    phead = 1/6
  end
  if rand() < phead
    1
  else
    0
  end
end
m_biased = Model("biased",biasedfunc)
"""
markov model, from paper
"""
function markovfunc(exp)
  transitions = 0
  for i in 1:3
    if exp[i] != exp[i+1]
      transitions += 1
    end
  end
  if transitions == 3
    t_prob = 4/5
  elseif transitions == 2
    t_prob = 3/5
  elseif transitions == 1
    t_prob = 2/5
  elseif transitions == 0
    t_prob = 1/5
  end
  if rand() < t_prob
    1 - exp[4]
  else
    exp[4]
  end
end
m_markov = Model("markov", markovfunc)
"""
fair model
"""
m_fair = Model("fair", (exp) -> rand(0:1))

"""
uniform prior samplers
"""
function allpriorsamp()
  rand([m_fair,m_biased,m_markov])
end
function fairmarkovsamp()
  rand([m_fair,m_markov])
end
function markovbiasedsamp()
  rand([m_markov,m_biased])
end
function fairbiasedsamp()
  rand([m_fair,m_biased])
end
@test optimalexp(allpriorsamp,experiments) in [[0,0,0,0],[1,1,1,1]]
@test optimalexp(markovbiasedsamp,experiments) in [[1,0,1,0],[0,1,0,1]]
