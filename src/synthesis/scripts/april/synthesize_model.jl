include("src/Autumn/generativemodel/final_evaluation.jl")

model_name = ARGS[1]

@timed begin 
  observations, user_events, grid_size = generate_observations_pedro_interface(model_name)
  matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=true, pedro=true, upd_func_space=6)
  global_event_vector_dict = Dict()
  redundant_events_set = Set()
  solutions = generate_on_clauses_GLOBAL(string(model_name, "_apr"), matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, state_synthesis_algorithm="heuristic")
  
  program_strings = []
  for solution in solutions 
    if solution[1] != [] 
      on_clauses, new_object_decomposition, global_var_dict = solution
      @show on_clauses 
      
      program = full_program_given_on_clauses(on_clauses, new_object_decomposition, global_var_dict, grid_size, matrix)
      push!(program_strings, program)
    end
  end

  results_directory = "april_results/$(model_name)"
  if !isdir(results_directory)
    mkdir(results_directory)
  end

  open("$(results_directory)/output_program.txt", "w+") do io
    println(io, join(program_strings, "\n"))
  end

end