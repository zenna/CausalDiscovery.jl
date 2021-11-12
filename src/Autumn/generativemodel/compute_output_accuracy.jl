include("test_synthesis.jl")
using Statistics 

function check_observations_equivalence(observations1, observations2)
  for i in 1:length(observations1) 
    obs1 = observations1[i]
    obs2 = observations2[i]
    obs1_tuples = sort(map(cell -> (cell.position.x, cell.position.y, cell.color), obs1), by=x -> repr(x))
    obs2_tuples = sort(map(cell -> (cell.position.x, cell.position.y, cell.color), obs2), by=x -> repr(x))
  
    if obs1_tuples != obs2_tuples
      return false
    end
  end
  true
end

results_folders = readdir("FINAL_RESULTS")
curr_result_folder = results_folders[end]

accuracy_file_name = "FINAL_RESULTS/$(curr_result_folder)/accuracy.txt"

model_folders = readdir("FINAL_RESULTS/$(curr_result_folder)")
for model_folder in model_folders 
  alg_accuracies = []
  for alg_folder in ["heuristic", "sketch", "sketch_SINGLE"]
    io = open("FINAL_RESULTS/$(curr_result_folder)/$(model_folder)/$(alg_folder)/program_strings.txt", "r")
    file_contents = read(io, String)
    close(io)

    file_parts = filter(x -> x != "", split(file_contents, "\n\n\n\n"))
    if length(file_parts) > 0 
      program_str = file_parts[1]
      
      # evaluate this program on the input user event sequence for the model 
      observations, user_events, grid_size = generate_observations(model_folder)

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

      # get observations from new program string 
      @show program_str
      observations_new = interpret_over_time_observations(parseautumn(program_str), length(user_events_for_interpreter), user_events_for_interpreter) 

      # check equivalence 
      matches = check_observations_equivalence(observations, observations_new)
      push!(alg_accuracies, matches ? "Y" : "N")
    else 
      push!(alg_accuracies, "X")
    end
  end
  open(accuracy_file_name, "a") do io 
    println(io, "$(model_folder): $(join(alg_accuracies, " "))")
  end
end

averages_file_name = "FINAL_RESULTS/$(curr_result_folder)/average_times.txt"

function compute_averages() 
  for model_folder in model_folders 
    averages = []
    for alg_folder in ["heuristic", "sketch", "sketch_SINGLE"]
      times_file_name = "FINAL_RESULTS/$(curr_result_folder)/$(model_folder)/$(alg_folder)/times.txt"
      times_file = open(times_file_name, "r")
      times_file_content = read(times_file, String)
      close(times_file)

      times = map(time_str -> parse(Float64, time_str), filter(x -> x != "", split(times_file_content, "\n")))
      average_time = round(Statistics.mean(times)/60)
      push!(averages, average_time)
    end
    # write averages to file
    open(averages_file_name, "a") do io 
      println(io, "$(model_folder): $(join(averages, " "))")
    end
  end  
end

compute_averages()