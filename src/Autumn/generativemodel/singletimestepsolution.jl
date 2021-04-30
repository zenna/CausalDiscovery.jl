using Autumn
using MacroTools: striplines
include("generativemodel.jl")

"""Construct matrix of single timestep solutions"""
function singletimestepsolution_matrix(observations, user_events, grid_size)
  object_decomposition = parse_and_map_objects(observations)
  object_types, object_mapping, background, _ = object_decomposition
  # matrix of update function sets for each object/time pair
  # number of rows = number of objects, number of cols = number of time steps  
  num_objects = length(collect(keys(object_mapping)))
  matrix = [[] for object_id in 1:num_objects, time in 1:(length(observations) - 1)]
  
  # SEED PREV USED RULES FOR EFFIENCY AT THE MOMENT
  prev_used_rules = ["(= objX (prev objX))",
                     "(= objX (moveLeft objX))",
                     "(= objX (moveRight objX))",
                    #  "(= objX (moveUpNoCollision objX))",
                    #  "(= objX (moveDownNoCollision objX))",
                     "(= objX (nextLiquid objX))",
                     "(= objX (nextSolid objX))",] # prev_used_rules = []

  prev_abstract_positions = []
  
  @show size(matrix)
  # for each subsequent frame, map objects
  for time in 2:length(observations)
    # for each object in previous time step, determine a set of update functions  
    # that takes the previous object to the next object
    for object_id in 1:num_objects
      update_functions, prev_used_rules, prev_abstract_positions = synthesize_update_functions(object_id, time, object_decomposition, user_events, prev_used_rules, prev_abstract_positions, grid_size)
      @show update_functions 
      if length(update_functions) == 0
        println("HOLY SHIT")
      end
      matrix[object_id, time - 1] = update_functions 
    end
  end
  matrix, object_decomposition, prev_used_rules
end

expr = nothing
mod = nothing
global_iters = 0
"""Synthesize a set of update functions that """
function synthesize_update_functions(object_id, time, object_decomposition, user_events, prev_used_rules, prev_abstract_positions, grid_size=16, max_iters=5)
  object_types, object_mapping, background, _ = object_decomposition
  @show object_id 
  @show time
  prev_object = object_mapping[object_id][time - 1]
  
  next_object = object_mapping[object_id][time]
  #@show object_id 
  #@show time
  #@show prev_object 
  #@show next_object
  # @show isnothing(prev_object) && isnothing(next_object)
  if isnothing(prev_object) && isnothing(next_object)
    [""], prev_used_rules, prev_abstract_positions
  elseif isnothing(prev_object)
    # perform position abstraction step
    prev_objects = filter(obj -> !isnothing(obj), [object_mapping[id][time - 1] for id in 1:length(collect(keys(object_mapping)))])
    prev_objects = filter(obj -> !isnothing(object_mapping[obj.id][1]), prev_objects)
    abstracted_positions, prev_abstract_positions = abstract_position(next_object.position, prev_abstract_positions, (object_types, prev_objects, background, grid_size))

    if length(next_object.custom_field_values) > 0
      abstracted_strings = abstract_string(next_object.custom_field_values[1], (object_types, prev_objects, background, grid_size))
      abstracted_string = abstracted_strings[1]
      abstracted_position = abstracted_positions[1]
      update_rules = [
        """(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(join(map(v -> """ "$(v)" """, next_object.custom_field_values), " ")) $(abstracted_position))))""",
        """(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(join(map(v -> """ "$(v)" """, next_object.custom_field_values), " ")) (Position $(next_object.position[1]) $(next_object.position[2])))))""",
        """(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(abstracted_string) $(abstracted_position))))""",
        """(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(abstracted_string) $(next_object.position[1]) $(next_object.position[2])))))""",
      ]
      update_rules, prev_used_rules, prev_abstract_positions
    else
      update_rules = map(pos -> 
      "(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(join(map(v -> """ "$(v)" """, next_object.custom_field_values), " ")) $(pos))))",
      abstracted_positions)
      vcat(update_rules..., "(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(join(map(v -> """ "$(v)" """, next_object.custom_field_values), " ")) (Position $(next_object.position[1]) $(next_object.position[2])))))"), prev_used_rules, prev_abstract_positions
    end
  elseif isnothing(next_object)
    if object_mapping[object_id][1] == nothing # object was added later; contained in addedList
      ["(= addedObjType$(prev_object.type.id)List (removeObj addedObjType$(prev_object.type.id)List (--> obj (== (.. obj id) $(object_id)))))"], prev_used_rules, prev_abstract_positions
    else # object was present at the start of the program
      ["(= obj$(object_id) (removeObj obj$(object_id)))"], prev_used_rules, prev_abstract_positions
    end
  else # actual synthesis problem
    prev_objects = filter(obj -> !isnothing(obj) && (obj.id != prev_object.id), [object_mapping[id][time - 1] for id in 1:length(collect(keys(object_mapping)))])
    #@show prev_objects
    solutions = []
    iters = 0
    prev_used_rules_index = 1
    using_prev = false
    while length(solutions) < 3 && iters < max_iters
      hypothesis_program = program_string_synth((object_types, sort([prev_objects..., prev_object], by=(x -> x.id)), background, grid_size))
      if (prev_object.custom_field_values != []) && (next_object.custom_field_values != []) && (prev_object.custom_field_values[1] != next_object.custom_field_values[1])
        update_rule = """(= obj$(object_id) (updateObj obj$(object_id) "color" "$(next_object.custom_field_values[1])"))"""
      elseif prev_used_rules_index <= length(prev_used_rules)
        update_rule = replace(prev_used_rules[prev_used_rules_index], "objX" => "obj$(object_id)")
        using_prev = true
        prev_used_rules_index += 1
      else
        using_prev = false
        update_rule = generate_hypothesis_update_rule(prev_object, (object_types, prev_objects, background, grid_size), p=0.2) # "(= obj1 (moveDownNoCollision (moveDownNoCollision (prev obj1))))"
      end      
      
      hypothesis_program = string(hypothesis_program[1:end-2], "\n\t (on true ", update_rule, ")\n)")
      println("HYPOTHESIS_PROGRAM")
      println(prev_object)
      println(hypothesis_program)
      # @show global_iters
      # @show update_rule

      global expr = striplines(compiletojulia(parseautumn(hypothesis_program)))
      #@show expr
      module_name = Symbol("CompiledProgram$(global_iters)")
      global expr.args[1].args[2] = module_name
      # @show expr.args[1].args[2]
      global mod = @eval $(expr)
      # @show repr(mod)
      hypothesis_frame_state = @eval mod.next(mod.init(nothing, nothing, nothing, nothing, nothing), nothing, nothing, nothing, nothing, nothing)
      
      hypothesis_object = filter(o -> o.id == object_id, hypothesis_frame_state.scene.objects)[1]
      #@show hypothesis_frame_state.scene.objects
      #@show hypothesis_object

      if render_equals(hypothesis_object, next_object)
        if using_prev
          println("HOORAY")
        end
        generic_update_rule = replace(update_rule, "obj$(object_id)" => "objX")
        if !(generic_update_rule in prev_used_rules) && !(occursin("color", generic_update_rule))
          push!(prev_used_rules, generic_update_rule)
        end
        if occursin("color", update_rule) 
          global global_iters += 1
          curr_objects = filter(obj -> !isnothing(obj), [object_mapping[id][time - 1] for id in 1:length(collect(keys(object_mapping)))])
          curr_objects = filter(obj -> !isnothing(object_mapping[obj.id][1]), curr_objects)
          abstracted_strings = abstract_string(next_object.custom_field_values[1], (object_types, curr_objects, background, grid_size))
          abstracted_string = abstracted_strings[1]

          if object_mapping[object_id][1] == nothing # object was added later; contained in addedList
            push!(solutions, """(= addedObjType$(prev_object.type.id)List (updateObj addedObjType$(prev_object.type.id)List (--> obj (updateObj obj "color" $(abstracted_string))) (--> obj (== (.. obj id) $(object_id)))))""")
          else # object was present at the start of the program
            push!(solutions, """(= obj$(object_id) (updateObj obj$(object_id) "color" $(abstracted_string)))""")
          end
        else
          if object_mapping[object_id][1] == nothing # object was added later; contained in addedList
            map_lambda_func = replace(string("(-->", replace(update_rule, "obj$(object_id)" => "obj")[3:end]), "(prev obj)" => "obj")
            push!(solutions, "(= addedObjType$(prev_object.type.id)List (updateObj addedObjType$(prev_object.type.id)List $(map_lambda_func) (--> obj (== (.. obj id) $(object_id)))))")
          else # object was present at the start of the program
            push!(solutions, update_rule)
          end
        end
      end
      
      iters += 1
      global global_iters += 1
      
    end
    if (iters == max_iters)
      println("FAILURE")
    end
    solutions, prev_used_rules, prev_abstract_positions
  end
end

"""Parse observations into object types and objects, and assign 
   objects in current observed frame to objects in next frame"""
function parse_and_map_objects(observations)
  object_mapping = Dict{Int, Array{Union{Nothing, Obj}}}()

  # check if observations contains frames with overlapping cells
  overlapping_cells = foldl(|, map(frame -> has_dups(map(cell -> (cell.position.x, cell.position.y), frame)), observations), init=false)
  println("OVERLAPPING_CELLS")
  println(overlapping_cells)
  # construct object_types
  ## initialize object_types based on first observation frame
  if overlapping_cells
    object_types, _, background, dim = parsescene_autumn_singlecell(observations[1])
  else
    object_types, _, background, dim = parsescene_autumn(observations[1])
  end

  ## iteratively build object_types through each subsequent observation frame
  for time in 2:length(observations)
    if overlapping_cells
      object_types, _, _, _ = parsescene_autumn_singlecell_given_types(observations[time], object_types)
    else
      object_types, _, _, _ = parsescene_autumn_given_types(observations[time], object_types)
    end
  end

  if overlapping_cells
    _, objects, _, _ = parsescene_autumn_singlecell_given_types(observations[1], object_types)
  else
    _, objects, _, _ = parsescene_autumn_given_types(observations[1], object_types)
  end

  for object in objects
    object_mapping[object.id] = [object]
  end

  for time in 2:length(observations)
    if overlapping_cells
      _, next_objects, _, _ = parsescene_autumn_singlecell_given_types(observations[time], object_types) # parsescene_autumn_singlecell
    else
      _, next_objects, _, _ = parsescene_autumn_given_types(observations[time], object_types) # parsescene_autumn_singlecell
    end
    # construct mapping between objects and next_objects
    for type in object_types
      curr_objects_with_type = filter(o -> o.type.id == type.id, objects)
      next_objects_with_type = filter(o -> o.type.id == type.id, next_objects)
      
      closest_objects = compute_closest_objects(curr_objects_with_type, next_objects_with_type)
      while !(isempty(curr_objects_with_type) || isempty(next_objects_with_type)) 
        for (object_id, closest_ids) in closest_objects
          if length(intersect(closest_ids, map(o -> o.id, next_objects_with_type))) == 1
            closest_id = intersect(closest_ids, map(o -> o.id, next_objects_with_type))[1]
            next_object = filter(o -> o.id == closest_id, next_objects_with_type)[1]

            # remove curr and next objects from respective lists
            filter!(o -> o.id != object_id, curr_objects_with_type)
            filter!(o -> o.id != closest_id, next_objects_with_type)
            delete!(closest_objects, object_id)
            
            # add next object to mapping
            next_object.id = object_id
            push!(object_mapping[object_id], next_object)
          end

          if length(collect(keys(filter(pair -> length(intersect(last(pair), map(o -> o.id, next_objects_with_type))) == 1, closest_objects)))) == 0
            # every remaining object to be mapped is equidistant to at least two closest objects, or zero objects
            # perform a brute force assignment
            while !isempty(curr_objects_with_type) && !isempty(next_objects_with_type)
              # do something
              object = curr_objects_with_type[1]
              next_object = next_objects_with_type[1]
              @show curr_objects_with_type
              @show next_objects_with_type
              curr_objects_with_type = filter(o -> o.id != object.id, curr_objects_with_type)
              next_objects_with_type = filter(o -> o.id != next_object.id, next_objects_with_type)
              
              next_object.id = object.id
              push!(object_mapping[object.id], next_object)
            end
            break
          end
        end
      end

      max_id = length(collect(keys(object_mapping)))
      if isempty(curr_objects_with_type) && !(isempty(next_objects_with_type))
        # handle addition of objects
        for i in 1:length(next_objects_with_type)
          next_object = next_objects_with_type[i]
          next_object.id = max_id + i
          object_mapping[next_object.id] = [[nothing for i in 1:(time - 1)]..., next_object]
        end
      elseif !(isempty(curr_objects_with_type)) && isempty(next_objects_with_type)
        # handle removal of objects
        for object in curr_objects_with_type
          push!(object_mapping[object.id], [nothing for i in time:length(observations)]...)
        end
      end
    end

    objects = next_objects

  end
  (object_types, object_mapping, background, dim)  
end

function compute_closest_objects(curr_objects, next_objects)
  closest_objects = Dict{Int, AbstractArray}()
  for object in curr_objects
    distances = map(o -> distance(object.position, o.position), next_objects)
    closest_objects[object.id] = map(obj -> obj.id, filter(o -> distance(object.position, o.position) == minimum(distances), next_objects))
  end
  closest_objects
end

function distance(pos1, pos2)
  pos1_x, pos1_y = pos1
  pos2_x, pos2_y = pos2
  # sqrt(Float((pos1_x - pos2_x)^2 + (pos1_y - pos2_y)^2))
  abs(pos1_x - pos2_x) + abs(pos1_y - pos2_y)
end

function render_equals(hypothesis_object, actual_object)
  translated_hypothesis_object = map(cell -> (cell.position.x + hypothesis_object.origin.x, cell.position.y + hypothesis_object.origin.y), hypothesis_object.render)
  translated_actual_object = map(pos -> (pos[1] + actual_object.position[1], pos[2] + actual_object.position[2]), actual_object.type.shape)
  translated_hypothesis_object == translated_actual_object
end

function generate_observations(m::Module)
  state = m.init(nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, m.render(state.scene))

  for i in 0:20
    if i in [2, 7, 12, 17]
      # state = m.next(state, nothing, nothing, nothing, nothing, nothing)
      state = m.next(state, nothing, nothing, nothing, nothing, mod.Down())
      push!(user_events, "down")
    elseif i == 10
      state = m.next(state, nothing, nothing, mod.Right(), nothing, nothing)
      push!(user_events, "right")
    elseif i == 5 || i == 16
      state = m.next(state, mod.Click(rand(1:6),rand(1:6)), nothing, nothing, nothing, nothing)
      push!(user_events, "clicked")
    else
      state = m.next(state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, m.render(state.scene))
  end

  # for i in 0:20
  #   if i == 2 || i == 7 || i == 12
  #     # state = m.next(state, nothing, nothing, nothing, nothing, nothing)
  #     state = m.next(state, nothing, nothing, nothing, nothing, mod.Down())
  #   elseif i == 14
  #     state = m.next(state, nothing, nothing, mod.Left(), nothing, nothing)
  #   elseif i == 4 || i == 16
  #     state = m.next(state, mod.Click(rand(1:6),rand(1:6)), nothing, nothing, nothing, nothing)      
  #   else
  #     state = m.next(state, nothing, nothing, nothing, nothing, nothing)
  #   end
  #   push!(observations, m.render(state.scene))
  # end
  observations, user_events
end

function singletimestepsolution_program(observations, grid_size=16)
  
  matrix, object_decomposition, _ = singletimestepsolution_matrix(observations, [], grid_size)
  singletimestepsolution_program_given_matrix(matrix, object_decomposition, grid_size)
end

function singletimestepsolution_program_given_matrix(matrix, object_decomposition, grid_size=16)
  object_types, object_mapping, background, _ = object_decomposition
  
  objects = sort(filter(obj -> obj != nothing, [object_mapping[i][1] for i in 1:length(collect(keys(object_mapping)))]), by=(x -> x.id))
  
  program_no_update_rules = program_string_synth((object_types, objects, background, grid_size))
  
  list_variables = join(map(type -> 
  """(: addedObjType$(type.id)List (List ObjType$(type.id)))\n  (= addedObjType$(type.id)List (initnext (list) (prev addedObjType$(type.id)List)))\n""", 
  object_types),"\n  ")
  
  time = """(: time Int)\n  (= time (initnext 0 (+ time 1)))"""

  update_rule_times = filter(time -> join(map(l -> l[1], matrix[:, time]), "") != "", [1:size(matrix)[2]...])
  update_rules = join(map(time -> """(on (== time $(time - 1))\n  (let\n    ($(join(map(l -> l[1], matrix[:, time]), "\n    "))))\n  )""", update_rule_times), "\n  ")
  
  string(program_no_update_rules[1:end-2], 
        "\n\n  $(list_variables)",
        "\n\n  $(time)", 
        "\n\n  $(update_rules)", 
        ")")
end

function has_dups(list::AbstractArray)
  length(unique(list)) != length(list) 
end

function abstract_position(position, prev_abstract_positions, object_decomposition, max_iters=100)
  object_types, environment_vars, _, _ = object_decomposition
  solutions = []
  iters = 0
  prev_used_index = 1
  using_prev = false
  while length(solutions) != 1 && iters < max_iters  
    
    if prev_used_index <= length(prev_abstract_positions)
      hypothesis_position = prev_abstract_positions[prev_used_index]
      using_prev = true
      prev_used_index += 1
    else
      using_prev = false
      hypothesis_position = generate_hypothesis_position(position, environment_vars)
    end
    hypothesis_position_program = generate_hypothesis_position_program(hypothesis_position, position, object_decomposition)
    println("HYPOTHESIS PROGRAM")
    println(hypothesis_position_program)
    global expr = striplines(compiletojulia(parseautumn(hypothesis_position_program)))
    #@show expr
    module_name = Symbol("CompiledProgram$(global_iters)")
    global expr.args[1].args[2] = module_name
    # @show expr.args[1].args[2]
    global mod = @eval $(expr)
    # @show repr(mod)
    hypothesis_frame_state = @eval mod.next(mod.init(nothing, nothing, nothing, nothing, nothing), nothing, nothing, nothing, nothing, nothing)
    hypothesis_matches = hypothesis_frame_state.matchesHistory[1]
    if hypothesis_matches
      # success 
      println("SUCCESS")
      push!(solutions, hypothesis_position)
      if !(hypothesis_position in prev_abstract_positions)
        push!(prev_abstract_positions, hypothesis_position)
      end
    end

    iters += 1
    global global_iters += 1
  end
  solutions, prev_abstract_positions
end

function abstract_string(string, object_decomposition, max_iters=50)
  object_types, environment_vars, _, _ = object_decomposition
  solutions = []
  iters = 0
  while length(solutions) != 1 && iters < max_iters  
    hypothesis_string = generate_hypothesis_string(string, environment_vars, object_types)
    hypothesis_string_program = generate_hypothesis_string_program(hypothesis_string, string, object_decomposition)
    println("HYPOTHESIS PROGRAM")
    println(hypothesis_string_program)
    global expr = striplines(compiletojulia(parseautumn(hypothesis_string_program)))
    #@show expr
    module_name = Symbol("CompiledProgram$(global_iters)")
    global expr.args[1].args[2] = module_name
    # @show expr.args[1].args[2]
    global mod = @eval $(expr)
    # @show repr(mod)
    hypothesis_frame_state = @eval mod.next(mod.init(nothing, nothing, nothing, nothing, nothing), nothing, nothing, nothing, nothing, nothing)
    hypothesis_matches = hypothesis_frame_state.matchesHistory[1]
    if hypothesis_matches
      # success 
      push!(solutions, hypothesis_string)
    end

    iters += 1
    global global_iters += 1
  end
  solutions
end

function generate_on_clauses(matrix, object_decomposition, user_events, grid_size=16)
  on_clauses = []
  object_types, object_mapping, background, dim = object_decomposition

  for object_type in object_types
    object_ids = sort(filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == object_type.id, collect(keys(object_mapping))))

    if length(object_ids) == 1
      object_trajectory = map(s -> replace(s, "id) $(object_ids[1])" => "id) x"), matrix[object_ids[1], :])
      object_id = -1
    elseif length(object_ids) > 1
      # compute the union of different update rules
      object_trajectories = map(id -> matrix[id, :], object_ids)
      for i in 1:length(object_trajectories)
        id = object_ids[i]
        @show id 
        @show object_trajectories[i] 
        object_trajectories[i] = map(list -> map(s -> replace(s, "id) $(id)" => "id) x"), list), object_trajectories[i])
      end
      distinct_update_rules = intersect(map(trajectory -> unique(vcat(trajectory...)), object_trajectories)...)

      # eliminate update rules that do not appear in intersection of all trajectories 
      for trajectory in object_trajectories
        for time in 1:length(trajectory)
          trajectory[time] = filter(update_rule -> update_rule in distinct_update_rules, trajectory[time])
        end
      end
      num_singleton_update_rule_sets = map(trajectory -> count(list -> length(list) == 1 && list != [""] && !(foldl(|, map(s -> occursin("color", s), list), init=false)), trajectory), object_trajectories)
      object_trajectory = object_trajectories[findall(x -> x == maximum(num_singleton_update_rule_sets), num_singleton_update_rule_sets)[1]]
      object_id = object_ids[findall(x -> x == maximum(num_singleton_update_rule_sets), num_singleton_update_rule_sets)[1]]
    end
    
    # simplify object trajectory so that each time step has exactly one update function 
    
    singleton_set_times = findall(update_rule_set -> length(update_rule_set) == 1 && update_rule_set != [""], object_trajectory)
    @show object_trajectory
    @show singleton_set_times
    for i in 0:length(singleton_set_times)
      if i == 0
        start_time = 1
        end_time = singleton_set_times[i + 1]
      elseif i == length(singleton_set_times)
        start_time = singleton_set_times[i]
        end_time = length(object_trajectory)
      else
        start_time = singleton_set_times[i]
        end_time = singleton_set_times[i + 1]
      end

      if (end_time - start_time) > 1
        most_common_rule = mode(vcat(object_trajectory[start_time:end_time]...))
        for time in (start_time + 1):(end_time - 1)
          object_trajectory[time] = [most_common_rule]
        end
        if !(end_time in singleton_set_times)
          object_trajectory[end_time] = [most_common_rule]
        end
      end

    end

    # determine an event predicate for each update function except for the no-change update function 
    distinct_update_rules = unique(vcat(object_trajectory...))
    for update_rule in distinct_update_rules
      if update_rule != "" && !is_no_change_rule(update_rule)
        println("UPDATE_RULEEE")
        println(update_rule)
        println(object_trajectory)
        println(findall(rule -> rule == update_rule, map(l -> l[1], object_trajectory)))
        event = generate_event(update_rule, object_trajectory, matrix, object_decomposition, user_events)
        
        # collect all objects of type object_type
        reformatted_update_rules = []
        if occursin("addObj", update_rule) && object_id != -1
          push!(reformatted_update_rules, replace(update_rule, " id) x" => " id) $(object_id)"))
        else 
          push!(reformatted_update_rules, replace(update_rule, "(--> obj (== (.. obj id) x))" => ""))
        end
        on_clause = "(on $(event) (let ($(join(reformatted_update_rules, "\n")))))"
        push!(on_clauses, on_clause)
      end

    end
  end
  on_clauses
end

# generate_event, generate_hypothesis_position, generate_hypothesis_position_program 
## tricky things: add user events, and fix environment 
global hypothesis_state = nothing
function generate_event(update_rule, object_trajectory, matrix, object_decomposition, user_events, max_iters=50)
  object_types, object_mapping, background, dim = object_decomposition 
  objects = sort(filter(obj -> obj != nothing, [object_mapping[i][1] for i in 1:length(collect(keys(object_mapping)))]), by=(x -> x.id))
  
  true_times = findall(rule -> rule == update_rule, map(l -> l[1], object_trajectory))
  true_time_events = map(time -> user_events[time], true_times)
  if length(unique(true_time_events)) == 1 && !isnothing(true_time_events[1])
    true_time_events[1]
  else
    iters = 0
    event = "false"
    while iters < max_iters 
      event = gen_event_bool(object_decomposition)
      println(event)
      program_str = singletimestepsolution_program_given_matrix(matrix, object_decomposition, 8) # CHANGE BACK TO DIM LATER
      program_tokens = split(program_str, """(: time Int)\n  (= time (initnext 0 (+ time 1)))""")
      program_str = string(program_tokens[1], """(: time Int)\n  (= time (initnext 0 (+ time 1)))""", "\n\t (: event Bool) \n\t (= event (initnext false $(event)))\n", program_tokens[2])
      println(program_str)
      global expr = striplines(compiletojulia(parseautumn(program_str)))
      #@show expr
      module_name = Symbol("CompiledProgram$(global_iters)")
      global expr.args[1].args[2] = module_name
      # @show expr.args[1].args[2]
      global mod = @eval $(expr)
      # @show repr(mod)

      iters += 1
      global global_iters += 1

      global hypothesis_state = @eval mod.init(nothing, nothing, nothing, nothing, nothing)
      @show hypothesis_state
      for time in 1:length(user_events)
        @show time
        global hypothesis_state = @eval mod.next(hypothesis_state, nothing, nothing, nothing, nothing, nothing)
      end
      event_values = map(key -> hypothesis_state.eventHistory[key], sort(collect(keys(hypothesis_state.eventHistory))))[2:end]
      for i in 1:length(event_values)
        rule = object_trajectory[i][1]
        if rule == "" || occursin("addObj", rule) || occursin("color", rule)
          event_values[i] = false
        end
      end
      
      # check if event_values match true_times/false_times 
      observation_data = map(time -> time in true_times, collect(1:length(user_events)))
      @show observation_data
      @show event_values
      
      if event_values == observation_data 
        break
      end
    end
    event    
  end
end

function is_no_change_rule(update_rule)
  update_functions = ["moveLeft", "moveRight", "moveUp", "moveDown", "nextSolid", "nextLiquid", "color", "addObj"]
  !foldl(|, map(x -> occursin(x, update_rule), update_functions))
end 

function full_program(observations, user_events, grid_size=16)
  matrix, object_decomposition, _ = singletimestepsolution_matrix(observations, user_events, grid_size)

  # ----- FIX THIS LATER -- HACK TO GET EXAMPLE TO WORK
  object_types, object_mapping, background, _ = object_decomposition
  
  new_matrix = [[] for i in 1:5, j in 1:size(matrix)[2]]
  for i in 1:size(new_matrix)[1]
    for j in 1:size(new_matrix)[2]
      new_matrix[i, j] = unique(matrix[i, j]) 
    end 
  end
  matrix = new_matrix
  delete!(object_mapping, 6)
  # object_decomposition = (object_types, object_mapping, background, grid_size)
  # -----

  on_clauses = generate_on_clauses(matrix, object_decomposition, user_events, grid_size)
  user_event_on_clauses = filter(on_clause -> foldl(|, map(event -> occursin(event, on_clause) , ["clicked", "left", "right", "down", "up"])), on_clauses)
  other_on_clauses = filter(on_clause -> !foldl(|, map(event -> occursin(event, on_clause) , ["clicked", "left", "right", "down", "up"])), on_clauses)
  
  on_clauses = vcat(other_on_clauses..., user_event_on_clauses...)

  object_types, object_mapping, background, _ = object_decomposition
  
  objects = sort(filter(obj -> obj != nothing, [object_mapping[i][1] for i in 1:length(collect(keys(object_mapping)))]), by=(x -> x.id))
  
  program_no_update_rules = program_string_synth((object_types, objects, background, grid_size))
  
  list_variables = join(map(type -> 
  """(: addedObjType$(type.id)List (List ObjType$(type.id)))\n  (= addedObjType$(type.id)List (initnext (list) (prev addedObjType$(type.id)List)))\n""", 
  object_types),"\n  ")
  
  time = """(: time Int)\n  (= time (initnext 0 (+ time 1)))"""

  update_rules = join(on_clauses, "\n  ")
  
  string(program_no_update_rules[1:end-2], 
        "\n\n  $(list_variables)",
        "\n\n  $(time)", 
        "\n\n  $(update_rules)", 
        ")")
end