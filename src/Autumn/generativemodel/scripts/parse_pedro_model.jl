include("../final_evaluation.jl")

model_name = ARGS[1]
date_string = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")

println("START TIME")
println(date_string)
println("CURRENTLY PARSING $(model_name)")

directory_name = "PEDRO_DATA/full_data/$(model_name)"
if !isdir(directory_name)
  mkdir(directory_name)
end

small_directory_name = "PEDRO_DATA/small_data/$(model_name)"
if !isdir(small_directory_name)
  mkdir(small_directory_name)
end

  observations, user_events, grid_size = generate_observations_pedro_interface(model_name)

# small_matrix, small_unformatted_matrix, small_object_decomposition, small_prev_used_rules = singletimestepsolution_matrix(observations[1:25], user_events[1:24], grid_size, singlecell=false, pedro=true, upd_func_space=6)
# small_x = (small_matrix, small_unformatted_matrix, small_object_decomposition, small_prev_used_rules)
# small_existing_files = readdir(small_directory_name)
# JLD.save("$(small_directory_name)/data_$(length(small_existing_files)).jld", "data", small_x)
# println("DONE SMALL!")
matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=true, pedro=true, upd_func_space=6)
x = (matrix, unformatted_matrix, object_decomposition, prev_used_rules)
existing_files = readdir(directory_name)
JLD.save("$(directory_name)/data_$(length(existing_files)).jld", "data", x)
println("DONE LARGE!")

println("END TIME")
date_string = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")
println(date_string)

# attempt solution 