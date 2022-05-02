include("singletimestepsolution.jl");
include("global_heuristic_automata_synthesis.jl")
include("sketch_automata_synthesis.jl")
include("sketch_multi_automata_synthesis.jl")
function workshop_evaluation() 
  sols = synthesize_program("wind", singlecell=false, interval_painting_param=true, upd_func_spaces=[1])
  sols = synthesize_program("disease", singlecell=false, upd_func_spaces=[2]) # remove lines 515, 516, 518, 519
  sols = synthesize_program("particles", singlecell=true, upd_func_spaces=[1])
  sols = synthesize_program("chase", singlecell=true, upd_func_spaces=[5])
  sols = synthesize_program("lights", singlecell=true, upd_func_spaces=[5])
  sols = synthesize_program("ants", singlecell=true, desired_solution_count=2, upd_func_spaces=[5]) # take second solution (random)
  sols = synthesize_program("ice", singlecell=false, desired_solution_count=1, upd_func_spaces=[3]) # remove "(== (% (prev time) 4) 2)"
  sols = synthesize_program("space_invaders", singlecell=true, upd_func_spaces=[1]) # no bullet intersection in obs. seq.
  sols = synthesize_program("mario", singlecell=false, desired_per_matrix_solution_count=5, upd_func_spaces=[4]) # first out of 4 sols
  sols = synthesize_program("paint", singlecell=false, desired_solution_count=1, upd_func_spaces=[1])
  sols = synthesize_program("water_plug", singlecell=true, desired_solution_count=1, upd_func_spaces=[1]) # add "|"-based transition events to event space
  sols = synthesize_program("sokoban_i", singlecell=true, desired_solution_count=1, upd_func_spaces=[1])
  sols = synthesize_program("magnets_i", singlecell=false, desired_solution_count=1, upd_func_spaces=[1])
  sols = synthesize_program("gravity_i", singlecell=false, desired_solution_count=1, upd_func_spaces=[2])
  sols = synthesize_program("gravity_ii", singlecell=false, desired_solution_count=1, upd_func_spaces=[2]) # add special case, remove line 477 + single.jl line 1929 
  # grow: not including
end

# sols = synthesize_program("wind", singlecell=false, interval_painting_param=true, upd_func_spaces=[1])
# sols = synthesize_program("disease", singlecell=false, upd_func_spaces=[2]) # remove lines 515, 516, 518, 519
# sols = synthesize_program("particles", singlecell=true, upd_func_spaces=[1])
# sols = synthesize_program("chase", singlecell=true, upd_func_spaces=[5]) # TIME-BASED
# sols = synthesize_program("lights", singlecell=true, upd_func_spaces=[5])
# sols = synthesize_program("ants", singlecell=true, desired_solution_count=2, upd_func_spaces=[5]) # take second solution (random)
# sols = synthesize_program("ice", singlecell=false, desired_solution_count=1, upd_func_spaces=[3]) # remove "(== (% (prev time) 4) 2)"
# sols = synthesize_program("space_invaders", singlecell=true, upd_func_spaces=[1]) YAY # TIME-BASED
# sols = synthesize_program("mario", singlecell=false, desired_per_matrix_solution_count=5, upd_func_spaces=[4]) # first out of 4 sols
# sols = synthesize_program("paint", singlecell=false, desired_solution_count=1, upd_func_spaces=[1])
# sols = synthesize_program("water_plug", singlecell=true, desired_solution_count=1, upd_func_spaces=[6]) # add "|"-based transition events to event space
# sols = synthesize_program("sokoban_i", singlecell=true, desired_solution_count=1, upd_func_spaces=[1]) 
# sols = synthesize_program("magnets_i", singlecell=false, desired_solution_count=1, upd_func_spaces=[1]) YAY
# sols = synthesize_program("gravity_i", singlecell=false, desired_solution_count=1, upd_func_spaces=[2])
# sols = synthesize_program("gravity_ii", singlecell=false, desired_solution_count=1, upd_func_spaces=[2]) # add special case


function conf_evaluation() 
  # for upd_func_space in [1,2,3,4,5,6]
  #   sols = synthesize_program("wind", singlecell=false, interval_painting_param=true, upd_func_spaces=[upd_func_space], time_based=true)
  # end

  # for upd_func_space in [1,2,3,4,5,6]
  #   sols = synthesize_program("disease", singlecell=false, upd_func_spaces=[upd_func_space]) # remove lines 515, 516, 518, 519
  # end

  # for upd_func_space in [1,2,3,4,5,6]
  #   sols = synthesize_program("particles", singlecell=true, upd_func_spaces=[upd_func_space])
  # end

  for upd_func_space in [1,2,3,4,5,6]
    sols = synthesize_program("chase", singlecell=true, upd_func_spaces=[upd_func_space], time_based=true) # TIME-BASED
  end

  for upd_func_space in [1,2,3,4,5,6]
    sols = synthesize_program("lights", singlecell=true, upd_func_spaces=[upd_func_space])
  end

  for upd_func_space in [1,2,3,4,5,6]
    sols = synthesize_program("ants", singlecell=true, desired_solution_count=2, upd_func_spaces=[upd_func_space]) # take second solution (random)
  end

  for upd_func_space in [1,2,3,4,5,6]
    sols = synthesize_program("ice", singlecell=false, desired_solution_count=1, upd_func_spaces=[upd_func_space]) # remove "(== (% (prev time) 4) 2)"
  end

  for upd_func_space in [1,2,3,4,5,6]
    sols = synthesize_program("space_invaders", singlecell=true, upd_func_spaces=[upd_func_space], time_based=true) # YAY # TIME-BASED
  end

  for upd_func_space in [1,2,3,4,5,6]
    sols = synthesize_program("mario", singlecell=false, desired_per_matrix_solution_count=5, upd_func_spaces=[upd_func_space]) # first out of 4 sols
  end

  for upd_func_space in [1,2,3,4,5,6]
    sols = synthesize_program("paint", singlecell=false, desired_solution_count=1, upd_func_spaces=[upd_func_space])
  end

  # for upd_func_space in [1,2,3,4,5,6]
  #   sols = synthesize_program("water_plug", singlecell=true, desired_solution_count=1, upd_func_spaces=[upd_func_space]) # add "|"-based transition events to event space
  # end

  for upd_func_space in [1,2,3,4,5,6]
    sols = synthesize_program("sokoban_i", singlecell=true, desired_solution_count=1, upd_func_spaces=[upd_func_space]) 
  end

  for upd_func_space in [1,2,3,4,5,6]
    sols = synthesize_program("magnets_i", singlecell=false, desired_solution_count=1, upd_func_spaces=[upd_func_space]) # YAY
  end

  for upd_func_space in [1,2,3,4,5,6]
    sols = synthesize_program("gravity_i", singlecell=false, desired_solution_count=1, upd_func_spaces=[upd_func_space])
  end

  for upd_func_space in [1,2,3,4,5,6]
    sols = synthesize_program("gravity_ii", singlecell=false, desired_solution_count=1, upd_func_spaces=[upd_func_space]) # add special case
  end

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
                                          sketch_timeout=0) 

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
    solutions = generate_on_clauses_GLOBAL(run_id, random, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, desired_solution_count, desired_per_matrix_solution_count, interval_painting_param, false, z3_option, time_based, 0, sketch_timeout, co_occurring_param, transition_param)
  elseif algorithm == "sketch_single"
    solutions = generate_on_clauses_SKETCH_SINGLE(run_id, random, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, desired_solution_count, desired_per_matrix_solution_count, interval_painting_param, z3_option, time_based, 0, sketch_timeout, co_occurring_param, transition_param)
  elseif algorithm == "sketch_multi"
    solutions = generate_on_clauses_SKETCH_MULTI(run_id, random, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size, desired_solution_count, desired_per_matrix_solution_count, interval_painting_param, z3_option, time_based, 0, sketch_timeout, co_occurring_param, transition_param)
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
  
  # open("/Users/riadas/Documents/urop/CausalDiscovery.jl/src/Autumn/generativemodel/workshop/$(model_name).txt","w") do io
  #   if model_name != "ants" 
  #     println(io, program_strings[1])
  #   else
  #     println(io, program_strings[2])
  #   end
  # end

  # open("/Users/riadas/Documents/urop/CausalDiscovery.jl/src/Autumn/generativemodel/conference/$(model_name).txt","a") do io
  #   println(io, string("BEGIN UPDATE FUNC SPACE: ", upd_func_spaces[1], "\n\n\n"))
  #   for program_string in program_strings
  #     println(io, program_string)
  #     println(io, "\n\n\n")
  #   end
  #   println(io, "END UPDATE FUNC SPACE: $(upd_func_spaces[1]) \n\n\n")
  # end

  program_strings
end

function synthesis_program_pedro(observations::AbstractArray)

end



function generate_observations(model_name::String)
  if occursin(":", model_name)
    # take from logged dir 
    observation_file_name = "/Users/riadas/Documents/urop/today_temp/CausalDiscovery.jl/logged_observations/$(model_name).jld"
    event_file_name = "/Users/riadas/Documents/urop/today_temp/CausalDiscovery.jl/logged_observations/$(model_name)_EVENTS.txt"
    observations = JLD.load(observation_file_name)["observations"]
    open(event_file_name,"r") do io
      user_events = map(line -> line == "nothing" ? nothing : line, filter(x -> x != "", split(read(io, String), "\n")))
    end
    
    return observations, user_events, 16
  end

  if model_name == "grow_ii"
    observations, user_events, grid_size = generate_observations_grow2(nothing)
    return observations, user_events, grid_size
  elseif model_name == "mario_ii"
    observations, user_events, grid_size = generate_observations_mario2(nothing)
    return observations, user_events, grid_size
  end

  if occursin("double_count_", model_name)
    program_expr = compiletojulia(parseautumn(programs["double_count"]))
  elseif occursin("count_", model_name)
    program_expr = compiletojulia(parseautumn(programs["count"]))
  else
    program_expr = compiletojulia(parseautumn(programs[model_name]))  
  end

  m = eval(program_expr)
  if model_name == "particles"
    observations, user_events, grid_size = generate_observations_particles(m)
  elseif model_name == "ants"
    observations, user_events, grid_size = generate_observations_ants(m)
  elseif model_name == "lights"
    observations, user_events, grid_size = generate_observations_lights(m)
  elseif model_name == "water_plug"
    observations, user_events, grid_size = generate_observations_water_plug(m)
  elseif model_name == "ice"
    observations, user_events, grid_size = generate_observations_ice(m)
  elseif model_name == "tetris"
    observations, user_events, grid_size = generate_observations_tetris(m)
  elseif model_name == "snake"
    observations, user_events, grid_size = generate_observations_snake(m)
  elseif model_name == "magnets_i"
    observations, user_events, grid_size = generate_observations_magnets(m)
  elseif model_name == "magnets_ii"
    observations, user_events, grid_size = generate_observations_magnets_ii(m)
  elseif model_name == "magnets_iii"
    observations, user_events, grid_size = generate_observations_magnets_iii(m)
  elseif model_name == "disease"
    observations, user_events, grid_size = generate_observations_disease(m)
  elseif model_name == "space_invaders"
    observations, user_events, grid_size = generate_observations_space_invaders(m)
  elseif model_name == "gol"
    observations, user_events, grid_size = generate_observations_gol(m)
  elseif model_name == "sokoban_i"
    observations, user_events, grid_size = generate_observations_sokoban(m)
  elseif model_name == "sokoban_ii"
    observations, user_events, grid_size = generate_observations_sokoban_ii(m)
  elseif model_name == "grow"
    observations, user_events, grid_size = generate_observations_grow(m)
  elseif model_name == "mario"
    observations, user_events, grid_size = generate_observations_mario(m)
  elseif model_name == "sand"
    observations, user_events, grid_size = generate_observations_sand_simple(m)
  elseif model_name == "gravity_i"
    observations, user_events, grid_size = generate_observations_gravity(m)
  elseif model_name == "gravity_ii"
    observations, user_events, grid_size = generate_observations_gravity2(m)
  elseif model_name == "gravity_iii"
    observations, user_events, grid_size = generate_observations_gravity3(m)
  elseif model_name == "egg"
    observations, user_events, grid_size = generate_observations_egg(m)
  elseif model_name == "balloon"
    observations, user_events, grid_size = generate_observations_balloon(m)
  elseif model_name == "wind"
    observations, user_events, grid_size = generate_observations_wind(m)
  elseif model_name == "paint"
    observations, user_events, grid_size = generate_observations_paint(m)
  elseif model_name == "chase"
    observations, user_events, grid_size = generate_observations_chase(m)
  elseif model_name == "bullets"
    observations, user_events, grid_size = generate_observations_bullets(m)
  elseif model_name == "count_1"
    observations, user_events, grid_size = generate_observations_count_1(m)
  elseif model_name == "count_2"
    observations, user_events, grid_size = generate_observations_count_2(m)
  elseif model_name == "count_3"
    observations, user_events, grid_size = generate_observations_count_3(m)
  elseif model_name == "count_4"
    observations, user_events, grid_size = generate_observations_count_4(m)
  elseif model_name == "gravity_iv"
    observations, user_events, grid_size = generate_observations_gravity4(m)
  elseif model_name == "double_count_1"
    observations, user_events, grid_size = generate_observations_double_count_1(m)
  elseif model_name == "double_count_2"
    observations, user_events, grid_size = generate_observations_double_count_2(m)
  elseif model_name == "swap"
    observations, user_events, grid_size = generate_observations_swap(m)
  else
    error("model $(model_name) does not exist")
  end
  filter_out_of_bounds_cells(observations, grid_size), user_events, grid_size
end

function generate_observations_custom_input(model_name::String, user_events)
  if occursin("double_count_", model_name)
    program_expr = compiletojulia(parseautumn(programs["double_count"]))
  elseif occursin("count_", model_name)
    program_expr = compiletojulia(parseautumn(programs["count"]))
  else
    program_expr = compiletojulia(parseautumn(programs[model_name]))  
  end
  # # @show typeof(program_expr)
  m = eval(program_expr)
  # # @show typeof(m)
  generate_observations_custom_input(m, user_events)
end


programs = Dict("particles"                                 => """(program
                                                                  (= GRID_SIZE 16)

                                                                  (object Particle (Cell 0 0 "blue"))

                                                                  (: particles (List Particle))
                                                                  (= particles 
                                                                    (initnext (list) 
                                                                              (updateObj (prev particles) (--> obj (uniformChoice (list (moveLeft obj) (moveRight obj) (moveDown obj) (moveUp obj)) ))))) 

                                                                  (on clicked (= particles (addObj (prev particles) (Particle (Position (.. click x) (.. click y))))))
                                                                  )""",
                "chase"                                      => """(program
                                                                    (= GRID_SIZE 16)
                                                                    
                                                                    (object Ant (Cell 0 0 "red"))
                                                                    (object Agent (Cell 0 0 "green"))
                                                                  
                                                                    (: ants (List Ant))
                                                                    (= ants (initnext (list ) 
                                                                                      (prev ants)))
                                                                  
                                                                    (: agent Agent)
                                                                    (= agent (initnext (Agent (Position 7 5)) (prev agent))) 
                                                                                                                                                                                    
                                                                    (: time Int)
                                                                    (= time (initnext 0 (+ (prev time) 1)))                                                                                                                   
                                                                                                    
                                                                    (on true (= ants (updateObj (prev ants) (--> obj (move obj (unitVector obj (closest obj Agent)))) )))
                                                                    (on (== (% time 10) 5) (= ants (addObj ants (map Ant (randomPositions GRID_SIZE 1)))))
                                                                    
                                                                    (on left (= agent (moveLeft (prev agent))))
                                                                    (on right (= agent (moveRight (prev agent))))
                                                                    (on up (= agent (moveUp (prev agent))))
                                                                    (on down (= agent (moveDown (prev agent))))
                                                                            
                                                                    (on (intersects (prev agent) (prev ants)) (= agent (removeObj (prev agent))))                                                                                                                   
                                                                  )""",
                "lights"                                    => """(program
                                                                  (= GRID_SIZE 10)
                                                                
                                                                  (object Light (: on Bool) (Cell 0 0 (if on then "yellow" else "white")))
                                                                
                                                                  (: lights (List Light))
                                                                  (= lights (initnext (map (--> pos (Light false pos)) (filter (--> pos (== (.. pos x) (.. pos y))) (allPositions GRID_SIZE))) 
                                                                                      (prev lights)))
                                                                
                                                                  (on clicked (= lights (updateObj lights (--> obj (updateObj obj "on" (! (.. obj on)))))))
                                                                )""",
                "water_plug"                                => """(program
                                                                  (= GRID_SIZE 16)
                                                                
                                                                  (object Button (: color String) (Cell 0 0 color))
                                                                  (object Vessel (Cell 0 0 "purple"))
                                                                  (object Plug (Cell 0 0 "orange"))
                                                                  (object Water (Cell 0 0 "blue"))
                                                                
                                                                  (: vesselButton Button)
                                                                  (= vesselButton (Button "purple" (Position 2 0)))
                                                                  (: plugButton Button)
                                                                  (= plugButton (Button "orange" (Position 5 0)))
                                                                  (: waterButton Button)
                                                                  (= waterButton (Button "blue" (Position 8 0)))
                                                                  (: removeButton Button)
                                                                  (= removeButton (Button "black" (Position 11 0)))
                                                                  (: clearButton Button)
                                                                  (= clearButton (Button "red" (Position 14 0)))
                                                                
                                                                  (: vessels (List Vessel))
                                                                  (= vessels (initnext (list (Vessel (Position 6 15)) (Vessel (Position 6 14)) (Vessel (Position 6 13)) (Vessel (Position 5 12)) (Vessel (Position 4 11)) (Vessel (Position 3 10)) (Vessel (Position 9 15)) (Vessel (Position 9 14)) (Vessel (Position 9 13)) (Vessel (Position 10 12)) (Vessel (Position 11 11)) (Vessel (Position 12 10))) (prev vessels)))
                                                                  (: plugs (List Plug))
                                                                  (= plugs (initnext (list (Plug (Position 7 15)) (Plug (Position 8 15)) (Plug (Position 7 14)) (Plug (Position 8 14)) (Plug (Position 7 13)) (Plug (Position 8 13))) (prev plugs)))
                                                                  (: water (List Water))
                                                                  (= water (initnext (list) (prev water)))
                                                                
                                                                  (= currentParticle (initnext "vessel" (prev currentParticle)))
                                                                
                                                                  (on true (= water (updateObj (prev water) (--> obj (nextLiquid obj)))))
                                                                  (on (& clicked (& (isFree click) (== currentParticle "vessel"))) (= vessels (addObj vessels (Vessel (Position (.. click x) (.. click y))))))
                                                                  (on (& clicked (& (isFree click) (== currentParticle "plug"))) (= plugs (addObj plugs (Plug (Position (.. click x) (.. click y))))))
                                                                  (on (& clicked (& (isFree click) (== currentParticle "water"))) (= water (addObj water (Water (Position (.. click x) (.. click y))))))
                                                                  (on (clicked vesselButton) (= currentParticle "vessel"))
                                                                  (on (clicked plugButton) (= currentParticle "plug"))
                                                                  (on (clicked waterButton) (= currentParticle "water"))
                                                                  (on (clicked removeButton) (= plugs (removeObj plugs (--> obj true))))
                                                                  (on (clicked clearButton) (let ((= vessels (removeObj vessels (--> obj true))) (= plugs (removeObj plugs (--> obj true))) (= water (removeObj water (--> obj true))))))  
                                                                )""",
                "ice"                                       => """(program
                                                                  (= GRID_SIZE 8)
                                                                  (object CelestialBody (: day Bool) (list (Cell 0 0 (if day then "gold" else "gray"))
                                                                                                          (Cell 0 1 (if day then "gold" else "gray"))
                                                                                                          (Cell 1 0 (if day then "gold" else "gray"))
                                                                                                          (Cell 1 1 (if day then "gold" else "gray"))))
                                                                  (object Cloud (list (Cell -1 0 "gray")
                                                                                      (Cell 0 0 "gray")
                                                                                      (Cell 1 0 "gray")))
                                                                  
                                                                  (object Water (: liquid Bool) (Cell 0 0 (if liquid then "blue" else "lightblue")))
                                                                  
                                                                  (: celestialBody CelestialBody)
                                                                  (= celestialBody (initnext (CelestialBody true (Position 0 0)) (prev celestialBody)))
                                                                
                                                                  (: cloud Cloud)
                                                                  (= cloud (initnext (Cloud (Position 4 0)) (prev cloud)))
                                                                  
                                                                  (: water (List Water))
                                                                  (= water (initnext (list) (updateObj (prev water) nextWater)))
                                                                  
                                                                  (on left (= cloud (nextCloud cloud (Position -1 0))))
                                                                  (on right (= cloud (nextCloud cloud (Position 1 0))))
                                                                  (on down (= water (addObj water (Water (.. celestialBody day) (move (.. cloud origin) (Position 0 1))))))
                                                                  (on clicked (let ((= celestialBody (updateObj celestialBody "day" (! (.. celestialBody day)))) (= water (updateObj water (--> drop (updateObj drop "liquid" (! (.. drop liquid)))))))))
                                                                
                                                                  (= nextWater (fn (drop) 
                                                                                  (if (.. drop liquid)
                                                                                    then (nextLiquid drop)
                                                                                    else (nextSolid drop))))
                                                                  
                                                                  (= nextCloud (fn (cloud position)
                                                                                  (if (isWithinBounds (move cloud position)) 
                                                                                    then (move cloud position)
                                                                                    else cloud)))
                                                                )""",
                "tetris" => ""
                ,"snake" => ""
                ,"magnets_i"                                  => """(program
                                                                (= GRID_SIZE 16)
                                                                
                                                                (object Magnet (: color String) (list (Cell 0 0 color) (Cell 0 1 color)))
                                                                
                                                                (: fixedMagnet Magnet)
                                                                (= fixedMagnet (initnext (Magnet "red" (Position 7 7)) (prev fixedMagnet)))
                                                              
                                                                (: mobileMagnet Magnet)
                                                                (= mobileMagnet (initnext (Magnet "blue" (Position 4 7)) (prev mobileMagnet)))
                                                              
                                                                (on clicked (= mobileMagnet (rotateNoCollision (prev mobileMagnet))))
                                                                (on left (= mobileMagnet (moveNoCollision (prev mobileMagnet) -1 0)))
                                                                (on right (= mobileMagnet (moveNoCollision (prev mobileMagnet) 1 0)))
                                                                (on up (= mobileMagnet (moveNoCollision (prev mobileMagnet) 0 -1)))
                                                                (on down (= mobileMagnet (moveNoCollision (prev mobileMagnet) 0 1)))
                                                                (on (adjacent (posPole mobileMagnet) (posPole fixedMagnet)) (= mobileMagnet (prev mobileMagnet)))
                                                                (on (adjacent (negPole mobileMagnet) (negPole fixedMagnet)) (= mobileMagnet (prev mobileMagnet)))
                                                                (on (in (displacement (posPole mobileMagnet) (negPole fixedMagnet)) attractVectors) (= mobileMagnet (move mobileMagnet    (unitVector (displacement (posPole mobileMagnet) (negPole fixedMagnet))))))
                                                                (on (in (displacement (negPole mobileMagnet) (posPole fixedMagnet)) attractVectors) (= mobileMagnet (move mobileMagnet (unitVector (displacement (negPole mobileMagnet) (posPole fixedMagnet))))))
                                                                  
                                                                (= posPole (fn (magnet) (first (render magnet))))  
                                                                (= negPole (fn (magnet) (last (render magnet))))  
                                                              
                                                                (= attractVectors (list (Position 0 2) (Position 2 0) (Position -2 0) (Position 0 -2)))
                                                              )"""
                ,"magnets_ii" => ""
                ,"magnets_iii" => ""
                ,"disease"                                    => """(program
                                                                (= GRID_SIZE 8)
                                                                
                                                                (object Particle (: health Bool) (Cell 0 0 (if health then "gray" else "darkgreen")))
                                                      
                                                                (: inactiveParticles (List Particle))
                                                                (= inactiveParticles (initnext (list (Particle true (Position 5 3)) (Particle true (Position 2 1)) (Particle true (Position 4 4)) (Particle true (Position 1 3)) )  
                                                                                    (updateObj (prev inactiveParticles) (--> obj (if (! (.. activeParticle health))
                                                                                                                                  then (updateObj obj "health" false)
                                                                                                                                  else obj)) 
                                                                                                                                                                                (--> obj (adjacent (.. obj origin) (.. (prev activeParticle) origin))))))   
                                                      
                                                                (: activeParticle Particle)
                                                                (= activeParticle (initnext (Particle false (Position 0 0)) (prev activeParticle))) 
                                                      
                                                                (on (!= (length (filter (--> obj (! (.. obj health))) (adjacentObjs activeParticle))) 0) (= activeParticle (updateObj (prev activeParticle) "health" false)))
                                                                (on (clicked (prev inactiveParticles)) 
                                                                    (let ((= inactiveParticles (addObj (prev inactiveParticles) (prev activeParticle))) 
                                                                          (= activeParticle (objClicked click (prev inactiveParticles)))
                                                                          (= inactiveParticles (removeObj inactiveParticles (objClicked click (prev inactiveParticles))))
                                                                        )))
                                                                (on left (= activeParticle (move (prev activeParticle) -1 0)))
                                                                (on right (= activeParticle (move (prev activeParticle) 1 0)))
                                                                (on up (= activeParticle (move (prev activeParticle) 0 -1)))
                                                                (on down (= activeParticle (move (prev activeParticle) 0 1)))
                                                              )"""
                ,"space_invaders"                     => """(program
                                                            (= GRID_SIZE 16)
                                                            
                                                            (object Enemy (Cell 0 0 "blue"))
                                                            (object Hero (Cell 0 0 "black"))
                                                            (object Bullet (Cell 0 0 "red"))
                                                            (object EnemyBullet (Cell 0 0 "orange"))
                                                            
                                                            (: enemies1 (List Enemy))
                                                            (= enemies1 (initnext (map 
                                                                                    (--> pos (Enemy pos)) 
                                                                                    (filter (--> pos (& (== (.. pos y) 1) (== (% (.. pos x) 2) 0))) (allPositions GRID_SIZE)))
                                                                                  (prev enemies1)))
                                                          
                                                            (: enemies2 (List Enemy))
                                                            (= enemies2 (initnext (map 
                                                                                    (--> pos (Enemy pos)) 
                                                                                    (filter (--> pos (& (== (.. pos y) 3) (== (% (.. pos x) 2) 1))) (allPositions GRID_SIZE)))
                                                                                  (prev enemies2)))
                                                          
                                                            
                                                            (: hero Hero)
                                                            (= hero (initnext (Hero (Position 8 15)) (prev hero)))
                                                            
                                                            (: enemyBullets (List EnemyBullet))
                                                            (= enemyBullets (initnext (list) (prev enemyBullets)))
                                                          
                                                            (: bullets (List Bullet))
                                                            (= bullets (initnext (list) (prev bullets)))
                                                            
                                                            (: time Int)
                                                            (= time (initnext 0 (+ (prev time) 1)))                                                         
                                                            
                                                            (on true (= enemyBullets (updateObj enemyBullets (--> obj (moveDown obj)))))
                                                            (on true (= bullets (updateObj bullets (--> obj (moveUp obj)))))
                                                            (on left (= hero (moveLeftNoCollision (prev hero))))
                                                            (on right (= hero (moveRightNoCollision (prev hero))))
                                                            (on (& up (.. (prev hero) alive)) (= bullets (addObj bullets (Bullet (.. (prev hero) origin)))))  
                                                          
                                                            (on (== (% time 10) 5) (= enemies1 (updateObj enemies1 (--> obj (moveLeft obj)))))
                                                            (on (== (% time 10) 0) (= enemies1 (updateObj enemies1 (--> obj (moveRight obj)))))
                                                          
                                                            (on (== (% time 10) 5) (= enemies2 (updateObj enemies2 (--> obj (moveRight obj)))))
                                                            (on (== (% time 10) 0) (= enemies2 (updateObj enemies2 (--> obj (moveLeft obj)))))
                                                            
                                                            (on (intersects (prev bullets) (prev enemies1))
                                                              (let ((= bullets (removeObj bullets (--> obj (intersects (prev obj) (prev enemies1)))))
                                                                    (= enemies1 (removeObj enemies1 (--> obj (intersects (prev obj) (prev bullets)))))))
                                                            )          
                                                                    
                                                            (on (intersects (prev bullets) (prev enemies2))
                                                              (let ((= bullets (removeObj bullets (--> obj (intersects (prev obj) (prev enemies2)))))
                                                                    (= enemies2 (removeObj enemies2 (--> obj (intersects (prev obj) (prev bullets)))))))
                                                            )
                                                                    
                                                            (on (== (% time 5) 2) (= enemyBullets (addObj enemyBullets (EnemyBullet (uniformChoice (map (--> obj (.. obj origin)) (prev enemies2)))))))         
                                                            (on (intersects (prev hero) (prev enemyBullets)) (= hero (removeObj (prev hero))))
                                                          
                                                            (on (intersects (prev bullets) (prev enemyBullets)) 
                                                              (let 
                                                                ((= bullets (removeObj bullets (--> obj (intersects (prev obj) (prev enemyBullets))))) 
                                                                  (= enemyBullets (removeObj enemyBullets (--> obj (intersects (prev obj) (prev bullets))))))))           
                                                          )"""
                ,"gol" => ""
                ,"sokoban_i" =>                               """(program
                                                                  (= GRID_SIZE 16)
                                                                  
                                                                  (object Agent (Cell 0 0 "blue"))
                                                                  (object Box (Cell 0 0 "black"))
                                                                  (object Goal (Cell 0 0 "red"))
                                                                  
                                                                  (: agent Agent)
                                                                  (= agent (initnext (Agent (Position 7 4)) (prev agent)))
                                                                    
                                                                  (: boxes (List Box))
                                                                  (= boxes (initnext (list (Box (Position 1 2)) (Box (Position 0 4)) (Box (Position 4 4)) (Box (Position 9 9)) (Box (Position 10 9)) (Box (Position 0 11))) (prev boxes)))
                                                                
                                                                  (: goal Goal)
                                                                  (= goal (initnext (Goal (Position 0 0)) (prev goal)))
                                                                  
                                                                  (on left (let ((= boxes (moveBoxes (prev boxes) (prev agent) (prev goal) -1 0)) 
                                                                                (= agent (moveAgent (prev agent) (prev boxes) (prev goal) -1 0))))) 
                                                                
                                                                  (on right (let ((= boxes (moveBoxes (prev boxes) (prev agent) (prev goal) 1 0)) 
                                                                                  (= agent (moveAgent (prev agent) (prev boxes) (prev goal) 1 0))))) 
                                                                
                                                                  (on up (let ((= boxes (moveBoxes (prev boxes) (prev agent) (prev goal) 0 -1)) 
                                                                              (= agent (moveAgent (prev agent) (prev boxes) (prev goal) 0 -1))))) 
                                                                
                                                                  (on down (let ((= boxes (moveBoxes (prev boxes) (prev agent) (prev goal) 0 1)) 
                                                                                (= agent (moveAgent (prev agent) (prev boxes) (prev goal) 0 1))))) 
                                                                  
                                                                  (on (& clicked (isFree click)) (= boxes (addObj boxes (Box (Position (.. click x) (.. click y))))))
                                                                
                                                                  (: moveBoxes (-> (List Box) Agent Goal Int Int (List Box)))
                                                                  (= moveBoxes (fn (boxes agent goal x y) 
                                                                                  (updateObj boxes 
                                                                                    (--> obj (if (intersects (move obj x y) goal) then (removeObj obj) else (moveNoCollision obj x y))) 
                                                                                    (--> obj (== (displacement (.. obj origin) (.. agent origin)) (Position (- 0 x) (- 0 y)))))))
                                                                
                                                                  (: moveAgent (-> Agent (List Box) Goal Int Int Agent))
                                                                  (= moveAgent (fn (agent boxes goal x y) 
                                                                                  (if (| (intersects (list (move agent x y)) (moveBoxes boxes agent goal x y)) 
                                                                                          (! (isWithinBounds (move agent x y)))) 
                                                                                    then agent 
                                                                                    else (move agent x y))))
                                                                )"""
                ,"sokoban_ii" => ""
                ,"grow"                                      => """(program
                (= GRID_SIZE 7)
                
                (object Water (Cell 0 0 "blue"))
                (object Leaf (: color String) (Cell 0 0 color))
                (object Cloud (list (Cell -1 0 "gray") (Cell 0 0 "gray") (Cell 1 0 "gray")
                                    (Cell -1 1 "gray") (Cell 0 1 "gray") (Cell 1 1 "gray")))
                
                (object Sun (: movingLeft Bool) (list (Cell 0 0 "gold")
                                              (Cell 0 1 "gold")
                                               (Cell 1 0 "gold")
                                              (Cell 1 1 "gold")))
              
                (: sun Sun)
                (= sun (initnext (Sun false (Position 0 0)) (prev sun)))
              
                (: water (List Water))
                (= water (initnext (list) (updateObj (prev water) (--> obj (if (! (isWithinBounds obj)) then (removeObj obj) else (moveDown obj))))))
                
                (: cloud Cloud)
                (= cloud (initnext (Cloud (Position 5 0)) (prev cloud)))
                
                (: leaves (List Leaf))
                (= leaves (initnext (list (Leaf "green" (Position 1 6) ) (Leaf "green" (Position 3 6)) (Leaf "green" (Position 5 6)) ) (prev leaves)))
                    
                (on down
                  (= water (addObj (prev water) (Water (.. (moveDown (prev cloud)) origin)))))
              
                (on (intersects (map (--> obj (moveDown obj)) (prev water) ) (prev leaves))
                  (= water (removeObj (prev water) (--> obj (intersects (moveDown obj) (prev leaves))) ) ) )
              
                (on (& (intersects (map (--> obj (moveDown obj)) (prev water)) (filter (--> obj (== (.. obj color) "green")) (prev leaves))) (! (intersects (prev sun) (prev cloud))))
                  (= leaves (addObj (prev leaves) (map (--> obj (Leaf (if (== (.. (.. (moveUp obj) origin) y) 4) then "mediumpurple" else "green") (.. (moveUp obj) origin))) (filter (--> obj (intersects (moveUp obj) (prev water))) (prev leaves))))))
                  
                (on left (= cloud (moveLeft (prev cloud))))
                (on right (= cloud (moveRight (prev cloud))))
              
                (on (== (.. (.. (prev sun) origin) x) 0) (= sun (updateObj (prev sun) "movingLeft" false)))
                (on (== (.. (.. (prev sun) origin) x) 5) (= sun (updateObj (prev sun) "movingLeft" true)))
              
                (on (clicked (prev sun)) (= sun (if (.. (prev sun) movingLeft) then (moveLeft (prev sun)) else (moveRight (prev sun)))))
              )"""
                ,"mario_3"                                       => """(program
                                                                      (= GRID_SIZE 16)
                                                                      (= background "white")
                                                                      
                                                                      (object Mario (: bullets Int) (Cell 0 0 "red"))
                                                                      (object Step (list (Cell -1 0 "darkorange") (Cell 0 0 "darkorange") (Cell 1 0 "darkorange")))
                                                                      (object Coin (Cell 0 0 "gold"))
                                                                      (object Enemy (: movingLeft Bool) (: lives Int) (list (Cell -1 0 "blue") (Cell 0 0 "blue") (Cell 1 0 "blue")
                                                                                                          (Cell -1 1 "blue") (Cell 0 1 "blue") (Cell 1 1 "blue")))
                                                                      (object Bullet (Cell 0 0 "mediumpurple"))
                                                                      
                                                                      (: mario Mario)
                                                                      (= mario (initnext (Mario 0 (Position 7 15)) (if (intersects (moveDown (prev mario)) (prev coins)) then (moveDown (prev mario)) else (moveDownNoCollision (prev mario)))))
                                                                    
                                                                      (: steps (List Step))
                                                                      (= steps (initnext (list (Step (Position 4 13)) (Step (Position 8 10)) (Step (Position 11 7))) (prev steps)))
                                                                    
                                                                      (: coins (List Coin))
                                                                      (= coins (initnext (list (Coin (Position 14 15)) (Coin (Position 4 7)) (Coin (Position 15 5)) (Coin (Position 4 12)) (Coin (Position 7 4)) (Coin (Position 11 6))) (prev coins)))
                                                                    
                                                                      (: enemy Enemy)
                                                                      (= enemy (initnext (Enemy true 1 (Position 7 0)) (if (.. (prev enemy) movingLeft) then (moveLeft (prev enemy)) else (moveRight (prev enemy)))))
                                                                    
                                                                      (: bullets (List Bullet))
                                                                      (= bullets (initnext (list) (updateObj (prev bullets) (--> obj (if (intersects (moveUp obj) (prev steps)) then (removeObj obj) else (moveUp obj))))))
                                                                      
                                                                      (: enemyLives Int)
                                                                      (= enemyLives (initnext 1 (prev enemyLives)))
                                                                    
                                                                      (on (== (.. (.. (prev enemy) origin) x) 1) (= enemy (moveRight (updateObj (prev enemy) "movingLeft" false))))
                                                                      (on (== (.. (.. (prev enemy) origin) x) 14) (= enemy (moveLeft (updateObj (prev enemy) "movingLeft" true))))
                                                                    
                                                                      (on left (= mario (if (intersects (moveLeft (prev mario)) (prev coins)) then (moveLeft (prev mario)) else (moveLeftNoCollision (prev mario)))))
                                                                      (on right (= mario (if (intersects (moveRight (prev mario)) (prev coins)) then (moveRight (prev mario)) else (moveRightNoCollision (prev mario)))))
                                                                      (on (& up (== (moveDownNoCollision (prev mario)) (prev mario))) (= mario (moveNoCollision (prev mario) 0 -4)))
                                                                    
                                                                      (on (intersects (prev mario) (prev coins)) 
                                                                        (let ((= coins (removeObj (prev coins) (--> obj (intersects obj (prev mario))))) 
                                                                              (= mario (moveDownNoCollision (updateObj (prev mario) "bullets" (+ (.. (prev mario) bullets) 1)))))) )
                                                                    
                                                                      (on (& clicked (> (.. (prev mario) bullets) 0)) 
                                                                        (let ((= bullets (addObj (prev bullets) (Bullet (.. (prev mario) origin)))) 
                                                                              (= mario (moveDownNoCollision (updateObj (prev mario) "bullets" (- (.. (prev mario) bullets) 1)))))))
                                                                    
                                                                      (on (intersects (prev enemy) (prev bullets))
                                                                        (let ((= bullets (removeObj (prev bullets) (--> obj (intersects obj (prev enemy))))) 
                                                                              (= enemy (if (== (prev enemyLives) 1) then (removeObj (prev enemy)) else (if (.. (prev enemy) movingLeft) then (moveLeft (prev enemy)) else (moveRight (prev enemy))) ))
                                                                              (= enemyLives (- (prev enemyLives) 1)))))
                                                                    )"""
                                                                    ,"mario"                                       => """(program
                                                                    (= GRID_SIZE 16)
                                                                    (= background "white")
                                                                    
                                                                    (object Mario (: bullets Int) (Cell 0 0 "red"))
                                                                    (object Step (list (Cell -1 0 "darkorange") (Cell 0 0 "darkorange") (Cell 1 0 "darkorange")))
                                                                    (object Coin (Cell 0 0 "gold"))
                                                                    (object Enemy (: movingLeft Bool) (: lives Int) (list (Cell -1 0 "blue") (Cell 0 0 "blue") (Cell 1 0 "blue")
                                                                                                        (Cell -1 1 "blue") (Cell 0 1 "blue") (Cell 1 1 "blue")))
                                                                    (object Bullet (Cell 0 0 "mediumpurple"))
                                                                    
                                                                    (: mario Mario)
                                                                    (= mario (initnext (Mario 0 (Position 7 15)) (if (intersects (moveDown (prev mario)) (prev coins)) then (moveDown (prev mario)) else (moveDownNoCollision (prev mario)))))
                                                                  
                                                                    (: steps (List Step))
                                                                    (= steps (initnext (list (Step (Position 4 13)) (Step (Position 8 10)) (Step (Position 11 7))) (prev steps)))
                                                                  
                                                                    (: coins (List Coin))
                                                                    (= coins (initnext (list (Coin (Position 4 12)) (Coin (Position 7 4)) (Coin (Position 11 6))) (prev coins)))
                                                                  
                                                                    (: enemy Enemy)
                                                                    (= enemy (initnext (Enemy true 1 (Position 7 0)) (if (.. (prev enemy) movingLeft) then (moveLeft (prev enemy)) else (moveRight (prev enemy)))))
                                                                  
                                                                    (: bullets (List Bullet))
                                                                    (= bullets (initnext (list) (updateObj (prev bullets) (--> obj (if (intersects (moveUp obj) (prev steps)) then (removeObj obj) else (moveUp obj))))))
                                                                    
                                                                    (: enemyLives Int)
                                                                    (= enemyLives (initnext 1 (prev enemyLives)))
                                                                  
                                                                    (on (== (.. (.. (prev enemy) origin) x) 1) (= enemy (moveRight (updateObj (prev enemy) "movingLeft" false))))
                                                                    (on (== (.. (.. (prev enemy) origin) x) 14) (= enemy (moveLeft (updateObj (prev enemy) "movingLeft" true))))
                                                                  
                                                                    (on left (= mario (if (intersects (moveLeft (prev mario)) (prev coins)) then (moveLeft (prev mario)) else (moveLeftNoCollision (prev mario)))))
                                                                    (on right (= mario (if (intersects (moveRight (prev mario)) (prev coins)) then (moveRight (prev mario)) else (moveRightNoCollision (prev mario)))))
                                                                    (on (& up (== (moveDownNoCollision (prev mario)) (prev mario))) (= mario (moveNoCollision (prev mario) 0 -4)))
                                                                  
                                                                    (on (intersects (prev mario) (prev coins)) 
                                                                      (let ((= coins (removeObj (prev coins) (--> obj (intersects obj (prev mario))))) 
                                                                            (= mario (moveDownNoCollision (updateObj (prev mario) "bullets" (+ (.. (prev mario) bullets) 1)))))) )
                                                                  
                                                                    (on (& clicked (> (.. (prev mario) bullets) 0)) 
                                                                      (let ((= bullets (addObj (prev bullets) (Bullet (.. (prev mario) origin)))) 
                                                                            (= mario (moveDownNoCollision (updateObj (prev mario) "bullets" (- (.. (prev mario) bullets) 1)))))))
                                                                  
                                                                    (on (intersects (prev enemy) (prev bullets))
                                                                      (let ((= bullets (removeObj (prev bullets) (--> obj (intersects obj (prev enemy))))) 
                                                                            (= enemy (if (== (prev enemyLives) 1) then (removeObj (prev enemy)) else (if (.. (prev enemy) movingLeft) then (moveLeft (prev enemy)) else (moveRight (prev enemy))) ))
                                                                            (= enemyLives (- (prev enemyLives) 1)))))
                                                                  )"""
                                                                  ,"mario_3"                                       => """(program
                                                                  (= GRID_SIZE 16)
                                                                  (= background "white")
                                                                  
                                                                  (object Mario (: bullets Int) (Cell 0 0 "red"))
                                                                  (object Step (list (Cell -1 0 "darkorange") (Cell 0 0 "darkorange") (Cell 1 0 "darkorange")))
                                                                  (object Coin (Cell 0 0 "gold"))
                                                                  (object Enemy (: movingLeft Bool) (: lives Int) (list (Cell -1 0 "blue") (Cell 0 0 "blue") (Cell 1 0 "blue")
                                                                                                      (Cell -1 1 "blue") (Cell 0 1 "blue") (Cell 1 1 "blue")))
                                                                  (object Bullet (Cell 0 0 "mediumpurple"))
                                                                  
                                                                  (: mario Mario)
                                                                  (= mario (initnext (Mario 0 (Position 7 15)) (if (intersects (moveDown (prev mario)) (prev coins)) then (moveDown (prev mario)) else (moveDownNoCollision (prev mario)))))
                                                                
                                                                  (: steps (List Step))
                                                                  (= steps (initnext (list (Step (Position 4 13)) (Step (Position 8 10)) (Step (Position 11 7))) (prev steps)))
                                                                
                                                                  (: coins (List Coin))
                                                                  (= coins (initnext (list (Coin (Position 14 15)) (Coin (Position 4 7)) (Coin (Position 15 5)) (Coin (Position 4 12)) (Coin (Position 7 4)) (Coin (Position 11 6))) (prev coins)))
                                                                
                                                                  (: enemy Enemy)
                                                                  (= enemy (initnext (Enemy true 1 (Position 7 0)) (if (.. (prev enemy) movingLeft) then (moveLeft (prev enemy)) else (moveRight (prev enemy)))))
                                                                
                                                                  (: bullets (List Bullet))
                                                                  (= bullets (initnext (list) (updateObj (prev bullets) (--> obj (if (intersects (moveUp obj) (prev steps)) then (removeObj obj) else (moveUp obj))))))
                                                                  
                                                                  (: enemyLives Int)
                                                                  (= enemyLives (initnext 1 (prev enemyLives)))
                                                                
                                                                  (on (== (.. (.. (prev enemy) origin) x) 1) (= enemy (moveRight (updateObj (prev enemy) "movingLeft" false))))
                                                                  (on (== (.. (.. (prev enemy) origin) x) 14) (= enemy (moveLeft (updateObj (prev enemy) "movingLeft" true))))
                                                                
                                                                  (on left (= mario (if (intersects (moveLeft (prev mario)) (prev coins)) then (moveLeft (prev mario)) else (moveLeftNoCollision (prev mario)))))
                                                                  (on right (= mario (if (intersects (moveRight (prev mario)) (prev coins)) then (moveRight (prev mario)) else (moveRightNoCollision (prev mario)))))
                                                                  (on (& up (== (moveDownNoCollision (prev mario)) (prev mario))) (= mario (moveNoCollision (prev mario) 0 -4)))
                                                                
                                                                  (on (intersects (prev mario) (prev coins)) 
                                                                    (let ((= coins (removeObj (prev coins) (--> obj (intersects obj (prev mario))))) 
                                                                          (= mario (moveDownNoCollision (updateObj (prev mario) "bullets" (+ (.. (prev mario) bullets) 1)))))) )
                                                                
                                                                  (on (& clicked (> (.. (prev mario) bullets) 0)) 
                                                                    (let ((= bullets (addObj (prev bullets) (Bullet (.. (prev mario) origin)))) 
                                                                          (= mario (moveDownNoCollision (updateObj (prev mario) "bullets" (- (.. (prev mario) bullets) 1)))))))
                                                                
                                                                  (on (intersects (prev enemy) (prev bullets))
                                                                    (let ((= bullets (removeObj (prev bullets) (--> obj (intersects obj (prev enemy))))) 
                                                                          (= enemy (if (== (prev enemyLives) 1) then (removeObj (prev enemy)) else (if (.. (prev enemy) movingLeft) then (moveLeft (prev enemy)) else (moveRight (prev enemy))) ))
                                                                          (= enemyLives (- (prev enemyLives) 1)))))
                                                                )"""
                                                                ,"mario_4"                                       => """(program
                                                                (= GRID_SIZE 16)
                                                                (= background "white")
                                                                
                                                                (object Mario (: bullets Int) (Cell 0 0 "red"))
                                                                (object Step (list (Cell -1 0 "darkorange") (Cell 0 0 "darkorange") (Cell 1 0 "darkorange")))
                                                                (object Coin (Cell 0 0 "gold"))
                                                                (object Enemy (: movingLeft Bool) (: lives Int) (list (Cell -1 0 "blue") (Cell 0 0 "blue") (Cell 1 0 "blue")
                                                                                                    (Cell -1 1 "blue") (Cell 0 1 "blue") (Cell 1 1 "blue")))
                                                                (object Bullet (Cell 0 0 "mediumpurple"))
                                                                
                                                                (: mario Mario)
                                                                (= mario (initnext (Mario 0 (Position 7 15)) (if (intersects (moveDown (prev mario)) (prev coins)) then (moveDown (prev mario)) else (moveDownNoCollision (prev mario)))))
                                                              
                                                                (: steps (List Step))
                                                                (= steps (initnext (list (Step (Position 4 13)) (Step (Position 8 10)) (Step (Position 11 7))) (prev steps)))
                                                              
                                                                (: coins (List Coin))
                                                                (= coins (initnext (list (Coin (Position 10 12)) (Coin (Position 0 14)) (Coin (Position 3 6)) (Coin (Position 15 9))  (Coin (Position 14 15)) (Coin (Position 4 7)) (Coin (Position 15 5)) (Coin (Position 4 12)) (Coin (Position 7 4)) (Coin (Position 11 6))) (prev coins)))
                                                              
                                                                (: enemy Enemy)
                                                                (= enemy (initnext (Enemy true 1 (Position 7 0)) (if (.. (prev enemy) movingLeft) then (moveLeft (prev enemy)) else (moveRight (prev enemy)))))
                                                              
                                                                (: bullets (List Bullet))
                                                                (= bullets (initnext (list) (updateObj (prev bullets) (--> obj (if (intersects (moveUp obj) (prev steps)) then (removeObj obj) else (moveUp obj))))))
                                                                
                                                                (: enemyLives Int)
                                                                (= enemyLives (initnext 1 (prev enemyLives)))
                                                              
                                                                (on (== (.. (.. (prev enemy) origin) x) 1) (= enemy (moveRight (updateObj (prev enemy) "movingLeft" false))))
                                                                (on (== (.. (.. (prev enemy) origin) x) 14) (= enemy (moveLeft (updateObj (prev enemy) "movingLeft" true))))
                                                              
                                                                (on left (= mario (if (intersects (moveLeft (prev mario)) (prev coins)) then (moveLeft (prev mario)) else (moveLeftNoCollision (prev mario)))))
                                                                (on right (= mario (if (intersects (moveRight (prev mario)) (prev coins)) then (moveRight (prev mario)) else (moveRightNoCollision (prev mario)))))
                                                                (on (& up (== (moveDownNoCollision (prev mario)) (prev mario))) (= mario (moveNoCollision (prev mario) 0 -4)))
                                                              
                                                                (on (intersects (prev mario) (prev coins)) 
                                                                  (let ((= coins (removeObj (prev coins) (--> obj (intersects obj (prev mario))))) 
                                                                        (= mario (moveDownNoCollision (updateObj (prev mario) "bullets" (+ (.. (prev mario) bullets) 1)))))) )
                                                              
                                                                (on (& clicked (> (.. (prev mario) bullets) 0)) 
                                                                  (let ((= bullets (addObj (prev bullets) (Bullet (.. (prev mario) origin)))) 
                                                                        (= mario (moveDownNoCollision (updateObj (prev mario) "bullets" (- (.. (prev mario) bullets) 1)))))))
                                                              
                                                                (on (intersects (prev enemy) (prev bullets))
                                                                  (let ((= bullets (removeObj (prev bullets) (--> obj (intersects obj (prev enemy))))) 
                                                                        (= enemy (if (== (prev enemyLives) 1) then (removeObj (prev enemy)) else (if (.. (prev enemy) movingLeft) then (moveLeft (prev enemy)) else (moveRight (prev enemy))) ))
                                                                        (= enemyLives (- (prev enemyLives) 1)))))
                                                              )"""                                                                  

                ,"sand"                                      => """(program
                                                                      (= GRID_SIZE 10)
                                                                    
                                                                      (object Button (: color String) (Cell 0 0 color))
                                                                      (object Sand (: liquid Bool) (Cell 0 0 (if liquid then "sandybrown" else "tan")))
                                                                      (object Water (Cell 0 0 "skyblue"))
                                                                    
                                                                      (: sandButton Button)
                                                                      (= sandButton (initnext (Button "red" (Position 2 0)) (prev sandButton)))
                                                                    
                                                                      (: waterButton Button)
                                                                      (= waterButton (initnext (Button "green" (Position 7 0)) (prev waterButton)))
                                                                    
                                                                      (: sand (List Sand))
                                                                      (= sand (initnext (list) 
                                                                                (updateObj (prev sand) (--> obj (if (.. obj liquid) 
                                                                    then (nextLiquid obj)
                                                                    else (nextSolid obj))))))
                                                                    
                                                                    (: water (List Water))
                                                                    (= water (initnext (list) (updateObj (prev water) (--> obj (nextLiquid obj)))))
                                                                    
                                                                    
                                                                    (: clickType String)
                                                                    (= clickType (initnext "sand" (prev clickType)))
                                                                    
                                                                    (on true (= sand (updateObj (prev sand) (--> obj (updateObj obj "liquid" true)) (--> obj (& (! (.. obj liquid)) (intersects (adjacentObjs obj) (prev water)))))))
                                                                    
                                                                    (on (clicked sandButton) (= clickType "sand"))
                                                                    (on (clicked waterButton) (= clickType "water"))
                                                                    (on (& (& clicked (isFree click)) (== clickType "sand"))  (= sand (addObj sand (Sand false (Position (.. click x) (.. click y))))))
                                                                    (on (& (& clicked (isFree click)) (== clickType "water")) (= water (addObj water (Water (Position (.. click x) (.. click y))))))
                                                                    
                                                                              )"""
                ,"gravity_i"                                 => """(program
                                                                  (= GRID_SIZE 16)
                                                                    
                                                                  (object Button (: color String) (Cell 0 0 color))
                                                                  (object Blob (list (Cell 0 -1 "blue") (Cell 0 0 "blue") (Cell 1 -1 "blue") (Cell 1 0 "blue")))
                                                        
                                                                  (: leftButton Button)
                                                                  (= leftButton (initnext (Button "red" (Position 0 7)) (prev leftButton)))
                                                                  
                                                                  (: rightButton Button)
                                                                  (= rightButton (initnext (Button "darkorange" (Position 15 7)) (prev rightButton)))
                                                                    
                                                                  (: upButton Button)
                                                                  (= upButton (initnext (Button "gold" (Position 7 0)) (prev upButton)))
                                                                  
                                                                  (: downButton Button)
                                                                  (= downButton (initnext (Button "green" (Position 7 15)) (prev downButton)))
                                                                  
                                                                  (: blobs (List Blob))
                                                                  (= blobs (initnext (list) (prev blobs)))
                                                                  
                                                                  (: gravity String)
                                                                  (= gravity (initnext "down" (prev gravity)))
                                                                  
                                                                  (on (== gravity "left") (= blobs (updateObj blobs (--> obj (moveLeftNoCollision obj)))))
                                                                  (on (== gravity "right") (= blobs (updateObj blobs (--> obj (moveRightNoCollision obj)))))
                                                                  (on (== gravity "up") (= blobs (updateObj blobs (--> obj (moveUpNoCollision obj)))))
                                                                  (on (== gravity "down") (= blobs (updateObj blobs (--> obj (moveDownNoCollision obj)))))
                                                                  
                                                                  (on (& clicked (isFree click)) (= blobs (addObj blobs (Blob (Position (.. click x) (.. click y))))) )
                                                                  
                                                                  (on (clicked leftButton) (= gravity "left"))
                                                        
                                                                  (on (clicked rightButton) (= gravity "right"))
                                                        
                                                                  (on (clicked upButton) (= gravity "up"))
                                                        
                                                                  (on (clicked downButton) (= gravity "down"))
                                                                )"""
                ,"gravity_ii"                                => """(program
                                                                    (= GRID_SIZE 30)
                                                                      
                                                                    (object Button (: color String) (Cell 0 0 color))
                                                                    (object Blob (: color String) (list (Cell 0 -1 color) (Cell 0 0 color) (Cell 1 -1 color) (Cell 1 0 color)))
                                                                  
                                                                    (: leftButton Button)
                                                                    (= leftButton (initnext (Button "red" (Position 0 14)) (prev leftButton)))
                                                                    
                                                                    (: rightButton Button)
                                                                    (= rightButton (initnext (Button "darkorange" (Position 29 14)) (prev rightButton)))
                                                                      
                                                                    (: upButton Button)
                                                                    (= upButton (initnext (Button "gold" (Position 14 0)) (prev upButton)))
                                                                    
                                                                    (: downButton Button)
                                                                    (= downButton (initnext (Button "green" (Position 14 29)) (prev downButton)))
                                                                    
                                                                    (: blobs (List Blob))
                                                                    (= blobs (initnext (list) (prev blobs)))
                                                                    
                                                                    (: gravity String)
                                                                    (= gravity (initnext "down" (prev gravity)))
                                                                    
                                                                    (: blobColor Int)
                                                                    (= blobColor (initnext 0 (prev blobColor)))
                                                                    
                                                                    (on (== gravity "left") (= blobs (updateObj (prev blobs) (--> obj (moveLeftNoCollision obj)))))
                                                                    (on (== gravity "right") (= blobs (updateObj (prev blobs) (--> obj (moveRightNoCollision obj)))))
                                                                    (on (== gravity "up") (= blobs (updateObj (prev blobs) (--> obj (moveUpNoCollision obj)))))
                                                                    (on (== gravity "down") (= blobs (updateObj (prev blobs) (--> obj (moveDownNoCollision obj)))))
                                                                    
                                                                    (on (& clicked (isFree click)) (= blobColor (% (+ (prev blobColor) 1) 3)))
                                                                    (on (& (& clicked (isFree click)) (== blobColor 0)) (= blobs (addObj blobs (Blob "blue" (Position (.. click x) (.. click y))))))
                                                                    (on (& (& clicked (isFree click)) (== blobColor 1)) (= blobs (addObj blobs (Blob "mediumpurple" (Position (.. click x) (.. click y))))))
                                                                    (on (& (& clicked (isFree click)) (== blobColor 2)) (= blobs (addObj blobs (Blob "magenta" (Position (.. click x) (.. click y))))))
                                                                    
                                                                    (on (clicked leftButton) (= gravity "left"))
                                                                  
                                                                    (on (clicked rightButton) (= gravity "right"))
                                                                  
                                                                    (on (clicked upButton) (= gravity "up"))
                                                                  
                                                                    (on (clicked downButton) (= gravity "down"))
                                                                  )"""
                ,"gravity_iii"                                 => """(program
                                                                    (= GRID_SIZE 40)
                                                                    (= background "black")
                                                                      
                                                                    (object Button (: color String) (Cell 0 0 color))
                                                                    (object Blob (list (Cell 0 0 "blue")))
                                                                    
                                                                    (: blobs (List Blob))
                                                                    (= blobs (initnext (list (Blob (Position 19 19))) (prev blobs)))
                                                                    
                                                                    (: xVel Int)
                                                                    (= xVel (initnext 0 (prev xVel)))
                                                                    
                                                                    (: yVel Int)
                                                                    (= yVel (initnext 0 (prev yVel)))
                                                                              
                                                                    (on (& clicked (isFree click)) (= blobs (addObj blobs (Blob (Position (.. click x) (.. click y))))))
                                                                    
                                                                    (on (& left (!= (prev xVel) -1)) (= xVel (- (prev xVel) 1)))
                                                                    (on (& right (!= (prev xVel) 1)) (= xVel (+ (prev xVel) 1)))
                                                                  
                                                                    (on (& up (!= (prev yVel) -1)) (= yVel (- (prev yVel) 1)))
                                                                    (on (& down (!= (prev yVel) 1)) (= yVel (+ (prev yVel) 1)))
                                                                    
                                                                    (on true (= blobs (updateObj blobs (--> obj (moveNoCollision obj (Position (prev xVel) (prev yVel)))))))
                                                                  )"""
                ,"egg"                                         => """(program
                                                                    (= GRID_SIZE 16)
                                                                    (= background "black")
                                                                    
                                                                    (object Button (: color String) (Cell 0 0 color))
                                                                    (object Piece (Cell 0 0 "gold"))
                                                                    (object Egg (list (Cell -1 -2 "tan") (Cell 0 -2 "tan") (Cell 1 -2 "tan")  
                                                                                      (Cell -2 -1 "tan") (Cell -1 -1 "tan") (Cell 0 -1 "tan") (Cell 1 -1 "tan") (Cell 2 -1 "tan")
                                                                                      (Cell -2 0 "tan") (Cell -1 0 "tan") (Cell 0 0 "tan") (Cell 1 0 "tan") (Cell 2 0 "tan") 
                                                                                      (Cell -2 1 "tan") (Cell -1 1 "tan") (Cell 0 1 "tan") (Cell 1 1 "tan") (Cell 2 1 "tan") 
                                                                                    (Cell -1 2 "tan") (Cell 0 2 "tan") (Cell 1 2 "tan")))
                                                                  
                                                                    (: egg Egg)
                                                                    (= egg (initnext (Egg (Position 7 13)) (prev egg)))
                                                                    
                                                                    (: pieces (List Piece))
                                                                    (= pieces (initnext (list) (updateObj (prev pieces) (--> obj (nextLiquid obj)))))
                                                                    
                                                                    (: button Button)
                                                                    (= button (initnext (Button "red" (Position 0 0)) (updateObj (prev button) "color" (if gravity then "pink" else "red"))))
                                                                    
                                                                    (: gravity Bool)
                                                                    (= gravity (initnext false (prev gravity)))
                                                                  
                                                                    (: height Int)
                                                                    (= height (initnext 15 (prev height)))
                                                                    
                                                                    (on gravity (= egg (moveDownNoCollision (prev egg))))
                                                                      
                                                                    (on (& left (! gravity)) (= egg (moveLeftNoCollision (prev egg))))
                                                                    (on (& right (! gravity)) (= egg (moveRightNoCollision (prev egg))))
                                                                    (on (& up (! gravity)) (= egg (moveUpNoCollision (prev egg))))
                                                                    (on (& down (! gravity)) (= egg (moveDownNoCollision (prev egg))))
                                                                  
                                                                    (on (clicked (prev button)) 
                                                                      (let ((= gravity (! (prev gravity)))
                                                                            (= height (.. (.. (prev egg) origin) y)))))
                                                                  
                                                                    (on (& (< height 7) (== (.. (.. egg origin) y) 13)) 
                                                                      (let ((= egg (removeObj egg)) 
                                                                            (= pieces (addObj (prev pieces) (map (--> obj (Piece (Position (.. (.. obj position) x) (+ 1 (.. (.. obj position) y))))) (render (prev egg))))))))
                                                                  
                                                                  )"""
                ,"balloon" => ""
              ,"wind"                                          => """(program
                                                                      (= GRID_SIZE 17)
                                                                    
                                                                      (object Water (Cell 0 0 "lightblue"))
                                                                      (object Cloud (map (--> pos (Cell (.. pos x) (.. pos y) "gray")) (rect (Position 0 0) (Position 16 1))))
                                                                      
                                                                      (: water (List Water))
                                                                      (= water (initnext (list) (updateObj (prev water) (--> obj (removeObj obj)) (--> obj (! (isWithinBounds obj)))))) 
                                                                           
                                                                      (: cloud Cloud)
                                                                      (= cloud (initnext (Cloud (Position 0 0)) (prev cloud)))
                                                                    
                                                                      (: wind Int)
                                                                      (= wind (initnext 0 (prev wind)))
                                                                      
                                                                      (: time Int)
                                                                      (= time (initnext 0 (+ (prev time) 1)))
                                                                      
                                                                      (on (== wind 0) (= water (updateObj (prev water) (--> obj (moveDown obj)))))
                                                                      (on (== wind 1) (= water (updateObj (prev water) (--> obj (moveRight (moveDown obj))))))
                                                                      (on (== wind -1) (= water (updateObj (prev water) (--> obj (moveLeft (moveDown obj))))))
                                                                    
                                                                      (on true (= water (updateObj water (--> obj (removeObj (prev obj))) (--> obj (! (isWithinBounds (prev obj)))))))
                                                                    
                                                                    
                                                                      (on left (= wind (if (== (prev wind) -1) then (prev wind) else (- (prev wind) 1))))
                                                                      (on right (= wind (if (== (prev wind) 1) then (prev wind) else (+ (prev wind) 1))))
                                                                      
                                                                      
                                                                      (on (== (% time 5) 2) 
                                                                        (= water (addObj 
                                                                                  water 
                                                                                  (map (--> pos (Water pos)) (list (Position 2 2)
                                                                                                                    
                                                                                                                  (Position 6 2)
                                                                                                                  
                                                                                                                  (Position 10 2)
                                                                                                                  
                                                                                                                  (Position 14 2))))))
                                                                    )"""
                ,"paint"                                         => """(program
                                                                      (= GRID_SIZE 16)
                                                                      
                                                                      (object Particle (: color String) (Cell 0 0 color))
                                                                    
                                                                      (: particles (List Particle))
                                                                      (= particles (initnext (list) (prev particles)))
                                                                      
                                                                      (: currColor String)
                                                                      (= currColor (initnext "red" (prev currColor)))
                                                                      
                                                                      (on clicked (= particles (addObj (prev particles) (Particle currColor (Position (.. click x) (.. click y))))))
                                                                      (on (& up (== (prev currColor) "red")) (= currColor "gold"))
                                                                      (on (& up (== (prev currColor) "gold")) (= currColor "green"))
                                                                      (on (& up (== (prev currColor) "green")) (= currColor "blue"))
                                                                      (on (& up (== (prev currColor) "blue")) (= currColor "purple"))
                                                                      (on (& up (== (prev currColor) "purple")) (= currColor "red"))
                                                                    )"""
                ,"ants" =>                                        """(program
                                                                      (= GRID_SIZE 16)
                                                                      
                                                                      (object Ant (Cell 0 0 "gray"))
                                                                      (object Food (Cell 0 0 "red"))
                                                                    
                                                                      (: ants (List Ant))
                                                                      (= ants (initnext (list (Ant (Position 5 5)) (Ant (Position 1 14))) (prev ants)))
                                                                    
                                                                      (: foods (List Food))
                                                                      (= foods (initnext (list) (prev foods)))
                                                                      
                                                                      (on true (= ants (updateObj (prev ants) (--> obj (move obj (unitVector obj (closest obj Food)))))))
                                                                      (on true (= foods (updateObj (prev foods) (--> obj (if (intersects obj (prev ants))
                                                                                                                           then (removeObj obj)
                                                                                                                           else obj)))))
                                                                    
                                                                      (on clicked (= foods (addObj foods (map Food (randomPositions GRID_SIZE 2)))))
                                                                    )"""
                ,"bullets" =>                                     """(program
                                                                      (= GRID_SIZE 16)
                                                                      (object Particle (Cell 0 0 "blue"))
                                                                      (object Bullet (: dir String) (Cell 0 0 "red"))
                                                                      
                                                                      (: particle Particle)
                                                                      (= particle (initnext (Particle (Position 8 8)) (prev particle)))
                                                                      
                                                                      (: bullets (List Bullet))
                                                                      (= bullets (initnext (list) (prev bullets)))
                                                                      
                                                                      (: dir String)
                                                                      (= dir (initnext "none" (prev dir)))
                                                                      
                                                                      (on true (= bullets (updateObj bullets (--> obj (moveLeft obj)) (--> obj (== (.. obj dir) "left")))))
                                                                      (on true (= bullets (updateObj bullets (--> obj (moveRight obj)) (--> obj (== (.. obj dir) "right")))))
                                                                      (on true (= bullets (updateObj bullets (--> obj (moveUp obj)) (--> obj (== (.. obj dir) "up")))))
                                                                      (on true (= bullets (updateObj bullets (--> obj (moveDown obj)) (--> obj (== (.. obj dir) "down")))))
                                                                      
                                                                      (on left (let ((= dir "left")
                                                                                    (= particle (moveLeft particle)))))
                                                                      (on right (let ((= dir "right")
                                                                                      (= particle (moveRight particle)))))
                                                                      (on up (let ((= dir "up")
                                                                                  (= particle (moveUp particle)))))
                                                                      (on down (let ((= dir "down")
                                                                                    (= particle (moveDown particle)))))
                                                                    
                                                                      
                                                                      (on (& clicked (== dir "left")) (= bullets (addObj bullets (Bullet "left" (.. (moveLeft particle) origin)))))
                                                                      (on (& clicked (== dir "right")) (= bullets (addObj bullets (Bullet "right" (.. (moveRight particle) origin)))))
                                                                      (on (& clicked (== dir "up")) (= bullets (addObj bullets (Bullet "up" (.. (moveUp particle) origin)))))
                                                                      (on (& clicked (== dir "down")) (= bullets (addObj bullets (Bullet "down" (.. (moveDown particle) origin)))))
                                                                    )"""
                , "count" =>                                     """(program
                                                                    (= GRID_SIZE 100)
                                                                      
                                                                    (object Button (: color String) (Cell 0 0 color))
                                                                    (object Blob (list (Cell 0 0 "blue")))
                                                                    
                                                                    (: blobs (List Blob))
                                                                    (= blobs (initnext (list (Blob (Position 50 50))) (prev blobs)))
                                                                    
                                                                    (: xVel Int)
                                                                    (= xVel (initnext 0 (prev xVel)))
                                                                    
                                                                    (: yVel Int)
                                                                    (= yVel (initnext 0 (prev yVel)))
                                                                    
                                                                    (: xActive Bool)
                                                                    (= xActive (initnext true (prev xActive)))

                                                                    (on clicked (= xActive (! xActive)))
                                                                    
                                                                    (on (& left xActive) (= xVel (- (prev xVel) 1)))
                                                                    (on (& right xActive) (= xVel (+ (prev xVel) 1)))

                                                                    (on (& up (! xActive)) (= yVel (- (prev yVel) 1)))
                                                                    (on (& down (! xActive)) (= yVel (+ (prev yVel) 1)))

                                                                    (on true (= blobs (updateObj blobs (--> obj (moveNoCollision obj (Position (sign (prev xVel)) (sign (prev yVel))))))))
                                                                  )"""
                , "double_count" =>                            """(program
                                                                  (= GRID_SIZE 100)
                                                                    
                                                                  (object Button (: color String) (Cell 0 0 color))
                                                                  (object Blob (list (Cell 0 0 "blue")))
                                                                  
                                                                  (: blobs (List Blob))
                                                                  (= blobs (initnext (list (Blob (Position 49 49))) (prev blobs)))
                                                                  
                                                                  (: xVel Int)
                                                                  (= xVel (initnext 0 (prev xVel)))
                                                                  
                                                                  (: yVel Int)
                                                                  (= yVel (initnext 0 (prev yVel)))
                                                                    
                                                                  (on (& left (== (prev yVel) 0)) (= xVel (- (prev xVel) 1)))
                                                                  (on (& right (== (prev yVel) 0)) (= xVel (+ (prev xVel) 1)))
                                                                
                                                                  (on (& up (== (prev xVel) 0)) (= yVel (- (prev yVel) 1)))
                                                                  (on (& down (== (prev xVel) 0)) (= yVel (+ (prev yVel) 1)))
                                                                
                                                                  (on true (= blobs (updateObj blobs (--> obj (move obj (Position (sign (prev xVel)) (sign (prev yVel))))))))
                                                                )"""
                , "gravity_iv" =>                             """(program
                                                                  (= GRID_SIZE 100)
                                                                    
                                                                  (object Button (: color String) (Cell 0 0 color))
                                                                  (object Blob (list (Cell 0 -1 "black") (Cell 0 0 "black") (Cell 1 -1 "black") (Cell 1 0 "black")))
                                                                
                                                                  (: buttons (List Button))
                                                                  (= buttons (initnext (list (Button "red" (Position 4 0)) 
                                                                              (Button "gold" (Position 8 0))                             
                                                                              (Button "darkorange" (Position 12 0))
                                                                                        
                                                                              (Button "lightgreen" (Position (- GRID_SIZE 1) 4))
                                                                                            (Button "green" (Position (- GRID_SIZE 1) 8))
                                                                                            (Button "lightseagreen" (Position (- GRID_SIZE 1) 12))
                                                                                            
                                                                                            (Button "lightblue" (Position 4 (- GRID_SIZE 1)))
                                                                                            (Button "blue" (Position 8 (- GRID_SIZE 1)))
                                                                                            

                                                                                        ) (prev buttons)))
                                                                  
                                                                  (: blobs (List Blob))
                                                                  (= blobs (initnext (list) (prev blobs)))
                                                                  
                                                                  (: gravity String)
                                                                  (= gravity (initnext "rr" (prev gravity)))
                                                                                                                                    
                                                                  (on (== gravity "ul") (= blobs (updateObj (prev blobs) (--> obj (move (prev obj) -1 -2)))))
                                                                  (on (== gravity "uu") (= blobs (updateObj (prev blobs) (--> obj (move (prev obj) 0 -2)))))
                                                                  (on (== gravity "ur") (= blobs (updateObj (prev blobs) (--> obj (move (prev obj) 1 -2)))))
                                                                
                                                                  (on (== gravity "ru") (= blobs (updateObj (prev blobs) (--> obj (move (prev obj) 2 -1)))))
                                                                  (on (== gravity "rr") (= blobs (updateObj (prev blobs) (--> obj (move (prev obj) 2 0)))))
                                                                  (on (== gravity "rd") (= blobs (updateObj (prev blobs) (--> obj (move (prev obj) 2 1)))))
                                                                
                                                                  (on (== gravity "dl") (= blobs (updateObj (prev blobs) (--> obj (move (prev obj) -1 2)))))
                                                                  (on (== gravity "dd") (= blobs (updateObj (prev blobs) (--> obj (move (prev obj) 0 2)))))
                                                                
                                                            
                                                                  (on (clicked (filter (--> obj (== (.. obj color) "red")) (prev buttons))) (= gravity "ul"))
                                                                  (on (clicked (filter (--> obj (== (.. obj color) "gold")) (prev buttons))) (= gravity "uu"))
                                                                  (on (clicked (filter (--> obj (== (.. obj color) "darkorange")) (prev buttons))) (= gravity "ur"))
                                                                
                                                                  (on (clicked (filter (--> obj (== (.. obj color) "lightgreen")) (prev buttons))) (= gravity "ru"))
                                                                  (on (clicked (filter (--> obj (== (.. obj color) "green")) (prev buttons))) (= gravity "rr"))
                                                                  (on (clicked (filter (--> obj (== (.. obj color) "lightseagreen")) (prev buttons))) (= gravity "rd"))
                                                                
                                                                  (on (clicked (filter (--> obj (== (.. obj color) "lightblue")) (prev buttons))) (= gravity "dl"))
                                                                  (on (clicked (filter (--> obj (== (.. obj color) "blue")) (prev buttons))) (= gravity "dd"))
                                                                  
                                                                  (on (& clicked (isFree click)) (= blobs (addObj blobs (Blob (Position (.. click x) (.. click y))))))

                                                                
                                                                )"""
               , "swap"                                    => """(program
               (= GRID_SIZE 40)
               (= background "black")
               
               (object Blob (map (--> pos (Cell pos "mediumpurple")) (rect (Position 0 0) (Position 1 1))))
               (object Button (: color String) (Cell 0 0 color))
               
               (: button1 Button)
               (= button1 (initnext (Button "red" (Position 0 3)) (prev button1)))
               
               (: button2 Button)
               (= button2 (initnext (Button "gold" (Position 0 6)) (prev button2)))
               
               (: button3 Button)
               (= button3 (initnext (Button "green" (Position 0 9)) (prev button3)))
               
               (: button4 Button)
               (= button4 (initnext (Button "blue" (Position 0 12)) (prev button4)))
               
               (: button5 Button)
               (= button5 (initnext (Button "red" (Position (- GRID_SIZE 1) 3)) (prev button5)))
               
               (: button6 Button)
               (= button6 (initnext (Button "gold" (Position (- GRID_SIZE 1) 6)) (prev button6)))
               
               (: button7 Button)
               (= button7 (initnext (Button "green" (Position (- GRID_SIZE 1) 9)) (prev button7)))
             
               (: button8 Button)
               (= button8 (initnext (Button "blue" (Position (- GRID_SIZE 1) 12)) (prev button8)))
               
               (: swapButton Button)
               (= swapButton (initnext (Button "red" (Position (/ GRID_SIZE 2) 0)) (prev swapButton)))
             
               (: blob Blob)
               (= blob (initnext (Blob (Position (/ GRID_SIZE 2) (/ GRID_SIZE 2))) (prev blob)))  
               
               (: globalState String)
               (= globalState (initnext "none" (prev globalState)))
               
               (: swapState String)
               (= swapState (initnext 1 (prev swapState)))
               
               (on (== globalState "left") (= blob (moveLeftNoCollision blob)))
               (on (== globalState "right") (= blob (moveRightNoCollision blob)))
               (on (== globalState "up") (= blob (moveUpNoCollision blob)))
               (on (== globalState "down") (= blob (moveDownNoCollision blob)))
               
               (on (== globalState "left-up") (= blob (moveLeftNoCollision (moveUpNoCollision blob))))
               (on (== globalState "right-up") (= blob (moveRightNoCollision (moveUpNoCollision blob))))
               (on (== globalState "left-down") (= blob (moveLeftNoCollision (moveDownNoCollision blob))))
               (on (== globalState "right-down") (= blob (moveRightNoCollision (moveDownNoCollision blob))))
             
               (on (& (== swapState 1) (clicked button1)) (= globalState "left"))
               (on (& (== swapState 1) (clicked button2)) (= globalState "right"))
               (on (& (== swapState 1) (clicked button3)) (= globalState "up"))
               (on (& (== swapState 1) (clicked button4)) (= globalState "down"))
               
               (on (& (== swapState 2) (clicked button5)) (= globalState "left-up"))
               (on (& (== swapState 2) (clicked button6)) (= globalState "right-up"))
               (on (& (== swapState 2) (clicked button7)) (= globalState "left-down"))
               (on (& (== swapState 2) (clicked button8)) (= globalState "right-down"))
               
               (on (& (== (prev swapState) 1) (clicked swapButton)) 
                 (let ((= swapState 2)
                       (= globalState "left-up"))))
               
               (on (& (== (prev swapState) 2) (clicked swapButton)) 
                 (let ((= swapState 1)
                       (= globalState "left"))))
             
             )
             """
                )