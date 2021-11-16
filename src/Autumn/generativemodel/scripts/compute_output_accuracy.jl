include("../test_synthesis.jl")
include("../output_match_testing_functions.jl")

# ----- BEGIN SCRIPT ----- # 

results_folders = readdir("FINAL_RESULTS")
curr_result_folder = filter(x -> !occursin(".txt", x) && !occursin(".DS", x), results_folders)[end]

accuracy_file_name = "FINAL_RESULTS/$(curr_result_folder)/accuracy.txt"

model_folders = filter(x -> !occursin(".DS", x), readdir("FINAL_RESULTS/$(curr_result_folder)"))

# compute accuracies and write to output file
for model_folder in model_folders
  @show model_folder
  alg_accuracies = []
  for alg_folder in ["heuristic", "sketch_multi", "sketch_single"]
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