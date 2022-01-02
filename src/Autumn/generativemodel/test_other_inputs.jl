include("test_synthesis.jl")
include("output_match_testing_functions.jl")

function test_random_other_inputs_given_orig(model_name, new_program_str; num_inputs::Int=10, input_len::Int=30, nothing_threshold=0.5)
  _, user_events, _ = generate_observations(model_name) 
  other_inputs = generate_multiple_random_inputs_given_orig(num_inputs, user_events, input_len, nothing_threshold)
  test_given_other_inputs(model_name, new_program_str, other_inputs)
end

function test_random_other_inputs(model_name, new_program_str; num_inputs::Int=10, input_len::Int=30)
  _, _, grid_size = generate_observations(model_name) 
  other_inputs = generate_multiple_random_inputs(num_inputs, input_len, grid_size)
  test_given_other_inputs(model_name, new_program_str, other_inputs)
end

function test_given_other_inputs(model_name, new_program_str, seqs)
  bools = []
  for seq in seqs 
    bool = matches_other_input(model_name, new_program_str, seq)
    push!(bools, bool)
  end
  Statistics.mean(bools), bools  
end

"""Check if ground-truth and synthesized programs produce same observations for given user event sequence"""
function matches_other_input(model_name, new_program_str, user_events)
  @show user_events
  # currently, the original programs are run via the compiler, instead of the 
  # interpreter; this should be changed, but we temporarily use the compiler here 
  observations_old = generate_observations_custom_input(model_name, user_events)  

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

  observations_new = interpret_over_time_observations(parseautumn(new_program_str), length(user_events_for_interpreter), user_events_for_interpreter) 

  check_observations_equivalence(observations_old, observations_new)
end

"""Generate multiple random inputs (user event sequences)"""
function generate_multiple_random_inputs(num_inputs, input_len::Int=30, grid_size::Int=16)
  seqs = [] 
  for i in 1:num_inputs 
    user_events = generate_random_input(input_len, grid_size)
    push!(seqs, user_events)
  end
  seqs
end

"""Generate multiple random inputs (user event sequences) using only events found in given user event sequence"""
function generate_multiple_random_inputs_given_orig(num_inputs, orig_user_events, input_len::Int=30, nothing_threshold=0.5) 
  seqs = [] 
  for i in 1:num_inputs 
    user_events = generate_random_input_given_orig(orig_user_events, input_len)
    push!(seqs, user_events)
  end
  seqs
end

"""Generate random input (user event sequence)"""
function generate_random_input(input_len::Int=30, grid_size::Int=16)
  event_choices = ["left", "right", "up", "down", "click", "nothing"]
  user_events = []

  for i in 1:input_len 
    event = rand(event_choices)
    if event == "click"
      x = rand(0:(grid_size - 1))
      y = rand(0:(grid_size - 1))
      push!(user_events, "click $(x) $(y)")
    else
      push!(user_events, event)
    end
  end
  user_events
end

"""Generate random input (user event sequence) using only events found in given user event sequence"""
function generate_random_input_given_orig(orig_user_events, input_len::Int=30, nothing_threshold=0.5)
  events = filter(e -> !isnothing(e) && e != "nothing", orig_user_events)
  new_events = []
  for i in 1:input_len 
    if rand() < nothing_threshold
      push!(new_events, "nothing")
    else
      push!(new_events, rand(events))
    end
  end
  new_events
end

