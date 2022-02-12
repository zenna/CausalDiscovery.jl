include("../final_evaluation.jl")

model_name = ARGS[1]

println("CURRENTLY PARSING $(model_name)")

directory_name = "PEDRO_DATA/$(model_name)"
if !isdir(directory_name)
  mkdir(directory_name)
end

observations, user_events, grid_size = generate_observations_pedro_interface(model_name)
matrix, unformatted_matrix, object_decomposition, prev_used_rules = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=false, pedro=true, upd_func_space=6)
x = (matrix, unformatted_matrix, object_decomposition, prev_used_rules)
# write final time to time text file 
existing_files = readdir(directory_name)
JLD.save("$(directory_name)/data_$(length(existing_files)).jld", "data", x)