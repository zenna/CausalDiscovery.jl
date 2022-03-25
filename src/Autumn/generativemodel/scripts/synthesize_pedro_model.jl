include("../final_evaluation.jl")

# first construct matrix 
include("parse_pedro_model.jl")

model_name = ARGS[1]
# size = ARGS[2] # "small" or "full"

directory_name = "PEDRO_DATA/full_data/$(model_name)"

# read observations from file 
observations, user_events, grid_size = generate_observations_pedro_interface(model_name)

# read update function matrix from file
files = filter(x -> occursin(".jld", x), readdir(directory_name))
file_name = string(directory_name, "/", "data_$(length(files) - 1).jld")
matrix, unformatted_matrix, object_decomposition, prev_used_rules = JLD.load(file_name)["data"]

# run synthesizer 
redundant_events_set = Set()
global_event_vector_dict = Dict()
println("YAY BEGIN SYNTHESIS")
solutions = @timed generate_on_clauses_GLOBAL(string("attempt_", model_name), matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size)
println("YAY END SYNTHESIS")

# save solutions in .JLD 
output_directory = "PEDRO_SYNTHESIS/$(model_name)"
if !isdir(output_directory)
  mkdir(output_directory)
  mkdir(string(output_directory, "/", "program_strings"))
  mkdir(string(output_directory, "/", "full_outputs"))
end
existing_files = filter(f -> occursin(".jld", f), readdir(string(output_directory, "/", "full_outputs")))
x = (matrix, unformatted_matrix, object_decomposition, prev_used_rules)
JLD.save("$(output_directory)/full_outputs/data_$(length(existing_files)).jld", "data", x)

# write program string to file
program_strings_directory = string(output_directory, "/", "program_strings") 
program_strings = []
for solution in solutions.value 
  if solution[1] != [] 
    on_clauses, new_object_decomposition, global_var_dict = solution
    @show on_clauses 
    
    program = full_program_given_on_clauses(on_clauses, new_object_decomposition, global_var_dict, grid_size, matrix)
    push!(program_strings, program)
  end
end

open("$(program_strings_directory)/$(length(existing_files)).txt","w") do io
  println(io, join(program_strings, "\n\n\n\n\n\n"))
end

println("DONE LARGE SYNTHESIS!")