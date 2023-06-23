include("singletimestepsolution.jl");
include("../automata_synthesis/heuristic_automata_synthesis.jl")
include("../automata_synthesis/sketch_automata_synthesis.jl")
include("../automata_synthesis/sketch_multi_automata_synthesis.jl")

function generate_observations(model_name::String)
  JLD.load("test/cisc/data/observed/single_trace_observations/$(model_name).jld", "data")
end

function synthesize_program_given_decomp(run_id, random, decomp, observation_tuple, global_event_vector_dict, redundant_events_set; 
                                          pedro = false,
                                          desired_solution_count = 1, # 2
                                          desired_per_matrix_solution_count = 1, # 5
                                          interval_painting_param = false, 
                                          upd_func_spaces = [1],
                                          z3_option = "none",
                                          time_based=false,
                                          co_occurring_param=false, 
                                          transition_param=false,
                                          algorithm="heuristic",
                                          sketch_timeout=0,
                                          stop_times=[]) 

  @show run_id
  program_strings = []

  # reset global_event_vector_dict and redundant_events_set for each new context:
  # remove events dealing with global or object-specific state
  for event in keys(global_event_vector_dict)
    if occursin("globalVar", event) || occursin("field1", event)
      delete!(global_event_vector_dict, event)
    end
  end

  for event in redundant_events_set 
    if occursin("globalVar", event) || occursin("field1", event)
      delete!(redundant_events_set, event)
    end
  end
  observations, user_events, grid_size = observation_tuple                               
  matrix, unformatted_matrix, object_decomposition, prev_used_rules = decomp                                        

  if algorithm == "heuristic"
    solutions = generate_on_clauses_GLOBAL(run_id, random, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, desired_solution_count, desired_per_matrix_solution_count, interval_painting_param, false, z3_option, time_based, 0, sketch_timeout, co_occurring_param, transition_param, stop_times=stop_times)
  elseif algorithm == "sketch_single"
    solutions = generate_on_clauses_SKETCH_SINGLE(run_id, random, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, desired_solution_count, desired_per_matrix_solution_count, interval_painting_param, z3_option, time_based, 0, sketch_timeout, co_occurring_param, transition_param, stop_times=stop_times)
  elseif algorithm == "sketch_multi"
    solutions = generate_on_clauses_SKETCH_MULTI(run_id, random, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, desired_solution_count, desired_per_matrix_solution_count, interval_painting_param, z3_option, time_based, 0, sketch_timeout, co_occurring_param, transition_param, stop_times=stop_times)
  else 
    error("algorithm $(algorithm) does not exist")
  end

  for solution in solutions 
    if solution[1] != [] 
      on_clauses, new_object_decomposition, global_var_dict = solution
      # # @show on_clauses 
      
      program = full_program_given_on_clauses(on_clauses, new_object_decomposition, global_var_dict, grid_size, matrix)
      push!(program_strings, program)
    end
  end
  program_strings                              
end

function synthesize_program(model_name::String; 
                            singlecell = false,
                            pedro = false,
                            desired_solution_count = 1, # 2
                            desired_per_matrix_solution_count = 1, # 5
                            interval_painting_param = false, 
                            upd_func_spaces = [1],
                            z3_option = "none",
                            time_based=false,
                            co_occurring_param=false, 
                            transition_param=false,
                            algorithm="heuristic",
                            sketch_timeout=0,
                            )
  # println(string("CURRENTLY WORKING ON: ", model_name))
  
  run_id = string(model_name, "_", algorithm)

  if pedro 
    observations, user_events, grid_size = generate_observations_pedro(model_name)
  else
    observations, user_events, grid_size = generate_observations(model_name)
  end

  # # @show (observations, user_events, grid_size)

  program_strings = []
  global_event_vector_dict = Dict()
  redundant_events_set = Set()
  for upd_func_space in upd_func_spaces # 1, 2, 3 
    matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=singlecell, pedro=pedro, upd_func_space=upd_func_space)
    # generate_on_clauses_GLOBAL
    # generate_on_clauses
    # solutions = generate_on_clauses_SKETCH_SINGLE(matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, desired_solution_count, desired_per_matrix_solution_count, interval_painting_param, z3_option, time_based, 0, 0, co_occurring_param, transition_param)
    #                                            matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size=16, desired_solution_count=1, desired_per_matrix_solution_count=1, interval_painting_param=false, z3_option="none", time_based=false, z3_timeout=0, sketch_timeout=0
    # solutions = generate_on_clauses(matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, desired_solution_count, desired_per_matrix_solution_count, interval_painting_param, z3_option, time_based) z3_option="none", time_based=false, z3_timeout=0, sketch_timeout=0, co_occurring_param=false, transition_param=false
    # solutions = generate_on_clauses_GLOBAL(matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, desired_solution_count, desired_per_matrix_solution_count, interval_painting_param, false, z3_option, time_based, 0, 0, co_occurring_param, transition_param)
    # solutions = generate_on_clauses_SKETCH_MULTI(matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, desired_solution_count, desired_per_matrix_solution_count, interval_painting_param, z3_option, time_based, 0, 0, co_occurring_param, transition_param)
    #                                            matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size=16, desired_solution_count=1, desired_per_matrix_solution_count=1, interval_painting_param=false, z3_option="none", time_based=false, z3_timeout=0, sketch_timeout=0, co_occurring_param=false, transition_param=false
    
    if algorithm == "heuristic"
      solutions = generate_on_clauses_GLOBAL(run_id, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, desired_solution_count, desired_per_matrix_solution_count, interval_painting_param, false, z3_option, time_based, 0, sketch_timeout, co_occurring_param, transition_param)
    elseif algorithm == "sketch_single"
      solutions = generate_on_clauses_SKETCH_SINGLE(run_id, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, desired_solution_count, desired_per_matrix_solution_count, interval_painting_param, z3_option, time_based, 0, sketch_timeout, co_occurring_param, transition_param)
    elseif algorithm == "sketch_multi"
      solutions = generate_on_clauses_SKETCH_MULTI(run_id, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, desired_solution_count, desired_per_matrix_solution_count, interval_painting_param, z3_option, time_based, 0, sketch_timeout, co_occurring_param, transition_param)
    else 
      error("algorithm $(algorithm) does not exist")
    end
    # # @show solutions
    for solution in solutions 
      if solution[1] != [] 
        on_clauses, new_object_decomposition, global_var_dict = solution
        # # @show on_clauses 
        
        program = full_program_given_on_clauses(on_clauses, new_object_decomposition, global_var_dict, grid_size, matrix)
        push!(program_strings, program)
      end
    end
    
    # if length(program_strings) >= desired_solution_count
    #   break
    # end    
  end
  
  # open("/Users/riadas/Documents/urop/CausalDiscovery.jl/src/synthesis/cisc/workshop/$(model_name).txt","w") do io
  #   if model_name != "ants" 
  #     println(io, program_strings[1])
  #   else
  #     println(io, program_strings[2])
  #   end
  # end

  # open("/Users/riadas/Documents/urop/CausalDiscovery.jl/src/synthesis/cisc/conference/$(model_name).txt","a") do io
  #   println(io, string("BEGIN UPDATE FUNC SPACE: ", upd_func_spaces[1], "\n\n\n"))
  #   for program_string in program_strings
  #     println(io, program_string)
  #     println(io, "\n\n\n")
  #   end
  #   println(io, "END UPDATE FUNC SPACE: $(upd_func_spaces[1]) \n\n\n")
  # end

  program_strings
end