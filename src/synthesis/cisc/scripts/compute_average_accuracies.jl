using JLD 
using Dates
using Statistics 

results_folders = readdir("FINAL_RESULTS")
curr_result_folder = filter(x -> !occursin(".txt", x) && !occursin(".DS", x), results_folders)[end]

time_averages_file_name = "FINAL_RESULTS/$(curr_result_folder)/average_times.txt"

model_folders = filter(x -> !occursin(".DS", x) && !occursin(".txt", x), readdir("FINAL_RESULTS/$(curr_result_folder)"))

# compute averages and write to output file
for model_folder in model_folders
  # # @show model_folder
  averages = []
  for alg_folder in ["heuristic", "sketch_multi", "sketch_single"]
    if alg_folder in readdir("FINAL_RESULTS/$(curr_result_folder)/$(model_folder)")
      # # @show alg_folder
      times_file_name = "FINAL_RESULTS/$(curr_result_folder)/$(model_folder)/$(alg_folder)/times.txt"
      try 
        times_file = open(times_file_name, "r")
        times_file_content = read(times_file, String)
        close(times_file)

        times = map(time_str -> parse(Float64, time_str), filter(x -> x != "", split(times_file_content, "\n")))
        average_time = round(Statistics.mean(times))
        push!(averages, average_time)
      catch e 
        push!(averages, -1)
      end
    else
      push!(averages, -1)
    end
  end

  open(time_averages_file_name, "a") do io 
    println(io, "$(model_folder): $(join(averages, " "))")
  end
end

