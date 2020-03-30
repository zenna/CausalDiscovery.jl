module OptimalDesign
export Model, optimalexp, approxutility,approxKL,postsamp,countdict
#a model is a struct of a name and a function which takes an experiment and outputs an observation
struct Model
  name
  func
end
(m::Model)(u) = m.func(u)
#the prior, priorsamp is a function which returns a random model according to the prior dist
#rejection sampling event with probability 0
struct ZeroProb <: Exception
end
"""
samples a random model from the posterior distribution, this is rejection
exp is experiment, obs is observation
"""
function postsamp(priorsamp,exp,obs)
  testmodel = priorsamp()
  testobs = testmodel(exp)
  counter = 0
  while counter < 200 && !(testobs == obs)
    counter += 1
    testmodel = priorsamp()
    testobs = testmodel(exp)
  end
  if counter == 200
    throw(ZeroProb())
  end
  testmodel
end
"""
convert sampler to approximate probabilities
"""
function countdict(sampler,n_samps)
  counts = Dict()
  for iter in 1:n_samps
    model=sampler()
    if !haskey(counts,model.name)
      counts[model.name] = 1/n_samps
    else
      counts[model.name] += 1/n_samps
    end
  end
  counts
end

"""
calculate the approximate KL-divergence between two samplers dist1, dist2
"""
KL_sample_size = 100000
function approxKL(dist1,dist2)
  #firstsamples = [dist1() for i in 1:KL_sample_size]
  #secondsamples = [dist2() for i in 1:KL_sample_size]
  countdict1 = countdict(dist1, KL_sample_size)
  countdict2 = countdict(dist2, KL_sample_size)
  total = 0
  for (key,val) in countdict1
    if val > 0
      total += val * (log(val) - log(countdict2[key]))
    end
  end
  total
end
"""
calculate the expected information gain for an experiment exp given the prior sampler
"""
util_sample_size = 1000
function approxutility(exp,priorsamp)
  KLdict = Dict()
  total = 0
  for i in 1:util_sample_size
    data = priorsamp()(exp)
    if haskey(KLdict,data)
      total += KLdict[data]
    else
      postdist = () -> postsamp(priorsamp,exp,data)
      div = approxKL(priorsamp,postdist)
      total += div
      KLdict[data] = div
    end
  end
  total / util_sample_size
end
#here we assume finite experiment set--how to maximize over infinite experiment
#set without any structure on the experiments?
function optimalexp(priorsamp,experiments)
  max = 0
  bestexp = -1
  for exp in experiments
    u = approxutility(exp, priorsamp)
    if u >= max
      max = u
      bestexp = exp
    end
  end
  bestexp
end
end # module
