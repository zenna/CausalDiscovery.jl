using JLD 
using Dates
include("../output_match_testing_functions.jl")
include("../verification_scripts/test_set_accuracy.jl")

# ----- BEGIN SCRIPT ----- # 

results_folders = readdir("APRIL_FINAL_RESULTS_AH")
curr_result_folder = filter(x -> !occursin(".txt", x) && !occursin(".DS", x), results_folders)[7]

accuracy_file_name = "APRIL_FINAL_RESULTS_AH/$(curr_result_folder)/accuracy.txt"

model_folders = filter(x -> !occursin(".DS", x), readdir("APRIL_FINAL_RESULTS_AH/$(curr_result_folder)"))

# compute accuracies and write to output file
for model_folder in model_folders
  # # @show model_folder
  alg_accuracies = []
  for alg_folder in ["heuristic", "sketch_multi", "sketch_single"]
    if alg_folder in readdir("APRIL_FINAL_RESULTS_AH/$(curr_result_folder)/$(model_folder)")
      # # @show alg_folder
      full_dir = "APRIL_FINAL_RESULTS_AH/$(curr_result_folder)/$(model_folder)/$(alg_folder)/program_strings.txt"
      try 
        io = open(full_dir, "r")
        file_contents = read(io, String)
        close(io)
    
        file_parts = filter(x -> x != "", split(file_contents, "\n\n\n\n"))
        non_random_file_parts = filter(x -> !occursin("uniformChoice", x) && !occursin("randomPositions", x), file_parts)
        if length(file_parts) > 0 
          program_str = non_random_file_parts[1]
          observations, user_events, grid_size = generate_observations(model_folder)
          matches = check_match_synthesized_and_original(model_folder, program_str, user_events)
          push!(alg_accuracies, matches == 1 ? "Y" : "N")
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