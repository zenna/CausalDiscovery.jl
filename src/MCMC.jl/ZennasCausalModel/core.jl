module CausalCore

using Distributions
using Statistics
export ExogenousVariable, EndogenousVariable, intervene, randomsample, prob

"""
Struct for an exogenous variable.
"""
struct ExogenousVariable
    name
    distribution
end

"""
Struct for an endogenous variable.
"""
struct EndogenousVariable
    operator
    parents
end

"""
Evalutes an endogenous variable given values of parent variables.
"""
function (u::EndogenousVariable)(u_)
    evaluated_vars = map(parent -> (parent)(u_), u.parents)
    return reduce(u.operator, evaluated_vars)
end

"""
Finds exogenous variable value from list of exogenous variable values.
"""
function (u::ExogenousVariable)(u_)
    for name in keys(u_)
        if u.name == name
            return getindex(u_, name)
        end
    end
end

"""
Randomly samples value from a variable.
"""
function randomsample(u)
    parent_values = Dict{Any,Any}()
    randomsample_helper(u, parent_values)
end

function randomsample_helper(u::EndogenousVariable, dict::Dict{Any, Any})
    if haskey(dict, u.name)
      getindex(dict, u.name)
    else
      sample_values = map(parent -> randomsample_helper(parent, dict), u.parents)
      val = u.operator(sample_values...)
      push!(dict, u.name => val)
      val
    end
end

function randomsample_helper(u::ExogenousVariable, dict::Dict{Any, Any})
    if haskey(dict, u.name)
        getindex(dict, u.name)
    else
        val = rand(u.distribution)
        push!(dict, u.name => val)
        val
    end
end

function randomsample_helper(u::Array, dict::Dict{Any, Any})
  sample_values = []
  for variable in u
    sample_value = randomsample_helper(variable, dict)
    push!(sample_values, sample_value)
  end
  sample_values
end

"""
Compute probability that u == val.
"""
function prob(u, val)
  NSAMPS = 100000
  total = 0
  for i=1:NSAMPS
    if randomsample(u) == val    
      total += 1
    end
  end
  total/NSAMPS
end

"""
Constructs new endogenous variable based on an intervention of an existing variable.
@param u1: endogenous variable that undergoes intervention.
@param u2: exogenous variable that takes deterministic value under intervention.
@param val: value of exogenous variable under intervention.
"""
function intervene(u1::EndogenousVariable, u2::ExogenousVariable, val) 
    new_parents = map(parent -> intervene(parent, u2, val), u1.parents)
    EndogenousVariable(u1.operator, new_parents)
end

"""
Constructs new, deterministic exogenous variable based on an intervention.
@param u1: exogenous variable that undergoes intervention.
@param u2: exogenous variable that takes deterministic value under intervention.
@param val: value of exogenous variable under intervention.
"""
function intervene(u1::ExogenousVariable, u2::ExogenousVariable, val) 
    if (u1.name == u2.name)
        if val == 0
            ExogenousVariable(u1.name, Bernoulli(0))
        else
            ExogenousVariable(u1.name, Bernoulli(1))
        end        
    else
        u1
    end
end

end
