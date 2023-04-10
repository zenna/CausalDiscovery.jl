import Pkg; Pkg.add("Pickle")
using Autumn
include("functional_synthesis/full_synthesis.jl")

function run_pedro_model(model_name; state_synthesis_algorithm="heuristic", multi_trace=false)
  if multi_trace 
    folder = string(pedro_interface_output_folder, "/", model_name)
    if !isdir(folder)
      files = reverse(sort(filter(x -> occursin(".json", x), readdir(folder))))
      l = [] 
      for i in 1:length(files)
        push!(l, generate_observations_pedro_interface(model_name, i))
      end
      observations = map(tup -> tup[1], l)
      user_events = map(tup -> tup[2], l)
      grid_size = l[1][3]
      return run_pedro_model_multi_trace(observations, user_events, grid_size, state_synthesis_algorithm)
    else
      return ""
    end
  else
    return run_pedro_model_single_trace(model_name, state_synthesis_algorithm)
  end
end

function run_model(model_name, state_synthesis_algorithm)
  run_pedro_model_single_trace(model_name, state_synthesis_algorithm)
end

function run_pedro_model_single_trace(model_name, state_synthesis_algorithm)
  
  if model_name == "Explore_Exploit"
    global pedro_interface_output_folder = "evaluation/empa/data/traces_may7"
  elseif model_name in ["Helper2", "Lemmings_small_take3", "Lemmings_small_take4", "Watergame2", "Relational_end", "Lemmings_small_take2", "Lemmings_small", "closing_gates5", "Sokoban2", "Butterflies2", "Antagonist", "Bait", "closing_gates", "Helper", "Jaws", "Plaqueattack", "Relational", "Sokoban", "Watergame", "Lemmings2", "Lemmings"]
    global pedro_interface_output_folder = "evaluation/empa/data/october_traces_new"
  else
    global pedro_interface_output_folder = "evaluation/empa/data/new_traces_fixed"
  end

  # pedro_interface_output_folder = "/scratch/riadas/EMPA_Data_Collection_Interface/new_traces_fixed" # new_traces_fixed  traces_may7
  observations, user_events, grid_size = generate_observations_pedro_interface(model_name, 1)

  @show pedro_interface_output_folder
  @show length(observations)

  singlecell = true 
  pedro = true

  if model_name == "closing_gates" || model_name == "closing_gates5"
    singlecell = false
  elseif model_name == "MyAliens"
    observations = observations[1:127]
    user_events = user_events[1:126]
  elseif model_name == "Survivezombies"
    observations = observations[1:end-1]
    user_events = user_events[1:end-1]
  elseif model_name == "Plaqueattack"
    observations = map(obs -> filter(c -> c.color != "white", obs), observations)
  elseif model_name == "Watergame"
    observations = map(obs -> filter(c -> c.color != "white", obs), observations)
  elseif model_name == "Lemmings2"
    observations, user_events, grid_size = generate_observations_pedro_interface(model_name, 1)
  elseif model_name == "Sokoban2"
    observations, user_events, grid_size = generate_observations_pedro_interface(model_name, 2)
  elseif model_name == "Lemmings_small"
    user_events[189] = "right"
    user_events[203] = "right"
  elseif model_name == "Lemmings_small_take3"
    observations, user_events, grid_size = generate_observations_pedro_interface(model_name, 2)  
  elseif model_name == "Lemmings_small_take4"
    observations, user_events, grid_size = generate_observations_pedro_interface(model_name, 1)  
  elseif model_name == "Watergame2"
    observations, user_events, grid_size = generate_observations_pedro_interface(model_name, 2)
    observations = map(obs -> filter(c -> c.color != "white", obs), observations)
  end

  matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=true, pedro=true, upd_func_space=6)
  global_event_vector_dict = Dict()
  redundant_events_set = Set()
  solutions = generate_on_clauses_GLOBAL(string(model_name, "_apr"), matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, state_synthesis_algorithm=state_synthesis_algorithm, symmetry=true)

  program_strings = []

  for solution in solutions 
    if solution[1] != [] 
      on_clauses, new_object_decomposition, global_var_dict = solution
      @show on_clauses 
      
      program = full_program_given_on_clauses(on_clauses, new_object_decomposition, global_var_dict, grid_size, matrix, unformatted_matrix, user_events)
      push!(program_strings, program)
    end
  end

  program_strings
end

function run_pedro_model_multi_trace(observations, old_user_events, grid_size, state_synthesis_algorithm)
  stop_times = map(i -> length(observations[i]) + (i == 1 ? 0 : sum(map(j -> length(observations[j]), 1:(i - 1)))), 1:(length(observations) - 1))
  matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, old_user_events, grid_size, singlecell=true, pedro=true, upd_func_space=6, multiple_traces=true)
  global_event_vector_dict = Dict()
  redundant_events_set = Set()

  user_events = vcat(map(events -> vcat(events..., nothing), old_user_events)...)[1:end-1] # user_events formatted as single vector with nothing in between original vectors
  solutions = generate_on_clauses_GLOBAL(string(model_name, "_apr"), matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, state_synthesis_algorithm=state_synthesis_algorithm, stop_times=stop_times)
end