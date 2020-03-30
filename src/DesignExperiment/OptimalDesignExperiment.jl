module OptimalDesign
export Model, optimalexp, approxutility,approxKL,postsamp,countdict,analyticoptimalexp,approxKL,exactpost
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
  while counter < 100000 && !(testobs == obs)
    counter += 1
    testmodel = priorsamp()
    testobs = testmodel(exp)
  end
  if counter == 100000
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
      div = approxKL(postdist,priorsamp)
      total += div
      KLdict[data] = div
    end
    println(i)
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
"""
prior is array of prior probabilities, likelihoods is array of likelihood functions, exp is experiment, data is obs
"""
function exactpost(prior,likelihoods,exp,data)
  dataprob = sum([prior[i] * likelihoods[i](exp,data) for i in 1:length(prior)])
  [prior[i] * likelihoods[i](exp,data) / dataprob for i in 1:length(prior)]
end
"""
probs1 and probs2 are arrays of probabilities
"""
function exactKL(probs1, probs2)
  sum([probs1[i] * (log(probs1[i] / probs2[i])) for i in 1:length(probs1)])
end
"""
analytic calculation of utility. We still sample to avoid blowing up with large number of possible data points.
"""
function analyticutil(prior,priorsamp,likelihoods,exp,samples)
  KLdict = Dict()
  total = 0
  for i in 1:samples
    data = priorsamp()(exp)
    if haskey(KLdict,data)
      total += KLdict[data]
    else
      postprobs = exactpost(prior,likelihoods,exp,data)
      div = exactKL(postprobs,prior)
      total += div
      KLdict[data] = div
    end
  end
  total / samples
end
"""
optimal exp using analytic functions
"""
function analyticoptimalexp(prior,priorsamp,likelihoods,experiments,samples)
  max = 0
  bestexp = -1
  for exp in experiments
    u = analyticutil(prior,priorsamp,likelihoods,exp,samples)
    println(exp,u)
    if u >= max
      max = u
      bestexp = exp
    end
  end
  bestexp
end
end # module
