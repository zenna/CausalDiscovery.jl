include("OptimalDesignExperiment.jl")
using .OptimalDesign, Test
#all experiment sequences
experiments = [[1,1,1,1],[1,1,1,0],[1,1,0,1],[1,1,0,0],[1,0,1,1],[1,0,1,0],
[1,0,0,1],[1,0,0,0],[0,1,1,1],[0,1,1,0],[0,1,0,1],[0,1,0,0],[0,0,1,1],[0,0,1,0],
[0,0,0,1],[0,0,0,0]]
n_exps=1
"""
biased model, from paper
"""
function biasedfunc(exp,n)
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
  [Int(rand() < phead) for i in 1:n]
end
m_biased = Model("biased",(exp) -> biasedfunc(exp,n_exps))
"""
markov model, from paper
"""
function markovfunc(exp,n)
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
  vals=[]
  for i in 1:n
    if rand() < t_prob
      push!(vals, 1 - exp[4])
    else
      push!(vals, exp[4])
    end
  end
  vals
end
m_markov = Model("markov",(exp) -> markovfunc(exp,n_exps))
"""
fair model
"""
function fairfunc(exp,n)
  [rand(0:1) for i in 1:n]
end
m_fair = Model("fair", (exp) -> fairfunc(exp,n_exps))

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
#@test optimalexp(allpriorsamp,experiments) in [[0,0,0,0],[1,1,1,1]]
#@test optimalexp(markovbiasedsamp,experiments) in [[1,0,1,0],[0,1,0,1]]
"""
faster special case of coin
"""
#probability of experiment under markov model
function markovprob(exp,data)
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
  if exp[4] == 1
    p_head = 1 - t_prob
  else
    p_head = t_prob
  end
  heads = sum(data)
  p_head^heads * (1 - p_head)^(length(data) - heads)
end
#probability of data under fair model
function fairprob(exp,data)
  0.5 ^ (length(data))
end
function biasedprob(exp,data)
  if sum(exp) == 4
    p_head = 5/6
  elseif sum(exp) == 3
    p_head = 2/3
  elseif sum(exp) == 2
    p_head = 1/2
  elseif sum(exp) == 1
    p_head = 1/3
  else
    p_head = 1/6
  end
  heads = sum(data)
  p_head^heads * (1 - p_head)^(length(data) - heads)
end
likelihoods = [fairprob, biasedprob, markovprob]
println(analyticoptimalexp([1/3,1/3,1/3],allpriorsamp,likelihoods,experiments, 100000))
println(analyticoptimalexp([1/2,1/2],markovbiasedsamp,[markovprob,biasedprob],experiments, 100000))
