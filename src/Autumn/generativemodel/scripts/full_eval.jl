include("../final_evaluation.jl")

model_name = ARGS[1]
algorithm = ARGS[2]
curr_date = ARGS[3]
iteration = ARGS[4]

println("CURRENTLY WORKING ON $(model_name)")

directory_name = "APRIL_FINAL_RESULTS/$(curr_date)"
if !isdir(directory_name)
  mkdir(directory_name)
end

model_subdirectory_name = "$(directory_name)/$(model_name)"
if !isdir(model_subdirectory_name)
  mkdir(model_subdirectory_name)
end

alg_subdirectory_name = "$(model_subdirectory_name)/$(algorithm)"
if !isdir(alg_subdirectory_name)
  mkdir(alg_subdirectory_name)
end

x = @timed run_model(model_name, algorithm, iteration, 10, 1)
save(string("$(alg_subdirectory_name)/full_data_$(iteration).jld"), model_name, x)

# write final time to time text file 
open("$(alg_subdirectory_name)/times.txt", "a") do io 
  println(io, x.time)
end

# write final program string to program_strings text file 
open("$(alg_subdirectory_name)/program_strings.txt", "a") do io 
  println(io, join(x.value, "\n\n\n\n"))
  println(io, "\n\n\n\n")
end