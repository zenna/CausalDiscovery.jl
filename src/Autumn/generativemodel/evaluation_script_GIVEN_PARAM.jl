

model_name = ARGS[1]

for algorithm in ["heuristic", "sketch_multi", "sketch_single"] 
  solutions_dict = Dict()
  if model_name == "wind"
    solutions_dict["wind"] = @timed synthesize_program("wind", singlecell=false, time_based=true, algorithm=algorithm, upd_func_spaces=[6], z3_option="partial", transition_param=false, sketch_timeout=120, desired_per_matrix_solution_count=5)
  elseif model_name == "disease"
    solutions_dict["disease"] = @timed synthesize_program("disease", singlecell=false, time_based=false, algorithm=algorithm, upd_func_spaces=[6], z3_option="partial", transition_param=false, sketch_timeout=120)
  
  elseif model_name == "gravity_i"
    solutions_dict["gravity_i"] = @timed synthesize_program("gravity_i", singlecell=false, time_based=false, algorithm=algorithm, upd_func_spaces=[6], z3_option="partial", transition_param=false, sketch_timeout=120)
  
  elseif model_name == "gravity_ii"
    solutions_dict["gravity_ii"] = @timed synthesize_program("gravity_ii", singlecell=false, time_based=false, algorithm=algorithm, upd_func_spaces=[6], z3_option="partial", transition_param=false, sketch_timeout=120)
  
  elseif model_name == "gravity_iii"
    solutions_dict["gravity_iii"] = synthesize_program("disease", singlecell=false, time_based=true, algorithm=algorithm, upd_func_spaces=[6], z3_option="partial", transition_param=false, sketch_timeout=120)
  
  elseif model_name == "gravity_iv"
    solutions_dict["gravity_iv"] = @timed synthesize_program("gravity_iv", singlecell=false, time_based=false, algorithm=algorithm, upd_func_spaces=[6], z3_option="partial", transition_param=false, sketch_timeout=120)
  
  elseif model_name == "paint"
    solutions_dict["paint"] = @timed synthesize_program("paint", singlecell=false, time_based=false, algorithm=algorithm, upd_func_spaces=[6], z3_option="partial", transition_param=false, sketch_timeout=120)
  
  elseif model_name == "bullets"
    solutions_dict["bullets"] = @timed synthesize_program("bullets", singlecell=true, time_based=false, algorithm=algorithm, upd_func_spaces=[6], z3_option="partial", transition_param=false, sketch_timeout=120)
  
  elseif model_name == "count_1"
    solutions_dict["count_1"] = @timed synthesize_program("count_1", singlecell=false, time_based=false, algorithm=algorithm, upd_func_spaces=[6], z3_option="partial", transition_param=false, sketch_timeout=120)
  
  elseif model_name == "count_2"
    solutions_dict["count_2"] = @timed synthesize_program("count_2", singlecell=false, time_based=false, algorithm=algorithm, upd_func_spaces=[6], z3_option="partial", transition_param=false, sketch_timeout=120)
  
  elseif model_name == "double_count_1"
    solutions_dict["double_count_1"] = @timed synthesize_program("double_count_1", singlecell=false, time_based=false, algorithm=algorithm, upd_func_spaces=[6], z3_option="partial", transition_param=false, sketch_timeout=120)
  
  elseif model_name == "double_count_2"
    solutions_dict["double_count_2"] = synthesize_program("disease", singlecell=false, time_based=true, algorithm=algorithm, upd_func_spaces=[6], z3_option="partial", transition_param=false, sketch_timeout=120)
  
  elseif model_name == "water_plug"
    solutions_dict["water_plug"] = synthesize_program("disease", singlecell=false, time_based=true, algorithm=algorithm, upd_func_spaces=[6], z3_option="partial", transition_param=false, sketch_timeout=120)
  
  elseif model_name == "mario"
    solutions_dict["mario"] = synthesize_program("disease", singlecell=false, time_based=true, algorithm=algorithm, upd_func_spaces=[6], z3_option="partial", transition_param=false, sketch_timeout=120)
  
  elseif model_name == "count_3"
    solutions_dict["count_3"] = synthesize_program("disease", singlecell=false, time_based=true, algorithm=algorithm, upd_func_spaces=[6], z3_option="partial", transition_param=false, sketch_timeout=120)
  
  elseif model_name == "count_4"
    solutions_dict["count_4"] = synthesize_program("disease", singlecell=false, time_based=true, algorithm=algorithm, upd_func_spaces=[6], z3_option="partial", transition_param=false, sketch_timeout=120)
  
  elseif model_name == "sand"
    solutions_dict["sand"] = @timed synthesize_program("sand", singlecell=false, time_based=false, algorithm=algorithm, upd_func_spaces=[6], z3_option="partial", transition_param=false, sketch_timeout=120)
  end
  
  model_name = ARGS[1]
  save(string("GIVEN_PARAM_DONE_JLD/DONE_$(model_name)_$(algorithm).jld"), model_name, solutions_dict[model_name])
  open("GIVEN_PARAM_DONE_TIME/DONE_$(model_name)_TIME_$(algorithm).txt", "w") do io 
    println(io, solutions_dict[model_name].time)
  end
end
