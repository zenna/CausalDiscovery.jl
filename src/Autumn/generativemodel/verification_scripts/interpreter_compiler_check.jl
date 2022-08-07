include("../final_evaluation.jl")

function check_observations_equivalence(observations1, observations2)
  for i in 1:length(observations1) 
    obs1 = observations1[i]
    obs2 = observations2[i]
    obs1_tuples = sort(map(cell -> (cell.position.x, cell.position.y, cell.color), obs1), by=x -> repr(x))
    obs2_tuples = sort(map(cell -> (cell.position.x, cell.position.y, cell.color), obs2), by=x -> repr(x))
  
    # # # @show obs1_tuples 
    # # # @show obs2_tuples

    if obs1_tuples != obs2_tuples
      # @show i
      # # # @show obs1_tuples 
      # # # @show obs2_tuples
      return false
    end
  end
  true
end

function check_evaluation_equivalence(model_name)
  if occursin("double_count", model_name)
    program_str = programs["double_count"]
  elseif occursin("count", model_name)
    program_str = programs["count"]
  else
    program_str = programs[model_name]
  end

  # observations from compiler
  observations, user_events, grid_size = generate_observations(model_name)

  # observations from interpreter 
  ## first convert user_events to interpreter form 
  user_events_for_interpreter = []
  for e in user_events 
    if isnothing(e) || e == "nothing"
      push!(user_events_for_interpreter, Dict())
    elseif e == "left"
      push!(user_events_for_interpreter, Dict(:left => true))
    elseif e == "right"
      push!(user_events_for_interpreter, Dict(:right => true))
    elseif e == "up"
      push!(user_events_for_interpreter, Dict(:up => true))
    elseif e == "down"
      push!(user_events_for_interpreter, Dict(:down => true))
    else
      x = parse(Int, split(e, " ")[2])
      y = parse(Int, split(e, " ")[3])
      push!(user_events_for_interpreter, Dict(:click => AutumnStandardLibrary.Click(x, y)))
    end
  end

  observations_from_interpreter = interpret_over_time_observations(parseautumn(program_str), length(user_events_for_interpreter), user_events_for_interpreter) 

  check_observations_equivalence(observations, filter_out_of_bounds_cells(map(obs -> filter(c -> c.color != "white", obs), observations_from_interpreter), grid_size))
end

all_deterministic_model_names = [
  # "magnets_i",
  # "sokoban_i",
  # "ice",
  # "lights",
  # "disease",
  # "grow",
  # "sand",
  # "bullets",
  # "gravity_i",
  # "gravity_ii",
  # "gravity_iii",
  # "gravity_iv",
  # "count_1",
  # "count_2",
  # "count_3",
  # "count_4",
  # "count_5",
  # "double_count_1",
  # "double_count_2",
  # "wind",
  # "paint",
  # "mario",
  # "water_plug",
]

for model_name in all_deterministic_model_names
  # @show model_name
  if !check_evaluation_equivalence(model_name)
    println("$(model_name): FALSE") 
  else
    println("$(model_name): TRUE")
  end
end