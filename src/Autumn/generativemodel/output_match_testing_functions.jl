# ----- BEGIN FUNCTIONS ----- #

function check_observations_equivalence(observations1, observations2)
  for i in 1:length(observations1) 
    obs1 = observations1[i]
    obs2 = observations2[i]
    obs1_tuples = sort(map(cell -> (cell.position.x, cell.position.y, cell.color), obs1), by=x -> repr(x))
    obs2_tuples = sort(map(cell -> (cell.position.x, cell.position.y, cell.color), obs2), by=x -> repr(x))
  
    # # @show obs1_tuples 
    # # @show obs2_tuples

    if obs1_tuples != obs2_tuples
      @show i
      # @show obs1_tuples 
      # @show obs2_tuples
      return false
    end
  end
  true
end

function check_match(model_name, program_str; pedro=false)
  if pedro 
    observations, user_events, grid_size = generate_observations_pedro_interface(model_name)
  else
    observations, user_events, grid_size = generate_observations(model_name)
  end

  # convert user_events to interpreter-appropriate format
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

  observations_new = interpret_over_time_observations(parseautumn(program_str), length(user_events_for_interpreter), user_events_for_interpreter) 
  check_observations_equivalence(observations, observations_new)
end

# ----- END FUNCTIONS ----- # 

model_names = readdir("may_results_sketch")

random_models = []
nonrandom_models = []
for model_name in model_names
  files = readdir("may_results_sketch/$(model_name)")
  if files != []
    @show model_name 
    open("may_results_sketch/$(model_name)/output_program.txt", "r") do io
      program_str = read(io, String)
      println(program_str)
      if occursin("uniformChoice", program_str) || occursin("Random", program_str)
        println("random")
        push!(random_models, model_name)
      else
        println("nonrandom")
        push!(nonrandom_models, model_name)
      end

    end
  end
end