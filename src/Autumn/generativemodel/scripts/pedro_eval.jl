include("../final_evaluation.jl")

model_name = ARGS[1]
algorithm = ARGS[2]
curr_date = ARGS[3]
iteration = ARGS[4]


directory_name = "PEDRO_FINAL_RESULTS/$(curr_date)"
if !isdir(directory_name)
  mkdir(directory_name)
end

model_subdirectory_name = "$(directory_name)/$(model_name)"
if !isdir(model_subdirectory_name)
  mkdir(model_subdirectory_name)
end

alg_subdirectory_name = "$(model_subdirectory_name)/$(algorithm)"
if !isdir(alg_subdirectory_name)
  mkdir(alg_subdirectory_name)
end
 

x = @timed begin
  pedro_interface_output_folder = "/scratch/riadas/EMPA_Data_Collection_Interface/traces_may7"
  observations, user_events, grid_size = generate_observations_pedro_interface(model_name)

  singlecell = true 
  pedro = true

  if model_name == "closing_gates"
    singlecell = false
  elseif model_name == "MyAliens"
    observations = observations[1:127]
    user_events = user_events[1:126]
  elseif model_name = "Survivezombies"
    observations = observations[1:end-1]
    user_events = user_events[1:end-1]
  elseif model_name == "Plaqueattack"
    observations = map(obs -> filter(c -> c.color != "white", obs), observations)
  elseif model_name == "Watergame"
    observations = map(obs -> filter(c -> c.color != "white", obs), observations)
  end

  matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=singlecell, pedro=pedro, upd_func_space=6)
  global_event_vector_dict = Dict()
  redundant_events_set = Set()
  solutions = generate_on_clauses_GLOBAL(string(model_name, "_apr"), matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, state_synthesis_algorithm=algorithm, symmetry=true)
                                                                                                                                       
                                                                                                                                                                                                                                                                                                                                                                                                                                            program_strings = []
  for solution in solutions
    if solution[1] != []
      on_clauses, new_object_decomposition, global_var_dict = solution
      @show on_clauses

      program = full_program_given_on_clauses(on_clauses, new_object_decomposition, global_var_dict, grid_size, matrix)
      push!(program_strings, program)
    end
  end

  results_directory = "october_final_results/$(model_name)"
  if !isdir(results_directory)
      mkdir(results_directory)
  end

  open("$(results_directory)/output_program.txt", "w+") do io
    println(io, join(program_strings, "\n"))
  end

  program_strings[1]
end

save(string("$(alg_subdirectory_name)/full_data_$(iteration).jld"), model_name, x)

# write final time to time text file 
open("$(alg_subdirectory_name)/times.txt", "a") do io 
  println(io, x.time)
end

# write final program string to program_strings text file 
open("$(alg_subdirectory_name)/program_strings.txt", "a") do io 
  println(io, join(x.value, "\n\n\n\n"))
  println(io, "\n\n\n\n")
end