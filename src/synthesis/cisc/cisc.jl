import Pkg; Pkg.add("Pickle")
using Autumn
using JLD 
using Dates
include("functional_synthesis/full_synthesis.jl")

function run_model(model_name::String, algorithm, iteration=1, desired_per_matrix_solution_count=1, desired_solution_count=1; multi_trace=false, indices=[], observations_tup=[])
  run_id = string(model_name, "_", algorithm, "_", iteration)
  # build desired directory structure
  date_string = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")

  directory_name = string("./scratch")
  if !isdir(directory_name)
    mkdir(directory_name)
  end

  directory_name = string("scratch/heuristic_final_results")
  if !isdir(directory_name)
    mkdir(directory_name)
  end

  directory_name = string("scratch/heuristic_final_results/results_$(date_string)")
  if !isdir(directory_name)
    mkdir(directory_name)
  end

  directory_name = string("scratch/heuristic_final_results/results_$(date_string)/", model_name)
  if !isdir(directory_name)
    mkdir(directory_name)
  end

  subdirectory_name = string(directory_name, "/", "per_matrix_count_$(desired_per_matrix_solution_count)_solution_count_$(desired_solution_count)_iteration_$(iteration)")
  if !isdir(subdirectory_name)
    mkdir(subdirectory_name)
  end

  # define synthesis parameter options 
  random_param_vals = [false, true] # false, true
  transition_param_vals = [false] # this option exists because of ambiguity in one model :( -- should make this a primitive 
  co_occurring_param_vals = [false] # [false, true]
  z3_option_vals = ["partial", "full"] # ["partial", "full"]
  time_based_vals = [false, true] # false, true 
  singlecell_vals = [false, true] # false, true

  # initialize global variables
  found_enough = false

  if !multi_trace 
    observations, user_events, grid_size = generate_observations(model_name)
    observation_tuple = (observations, user_events, grid_size)
    old_user_events = user_events  
  else
    # files = filter(x -> occursin(".jld", x), readdir("multi_trace_data/$(model_name)"))
    # observation_tuples = []
    # for file in files 
    #   push!(observation_tuples, JLD.load("multi_trace_data/$(model_name)/$(file)")["data"])
    # end

    # if indices != []
    #   observation_tuples = map(i -> observation_tuples[i], indices)
    # end

    # observations = map(tup -> tup[1], observation_tuples)
    # user_events = map(tup -> tup[2], observation_tuples)
    # grid_size = observation_tuples[1][3]
    observation_tuple = observations_tup
    observations, user_events, grid_size = observation_tuple
    old_user_events = user_events
  end

  singlecell_decomp = nothing # decomp_time_single.value 
  multicell_decomp = nothing # decomp_time_multi.value 

  singlecell_global_event_vector_dict = Dict()
  singlecell_redundant_events_set = Set()

  multicell_global_event_vector_dict = Dict()
  multicell_redundant_events_set = Set()

  total_time = 0 # decomp_time_single.time + decomp_time_multi.time

  all_sols = []

  # compute products over all the synthesis parameter options 
  param_options = vec(collect(Base.product(singlecell_vals, time_based_vals, z3_option_vals, co_occurring_param_vals, transition_param_vals, random_param_vals)))

  for param_option in param_options
    println("DO YOU SEE ME")
    println("singlecell, time_based, z3_option, co_occurring_param, transition_param, random_param")
    @show param_option 

    singlecell, time_based, z3_option, co_occurring_param, transition_param, random_param = param_option

    user_events = old_user_events

    if singlecell
      if isnothing(singlecell_decomp)
        decomp_time_single = @timed singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=true, upd_func_space=6, multiple_traces=multi_trace)
        singlecell_decomp = decomp_time_single.value 
        total_time += decomp_time_single.time
      end
    else
      if isnothing(multicell_decomp)
        decomp_time_multi = @timed singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=false, upd_func_space=6, multiple_traces=multi_trace)
        multicell_decomp = decomp_time_multi.value 
        total_time += decomp_time_multi.time
      end
    end

    if multi_trace 
      user_events = vcat(map(events -> vcat(events..., nothing), old_user_events)...)[1:end-1]
      stop_times = map(i -> length(observations[i]) + (i == 1 ? 0 : sum(map(j -> length(observations[j]), 1:(i - 1)))), 1:(length(observations) - 1))
      observation_tuple = (observations, user_events, grid_size)
    else
      stop_times = []  
    end

    timed_tuple = @timed synthesize_program_given_decomp( run_id, 
                                                          random_param,
                                                          singlecell ? deepcopy(singlecell_decomp) : deepcopy(multicell_decomp), 
                                                          deepcopy(observation_tuple),
                                                          singlecell ? singlecell_global_event_vector_dict : multicell_global_event_vector_dict,
                                                          singlecell ? singlecell_redundant_events_set : multicell_redundant_events_set, 
                                                          upd_func_spaces=[6], 
                                                          time_based=time_based,
                                                          z3_option=z3_option,
                                                          desired_per_matrix_solution_count=desired_per_matrix_solution_count,
                                                          desired_solution_count=desired_solution_count,
                                                          algorithm=algorithm,
                                                          sketch_timeout=120, # 120
                                                          stop_times=stop_times
                                                          )
                      # try
                      # catch e 
                      #   (value=[], time=0)  
                      # end
    sols = timed_tuple.value
    
    # println("LOOK AT THIS")
    # # @show sols
    # write solution to file
    save(string(subdirectory_name, "/", string("transition_param_", transition_param, 
                                                "_co_occurring_", co_occurring_param, 
                                                "_time_based_", time_based, 
                                                "_z3_option_", z3_option, 
                                                "_singlecell_", singlecell, ".jld")), 
          String(model_name), 
          timed_tuple)
    open(string(subdirectory_name, "/program_strings_", string("transition_param_", transition_param, "_co_occurring_", co_occurring_param, "_time_based_", time_based, "_z3_option_", z3_option, "_singlecell_", singlecell), ".txt"),"a") do io
      println(io, "-----------------------------------------")
      println(io, string("transition_param_", transition_param, "_co_occurring_", co_occurring_param, "_time_based_", time_based, "_z3_option_", z3_option, "_time_based=", time_based, ", singlecell=", singlecell, "\n"))
      println(io, join(sols, "\n\n\n\n"))
    end
    push!(all_sols, sols...)
    total_time += timed_tuple.time
    
    non_random_solutions = filter(x -> !occursin("randomPositions", x) && (!occursin("uniformChoice", x) || occursin("uniformChoice (map", x)), all_sols)
    if (random_param && singlecell && length(all_sols) >= 1) || length(non_random_solutions) >= 1 
      found_enough = true 
      # println("FINAL TIME") 
      # # @show total_time 

      open(string(subdirectory_name, "/final_time", ".txt"),"a") do io
        println(io, "-----------------------------------------")
        println(io, "FINAL TIME")
        println(io, string(total_time))
      end

      break
    end

    # if total_time > 60 * 120
    #   break
    # end

  end
  
  if !found_enough # length(all_sols) == 0 
    # co_occurring_param (Water Plug), transition_param (Disease)

    for z3_option in ["partial", "full"] 
      for singlecell in [false, true] 
                        # @timed sols = synthesize_program(model_name, 
                        #                                   upd_func_spaces=[6], 
                        #                                   singlecell=singlecell, 
                        #                                   time_based=time_based,
                        #                                   z3_option="full",
                        #                                   sketch_timeout=60 * 120)

        timed_tuple = @timed synthesize_program_given_decomp(run_id,
                                                             false,
                                                             singlecell ? deepcopy(singlecell_decomp) : deepcopy(multicell_decomp), 
                                                             deepcopy(observation_tuple),
                                                             singlecell ? singlecell_global_event_vector_dict : multicell_global_event_vector_dict,
                                                             singlecell ? singlecell_redundant_events_set : multicell_redundant_events_set, 
                                                             upd_func_spaces=[6], 
                                                             time_based=false,
                                                             z3_option=z3_option,
                                                             desired_per_matrix_solution_count=10000,
                                                             desired_solution_count=desired_solution_count,
                                                             algorithm=algorithm,
                                                             sketch_timeout=0)
                      # try     
                      # catch e 
                      #   (value=[], time=0)
                      # end

        sols = timed_tuple.value
        total_time += timed_tuple.time 
        subdirectory_name = string(directory_name, "/", "per_matrix_count_$(desired_per_matrix_solution_count)_solution_count_$(desired_solution_count)")
        save(string(subdirectory_name, "/", string("EXTRA_singlecell_", singlecell, "_time_based_", time_based, "_z3_option_", "full", "_co_occurring_", "false", "_transition_param_", "false", ".jld")), String(model_name), timed_tuple)
        open(string(subdirectory_name, "/program_strings.txt"),"a") do io
          # println("-----------------------------------------")
          println(io, string("EXTRA: time_based=", time_based, ", singlecell=", singlecell, "\n"))
          println(io, join(sols, "\n\n\n\n"))
        end
        push!(all_sols, sols...)

        non_random_solutions = filter(x -> !occursin("randomPositions", x) && !occursin("uniformChoice", x), all_sols)
        if length(non_random_solutions) >= 1 
          found_enough = true 
          # println("FINAL TIME") 
          # # @show total_time 
          break
        end
  
      end

      if found_enough 
        open(string(subdirectory_name, "/final_time", ".txt"),"a") do io
          println(io, "-----------------------------------------")
          println(io, "FINAL TIME")
          println(io, string(total_time))
        end

        break
      end
    
    end

  end

  if !found_enough 
    open(string(subdirectory_name, "/final_time", ".txt"),"a") do io
      println(io, "-----------------------------------------")
      println(io, "FINAL TIME")
      println(io, string(total_time))
    end

  end

  all_sols
end

function run_model_multi_trace(model_name, singlecell=false, pedro=false; indices=[])
  model_folders = readdir("multi_trace_data")
  if model_name in model_folders
    files = filter(x -> occursin(".jld", x), readdir("multi_trace_data/$(model_name)"))
    observation_tuples = []
    for file in files 
      push!(observation_tuples, JLD.load("multi_trace_data/$(model_name)/$(file)")["data"])
    end

    if indices != []
      observation_tuples = map(i -> observation_tuples[i], indices)
    end

    observations = map(tup -> tup[1], observation_tuples)
    old_user_events = map(tup -> tup[2], observation_tuples)

    matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, old_user_events, grid_size, singlecell=singlecell, pedro=pedro, upd_func_space=6, multiple_traces=true)

    object_types, object_mapping, background, grid_size = object_decomposition

    user_events = vcat(map(events -> vcat(events..., nothing), old_user_events)...)[1:end-1]
    stop_times = map(i -> length(observations[i]) + (i == 1 ? 0 : sum(map(j -> length(observations[j]), 1:(i - 1)))), 1:(length(observations) - 1))

    global_event_vector_dict = Dict()
    redundant_events_set = Set()

    solutions = generate_on_clauses_GLOBAL(model_name, false, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, stop_times=stop_times)
  else
    solutions = []
  end
  solutions
end