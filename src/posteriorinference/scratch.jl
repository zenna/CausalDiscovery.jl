function compute_likelihood(program, observation_seq)


end

function compute_log_likelihood_cisc(on_clauses, concrete_update_function_matrix, object_decomposition) 
  object_types, object_mapping, background, _ = object_decomposition
  
  log_prob = 0

  # (addObj uniformChoice), (addObj randomPositions)  
  for object_id in size(concrete_update_function_matrix)[1]
    for time in size(concrete_update_function_matrix)[2]
      u = concrete_update_function_matrix[object_id, time]
      if occursin("addObj", u)
        if occursin("randomPositions GRID_SIZE 1", u) 
          log_prob += log2(1/(grid_size * grid_size))
        elseif occursin("randomPositions GRID_SIZE 2") 
          log_prob += log2(2/(grid_size * grid_size))/2
        else # uniformChoice
          list_expr_str = split(u, "uniformChoice ")[end][1:end-2]
          type_id = parse(Int, split(split(list_expr_str, "prev addedObjType")[end], " ")[1])
          # compute number of objects of type type_id at time t 
          object_ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping)))

          alive_object_ids = filter(id -> !isnothing(object_mapping[id][time]), object_ids_with_type)
          log_prob += log2(1/length(alive_object_ids))
        end
      end
    end
  end

  log_prob
end

function compute_log_likelihood_empa_lower_bound(on_clauses, concrete_update_function_matrix, abstract_update_function_matrix, object_decomposition) 
  object_types, object_mapping, background, _ = object_decomposition
  log_prob = 0

  # new from cisc: non-deterministic events
  # (addObj uniformChoice), (update function uniformChoice), (update function closestRandom)

  # find on-clauses with non-deterministic events 
  on_clauses_with_nondeterministic_events = filter(c -> occursin("uniformChoice", split(c, "\n")[1]), on_clauses)

  for time in size(concrete_update_function_matrix)[2] 
    # check if any update functions triggered by non-deterministic events occurred 
    all_update_funcs = map(u -> join(split(formatted_update_func, "(--> obj")[1:end - 1], "(--> obj"), vcat(concrete_update_function_matrix[:, time]...))
    for on_clause in on_clauses_with_nondeterministic_events 
      formatted_update_func = split(on_clause, "\n")[end]
      update_func = join(split(formatted_update_func, "(--> obj")[1:end - 1], "(--> obj") # get rid of the final lambda argument containing the event 
      if update_func in all_update_funcs 
        log += log2(1/10)
      end
    end

    # check if non-deterministic update functions occurred 
    for object_id in size(concrete_update_function_matrix)[1]
      u = concrete_update_function_matrix[object_id, time]
      if occursin("addObj", u)
        if occursin("uniformChoice", u) 
          list_expr_str = split(u, "uniformChoice ")[end][1:end-2]
          type_id = parse(Int, split(split(list_expr_str, "prev addedObjType")[end], " ")[1])
          # compute number of objects of type type_id at time t 
          object_ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping)))

          alive_object_ids = filter(id -> !isnothing(object_mapping[id][time]), object_ids_with_type)
          log_prob += log2(1/length(alive_object_ids))
        end
      elseif occursin("uniformChoice", u) # Brownian motion
        # compare concrete and abstract update function matrices 
        list_expr_str = split(u, "uniformChoice ")[end][1:end-2]
        aex = parseau(list_expr_str)
        if occursin("closest", u) 
          log_prob += log2(length(filter(x -> occursin("closest", x) && !occursin("--> obj (prev obj)", x), abstract_update_function_matrix[object_id, time]))/length(aex.args))
        else 
          log_prob += log2(length(filter(x -> !occursin("closest", x) && !occursin("--> obj (prev obj)", x), abstract_update_function_matrix[object_id, time]))/length(aex.args))
        end
      elseif occursin("closestRandom", u)
        # compare concrete and abstract update function matrices 
        num_directions = length(filter(x -> occursin("closest", x), abstract_update_function_matrix[object_id, time]))
        log_prob += log2(num_directions/4)
      end

    end

  end

  log_prob
end

"""
- function indicating which on-clauses are run when interpreting a program 
-- easy for global events 
-- for object-specific events: check inside updateObj 
-- can make this a boolean flag in the interpreter: can print out the on-clause AExpr or something?

once we've detected which on-clauses are true/run, then we can perform various modifications: 
- convert each one into a deterministic version:
-- global events: turn the random part of the on-clause event to true 
-- uniformChoice in update function: pick one of the options 
-- closestRandom in update function: pick one of the options (what the options are must be computed)
(-- have to break up the object-specific events into their individual id's)
basically, we can perform these modifications fairly easily at the level of the AST/AExpr, rather than the string level (obviously, I guess)

once we've done this, we can add the part where we keep track of object decompositions with 
different latent states, and propogate that through the program. 

"""