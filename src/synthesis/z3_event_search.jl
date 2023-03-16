using Z3 

# ctx = Context()
# x = bv_const(ctx, "x", 32)
# y = bv_const(ctx, "y", 32)

# s = Solver(ctx, "QF_BV")
# add(s, x & y & 3 == 1)

# res = check(s)
# @assert res == Z3.sat

# m = get_model(s)

# for (k, v) in consts(m)
#     # println("$(k) = $(get_numeral_int64(v))")
# end

function bitarr_to_int(arr, val = 0)
  v = 2^(length(arr)-1)
  for i in eachindex(arr)
      val += v*arr[i]
      v >>= 1
  end
  return val
end

"""Z3 solution where we concatenate event vectors for each object_id to create one long bit vector (per event) 
   Potential problem: How will Z3 handle bit vectors longer than 64 bits?
"""
function event_search_z3_concat(event_vector_dict, observed_data_dict) 
  object_ids = sort(collect(keys(observed_data_dict)))
    
  # construct bit vector we want z3 to find a match for 
  ambig_positions = Dict(map(id -> id => findall(v -> v == -1, observed_data_dict[id])), object_ids)
  observed_bv = vcat(map(id -> filter(x -> x != -1, observed_data_dict[object_id]), object_ids)...)

  # construct atom vectors we want z3 to use 
  atom_dict = Dict()
  for event in keys(event_vector_dict)
    event_values = event_vector_dict[event]

    # check that event is global or object-specific with the right type
    if event_values isa AbstractArray 
      event_vector = vcat(map(id -> map(t -> event_values[t], filter(pos -> !(pos in ambig_positions[id]), collect(1:length(event_values)))), object_ids)...)
      atom_dict[event] = event_vector      
    elseif Set(collect(keys(event_values))) == Set(object_ids)
      event_vector = vcat(map(id -> map(t -> event_values[id][t], filter(pos -> !(pos in ambig_positions[id]), collect(1:length(event_values[id])))), object_ids)...)
      atom_dict[event] = event_vector
    end
  end

  # get integer value of observed bit vector
  observed_bv_val = bitarr_to_int(observed_bv)
  bitsize = length(observed_bv_val)

  # construct array of bit vector values
  atoms = map(a -> bv_val(ctx, bitarr_to_int(a), bitsize), sort(collect(keys(atom_dict))))

  # construct Z3 problem 
  ctx = Context()

  z3_atoms = constant(ctx, "atoms", array_sort(ctx, int_sort(ctx), bv_sort(ctx, length(observed_bv_val))))
  i = 0
  for elem in atoms
    z3_atoms = Store(z3_atoms, i, elem)
    i = i + 1
  end

  atom_index = int_const(ctx, "i")
  s = Solver(ctx, "QF_BVA")
  add(s, atom_index >= 0)
  add(s, atom_index < length(observed_bv_val))
  add(s, Select(z3_atoms, atom_index) == observed_bv_val)

  res = check(s)

  if res == Z3.sat 
    m = get_model(s)
    for (k, v) in consts(m)
      index = get_numeral_int64(v))
      break
    end  
  else
    index = -1 
  end
  
  if index != -1 
    sort(collect(keys(atom_dict)))[index]
  else 
    ""
  end
end

"""Z3 solution that avoids concatenation of bit vectors into too-long ones"""
function event_search_z3_concat(event_vector_dict, observed_data_dict) 
  object_ids = sort(collect(keys(observed_data_dict)))
    
  # construct dictionary of bit vectors we want z3 to find a match for 
  ambig_positions_dict = Dict(map(id -> id => findall(v -> v == -1, observed_data_dict[id])), object_ids)
  observed_bv_dict = Dict(map(id -> id => filter(x -> x != -1, observed_data_dict[object_id]), object_ids))

  # construct atom vectors we want z3 to use 
  atom_dict = Dict() # maps event to dictionary of event values with ambig positions filtered out 
  for event in keys(event_vector_dict)
    event_values = event_vector_dict[event]

    # check that event is global or object-specific with the right type
    if event_values isa AbstractArray 
      event_values_dict = Dict(map(id -> id => map(t -> event_values[t], filter(pos -> !(pos in ambig_positions[id]), collect(1:length(event_values)))), object_ids))
      atom_dict[event] = event_values_dict      
    elseif Set(collect(keys(event_values))) == Set(object_ids)
      event_values_dict = Dict(map(id -> id => map(t -> event_values[id][t], filter(pos -> !(pos in ambig_positions[id]), collect(1:length(event_values[id])))), object_ids))
      atom_dict[event] = event_values_dict
    end
  end

  # get integer values of observed bit vectors
  # observed_bv_vals_dict = Dict(map(id -> id => bitarr_to_int(observed_bv_dict[id]), collect(keys(observed_bv_dict)))) # object_id => int value of observed bit vector
  # bitsize_dict = Dict(map(id -> id => length(observed_bv_dict[id]), collect(keys(observed_bv_dict)))) # object_id => length of observed bit vector

  # construct Z3 problem 
  ctx = Context()

  z3_atoms = [constant(ctx, "atoms$(i)", array_sort(ctx, int_sort(ctx), bv_sort(ctx, length(observed_bv_dict[object_ids[i]])))) for i in 1:length(object_ids)]
  for object_id_idx in 1:length(object_ids)
    # list of bit vector int values corresponding to given object_id for each event (sorted by event)
    atoms = map(event -> bv_val(ctx, bitarr_to_int(atom_dict[event][object_ids[object_id_idx]])), sort(collect(keys(atom_dict)), by=length))
    i = 0 # Z3 arrays are 0-indexed? or 1-indexed? using 0-indexing currently
    for elem in atoms
      z3_atoms[object_id_idx] = Store(z3_atoms[object_id_idx], i, elem)
      i = i + 1
    end      
  end

  atom_index = int_const(ctx, "atom_index")

  s = Solver(ctx, "QF_BVA")
  add(s, atom_index >= 0)
  add(s, atom_index < length(collect(keys(atom_dict))))

  for i in 1:length(object_ids)
    add(s, Select(z3_atoms[i], atom_index) == observed_bv_vals_dict[object_ids[i]])  
  end 

  res = check(s)

  if res == Z3.sat 
    m = get_model(s)
    for (k, v) in consts(m)
      index = get_numeral_int64(v))
      break
    end  
  else
    index = -1 
  end
  
  if index != -1 
    sort(collect(keys(atom_dict)))[index]
  else 
    ""
  end
end