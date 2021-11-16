include("test_synthesis.jl")

# ----- BEGIN FUNCTIONS ----- #

function check_observations_equivalence(observations1, observations2)
  for i in 1:length(observations1) 
    obs1 = observations1[i]
    obs2 = observations2[i]
    obs1_tuples = sort(map(cell -> (cell.position.x, cell.position.y, cell.color), obs1), by=x -> repr(x))
    obs2_tuples = sort(map(cell -> (cell.position.x, cell.position.y, cell.color), obs2), by=x -> repr(x))
  
    @show obs1_tuples 
    @show obs2_tuples

    if obs1_tuples != obs2_tuples
      @show i
      @show obs1_tuples 
      @show obs2_tuples
      return false
    end
  end
  true
end

function check_match(model_name, program_str)
  observations, user_events, grid_size = generate_observations(model_name)

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


# ----- BEGIN SCRIPT ----- # 

results_folders = readdir("FINAL_RESULTS")
curr_result_folder = filter(x -> !occursin(".txt", x) && !occursin(".DS", x), results_folders)[end]

accuracy_file_name = "FINAL_RESULTS/$(curr_result_folder)/accuracy.txt"

model_folders = filter(x -> !occursin(".DS", x), readdir("FINAL_RESULTS/$(curr_result_folder)"))

# compute accuracies and write to output file
for model_folder in model_folders
  @show model_folder
  alg_accuracies = []
  for alg_folder in ["heuristic", "sketch", "sketch_SINGLE"]
    if alg_folder in readdir("FINAL_RESULTS/$(curr_result_folder)/$(model_folder)")
      @show alg_folder
      full_dir = "FINAL_RESULTS/$(curr_result_folder)/$(model_folder)/$(alg_folder)/program_strings.txt"
      try 
        io = open(full_dir, "r")
        file_contents = read(io, String)
        close(io)
    
        file_parts = filter(x -> x != "", split(file_contents, "\n\n\n\n"))
        non_random_file_parts = filter(x -> !occursin("uniformChoice", x) && !occursin("randomPositions", x), file_parts)
        if length(file_parts) > 0 
          program_str = non_random_file_parts[1]
          matches = check_match(model_folder, program_str)
          push!(alg_accuracies, matches ? "Y" : "N")
        else 
          push!(alg_accuracies, "X")
        end
      catch e 
        push!(alg_accuracies, "X")
      end
    else
      push!(alg_accuracies, "X")
    end
  end

  open(accuracy_file_name, "a") do io 
    println(io, "$(model_folder): $(join(alg_accuracies, " "))")
  end
end

# ----- END SCRIPT ----- #