import Pkg; Pkg.add("Pickle")
using Autumn
include("test_synthesis.jl")

# function to be run on remote processes; 
# function do_work(jobs, results) # define work function everywhere
#   while true
#       param_option = take!(jobs)
#       # do work 
#       decomp, 
#       observation_tuple, 
#       event_vector_dict, 
#       redundant_events_set, 
#       algorithm, 
#       desired_per_matrix_solution_count, 
#       desired_solution_count, 
#       singlecell, 
#       time_based, 
#       z3_option, 
#       co_occurring_param, 
#       transition_param = param_option

#       result = @timed synthesize_program_given_decomp(decomp, 
#                                                       singlecell, 
#                                                       deepcopy(observation_tuple),
#                                                       deepcopy(event_vector_dict),
#                                                       deepcopy(redundant_events_set), 
#                                                       upd_func_spaces=[6], 
#                                                       time_based=time_based,
#                                                       z3_option=z3_option,
#                                                       desired_per_matrix_solution_count=desired_per_matrix_solution_count,
#                                                       desired_solution_count=desired_solution_count,
#                                                       algorithm=algorithm,
#                                                       )

#       put!(results, result)
#   end
# end

function run_pedro_model(model_name, state_synthesis_algorithm)
  observations, user_events, grid_size = generate_observations_pedro_interface(model_name)
  matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=true, pedro=true, upd_func_space=6)
  global_event_vector_dict = Dict()
  redundant_events_set = Set()
  solutions = generate_on_clauses_GLOBAL(string(model_name, "_apr"), matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, state_synthesis_algorithm=state_synthesis_algorithm)
end

function run_pedro_model_multi_trace(observations, old_user_events, state_synthesis_algorithm)
  stop_times = map(i -> length(observations[i]) + (i == 1 ? 0 : sum(map(j -> length(observations[j]), 1:(i - 1)))), 1:(length(observations) - 1))
  matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, old_user_events, grid_size, singlecell=true, pedro=true, upd_func_space=6, multiple_traces=true)
  global_event_vector_dict = Dict()
  redundant_events_set = Set()

  user_events = vcat(map(events -> vcat(events..., nothing), old_user_events)...)[1:end-1] # user_events formatted as single vector with nothing in between original vectors
  solutions = generate_on_clauses_GLOBAL(string(model_name, "_apr"), matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, state_synthesis_algorithm=state_synthesis_algorithm, stop_times=stop_times)
end

function run_model(model_name::String, algorithm, desired_per_matrix_solution_count, desired_solution_count; symmetry=false)
  # build desired directory structure
  date_string = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")
  directory_name = string("heuristic_final_results/results_$(date_string)")
  mkdir(directory_name)
  directory_name = string("heuristic_final_results/results_$(date_string)/", model_name)
  mkdir(directory_name)
  
  subdirectory_name = string(directory_name, "/", "per_matrix_count_$(desired_per_matrix_solution_count)_solution_count_$(desired_solution_count)")
  mkdir(subdirectory_name)

  # define synthesis parameter options 
  transition_param_vals = [false] # this option exists because of ambiguity in one model :( -- should make this a primitive 
  co_occurring_param_vals = [false] # [false, true]
  z3_option_vals = ["full"] # ["full", "partial"]
  time_based_vals = [false, true]
  singlecell_vals = [false, true]

  # initialize global variables
  found_enough = false

  observations, user_events, grid_size = generate_observations(model_name)
  observation_tuple = (observations, user_events, grid_size)

  singlecell_decomp = nothing # decomp_time_single.value 
  multicell_decomp = nothing # decomp_time_multi.value 

  singlecell_global_event_vector_dict = Dict()
  singlecell_redundant_events_set = Set()

  multicell_global_event_vector_dict = Dict()
  multicell_redundant_events_set = Set()

  total_time = 0 # decomp_time_single.time + decomp_time_multi.time

  all_sols = []

  # compute products over all the synthesis parameter options 
  param_options = vec(collect(Base.product(singlecell_vals, time_based_vals, z3_option_vals, co_occurring_param_vals, transition_param_vals)))

  for param_option in param_options
    # println("DO YOU SEE ME")
    # println("singlecell, time_based, z3_option, co_occurring_param, transition_param")
    # @show param_option 

    singlecell, time_based, z3_option, co_occurring_param, transition_param = param_option

    if singlecell
      if isnothing(singlecell_decomp)
        decomp_time_single = @timed singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=true, upd_func_space=6)
        singlecell_decomp = decomp_time_single.value 
        total_time += decomp_time_single.time
      end
    else
      if isnothing(multicell_decomp)
        decomp_time_multi = @timed singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=false, upd_func_space=6)
        multicell_decomp = decomp_time_multi.value 
        total_time += decomp_time_multi.time
      end
    end

    # timed_tuple = @timed synthesize_program(model_name, 
    #                                         singlecell=singlecell, 
    #                                         upd_func_spaces=[6], 
    #                                         time_based=time_based,
    #                                         z3_option=z3_option,
    #                                         desired_per_matrix_solution_count=desired_per_matrix_solution_count,
    #                                         desired_solution_count=desired_solution_count,
    #                                         algorithm="sketch_multi")


    timed_tuple = @timed synthesize_program_given_decomp(singlecell ? deepcopy(singlecell_decomp) : deepcopy(multicell_decomp), 
                                                          deepcopy(observation_tuple),
                                                          singlecell ? singlecell_global_event_vector_dict : multicell_global_event_vector_dict,
                                                          singlecell ? singlecell_redundant_events_set : multicell_redundant_events_set, 
                                                          upd_func_spaces=[6], 
                                                          time_based=time_based,
                                                          z3_option=z3_option,
                                                          desired_per_matrix_solution_count=desired_per_matrix_solution_count,
                                                          desired_solution_count=desired_solution_count,
                                                          algorithm=algorithm,
                                                          sketch_timeout=120,
                                                          symmetry=symmetry,
                                                          )
                      # try
                      # catch e 
                      #   (value=[], time=0)  
                      # end
    sols = timed_tuple.value
    
    # println("LOOK AT THIS")
    # @show sols
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
    if length(non_random_solutions) >= 1 
      found_enough = true 
      # println("FINAL TIME") 
      # @show total_time 

      open(string(subdirectory_name, "/final_time", ".txt"),"a") do io
        println(io, "-----------------------------------------")
        println(io, "FINAL TIME")
        println(io, string(total_time))
      end

      break
    end

    if total_time > 60 * 120
      break
    end

  end
  
  if !found_enough # length(all_sols) == 0 
    # co_occurring_param (Water Plug), transition_param (Disease)

    for time_based in [false, true] 
      for singlecell in [false, true] 
                        # @timed sols = synthesize_program(model_name, 
                        #                                   upd_func_spaces=[6], 
                        #                                   singlecell=singlecell, 
                        #                                   time_based=time_based,
                        #                                   z3_option="full",
                        #                                   sketch_timeout=60 * 120)

        timed_tuple = @timed synthesize_program_given_decomp(singlecell ? deepcopy(singlecell_decomp) : deepcopy(multicell_decomp), 
                                                             deepcopy(observation_tuple),
                                                             singlecell ? singlecell_global_event_vector_dict : multicell_global_event_vector_dict,
                                                             singlecell ? singlecell_redundant_events_set : multicell_redundant_events_set, 
                                                             upd_func_spaces=[6], 
                                                             time_based=time_based,
                                                             z3_option="full",
                                                             desired_per_matrix_solution_count=10000,
                                                             desired_solution_count=desired_solution_count,
                                                             algorithm=algorithm,
                                                             sketch_timeout=120 * 60,
                                                             symmetry=symmetry)
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
          # @show total_time 
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

# function run_all_models(algorithm, desired_per_matrix_solution_count, desired_solution_count)
#   # for model_name in model_names 
#   #   println(string("CURRENT MODEL:", model_name))
#   #   task = @async(run_model(model_name, desired_per_matrix_solution_count, desired_solution_count))  # run everything via myfunc()

#   #   # println("task is started: ", istaskstarted(task))
#   #   # println("Task is done: ", istaskdone(task))

#   #   total_time = 0
#   #   while !istaskdone(task) && total_time < 60*60*3 # 3 hours 
#   #     sleep(10)
#   #     total_time += 10
#   #   end

#   #   if !istaskdone(task)
#   #       # println("Killing task.")
#   #       @async(Base.throwto(task, DivideError()))
#   #   end

#   #   # println("all done with $(model_name).")
#   # end
#   models = [
#     # "particles", 
#     #  "ants", 
#     #  "chase",
#     #  "lights",
#     #  "ice",
#     #  "paint", 
#     #  "magnets_i",
#     #  "sokoban_i",
#     # "sand",
#     # "gravity_i", 
#     # "gravity_iii",
#     "gravity_iv",
#     # "disease", 
#     # "gravity_ii",
#     # # "space_invaders",
#     # "wind",
#     # "bullets", 
#     # "count_1",
#     # "count_2",
#     # "double_count_1",
#     # "water_plug",
#     # "mario",

#     # "count_3",
#     # "count_4",
#     # "double_count_2",
     
#     #  "grow",
#     #  "egg",
#     #  "double_count_3",
#     #  "green_light",
#     #  "
#      ]

#   for model_name in models
#     run_model(model_name, desired_per_matrix_solution_count, desired_solution_count)
#   end
# end

# # function run()
# #   # println("BEGIN RUN")
# #   for desired_per_matrix_solution_count in [5] # [1, 5]
# #     for desired_solution_count in [1]
# #       run_all_models(desired_per_matrix_solution_count, desired_solution_count)
# #     end
# #   end
# #   # println("END RUN")
# # end

# # global model_names = []

# # function hack()
# #   for model_name in global_model_names 
# #     # @show model_name
# #     global model_names = [model_name]
# #     run()
# #   end
# # end


# # model_name = ARGS[1]
# # x = @timed run_model(model_name, 5, 1)
# # save(string("DONE/DONE_$(model_name)_heuristic.jld"), model_name, x)
# # open("DONE/DONE_$(model_name)_TIME_heuristic.txt", "w") do io 
# #   println(io, x.time)
# # end