include("compute_likelihood.jl");
using StatsBase 

function mcmc(init_program, observations, iters=1000)

  chain = [init_program]
  for i in 1:iters 
    curr_val = chain[i]
    proposed_val = propose(curr_val)
    
    curr_score = compute_likelihood(curr_val, observations)
    proposed_score = compute_likelihood(proposed_val, observations)
    
    alpha = 2^(proposed_score - curr_score) # (2^proposed_score)/(2^curr_score)
    u = rand()
    if u <= alpha 
      push!(chain, proposed_val)
    else 
      push!(chain, curr_val)
    end
  end

  mode(chain) # chain[end]
end

function propose(program_)
  program = repr(parseautumn(program_))
  parts = split(program, "range ")
  new_parts = []
  for i in 2:2:length(parts)
    push!(new_parts, parts[i - 1])
    part = parts[i]
    paren_index = collect(findfirst(")", part))[1]
    new_part = string("range ", noise(parse(Int, part[1:paren_index - 1])), part[paren_index:end])
    push!(new_parts, new_part)
  end
  join(new_parts, "range ")
end

function noise(n)
  sample(collect(n - 3 : n + 3), Weights([0.2, 0.2, 0.2, 0.4, 0.2, 0.2, 0.2]))
end