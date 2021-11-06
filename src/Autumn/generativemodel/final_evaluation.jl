include("test_synthesis.jl")

global_model_names = [
              "particles", 
               "ants", 
               "chase",
               "lights",
               "ice",
               "paint", 
               "magnets_i",
               "sokoban_i",
               "wind", 
               "sand",
               "bullets",
               "gravity_i", 
               "gravity_iii",
               "disease", 
               "gravity_ii",
               "mario",
               "space_invaders",
               "water_plug",
               "count_1",
               "count_2",
               "count_3",
               "count_4",
               "double_count_1",
               "double_count_2",
               
              #  "grow",
              #  "egg",
              #  "double_count_3",
              #  "green_light",
              #  "
               ]

function run_model(model_name::String, desired_per_matrix_solution_count, desired_solution_count)
  date_string = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")
  directory_name = string("final_results/results_$(date_string)")
  mkdir(directory_name)
  directory_name = string("final_results/results_$(date_string)/", model_name)
  mkdir(directory_name)
  
  subdirectory_name = string(directory_name, "/", "per_matrix_count_$(desired_per_matrix_solution_count)_solution_count_$(desired_solution_count)")
  mkdir(subdirectory_name)

  transition_param_vals = [false] # [false, true]
  co_occurring_param_vals = [false, true] # [false, true]
  z3_option_vals = ["full"] # ["full", "partial"]
  time_based_vals = [false, true]
  singlecell_vals = [true, true]

  found_enough = false

  observations, user_events, grid_size = generate_observations(model_name)
  observation_tuple = (observations, user_events, grid_size)
  decomp_time_single = @timed singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=true, upd_func_space=6)
  decomp_time_multi = @timed singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=false, upd_func_space=6)

  singlecell_decomp = decomp_time_single.value 
  multicell_decomp = decomp_time_multi.value 

  singlecell_global_event_vector_dict = Dict()
  singlecell_redundant_events_set = Set()

  multicell_global_event_vector_dict = Dict()
  multicell_redundant_events_set = Set()

  total_time = decomp_time_single.time + decomp_time_multi.time

  all_sols = []
  for transition_param in transition_param_vals # this option exists because of ambiguity in one model :( -- should make this a primitive 
    for co_occurring_param in co_occurring_param_vals
      for z3_option in z3_option_vals # this option exists because of ambiguity in one model :( 
        for time_based in time_based_vals 
          for singlecell in singlecell_vals
            
            # timed_tuple = @timed synthesize_program(model_name, 
            #                                         singlecell=singlecell, 
            #                                         upd_func_spaces=[6], 
            #                                         time_based=time_based,
            #                                         z3_option=z3_option,
            #                                         desired_per_matrix_solution_count=desired_per_matrix_solution_count,
            #                                         desired_solution_count=desired_solution_count)

        
            timed_tuple = @timed synthesize_program_given_decomp(singlecell ? singlecell_decomp : multicell_decomp, 
                                                                 observation_tuple,
                                                                 singlecell ? singlecell_global_event_vector_dict : multicell_global_event_vector_dict,
                                                                 singlecell ? singlecell_redundant_events_set : multicell_redundant_events_set, 
                                                                 upd_func_spaces=[6], 
                                                                 time_based=time_based,
                                                                 z3_option=z3_option,
                                                                 desired_per_matrix_solution_count=desired_per_matrix_solution_count,
                                                                 desired_solution_count=desired_solution_count)
            
            sols = timed_tuple.value
            
            # write solution to file
            save(string(subdirectory_name, "/", string("transition_param_", transition_param, 
                                                       "_co_occurring_", co_occurring_param, 
                                                       "_time_based_", time_based, 
                                                       "_z3_option_", z3_option, 
                                                       "_singlecell_", singlecell, ".jld")), 
                 String(model_name), 
                 timed_tuple)
            open(string(subdirectory_name, "/program_strings_", string("transition_param_", transition_param, "_co_occurring_", co_occurring_param, "_time_based_", time_based, "_z3_option_", z3_option, "_singlecell_", singlecell), ".txt"),"a") do io
              println("-----------------------------------------")
              println(io, string("transition_param_", transition_param, "_co_occurring_", co_occurring_param, "_time_based_", time_based, "_z3_option_", z3_option, "_time_based=", time_based, ", singlecell=", singlecell, "\n"))
              println(io, join(sols, "\n\n\n\n"))
            end
            push!(all_sols, sols...)
            total_time += timed_tuple.time
            
            non_random_solutions = filter(x -> !occursin("randomPositions", x) && !occursin("uniformChoice", x), all_sols)
            if length(non_random_solutions) >= 1 
              found_enough = true 
              println("FINAL TIME") 
              @show total_time 
              break
            end
          end
    
          if found_enough 
            break 
          end
    
        end
    
        if found_enough 
          break 
        end

      end

      if found_enough 
        break 
      end
      
    end

    open(string(subdirectory_name, "/final_time", ".txt"),"a") do io
      println(io, "-----------------------------------------")
      println(io, "FINAL TIME")
      println(io, string(total_time))
    end

  end

  if length(all_sols) == 0 
    # co_occurring_param (Water Plug), transition_param (Disease)

    for time_based in time_based_vals 
      for singlecell in singlecell_vals 
        timed_tuple = try
                        @timed sols = synthesize_program(model_name, 
                                                          upd_func_spaces=[6], 
                                                          singlecell=singlecell, 
                                                          time_based=time_based,
                                                          z3_option="full",
                                                          desired_per_matrix_solution_count=10000)
                      catch e
                        e                      
                      end
        sols = timed_tuple.value
        subdirectory_name = string(directory_name, "/", "per_matrix_count_$(desired_per_matrix_solution_count)_solution_count_$(desired_solution_count)")
        save(string(subdirectory_name, "/", string("EXTRA_singlecell_", singlecell, "_time_based_", time_based, "_z3_option_", "full", "_co_occurring_", "false", "_transition_param_", "false", ".jld")), String(model_name), timed_tuple)
        open(string(subdirectory_name, "/program_strings.txt"),"a") do io
          println("-----------------------------------------")
          println(io, string("EXTRA: time_based=", time_based, ", singlecell=", singlecell, "\n"))
          println(io, join(sols, "\n\n\n\n"))
        end
        push!(all_sols, sols...)
  
      end
    
    end

  end
  all_sols
end

function run_all_models(desired_per_matrix_solution_count, desired_solution_count)
  # for model_name in model_names 
  #   println(string("CURRENT MODEL:", model_name))
  #   task = @async(run_model(model_name, desired_per_matrix_solution_count, desired_solution_count))  # run everything via myfunc()

  #   println("task is started: ", istaskstarted(task))
  #   println("Task is done: ", istaskdone(task))

  #   total_time = 0
  #   while !istaskdone(task) && total_time < 60*60*3 # 3 hours 
  #     sleep(10)
  #     total_time += 10
  #   end

  #   if !istaskdone(task)
  #       println("Killing task.")
  #       @async(Base.throwto(task, DivideError()))
  #   end

  #   println("all done with $(model_name).")
  # end
  for model_name in global_model_names 
    run_model(model_name, desired_per_matrix_solution_count, desired_solution_count)
  end
end

function run()
  println("BEGIN RUN")
  for desired_per_matrix_solution_count in [5] # [1, 5]
    for desired_solution_count in [1]
      run_all_models(desired_per_matrix_solution_count, desired_solution_count)
    end
  end
  println("END RUN")
end

global model_names = []

function hack()
  for model_name in global_model_names 
    @show model_name
    global model_names = [model_name]
    run()
  end
end

""" 
TODO:
- try/catch handling: DONE 
- global timeout for each model (2 hours?): DONE
- add params for co_occurring_param and transition_param: DONE 

- add additional parenthetical options to Z3 full: DONE 
- make custom observations sequences for random models
- generalize remaining events in event space (Mario, etc.), i.e. remove compound events: DONE 
- test final_evaluation script on small example sets 
- run final_evaluation script 

list of random models:
- particles: DONE 
- ants 
- chase 
- space invaders -- can skip though because this usually works off the bat (DONE)


"""