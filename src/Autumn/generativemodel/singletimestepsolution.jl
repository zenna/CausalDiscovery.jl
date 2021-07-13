using Autumn
using MacroTools: striplines
using StatsBase
using Random
include("generativemodel.jl")
include("state_construction_utils.jl")
include("construct_observation_data.jl")

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
                    #  "(= objX (moveUpNoCollision objX))",
                     "(= objX (moveDown objX))",
                    #  "(= objX (moveLeftNoCollision objX))",
                    #  "(= objX (moveRightNoCollision objX))",
                    #  "(= objX (nextLiquid objX))",
                    #  "(= objX (nextSolid objX))",
                    #  "(= objX (removeObj objX))",
                     "(= objX (moveLeft (moveDown objX)))",
                     "(= objX (moveRight (moveDown objX)))",
                    ] # prev_used_rules = []

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
function synthesize_update_functions(object_id, time, object_decomposition, user_events, prev_used_rules, prev_abstract_positions, grid_size=16, max_iters=4)
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
    start_objects = filter(obj -> !isnothing(obj), [object_mapping[id][1] for id in collect(keys(object_mapping))])
    prev_objects_maybe_listed = filter(obj -> !isnothing(obj) && !isnothing(object_mapping[obj.id][1]), [object_mapping[id][time - 1] for id in 1:length(collect(keys(object_mapping)))])
    prev_objects = filter(obj -> count(x -> x.type.id == obj.type.id, start_objects) == 1, prev_objects_maybe_listed)
    println("HELLO")
    @show prev_objects
    # add uniformChoice option
    matching_objects = filter(o -> o.position == next_object.position, prev_objects_maybe_listed)
    if (matching_objects != []) && (isnothing(object_mapping[matching_objects[1].id][1]) || (count(x -> x.type.id == matching_objects[1].type.id, start_objects) > 1)) 
      matching_object = matching_objects[1]
      abstracted_positions = ["(.. (uniformChoice (prev addedObjType$(matching_object.type.id)List)) origin)"]
    else
      abstracted_positions, prev_abstract_positions = abstract_position(next_object.position, prev_abstract_positions, user_events[time - 1], (object_types, prev_objects, background, grid_size))
    end

    if length(next_object.custom_field_values) > 0
      update_rules = [
        """(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(join(map(v -> """ "$(v)" """, next_object.custom_field_values), " ")) (Position $(next_object.position[1]) $(next_object.position[2])))))""",
      ]
      
      # perform string abstraction 
      abstracted_strings = abstract_string(next_object.custom_field_values[1], (object_types, prev_objects, background, grid_size))
      if abstracted_strings != []
        abstracted_string = abstracted_strings[1]
        update_rules = vcat(update_rules..., """(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(abstracted_string) (Position $(next_object.position[1]) $(next_object.position[2])))))""")
      end
      
      if length(abstracted_positions) != 0
        abstracted_position = abstracted_positions[1]
        update_rules = vcat(update_rules..., 
                            """(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(join(map(v -> """ "$(v)" """, next_object.custom_field_values), " ")) $(abstracted_position))))""",
                           )
        if abstracted_strings != []
          update_rules = vcat(update_rules..., 
                              """(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(abstracted_string) $(abstracted_position))))""",
                             )
        end
        
      end
      reverse(update_rules), prev_used_rules, prev_abstract_positions
    else
      update_rules = map(pos -> 
      "(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(join(map(v -> """ "$(v)" """, next_object.custom_field_values), " ")) $(pos))))",
      abstracted_positions)
      vcat(update_rules..., "(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(join(map(v -> """ "$(v)" """, next_object.custom_field_values), " ")) (Position $(next_object.position[1]) $(next_object.position[2])))))"), prev_used_rules, prev_abstract_positions
    end
  elseif isnothing(next_object)
    start_objects = sort(filter(obj -> obj != nothing, [object_mapping[i][1] for i in 1:length(collect(keys(object_mapping)))]), by=(x -> x.id))
    contained_in_list = isnothing(object_mapping[object_id][1]) || (count(x -> x.type.id == object_mapping[object_id][1].type.id, start_objects) > 1)

    if contained_in_list # object was added later; contained in addedList
      ["(= addedObjType$(prev_object.type.id)List (removeObj (prev addedObjType$(prev_object.type.id)List) (--> obj (== (.. obj id) $(object_id)))))"], prev_used_rules, prev_abstract_positions
    else # object was present at the start of the program
      ["(= obj$(object_id) (removeObj obj$(object_id)))"], prev_used_rules, prev_abstract_positions
    end
  else # actual synthesis problem
    # prev_objects = filter(obj -> !isnothing(obj) && (obj.id != prev_object.id), [object_mapping[id][time - 1] for id in 1:length(collect(keys(object_mapping)))])
    prev_existing_objects = filter(obj -> !isnothing(obj) && (obj.id != prev_object.id), [object_mapping[id][time - 1] for id in 1:length(collect(keys(object_mapping)))])
    prev_removed_object_ids = filter(id -> isnothing(object_mapping[id][time - 1]) && (unique(object_mapping[id][1:time - 1]) != [nothing]) && (id != prev_object.id), collect(keys(object_mapping)))
    prev_removed_objects = deepcopy(map(id -> filter(obj -> !isnothing(obj), object_mapping[id][1:time - 1])[1], prev_removed_object_ids))
    foreach(obj -> obj.position = (-1, -1), prev_removed_objects)

    prev_objects = vcat(prev_existing_objects..., prev_removed_objects...)

    #@show prev_objects
    solutions = []
    iters = 0
    prev_used_rules_index = 1
    using_prev = false
    while length(solutions) < 2 && iters < max_iters # length(solutions) < 3 && 
      hypothesis_program = program_string_synth_update_rule((object_types, sort([prev_objects..., prev_object], by=(x -> x.id)), background, grid_size))
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

        start_objects = sort(filter(obj -> obj != nothing, [object_mapping[i][1] for i in 1:length(collect(keys(object_mapping)))]), by=(x -> x.id))
        contained_in_list = isnothing(object_mapping[object_id][1]) || (count(x -> x.type.id == object_mapping[object_id][1].type.id, start_objects) > 1)

        if occursin("color", update_rule) 
          global global_iters += 1
          start_objects = filter(obj -> !isnothing(obj), [object_mapping[id][1] for id in collect(keys(object_mapping))])
          prev_objects_maybe_listed = filter(obj -> !isnothing(obj) && !isnothing(object_mapping[obj.id][1]), [object_mapping[id][time - 1] for id in 1:length(collect(keys(object_mapping)))])
          curr_objects = filter(obj -> count(x -> x.type.id == obj.type.id, start_objects) == 1, prev_objects_maybe_listed)      
          abstracted_strings = abstract_string(next_object.custom_field_values[1], (object_types, curr_objects, background, grid_size))
          
          if abstracted_strings != []
            abstracted_string = abstracted_strings[1]
            if contained_in_list # object was added later; contained in addedList
              push!(solutions, """(= addedObjType$(prev_object.type.id)List (updateObj (prev addedObjType$(prev_object.type.id)List) (--> obj (updateObj obj "color" $(abstracted_string))) (--> obj (== (.. obj id) $(object_id)))))""")
            else # object was present at the start of the program
              push!(solutions, """(= obj$(object_id) (updateObj (prev obj$(object_id)) "color" $(abstracted_string)))""")
            end  
          end

          if contained_in_list # object was added later; contained in addedList
            push!(solutions, """(= addedObjType$(prev_object.type.id)List (updateObj (prev addedObjType$(prev_object.type.id)List) (--> obj (updateObj obj "color" "$(next_object.custom_field_values[1])")) (--> obj (== (.. obj id) $(object_id)))))""")
          else # object was present at the start of the program
            push!(solutions, """(= obj$(object_id) (updateObj (prev obj$(object_id)) "color" "$(next_object.custom_field_values[1])"))""")
          end

        else
          if contained_in_list # object was added later; contained in addedList
            map_lambda_func = replace(string("(-->", replace(update_rule, "obj$(object_id)" => "obj")[3:end]), "(prev obj)" => "obj")
            push!(solutions, "(= addedObjType$(prev_object.type.id)List (updateObj (prev addedObjType$(prev_object.type.id)List) $(map_lambda_func) (--> obj (== (.. obj id) $(object_id)))))")
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
  println("HERE 1")
  println(object_types)

  if overlapping_cells
    _, objects, _, _ = parsescene_autumn_singlecell_given_types(observations[1], object_types)
  else
    _, objects, _, _ = parsescene_autumn_given_types(observations[1], object_types)
  end
  println("HERE 2")
  println(object_types)

  for object in objects
    object_mapping[object.id] = [object]
  end

  for time in 2:length(observations)
    println("HERE 3")
    println(object_types)
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
  (translated_hypothesis_object == translated_actual_object) && hypothesis_object.alive
end

function singletimestepsolution_program(observations, user_events, grid_size=16)
  
  matrix, object_decomposition, _ = singletimestepsolution_matrix(observations, user_events, grid_size)
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
  update_rules = join(map(time -> """(on (== time $(time - 1))\n  (let\n    ($(join(filter(rule -> !occursin("--> obj obj", rule), map(l -> l[1], matrix[:, time])), "\n    "))))\n  )""", update_rule_times), "\n  ")
  
  string(program_no_update_rules[1:end-2], 
        "\n\n  $(list_variables)",
        "\n\n  $(time)", 
        "\n\n  $(update_rules)", 
        ")")
end

function singletimestepsolution_program_given_matrix_NEW(matrix, object_decomposition, grid_size=16)  
  object_types, object_mapping, background, _ = object_decomposition
  
  program_no_update_rules = program_string_synth_standard_groups((object_types, object_mapping, background, grid_size))
  time = """(: time Int)\n  (= time (initnext 0 (+ time 1)))"""
  update_rule_times = filter(time -> join(map(l -> l[1], matrix[:, time]), "") != "", [1:size(matrix)[2]...])
  update_rules = join(map(time -> """(on (== time $(time - 1))\n  (let\n    ($(join(filter(rule -> !occursin("--> obj obj", rule), map(l -> filter(x -> !occursin("uniformChoice", x), l)[1], matrix[:, time])), "\n    "))))\n  )""", update_rule_times), "\n  ")
  
  for type in object_types
    update_rules = replace(update_rules, "(prev addedObjType$(type.id)List)" => "addedObjType$(type.id)List")
  end

  string(program_no_update_rules[1:end-2], 
        "\n\n  $(time)", 
        "\n\n  $(update_rules)", 
        ")")
end

function has_dups(list::AbstractArray)
  length(unique(list)) != length(list) 
end

function abstract_position(position, prev_abstract_positions, user_event, object_decomposition, max_iters=50)
  object_types, prev_objects, _, _ = object_decomposition
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
      hypothesis_position = generate_hypothesis_position(position, vcat(prev_objects, user_event))
      if hypothesis_position == ""
        break
      end
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
    if !isnothing(user_event) && occursin("click",split(user_event, " ")[1])
      global x = parse(Int, split(user_event, " ")[2])
      global y = parse(Int, split(user_event, " ")[3])
      hypothesis_frame_state = @eval mod.next(mod.init(nothing, nothing, nothing, nothing, nothing), mod.Click(x, y), nothing, nothing, nothing, nothing)
    else
      hypothesis_frame_state = @eval mod.next(mod.init(nothing, nothing, nothing, nothing, nothing), nothing, nothing, nothing, nothing, nothing)
    end

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

function abstract_string(string, object_decomposition, max_iters=25)
  object_types, environment_vars, _, _ = object_decomposition
  solutions = []
  iters = 0
  if length(environment_vars) != 0
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
  end
  solutions
end

function generate_on_clauses(matrix, object_decomposition, user_events, grid_size=16)
  on_clauses = []
  global_var_dict = Dict()
  object_types, object_mapping, background, dim = object_decomposition

  pre_filtered_matrix = pre_filter_with_direction_biases(matrix, user_events, object_decomposition) 
  filtered_matrix = filter_update_function_matrix(pre_filtered_matrix, object_decomposition)
  
  anonymized_filtered_matrix = deepcopy(filtered_matrix)
  for i in 1:size(matrix)[1]
    for j in 1:size(matrix)[2]
      anonymized_filtered_matrix[i,j] = [replace(replace(filtered_matrix[i, j][1], "id) $(i)" => "id) x"), "obj$(i)" => "objX")]
    end
  end
  
  global_object_decomposition = object_decomposition
  global_state_update_times = ["" for x in 1:length(user_events)]

  state_update_on_clauses = []

  for object_type in object_types
    object_ids = sort(filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == object_type.id, collect(keys(object_mapping))))

    all_update_rules = filter(rule -> rule != "", unique(vcat(vec(anonymized_filtered_matrix[object_ids, :])...)))

    addObj_rules = unique(filter(rule -> occursin("addObj", rule), vcat(map(id -> vcat(filtered_matrix[id, :]...), object_ids)...)))
    addObj_times_dict = Dict()

    for rule in addObj_rules 
      addObj_times_dict[rule] = sort(unique(vcat(map(id -> findall(r -> r == rule, vcat(filtered_matrix[id, :]...)), object_ids)...)))
    end
    
    group_addObj_rules = false
    if length(unique(collect(values(addObj_times_dict)))) == 1
      group_addObj_rules = true
      all_update_rules = filter(r -> !(r in addObj_rules), all_update_rules)
      push!(all_update_rules, addObj_rules[1])
    end

    for update_rule in all_update_rules 
      # find a trajectory containing this update_rule
      if length(object_ids) == 1
        object_id = object_ids[1]
        object_trajectory = filtered_matrix[object_ids[1], :]
      else
        ids_with_rule = map(idx -> object_ids[idx], findall(idx_set -> idx_set != [], map(id -> findall(rule -> rule[1] == update_rule, anonymized_filtered_matrix[id, :]), object_ids)))
        trajectory_lengths = map(id -> length(unique(filter(x -> x != "", anonymized_filtered_matrix[id, :]))), ids_with_rule)
        max_index = findall(x -> x == maximum(trajectory_lengths) , trajectory_lengths)[1]
        object_id = ids_with_rule[max_index]
        object_trajectory = filtered_matrix[object_id, :]
      end

      # de-anonymize update_rule 
      update_rule = replace(replace(update_rule, "id) x" => "id) $(object_id)"), "objX" => "obj$(object_id)")

      # determine an event predicate for each update function except for the no-change update function 
      distinct_update_rules = filter(rule -> rule != "", unique(vcat(object_trajectory...)))
      
      # sort distinct update functions by their frequency in the trajectory
      distinct_update_rules = reverse(sort(distinct_update_rules, by=x -> count(y -> y[1] == x, object_trajectory)))
      println("HERE")
      println(distinct_update_rules)

      if update_rule != "" && !is_no_change_rule(update_rule)
        println("UPDATE_RULEEE")
        println(update_rule)
        println(object_trajectory)
        println(length(object_trajectory))
        println(findall(rule -> rule == update_rule, map(l -> l[1], object_trajectory)))
        event, event_vector_dict = generate_event(update_rule, distinct_update_rules, object_id, object_trajectory, matrix, filtered_matrix, global_object_decomposition, user_events, state_update_on_clauses, global_var_dict)
        println("EVENT")
        println(event)
        @show event_vector_dict

        if event != ""
          # collect all objects of type object_type
          on_clause = format_on_clause(update_rule, event, object_id, object_ids, object_type, group_addObj_rules, addObj_rules, object_mapping)
          push!(on_clauses, on_clause)
        else # handle construction of new state

          if occursin("addObj", update_rule)
            object_trajectories = map(id -> filtered_matrix[id, :], filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id == filter(obj -> !isnothing(obj), object_mapping[object_id])[1].type.id, collect(keys(object_mapping))))
            true_times = vcat(map(trajectory -> findall(rule -> rule == update_rule, vcat(trajectory...)), object_trajectories)...)
          else 
            true_times = findall(rule -> rule == update_rule, vcat(object_trajectory...))
          end

          on_clause, new_global_var_dict, new_state_update_times = generate_new_state(update_rule, true_times, event_vector_dict, global_var_dict, global_state_update_times)
          @show on_clause 
          @show new_state_update_times 
          @show new_global_var_dict

          on_clause = format_on_clause(split(on_clause, "\n")[2][1:end-1], replace(split(on_clause, "\n")[1], "(on " => ""), object_id, object_ids, object_type, group_addObj_rules, addObj_rules, object_mapping)
          push!(on_clauses, on_clause)
          global_var_dict = new_global_var_dict 
          state_update_on_clauses = filter(x -> x != "", new_state_update_times)
          global_state_update_times = new_state_update_times
          
          @show global_var_dict 
          @show state_update_on_clauses 
          @show global_state_update_times
          # true_times = findall(rule -> rule == update_rule, vcat(object_trajectory...))    
          # true_time_events = filter(x -> !isnothing(x) && (x != "nothing"), map(time -> isnothing(user_events[time]) ? user_events[time] : split(user_events[time], " ")[1], true_times))
          # user_event = unique(true_time_events)[1]

          # on_clause, state_update_on_clauses_local, new_object_decomposition, new_global_var_dict, new_global_state_update_times = generate_new_state(update_rule, user_event, user_events, object_id, object_trajectory, object_decomposition, filtered_matrix, global_var_dict, global_state_update_times)
          # push!(on_clauses, on_clause)
          # object_types, object_mapping, background, grid_size = new_object_decomposition
          # global_object_decomposition = (object_types, object_mapping, background, grid_size)
          # global_var_dict = new_global_var_dict
          # global_state_update_times = new_global_state_update_times 
          # state_update_on_clauses = filter(x -> x != "", new_global_state_update_times)
          # @show new_global_state_update_times
          # @show on_clause
          # @show state_update_on_clauses 
          # @show object_types 
          # println("HI THERE")
          # @show object_mapping 
          # modify filtered_matrix: add field value to addObj rules

          if length(collect(keys(global_var_dict))) == 0
            for object_id in object_ids
              for time in 1:size(filtered_matrix)[2]
                update_rule = filtered_matrix[object_id, time][1]
                if occursin("addObj", update_rule)
                  if occursin("\"", update_rule)
                    field_value = object_mapping[object_id][time + 1].custom_field_values[2]
                    split_rule = split(update_rule, "\"")
                    new_components = [split_rule[1], " $(field_value) ", "\"", split_rule[2], "\"", join(split_rule[3:end], "\"")]
                  else
                    field_value = object_mapping[object_id][time + 1].custom_field_values[1]
                    split_rule = split(update_rule, "ObjType$(object_type.id)")
                    new_components = [split_rule[1], "ObjType$(object_type.id)", " $(field_value) ", join(split_rule[2:end], "ObjType$(object_type.id)")]
                  end
                  new_rule = join(new_components, "")
                  filtered_matrix[object_id][time] = [new_rule]
                end
              end
            end
          end

        end

      end

    end
  end
  [on_clauses..., state_update_on_clauses...], global_object_decomposition, global_var_dict 
end

function format_on_clause(update_rule, event, object_id, object_ids, object_type, group_addObj_rules, addObj_rules, object_mapping)
  if occursin("addObj", update_rule)

    if group_addObj_rules
      on_clause = "(on $(event) (let ($(join(addObj_rules, "\n")))))"
    else
      reformatted_rule = replace(update_rule, " id) x" => " id) $(object_id)")
      on_clause = "(on $(event) $(reformatted_rule))"
    end
  else 
    start_objects = filter(obj -> !isnothing(obj), [object_mapping[id][1] for id in collect(keys(object_mapping))])
    nonlist_start_objects = filter(obj -> count(x -> x.type.id == obj.type.id, start_objects) == 1, start_objects)
    type_id = object_type.id
  
    if occursin(".. (first (filter", event)
      reformatted_event = split(event, " ")[2] 
      second_reformatted_event = replace(split(event, reformatted_event)[2][1:end-1], "(first (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type_id)List)))" => "obj")
      reformatted_rule = replace(update_rule, "(--> obj (== (.. obj id) $(object_id)))" => "(--> obj $(second_reformatted_event))")
  
      on_clause = "(on $(reformatted_event) $(reformatted_rule))"
    elseif occursin("(first (filter", event)
      reformatted_event = replace(event, "(first (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type_id)List)))" => "obj")
      reformatted_rule = replace(update_rule, "(--> obj (== (.. obj id) $(object_id)))" => "(--> obj $(reformatted_event))")
      on_clause = "(on true $(reformatted_rule))"
    elseif occursin("filter", event) && !(object_id in map(obj -> obj.id, nonlist_start_objects))
      # obj involved in event is in a list, so it cannot be accessed directly 
      reformatted_event = replace(event, "(filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type_id)List))" => "obj")
      reformatted_rule = replace(update_rule, "(--> obj (== (.. obj id) $(object_id)))" => "(--> obj $(reformatted_event))")
      
      second_reformatted_event = replace(event, "(filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type_id)List))" => "(prev addedObjType$(type_id)List)")
      
      on_clause = "(on $(second_reformatted_event) $(reformatted_rule))"
    else
      if !(object_id in map(obj -> obj.id, nonlist_start_objects))  
        reformatted_rule = replace(update_rule, "(--> obj (== (.. obj id) $(object_id)))" => "(--> obj true)")
        on_clause = "(on $(event) $(reformatted_rule))"
      else
        if !occursin("addObj", update_rule)
          reformatted_rules = map(id -> replace(update_rule, "(.. obj id) $(object_id))" => "(.. obj id) $(id))"), object_ids)
          # reformatted_rule = replace(update_rule, "(--> obj (== (.. obj id) $(object_id)))" => "")
          on_clause = "(on $(event) (let ($(join(reformatted_rules, "\n")))))"  
        else
          on_clause = "(on $(event) $(update_rule))"
        end
      end
    end 
  end
  on_clause 
end


"Select one update function from each matrix cell's update function set, which may contain multiple update functions"
function filter_update_function_matrix(matrix, object_decomposition)
  object_types, object_mapping, _, _ = object_decomposition

  new_matrix = deepcopy(matrix)
  # for each row (trajectory) in the update function matrix, filter down its update function sets
  for object_id in 1:size(matrix)[1]
    object_type = filter(object -> !isnothing(object), object_mapping[object_id])[1].type
    
    # count frequency of an update function across a type if the type has no color state,
    # and within the same color state of a type otherwise
    if length(object_type.custom_fields) == 0 # no need to split by type's color
      same_type_update_function_set = []
      for other_object_id in 1:size(matrix)[1] 
        other_object_type = filter(object -> !isnothing(object), object_mapping[other_object_id])[1].type
        if other_object_type.id == object_type.id 
          update_rules = map(s -> replace(s, "id) $(other_object_id)" => "id) x"), vcat(matrix[other_object_id, :]...))
          same_type_update_function_set = vcat(same_type_update_function_set..., update_rules...)
        end
      end

      # perform filtering 
      for time in 1:size(matrix)[2]
        update_functions = map(s -> replace(s, "id) $(object_id)" => "id) x"), matrix[object_id, time])
        if length(update_functions) > 1 
          update_function_frequencies = map(func -> count(x -> x == func, same_type_update_function_set), update_functions)
          max_id = findall(x -> x == maximum(update_function_frequencies), update_function_frequencies)[1]
          new_matrix[object_id, time] = [update_functions[max_id]]
        end
      end

    else # split by type's color
      same_type_update_function_sets = Dict()
      for color in object_type.custom_fields[1][3] 
        same_type_update_function_sets[color] = []
      end
      same_type_update_function_sets[nothing] = []
      @show same_type_update_function_sets 
      for other_object_id in 1:size(matrix)[1]

        other_object_type = filter(object -> !isnothing(object), object_mapping[other_object_id])[1].type
        
        if other_object_type.id == object_type.id
          @show other_object_id

          for time in 1:size(matrix)[2]
            if !isnothing(object_mapping[other_object_id][time])
              color = object_mapping[other_object_id][time].custom_field_values[1]
              @show color

              if !isnothing(object_mapping[other_object_id][time + 1]) && (object_mapping[other_object_id][time + 1].custom_field_values[1] != color)
                # color change update rules are placed in the `nothing` category
                update_rules = map(s -> replace(s, "id) $(other_object_id)" => "id) x"), matrix[other_object_id, time])
                same_type_update_function_sets[nothing] = vcat(same_type_update_function_sets[nothing]..., update_rules...)
              else
                update_rules = map(s -> replace(s, "id) $(other_object_id)" => "id) x"), matrix[other_object_id, time])
                same_type_update_function_sets[color] = vcat(same_type_update_function_sets[color]..., update_rules...)
              end

            elseif !isnothing(object_mapping[other_object_id][time + 1])
              # object was just added; update functions are addObj 
              update_rules = map(s -> replace(s, "id) $(other_object_id)" => "id) x"), matrix[other_object_id, time])
              same_type_update_function_sets[nothing] = vcat(same_type_update_function_sets[nothing]..., update_rules...)
            end
          end
        end
      end

      # perform filtering
      for time in 1:size(matrix)[2]
        update_functions = map(s -> replace(s, "id) $(object_id)" => "id) x"), matrix[object_id, time])
        @show update_functions
        if length(update_functions) > 1
          object = object_mapping[object_id][time]
          if !isnothing(object)
            color = object.custom_field_values[1]
            update_function_frequencies = map(func -> count(x -> x == func, same_type_update_function_sets[color]), update_functions)
          else
            update_function_frequencies = map(func -> count(x -> x == func, same_type_update_function_sets[nothing]), update_functions)
          end
          max_id = findall(x -> x == maximum(update_function_frequencies), update_function_frequencies)[1]
          new_matrix[object_id, time] = [update_functions[max_id]]
        end
      end

    end

  end
  
  for object_id in 1:size(new_matrix)[1]
    @show new_matrix[object_id, :]
    new_matrix[object_id, :] = map(list -> [replace(list[1], " id) x" => " id) $(object_id)")], new_matrix[object_id, :])
  end

  new_matrix
end

function pre_filter_with_direction_biases(matrix, user_events, object_decomposition)
  object_types, object_mapping, _, _ = object_decomposition 

  new_matrix = deepcopy(matrix)

  for direction in ["left", "right", "up", "down"]
    event_times = findall(event -> event == direction, user_events)
    for object_id in 1:size(matrix)[1]
      type_id = filter(x -> !isnothing(x), object_mapping[object_id])[1].type.id
      other_object_ids = sort(filter(id -> (id != object_id) && filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping))))
      
      trajectory = matrix[object_id, :]
      direction_update_at_every_time = foldl(&, map(list -> occursin(string("move", uppercasefirst(direction), "NoCollision"), join(list, "")), trajectory), init=true)
      for event_time in event_times 
        direction_update_at_event_time = occursin(string("move", uppercasefirst(direction), "NoCollision"), join(trajectory[event_time], ""))

        deltas = [(!isnothing(object_mapping[id][event_time]) && 
                   !isnothing(object_mapping[id][event_time + 1]) &&
                   (object_mapping[id][event_time].position != object_mapping[id][event_time + 1].position)) 
                   for id in other_object_ids]

        if direction_update_at_event_time && !direction_update_at_every_time && !(1 in deltas)
          new_matrix[object_id, event_time] = filter(rule -> occursin(string("move", uppercasefirst(direction)), rule), trajectory[event_time])
        end
      end
    end
  end

  deepcopy(new_matrix)
end

# generate_event, generate_hypothesis_position, generate_hypothesis_position_program 
## tricky things: add user events, and fix environment 
global hypothesis_state = nothing
function generate_event(update_rule, distinct_update_rules, object_id, object_trajectory, matrix, filtered_matrix, object_decomposition, user_events, state_update_on_clauses, global_var_dict, max_iters=50)
  object_types, object_mapping, background, dim = object_decomposition 
  objects = sort(filter(obj -> obj != nothing, [object_mapping[i][1] for i in 1:length(collect(keys(object_mapping)))]), by=(x -> x.id))
  #println("WHAT 1")
  #@show length(vcat(object_trajectory...))

  if occursin("addObj", update_rule)
    object_trajectories = map(id -> filtered_matrix[id, :], filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id == filter(obj -> !isnothing(obj), object_mapping[object_id])[1].type.id, collect(keys(object_mapping))))
    true_times = vcat(map(trajectory -> findall(rule -> rule == update_rule, vcat(trajectory...)), object_trajectories)...)
  else
    true_times = findall(rule -> rule == update_rule, vcat(object_trajectory...))
  end
  @show true_times 
  @show user_events
  true_time_events = map(time -> isnothing(user_events[time]) ? user_events[time] : split(user_events[time], " ")[1], true_times)
  false_time_events = map(time -> isnothing(user_events[time]) ? user_events[time] : split(user_events[time], " ")[1], findall(rule -> rule != update_rule, vcat(object_trajectory...)))

  observation_data = map(time -> time in true_times ? 1 : 0, collect(1:length(user_events)))
  update_rule_index = findall(rule -> rule == update_rule, distinct_update_rules)[1]
  #println("WHAT 3")

  if !occursin("addObj", update_rule)
    for time in 1:length(object_trajectory)
      rule = object_trajectory[time][1]
      #@show rule
      #@show distinct_update_rules
      if (rule == "") || (findall(r -> r == rule, distinct_update_rules)[1] > update_rule_index) 
        observation_data[time] = -1
      elseif (findall(r -> r == rule, distinct_update_rules)[1] < update_rule_index)
        observation_data[time] = 0
      end

      if occursin("\"color\" \"", update_rule)
        if is_no_change_rule(rule) && occursin(object_mapping[object_id][time + 1].custom_field_values[1], update_rule) && observation_data[time] != 1
          observation_data[time] = -1
        end
      end
    end
  end

  println("----------------> LOOK AT ME")
  @show object_decomposition

  unique_true_events = unique(true_time_events)
  if (length(unique_true_events) == 1) && !isnothing(unique_true_events[1]) && unique_true_events[1] != "nothing" && !(unique_true_events[1] in false_time_events) # && split(unique_true_events[1], " ")[1] != "clicked"
    println("ABC")
    unique_true_events[1]
  else
    iters = 0
    event = "false"
    event_vector_dict = Dict()
    old_events = []
    while iters < max_iters
      event_sampling_max_iters = 75
      event_sampling_iters = 0
      event = ""
      while event_sampling_iters < event_sampling_max_iters 

        event = gen_event_bool(object_decomposition, object_id, unique(true_time_events), global_var_dict)
        if !(event in old_events)
          push!(old_events, event)
          break
        end
        event_sampling_iters += 1
        event = ""
      end
      println(event)

      if event != "" # new event to try found
        program_str = singletimestepsolution_program_given_matrix_NEW(matrix, object_decomposition, dim) # CHANGE BACK TO DIM LATER
        program_tokens = split(program_str, """(: time Int)\n  (= time (initnext 0 (+ time 1)))""")
        if state_update_on_clauses != []
          global_var_init_val = global_var_dict[1][1]
          program_str = string(program_tokens[1], """(: time Int)\n  (= time (initnext 0 (+ time 1)))""", "\n\t (: globalVar1 Int)\n\t (= globalVar1 (initnext $(global_var_init_val) (prev globalVar1)))\n\t (: event Bool) \n\t (= event (initnext false $(event)))\n", program_tokens[2])
          
          state_update_on_clauses_str = join(state_update_on_clauses, "\n  ")
          program_str = string(program_str[1:end-1], state_update_on_clauses_str, ")")
        else
          program_str = string(program_tokens[1], """(: time Int)\n  (= time (initnext 0 (+ time 1)))""", "\n\t (: event Bool) \n\t (= event (initnext false $(event)))\n", program_tokens[2])
        end
        
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
          if user_events[time] != nothing && (split(user_events[time], " ")[1] in ["click", "clicked"])
            global x = parse(Int, split(user_events[time], " ")[2])
            global y = parse(Int, split(user_events[time], " ")[3])
  
            global hypothesis_state = @eval mod.next(hypothesis_state, mod.Click(x, y), nothing, nothing, nothing, nothing)
          elseif user_events[time] == "left"
            global hypothesis_state = @eval mod.next(hypothesis_state, nothing, mod.Left(), nothing, nothing, nothing)
          elseif user_events[time] == "right"
            global hypothesis_state = @eval mod.next(hypothesis_state, nothing, nothing, mod.Right(), nothing, nothing)
          elseif user_events[time] == "up"
            global hypothesis_state = @eval mod.next(hypothesis_state, nothing, nothing, nothing, mod.Up(), nothing)
          elseif user_events[time] == "down"
            global hypothesis_state = @eval mod.next(hypothesis_state, nothing, nothing, nothing, nothing, mod.Down())
          else
            global hypothesis_state = @eval mod.next(hypothesis_state, nothing, nothing, nothing, nothing, nothing)
          end
        end
        event_values = map(key -> hypothesis_state.eventHistory[key], sort(collect(keys(hypothesis_state.eventHistory))))[2:end]

        # update event_vector_dict 
        event_vector_dict[event] = event_values

        # check if event_values match true_times/false_times 
        @show observation_data
        @show event_values
        
        equals = true
        for time in 1:length(observation_data)
          if (observation_data[time] != event_values[time]) && (observation_data[time] != -1)
            equals = false
            println("NO SUCCESS")
            break
          end
        end
  
        if equals
          println("SUCCESS") 
          break
        end
      else
        break
      end
    end
    event, event_vector_dict    
  end
end

# generation of new global state 
function generate_new_state(update_rule, update_function_times, event_vector_dict, global_var_dict, state_update_times)
  @show update_function_times  
  new_state_update_times = deepcopy(state_update_times)

  # compute best co-occurring event (i.e. event with fewest false positives)
  co_occurring_events = []
  for event in keys(event_vector_dict)
    event_vector = event_vector_dict[event]
    event_times = findall(x -> x == 1, event_vector)
    if repr(sort(intersect(event_times, update_function_times))) == repr(sort(update_function_times))
      push!(co_occurring_events, (event, length([time for time in event_times if !(time in update_function_times)])))
    end 
  end
  co_occurring_event = sort(co_occurring_events, by=x->x[2])[1][1]
  co_occurring_event_trajectory = event_vector_dict[co_occurring_event]

  # initialize global_var_dict and get global_var_value
  if length(collect(keys(global_var_dict))) == 0
    global_var_value = 1
    global_var_dict[1] = ones(Int, length(state_update_times))
  else
    global_var_value = maximum(global_var_dict[1])
  end

  true_positive_times = update_function_times # times when co_occurring_event happened and update_rule happened 
  false_positive_times = [] # times when user_event happened and update_rule didn't happen

  # construct true_positive_times and false_positive_times 
  for time in 1:length(user_events)
    if co_occurring_event_trajectory[time] == 1 && !(time in true_positive_times)
        push!(false_positive_times, time)
    end
  end

  # compute ranges in which to search for events 
  ranges = []
  augmented_true_positive_times = map(t -> (t, global_var_value), true_positive_times)
  augmented_false_positive_times = map(t -> (t, global_var_value + 1), false_positive_times)
  augmented_positive_times = sort(vcat(augmented_true_positive_times, augmented_false_positive_times), by=x -> x[1])

  for i in 1:(length(augmented_positive_times)-1)
    prev_time, prev_value = augmented_positive_times[i]
    next_time, next_value = augmented_positive_times[i + 1]
    if prev_value != next_value
      push!(ranges, (augmented_positive_times[i], augmented_positive_times[i + 1]))
    end
  end

  # add ranges that interface between global_var_value and lower values 
  if global_var_value > 1
    for time in 1:(length(state_update_times) - 1)
      prev_val = global_var_dict[1][time]
      next_val = global_var_dict[1][time + 1]

      if (prev_val < global_var_value) && (next_val == global_var_value)
        if (filter(t -> t[1] == time + 1, augmented_positive_times) != []) && (filter(t -> t[1] == time + 1, augmented_positive_times)[1][2] != global_var_value)
          new_value = filter(t -> t[1] == time + 1, augmented_positive_times)[1][2]
          push!(ranges, ((time, prev_val), (time + 1, new_value)))        
        else
          push!(ranges, ((time, prev_val), (time + 1, next_val)))        
        end

      elseif (prev_val == global_var_value) && (next_val < global_var_value)
        if (filter(t -> t[1] == time, augmented_positive_times) != []) && (filter(t -> t[1] == time, augmented_positive_times)[1][2] != global_var_value)
          new_value = filter(t -> t[1] == time, augmented_positive_times)[1][2]
          push!(ranges, ((time, new_value), (time + 1, next_val)))        
        else
          push!(ranges, ((time, prev_val), (time + 1, next_val)))        
        end
      end
    end
  end

  grouped_ranges = group_ranges(ranges)

  # while there are ranges that need to be explained, search for explaining events within them
  while length(grouped_ranges) > 0 
    grouped_range = grouped_ranges[1]
    grouped_ranges = grouped_ranges[2:end] # remove first range from ranges 

    range = grouped_range[1]
    start_value = range[1][2]
    end_value = range[2][2]

    time_ranges = map(r -> (r[1][1], r[2][1] - 1), grouped_range)

    # construct state update function
    state_update_function = "(= globalVar1 $(end_value))"

    # get current maximum value of globalVar
    max_global_var_value = maximum(map(tuple -> tuple[2], augmented_positive_times))

    # search for events within range
    events_in_range = find_state_update_events(event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value, global_var_dict)
    if events_in_range != [] # event with zero false positives found
      state_update_event, event_times = events_in_range[1]

      # construct state update on-clause
      state_update_on_clause = "(on $(state_update_event)\n$(state_update_function))"
      
      # add to state_update_times 
      for time in event_times 
        new_state_update_times[time] = state_update_on_clause
      end

    else # no event with zero false positives found; use best false-positive event and specialize globalVar values (i.e. add new value)
      # find co-occurring event with fewest false positives 
      false_positive_events = find_state_update_events_false_positives(event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value, global_var_dict)
      false_positive_events_with_state = filter(e -> occursin("globalVar1", e[1]), false_positive_events) # want the most specific events in the false positive case
      false_positive_event, _, true_positive_times, false_positive_times = false_positive_events_with_state[1] 

      # construct state update on-clause
      state_update_on_clause = "(on $(false_positive_event)\n$(state_update_function))"
      
      # add to state_update_times
      for time in true_positive_times 
        new_state_update_times[time] = state_update_on_clause            
      end
      
      augmented_positive_times_labeled = map(tuple -> (tuple[1], tuple[2], "update_function"), augmented_positive_times) 
      for time in false_positive_times  
        push!(augmented_positive_times_labeled, (time, max_global_var_value + 1, "event"))
      end
      augmented_positive_times_labeled = sort(augmented_positive_times_labeled, by=x->x[1])

      # relabel false positive times 
      # based on relabeling, relabel other existing labels if necessary 
      for tuple_index in 1:length(augmented_positive_times_labeled)
        tuple = augmented_positive_times_labeled[tuple_index]
        if tuple[3] == "event"
          for prev_index in (tuple_index-1):-1:1
            prev_tuple = augmented_positive_times_labeled[prev_index]

            if prev_tuple[2] == global_var_value 
              break
            end

            if (prev_tuple[2] > global_var_value) && (prev_tuple[3] == "update_function")
              augmented_positive_times_labeled[prev_index] = (prev_tuple[1], max_global_var_value + 1, prev_tuple[3])
            end
          end
        end
      end
      augmented_positive_times = map(t -> (t[1], t[2]), filter(tuple -> tuple[3] == "update_function", augmented_positive_times_labeled))      

      # compute new ranges and find state update events
      new_ranges = [] 
      for i in 1:(length(augmented_positive_times)-1)
        prev_time, prev_value = augmented_positive_times[i]
        next_time, next_value = augmented_positive_times[i + 1]
        if prev_value != next_value
          if length(unique(new_state_update_times[prev_time:next_time-1])) == 1 && unique(new_state_update_times[prev_time:next_time-1])[1] == ""
            # if there are no state update functions within this range, add it to new_ranges
            push!(new_ranges, (augmented_positive_times[i], augmented_positive_times[i + 1]))
          elseif intersect(true_positive_times, collect(prev_time:next_time-1)) == []
            # if the state_update_function in this range is not among those just added (which are correct), add range to new_ranges
            @show prev_time 
            @show prev_value 
            @show next_time 
            @show next_value 
            
            on_clause_index = findall(x -> x != "", new_state_update_times[prev_time:next_time-1])[1]
            # on_clause = new_state_update_times[prev_time:next_time-1][on_clause_index]
            
            # on_clause_event = split(on_clause, "\n")[1]
            # on_clause_function = split(on_clause, "\n")[2]

            # if occursin("(== (prev globalVar1) ", on_clause_event)
            #   on_clause_segments = split(on_clause_event, "(== (prev globalVar1) ")
            #   on_clause_event = string(on_clause_segments[1], "(== (prev globalVar1) ", prev_value, on_clause_segments[2][2:end])
            # end

            # on_clause_function = "(= globalVar1 $(next_value)))"
            new_state_update_times[on_clause_index + prev_time - 1] = ""
            push!(new_ranges, (augmented_positive_times[i], augmented_positive_times[i + 1]))
          end
        end
      end

      # add ranges that interface between global_var_value and lower values to new_ranges 
      if global_var_value > 1
        for time in 1:(length(state_update_times) - 1)
          prev_val = global_var_dict[1][time]
          next_val = global_var_dict[1][time + 1]

          if ((prev_val < global_var_value) && (next_val == global_var_value) || (prev_val == global_var_value) && (next_val < global_var_value))
            if intersect([time], collect(prev_time:next_time - 1)) == [] 
              push!(new_ranges, ((time, prev_val), (time + 1, next_val)))
            end
          end
        end
      end
      grouped_ranges = group_ranges(new_ranges) 
    end
  end

  # update global_var_dict
  _, init_value = augmented_positive_times[1]
  for time in 1:length(global_var_dict[1]) 
    if global_var_dict[1][time] >= global_var_value 
      global_var_dict[1][time] = init_value
    end
  end

  curr_value = -1
  for time in 1:length(global_var_dict[1])
    if curr_value != -1 
      global_var_dict[1][time] = curr_value
    end
    if new_state_update_times[time] != ""
      curr_value = parse(Int, split(split(new_state_update_times[time], "\n")[2], "(= globalVar1 ")[2][1])
    end
  end

  on_clause = "(on $(occursin("globalVar1", co_occurring_event) ? co_occurring_event : "(& (== globalVar1 $(global_var_value)) $(co_occurring_event))")\n$(update_rule))"
  
  on_clause, global_var_dict, new_state_update_times
end

function generate_new_object_specific_state(update_rule, update_function_times_dict, event_vector_dict, type_id, object_decomposition)
  object_types, object_mapping, background, grid_size = object_decomposition 

  # initialize state_update_times 
  state_update_times = Dict()
  for id in collect(keys(update_function_times_dict))
    state_update_times[id] = [("", -1) for i in 1:length(collect(values(event_vector_dict))[1])]
  end

  # compute co-occurring event 
  # only look at global events for now 
  events = filter(k -> event_vector_dict[k] isa Array, collect(keys(event_vector_dict))) 
  co_occurring_events = []
  for event in events 
    event_vector = event_vector_dict[event]
    co_occurring = foldl(&, map(update_function_times -> is_co_occurring(event, event_vector, update_function_times), collect(values(update_function_times_dict))), init=true)
    if co_occurring
      false_positive_count = num_false_positives(event_vector, update_function_times)
      push!(co_occurring_events, (event, num_false_positives))
    end
  end
  co_occurring_event = sort(co_occurring_events, by=x -> x[2])[1]
  co_occurring_event_trajectory = event_vector_dict[co_occurring_event]

  augmented_positive_times_dict = Dict()
  for object_id in collect(keys(update_function_times_dict)) 
    true_positive_times = update_function_times_dict[object_id] # times when co_occurring_event happened and update_rule happened 
    false_positive_times = [] # times when user_event happened and update_rule didn't happen
    
    # construct false_positive_times 
    for time in 1:length(user_events)
      if co_occurring_event_trajectory[time] == 1 && !(time in true_positive_times)
          push!(false_positive_times, time)
      end
    end

    # construct positive times list augmented by true/false value 
    augmented_true_positive_times = map(t -> (t, 1), true_positive_times)
    augmented_false_positive_times = map(t -> (t, 2), false_positive_times)
    augmented_positive_times = sort(vcat(augmented_true_positive_times, augmented_false_positive_times), by=x -> x[1])  

    augmented_positive_times_dict[object_id] = augmented_positive_times 
  end

  # compute ranges 
  ranges_dict = Dict()
  for object_id in collect(keys(update_function_times_dict))
    ranges = []
    augmented_positive_times = augmented_positive_times_dict[object_id]
    for i in 1:(length(augmented_positive_times)-1)
      prev_time, prev_value = augmented_positive_times[i]
      next_time, next_value = augmented_positive_times[i + 1]
      if prev_value != next_value
        push!(ranges, (augmented_positive_times[i], augmented_positive_times[i + 1]))
      end
    end
    ranges_dict[object_id] = ranges
  end
  grouped_ranges = group_ranges(ranges_dict)

  while length(grouped_ranges) > 0
    grouped_range = grouped_ranges[1]
    grouped_ranges = grouped_ranges[2:end]

    range = grouped_range[1]
    start_value = range[1][2]
    end_value = range[2][2]

    # try global events first 
    events_in_range = []
    if events_in_range == [] # if no global events are found, try object-specific events 
      # do something
    end

    if length(events_in_range) > 0 # only handling perfect matches currently 
      event, event_times = events_in_range[1]

      # construct state_update_function 
      state_update_function = ""

      for id in collect(keys(state_update_times))
        object_event_times = map(t -> t[1], filter(time -> time[2] == object_id, event_times))
        for time in object_event_times 
          state_update_times[id][time] = (state_update_function, end_value)
        end
      end
    end
  end

  # construct field values for each object 
  object_field_values = Dict()
  for object_id in collect(keys(update_function_times_dict))
    init_value = augmented_positive_times_dict[object_id][1][2]
    object_field_values[object_id] = [init_value for i in 1:(length(state_update_times) + 1)]
    
    curr_value = -1
    for time in 1:length(object_field_values[object_id])
      if curr_value != -1
        object_field_values[object_id][time] = curr_value
      end
      
      if state_update_times[object_id][time] != ("", -1)
        curr_value = state_update_times[object_id][time][2]
      end
    end
  end

  # construct new object decomposition
  ## add field to correct ObjType in object_types
  new_object_types = deepcopy(object_types)
  new_object_type = filter(type -> type.id == type_id, new_object_types)[1]
  push!(new_object_type.custom_fields, ("field1", "Int", [1, 2]))
  
  ## modify objects in object_mapping
  new_object_mapping = deepcopy(object_mapping)
  for id in collect(keys(new_object_mapping))
    if id in collect(keys(update_function_times_dict))
      for time in 1:length(new_object_mapping[id])
        new_object_mapping[id][time].type = new_object_type 
        new_object_mapping[id][time].custom_field_values = vcat(new_object_mapping[id][time].custom_field_values, object_field_values[id][time])
      end
    end
  end
  new_object_decomposition = new_object_types, new_object_mapping, background, grid_size

  on_clause = "(on $(co_occurring_event) (= ))"
  state_update_on_clauses = unique(filter(r -> r != "", vcat([state_update_times[k][1] for k in collect(keys(state_update_times))]...)))
  on_clause, state_update_on_clauses, new_object_decomposition 
end

function generate_new_state(update_rule, user_event, user_events, object_id, object_trajectory, object_decomposition, filtered_matrix, global_var_dict, state_update_times)
  object_types, object_mapping, background, grid_size = object_decomposition
  
  on_clause = "" 
  state_update_on_clauses = []
  new_object_decomposition = object_decomposition
  new_state_update_times = deepcopy(state_update_times)

  if occursin("addObj", update_rule)
    if occursin("click", user_event) 
      event_times = []
      modified_user_event = "(& clicked (isFree click))"

      object_trajectories = map(id -> filtered_matrix[id, :], filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id == filter(obj -> !isnothing(obj), object_mapping[object_id])[1].type.id, collect(keys(object_mapping))))
      true_rule_times = vcat(map(trajectory -> findall(rule -> rule == update_rule, vcat(trajectory...)), object_trajectories)...) 
  
      true_event_times = [] # times when user_event happened and update_rule happened 
      false_event_times = [] # times when user_event happened and update_rule didn't happen

      for time in 1:length(user_events)
        if !isnothing(user_events[time]) && occursin("click", user_events[time])
          # check if clicked position is free 
          object_positions = map(o -> o.position, filter(obj -> !isnothing(obj), [object_mapping[id][time] for id in collect(keys(object_mapping))]))
          click_x = parse(Int, split(user_events[time], " ")[2])
          click_y = parse(Int, split(user_events[time], " ")[3])

          if !((click_x, click_y) in object_positions) 
            if time in true_rule_times 
              push!(true_event_times, time)
            else
              push!(false_event_times, time)
            end
          end
        end
      end

      if length(collect(keys(global_var_dict))) == 0
        global_var_value = 1
        global_var_dict[1] = ones(Int, length(user_events))
      else
        global_var_value = maximum(global_var_dict[1])
        false_event_times = filter(time -> global_var_dict[1][time] == global_var_value, false_event_times)
      end
  
      # compute ranges in which to search for events 
      ranges = []
      augmented_true_event_times = map(t -> (t, true), true_event_times)
      augmented_false_event_times = map(t -> (t, false), false_event_times)

      augmented_event_times = sort(vcat(augmented_true_event_times, augmented_false_event_times), by=x -> x[1])
      for i in 1:(length(augmented_event_times)-1)
        prev_time, prev_bool = augmented_event_times[i]
        next_time, next_bool = augmented_event_times[i + 1]
        if prev_bool != next_bool
          push!(ranges, (augmented_event_times[i], augmented_event_times[i + 1]))
        end
      end

      for range in ranges
        start_time = range[1][1] + 1
        start_bool = range[1][2]

        end_time = range[2][1] - 1
        end_bool = range[2][2]

        events_in_range = filter(event -> !isnothing(event) && (event != "nothing"), user_events[start_time:end_time])
        if events_in_range != []
          event = events_in_range[1]
          event_time = filter(time -> (time >= start_time) && (time <= end_time), findall(x -> x == event, user_events))[1]
          push!(event_times, event_time)

          if occursin("click", event)
            x = parse(Int, split(event, " ")[2])
            y = parse(Int, split(event, " ")[3])
            clicked_objects = filter(obj -> !isnothing(obj) && obj.position == (x, y), [object_mapping[id][event_time] for id in collect(keys(object_mapping))])
            if clicked_objects != []
              clicked_object = clicked_objects[1]
              clicked_object_id = clicked_object.id 
              
              # check if object is in list
              start_objects = sort(filter(obj -> obj != nothing, [object_mapping[i][1] for i in 1:length(collect(keys(object_mapping)))]), by=(x -> x.id))
              contained_in_list = isnothing(object_mapping[clicked_object_id][1]) || (count(x -> x.type.id == object_mapping[clicked_object_id][1].type.id, start_objects) > 1)
              
              if contained_in_list 
                state_update_event = "(clicked (prev addedObjType$(clicked_object.type.id)List))"
              else
                state_update_event = "(clicked (prev obj$(clicked_object_id)))"
              end                
            end
          else # event is not click
            if start_bool && !end_bool 
              state_update_event = "(& $(event) (== (prev globalVar1) $(global_var_value)))" 
            else
              state_update_event = "(& $(event) (== (prev globalVar1) $(global_var_value + 1)))" 
            end
          end

          if start_bool && !end_bool 
            state_update_function = "(= globalVar1 $(global_var_value + 1))"
          else
            state_update_function = "(= globalVar1 $(global_var_value))"
          end
          state_update_on_clause = "(on $(state_update_event) $(state_update_function))"
          state_update_on_clauses = vcat(state_update_on_clauses..., state_update_on_clause)

        end
      end

      @show event_times 

      if length(ranges) == 1
        event_time = event_times[1]
        start_bool = ranges[1][1][2]
        end_bool = ranges[1][2][2]

        if start_bool && !end_bool 
          for time in (event_time + 1):length(user_events)
            if global_var_dict[1][time] == global_var_value 
              global_var_dict[1][time] = global_var_value + 1
            end
          end
        elseif !start_bool && end_bool 
          for time in 1:event_time
            if global_var_dict[1][time] == global_var_value 
              global_var_dict[1][time] = global_var_value + 1
            end
          end
        end

      elseif length(ranges) == 2
        event_time_1 = event_times[1]
        event_time_2 = event_times[2]

        start_bool = ranges[1][2][2]
        end_bool = ranges[2][1][2]

        if start_bool && end_bool 
          for time in vcat(collect(1:event_time_1), collect((event_time_2 + 1):length(user_events)))
            if global_var_dict[1][time] == global_var_value 
              global_var_dict[1][time] = global_var_value + 1
            end           
          end
        elseif !start_bool && !end_bool 
          for time in (event_time_1 + 1):event_time_2
            if global_var_dict[1][time] == global_var_value 
              global_var_dict[1][time] = global_var_value + 1
            end
          end
        end
      end  
      
      # modify state_update_times 
      for i in 1:(length(user_events) - 1)
        if new_state_update_times[i] != ""
          state_update = new_state_update_times[i]
          event_value = parse(Int, split(state_update, "== (prev globalVar1) ")[2][1])
          next_value = parse(Int, split(state_update, "(= globalVar1 ")[2][1])
          if event_value != global_var_dict[1][i]
            println("hello")
            new_state_update_times[i] = replace(state_update, "== (prev globalVar1) $(event_value)" => "== (prev globalVar1) $(global_var_dict[1][i])")
          end

          if next_value != global_var_dict[1][i + 1]
            new_state_update_times[i] = replace(state_update, "(= globalVar1 $(next_value)" => "(= globalVar1 $(global_var_dict[1][i + 1])")
          end
        end
      end

      for i in 1:length(event_times)
        new_clause = state_update_on_clauses[i]
        event_time = event_times[i]
        new_state_update_times[event_time] = new_clause
      end


      on_clause = "(on (& $(modified_user_event) (== (prev globalVar1) $(global_var_value))) $(update_rule))"
      println("HAHA")
      @show state_update_on_clauses
    end
  else
    true_event_times = []
    false_event_times = []
    for time in 1:length(object_trajectory)
      if (user_events[time] == user_event)
        if object_trajectory[time] == [update_rule]
          push!(true_event_times, time)
        else
          push!(false_event_times, time)
        end
      end
    end
  
    # check separability
    start_time = -1
    end_time = -1
    if (minimum(true_event_times) > maximum(false_event_times)) 
      start_time = maximum(false_event_times) + 1
      end_time = minimum(true_event_times) - 1
    elseif (minimum(false_event_times) > maximum(true_event_times))
      start_time = maximum(true_event_times) + 1
      end_time = minimum(false_event_times) - 1
    end
  
    if (start_time != -1) && (end_time != -1)
      # search for an event in between these times 
      events_in_range = filter(event -> !isnothing(event) && (event != "nothing") && occursin("click", event), user_events[start_time:end_time])
      if events_in_range != []
        event = events_in_range[1]
        time_ = findall(x -> x == event, user_events)[1]
        x = parse(Int, split(event, " ")[2])
        y = parse(Int, split(event, " ")[3])
        clicked_objects = filter(obj -> obj.position == (x, y), [object_mapping[id][time_] for id in collect(keys(object_mapping))])
        if clicked_objects != []
          clicked_object = clicked_objects[1]
          clicked_object_id = clicked_object.id 
          
          # check if object is in list
          start_objects = sort(filter(obj -> obj != nothing, [object_mapping[i][1] for i in 1:length(collect(keys(object_mapping)))]), by=(x -> x.id))
          contained_in_list = isnothing(object_mapping[clicked_object_id][1]) || (count(x -> x.type.id == object_mapping[clicked_object_id][1].type.id, start_objects) > 1)
          
          if contained_in_list 
            state_update_event = "(clicked (prev addedObjType$(clicked_object.type.id)List))"
          else
            state_update_event = "(clicked (prev obj$(clicked_object_id)))"
          end
          
          type_id = filter(obj -> !isnothing(obj), object_mapping[object_id])[1].type.id 
          
          # HACK: proper way to do this is to look at other trajectories, and notice that the clicked object 
          # undergoes a state change
          state_update_function = """(let ((= addedObjType$(type_id)List (updateObj (prev addedObjType$(type_id)List) (--> obj (updateObj obj "field1" 2)))) 
                                           (= addedObjType$(type_id)List (updateObj addedObjType$(type_id)List (--> obj (updateObj obj "field1" 1)) (--> obj (== (.. obj id) (.. (objClicked click addedObjType$(type_id)List) id)))))
                                          ))"""
  
          state_update_on_clause = """(on $(state_update_event) $(state_update_function))"""
          push!(state_update_on_clauses, state_update_on_clause)
          field_name = "field1"
          field_values = [1, 2]
          on_clause = "(on $(user_event) $(replace(update_rule, "(--> obj (== (.. obj id) $(object_id)))" => "(--> obj (== (.. obj field1) 1))")))"
          
          # construct new object decomposition
          ## add field to correct ObjType in object_types
          new_object_types = deepcopy(object_types)
          new_object_type = filter(type -> type.id == type_id, new_object_types)[1]
          push!(new_object_type.custom_fields, ("field1", "Int", [1, 2]))
          
          ## modify objects in object_mapping
          unformatted_update_rule = replace(update_rule, "obj$(object_id)" => "objX")
          unformatted_update_rule = replace(unformatted_update_rule, " id) $(object_id)" => " id) x")
          new_object_mapping = deepcopy(object_mapping)
          for object_id in collect(keys(new_object_mapping))
            object_type_id = filter(x -> !isnothing(x), new_object_mapping[object_id])[1].type.id 
            if object_type_id == type_id 
              foreach(obj -> obj.type = new_object_type, filter(x -> !isnothing(x), new_object_mapping[object_id]))
              updates_before_time = map(rule -> replace(replace(rule, "obj$(object_id)" => "objX"), " id) $(object_id)" => " id) x"), vcat(filtered_matrix[object_id, 1:time_]...))
              updates_after_time = map(rule -> replace(replace(rule, "obj$(object_id)" => "objX"), " id) $(object_id)" => " id) x"), vcat(filtered_matrix[object_id, time_+1:end]...))
  
              if unformatted_update_rule in updates_before_time
                for obj in new_object_mapping[object_id][1:time_] 
                  if !isnothing(obj)
                    obj.custom_field_values = vcat(obj.custom_field_values..., 1)                  
                  end 
                end
              else
                for obj in new_object_mapping[object_id][1:time_] 
                  if !isnothing(obj)
                    obj.custom_field_values = vcat(obj.custom_field_values..., 2)                  
                  end 
                end
              end
  
              if unformatted_update_rule in updates_after_time 
                for obj in new_object_mapping[object_id][time_+1:end] 
                  if !isnothing(obj)
                    obj.custom_field_values = vcat(obj.custom_field_values..., 1)                  
                  end 
                end
              else
                for obj in new_object_mapping[object_id][time_+1:end] 
                  if !isnothing(obj)
                    obj.custom_field_values = vcat(obj.custom_field_values..., 2)                  
                  end 
                end
              end
  
            end
          end
          new_object_decomposition = (new_object_types, new_object_mapping, background, grid_size)
        end
      end
    end  
  end

  on_clause, state_update_on_clauses, new_object_decomposition, global_var_dict, new_state_update_times
end

function is_no_change_rule(update_rule)
  update_functions = ["moveLeft", "moveRight", "moveUp", "moveDown", "nextSolid", "nextLiquid", "color", "addObj", "move"]
  !foldl(|, map(x -> occursin(x, update_rule), update_functions))
end 

function full_program(observations, user_events, grid_size=16)
  matrix, object_decomposition, _ = singletimestepsolution_matrix(observations, user_events, grid_size)

  object_types, object_mapping, background, _ = object_decomposition
  
  new_matrix = [[] for i in 1:size(matrix)[1], j in 1:size(matrix)[2]]
  for i in 1:size(new_matrix)[1]
    for j in 1:size(new_matrix)[2]
      new_matrix[i, j] = unique(matrix[i, j]) 
    end 
  end
  matrix = new_matrix

  on_clauses, new_object_decomposition, global_var_dict = generate_on_clauses(matrix, object_decomposition, user_events, grid_size)
  object_types, object_mapping, background, _ = new_object_decomposition

  on_clauses = unique(on_clauses)
  true_on_clauses = filter(on_clause -> occursin("on true", on_clause), on_clauses)
  user_event_on_clauses = filter(on_clause -> !(on_clause in true_on_clauses) && foldl(|, map(event -> occursin(event, on_clause) , ["clicked", "left", "right", "down", "up"])), on_clauses)
  other_on_clauses = filter(on_clause -> !((on_clause in true_on_clauses) || (on_clause in user_event_on_clauses)), on_clauses)
  
  on_clauses = vcat(true_on_clauses, other_on_clauses..., user_event_on_clauses...)
  
  objects = sort(filter(obj -> obj != nothing, [object_mapping[i][1] for i in 1:length(collect(keys(object_mapping)))]), by=(x -> x.id))
  
  program_no_update_rules = program_string_synth_standard_groups((object_types, object_mapping, background, grid_size))
  
  if length(collect(keys(global_var_dict))) > 0
    global_var_init_val = global_var_dict[1][1]
    program_no_update_rules = string(program_no_update_rules[1:end-2], "(: globalVar1 Int)\n (= globalVar1 (initnext $(global_var_init_val) (prev globalVar1)))", ")")
  end
  
  t = """(: time Int)\n  (= time (initnext 0 (+ time 1)))"""

  update_rules = join(on_clauses, "\n  ")
  
  string(program_no_update_rules[1:end-1], 
        "\n\n  $(t)", 
        "\n\n  $(update_rules)", 
        ")")
end