@timed begin 
  model_name = "mario_1"
  sols = run_model("mario", "heuristic", 1, 1, 1)
  # observations, user_events, grid_size = JLD.load("new_three_mario_traces.jld")["data"]
  # observations = observations[1]
  # user_events = user_events[1]

  # pedro=false
  # singlecell=false
  
  # matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=singlecell, pedro=pedro, upd_func_space=6, multiple_traces=false)
  # stop_times = []
  # redundant_events_set = Set()
  # global_event_vector_dict = Dict()
  # solutions = generate_on_clauses_GLOBAL(model_name, false, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, stop_times=stop_times)
end

@timed begin 
  model_name = "mario_2"
  observations, user_events, grid_size = JLD.load("new_three_mario_traces.jld")["data"]
  observations = observations[1:2]
  user_events = user_events[1:2]
  
  observations_tuple = (observations, user_events, grid_size)
  sols = run_model("mario", "heuristic", 2, 1, 1, multi_trace=true, observations_tup=observations_tuple)
  # pedro=false
  # singlecell=false
  
  # println("starting matrix construction")
  # matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=singlecell, pedro=pedro, upd_func_space=6, multiple_traces=true)
  # stop_times = map(i -> length(observations[i]) + (i == 1 ? 0 : sum(map(j -> length(observations[j]), 1:(i - 1)))), 1:(length(observations) - 1))
  # user_events = vcat(map(events -> vcat(events..., nothing), user_events)...)[1:end-1]
  # redundant_events_set = Set()
  # global_event_vector_dict = Dict()

  # println("starting generate_on_clauses_GLOBAL")
  # solutions = generate_on_clauses_GLOBAL(model_name, false, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, stop_times=stop_times)
end


@timed begin 
  model_name = "mario_3"
  observations, user_events, grid_size = JLD.load("new_three_mario_traces.jld")["data"]
  observations = observations[1:3]
  user_events = user_events[1:3]

  observations_tuple = (observations, user_events, grid_size)
  sols = run_model("mario", "heuristic", 3, 1, 1, multi_trace=true, observations_tup=observations_tuple)
  
  # pedro=false
  # singlecell=false
  
  # println("starting matrix construction")
  # matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=singlecell, pedro=pedro, upd_func_space=6, multiple_traces=true)
  # stop_times = map(i -> length(observations[i]) + (i == 1 ? 0 : sum(map(j -> length(observations[j]), 1:(i - 1)))), 1:(length(observations) - 1))
  # user_events = vcat(map(events -> vcat(events..., nothing), user_events)...)[1:end-1]
  # redundant_events_set = Set()
  # global_event_vector_dict = Dict()

  # println("starting generate_on_clauses_GLOBAL")
  # solutions = generate_on_clauses_GLOBAL(model_name, false, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, stop_times=stop_times)
end

@timed begin 
  model_name = "sokoban_1"
  observations, user_events, grid_size = JLD.load("final_sokoban_observations.jld")["data"]
  sols = run_model("sokoban_i", "heuristic", 1, 1, 1)

  # observations = observations[1]
  # user_events = user_events[1]
  
  # pedro=false
  # singlecell=true
  
  # matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=singlecell, pedro=pedro, upd_func_space=6, multiple_traces=false)
  # stop_times = []
  # redundant_events_set = Set()
  # global_event_vector_dict = Dict()
  # solutions = generate_on_clauses_GLOBAL(model_name, false, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, stop_times=stop_times)
end

@timed begin 
  model_name = "sokoban_2"
  observations, user_events, grid_size = JLD.load("final_sokoban_observations.jld")["data"]
  observations = observations[1:2]
  user_events = user_events[1:2]
  
  observations_tuple = (observations, user_events, grid_size)
  sols = run_model("sokoban_i", "heuristic", 2, 1, 1, multi_trace=true, observations_tup=observations_tuple)

  # pedro=false
  # singlecell=true
  
  # println("starting matrix construction")
  # matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=singlecell, pedro=pedro, upd_func_space=6, multiple_traces=true)
  # stop_times = map(i -> length(observations[i]) + (i == 1 ? 0 : sum(map(j -> length(observations[j]), 1:(i - 1)))), 1:(length(observations) - 1))
  # user_events = vcat(map(events -> vcat(events..., nothing), user_events)...)[1:end-1]
  # redundant_events_set = Set()
  # global_event_vector_dict = Dict()

  # println("starting generate_on_clauses_GLOBAL")
  # solutions = generate_on_clauses_GLOBAL(model_name, false, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, stop_times=stop_times)
end



@timed begin 
  model_name = "coins-4"
  observations, user_events, grid_size = JLD.load("coins_full_reverse.jld")["data"]
  observations = observations[1]
  user_events = user_events[1]
  
  pedro=false
  singlecell=true
  
  matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=singlecell, pedro=pedro, upd_func_space=6, multiple_traces=false)
  stop_times = []
  redundant_events_set = Set()
  global_event_vector_dict = Dict()
  solutions = generate_on_clauses_GLOBAL(model_name, false, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, stop_times=stop_times)
end

@timed begin 
  model_name = "coins-5"
  observations, user_events, grid_size = JLD.load("coins_full_reverse.jld")["data"]
  observations = observations[1:2]
  user_events = user_events[1:2]
  
  pedro=false
  singlecell=true
  
  println("starting matrix construction")
  matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=singlecell, pedro=pedro, upd_func_space=6, multiple_traces=true)
  stop_times = map(i -> length(observations[i]) + (i == 1 ? 0 : sum(map(j -> length(observations[j]), 1:(i - 1)))), 1:(length(observations) - 1))
  user_events = vcat(map(events -> vcat(events..., nothing), user_events)...)[1:end-1]
  redundant_events_set = Set()
  global_event_vector_dict = Dict()

  println("starting generate_on_clauses_GLOBAL")
  solutions = generate_on_clauses_GLOBAL(model_name, false, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, stop_times=stop_times)
end

@timed begin 
  model_name = "coins-6"
  observations, user_events, grid_size = JLD.load("coins_full_reverse.jld")["data"]
  observations = observations[1:3]
  user_events = user_events[1:3]
  
  pedro=false
  singlecell=true
  
  println("starting matrix construction")
  matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=singlecell, pedro=pedro, upd_func_space=6, multiple_traces=true)
  stop_times = map(i -> length(observations[i]) + (i == 1 ? 0 : sum(map(j -> length(observations[j]), 1:(i - 1)))), 1:(length(observations) - 1))
  user_events = vcat(map(events -> vcat(events..., nothing), user_events)...)[1:end-1]
  redundant_events_set = Set()
  global_event_vector_dict = Dict()

  println("starting generate_on_clauses_GLOBAL")
  solutions = generate_on_clauses_GLOBAL(model_name, false, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, stop_times=stop_times)
end

@timed begin 
  model_name = "coins-7"
  observations, user_events, grid_size = JLD.load("coins_full_reverse.jld")["data"]
  observations = observations[1:4]
  user_events = user_events[1:4]
  
  pedro=false
  singlecell=true
  
  println("starting matrix construction")
  matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=singlecell, pedro=pedro, upd_func_space=6, multiple_traces=true)
  stop_times = map(i -> length(observations[i]) + (i == 1 ? 0 : sum(map(j -> length(observations[j]), 1:(i - 1)))), 1:(length(observations) - 1))
  user_events = vcat(map(events -> vcat(events..., nothing), user_events)...)[1:end-1]
  redundant_events_set = Set()
  global_event_vector_dict = Dict()

  println("starting generate_on_clauses_GLOBAL")
  solutions = generate_on_clauses_GLOBAL(model_name, false, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, stop_times=stop_times)
end

@timed begin 
  model_name = "coins-8"
  observations, user_events, grid_size = JLD.load("coins_full_reverse.jld")["data"]
  observations = observations[1:5]
  user_events = user_events[1:5]
  
  pedro=false
  singlecell=true
  
  println("starting matrix construction")
  matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=singlecell, pedro=pedro, upd_func_space=6, multiple_traces=true)
  stop_times = map(i -> length(observations[i]) + (i == 1 ? 0 : sum(map(j -> length(observations[j]), 1:(i - 1)))), 1:(length(observations) - 1))
  user_events = vcat(map(events -> vcat(events..., nothing), user_events)...)[1:end-1]
  redundant_events_set = Set()
  global_event_vector_dict = Dict()

  println("starting generate_on_clauses_GLOBAL")
  solutions = generate_on_clauses_GLOBAL(model_name, false, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, stop_times=stop_times)
end


@timed begin 
  model_name = "coins-9"
  observations, user_events, grid_size = JLD.load("coins_full_reverse.jld")["data"]
  observations = observations[1:6]
  user_events = user_events[1:6]
  
  pedro=false
  singlecell=true
  
  println("starting matrix construction")
  matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=singlecell, pedro=pedro, upd_func_space=6, multiple_traces=true)
  stop_times = map(i -> length(observations[i]) + (i == 1 ? 0 : sum(map(j -> length(observations[j]), 1:(i - 1)))), 1:(length(observations) - 1))
  user_events = vcat(map(events -> vcat(events..., nothing), user_events)...)[1:end-1]
  redundant_events_set = Set()
  global_event_vector_dict = Dict()

  println("starting generate_on_clauses_GLOBAL")
  solutions = generate_on_clauses_GLOBAL(model_name, false, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, stop_times=stop_times)
end

@timed begin 
  model_name = "coins-10"
  observations, user_events, grid_size = JLD.load("coins_full_reverse.jld")["data"]
  observations = observations[1:7]
  user_events = user_events[1:7]
  
  pedro=false
  singlecell=true
  
  println("starting matrix construction")
  matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=singlecell, pedro=pedro, upd_func_space=6, multiple_traces=true)
  stop_times = map(i -> length(observations[i]) + (i == 1 ? 0 : sum(map(j -> length(observations[j]), 1:(i - 1)))), 1:(length(observations) - 1))
  user_events = vcat(map(events -> vcat(events..., nothing), user_events)...)[1:end-1]
  redundant_events_set = Set()
  global_event_vector_dict = Dict()

  println("starting generate_on_clauses_GLOBAL")
  solutions = generate_on_clauses_GLOBAL(model_name, false, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, stop_times=stop_times)
end


@timed begin 
  model_name = "magnets_1"
  sols = run_model("magnets_i", "heuristic", 1, 1, 1)

  # observations, user_events, grid_size = JLD.load("magnets_final.jld")["data"]
  # observations = observations[1]
  # user_events = user_events[1]
  
  # pedro=false
  # singlecell=false
  
  # matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=singlecell, pedro=pedro, upd_func_space=6, multiple_traces=false)
  # stop_times = []
  # redundant_events_set = Set()
  # global_event_vector_dict = Dict()
  # solutions = generate_on_clauses_GLOBAL(model_name, false, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, stop_times=stop_times)
end

@timed begin 
  model_name = "magnets_2"
  observations, user_events, grid_size = JLD.load("magnets_final.jld")["data"]
  observations = observations[1:2]
  user_events = user_events[1:2]
  
  observations_tuple = (observations, user_events, grid_size)
  sols = run_model("magnets", "heuristic", 2, 1, 1, multi_trace=true, observations_tup=observations_tuple)

  # pedro=false
  # singlecell=false
  
  # println("starting matrix construction")
  # matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=singlecell, pedro=pedro, upd_func_space=6, multiple_traces=true)
  # stop_times = map(i -> length(observations[i]) + (i == 1 ? 0 : sum(map(j -> length(observations[j]), 1:(i - 1)))), 1:(length(observations) - 1))
  # user_events = vcat(map(events -> vcat(events..., nothing), user_events)...)[1:end-1]
  # redundant_events_set = Set()
  # global_event_vector_dict = Dict()

  # println("starting generate_on_clauses_GLOBAL")
  # solutions = generate_on_clauses_GLOBAL(model_name, false, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, stop_times=stop_times)
end
