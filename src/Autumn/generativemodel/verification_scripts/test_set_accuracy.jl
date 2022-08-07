include("../final_evaluation.jl")

test_trace_directory = "/Users/riadas/Documents/urop/CausalDiscoveryApp/saved_test_traces_user_study/"

function check_model_against_test_traces(model_name, program_str)
  model_directory = string(test_trace_directory, model_name)
  files = filter(x -> occursin(".jld", x), readdir(model_directory)) 

  accs = []
  for i in 1:length(files)
    _, user_events, _ = generate_observations_interface(model_name, i, dir=test_trace_directory)

    if i == 2 
      @show user_events
    end

    acc = check_match_synthesized_and_original(model_name, program_str, user_events)
    @show i 
    @show acc
    push!(accs, acc)
  end
  round(Statistics.mean(accs), digits=3)
end

function check_match_synthesized_and_original(model_name, program_str, user_events)
  # first convert user_events to interpreter form 
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

  if occursin("double_count", model_name)
    ground_truth_program_str = programs["double_count"]
  elseif occursin("count", model_name)
    ground_truth_program_str = programs["count"]
  else
    ground_truth_program_str = programs[model_name]
  end

  _, _, grid_size = generate_observations(model_name)

  ground_truth_observations = interpret_over_time_observations(parseautumn(ground_truth_program_str), length(user_events_for_interpreter), user_events_for_interpreter) 
  synthesized_observations = interpret_over_time_observations(parseautumn(program_str), length(user_events_for_interpreter), user_events_for_interpreter)

  ground_truth_observations = filter_out_of_bounds_cells(map(obs -> filter(c -> c.color != "white", obs), ground_truth_observations), grid_size)
  synthesized_observations = filter_out_of_bounds_cells(map(obs -> filter(c -> c.color != "white", obs), synthesized_observations), grid_size)

  check_observations_equivalence(ground_truth_observations, synthesized_observations)
end


function check_observations_equivalence(observations1, observations2)
  for i in 1:length(observations1) 
    obs1 = observations1[i]
    obs2 = observations2[i]
    obs1_tuples = sort(map(cell -> (cell.position.x, cell.position.y, cell.color), obs1), by=x -> repr(x))
    obs2_tuples = sort(map(cell -> (cell.position.x, cell.position.y, cell.color), obs2), by=x -> repr(x))
  
    # # # @show obs1_tuples 
    # # # @show obs2_tuples

    if obs1_tuples != obs2_tuples
      @show i
      # # # @show obs1_tuples 
      # # # @show obs2_tuples
      return (i - 1)/length(observations1)
    end
  end
  1
end


