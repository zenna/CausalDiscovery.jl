using Random
using DataStructures
using Statistics
using Colors
using Images

"""
Example Use:
> rng = MersenneTwister(0)
> image = render(generatescene_objects(rng))
> save("scene.png", colorview(RGBA, image))
> println(parsescene_image(image))
"""

# ----- define colors and color-related functions ----- # 

colors = ["red", "yellow", "green", "blue"]
backgroundcolors = ["white", "black"]

"""Euclidean distance between two RGB/RGBA colors"""
function colordist(color1, color2)
  (color1.r - color2.r)^2 + (color1.g - color2.g)^2 + (color1.b - color2.b)^2 
end

"""CSS string color name from RGB color"""
function colorname(r::RGB)
  rgbs = vcat(keys(rgb_to_colorname)...)
  colordists = map(x -> colordist(r, x), rgbs)
  minidx = findall(x -> x == minimum(colordists), colordists)[1]
  rgb_key = rgbs[minidx]
  rgb_to_colorname[rgb_key]
end

"""CSS string color name from RGBA color"""
function colorname(rgba::RGBA)
  rgb = RGB(rgba.r, rgba.g, rgba.b)
  colorname(rgb)
end

"""RGB value from CSS string color name"""
function rgb(colorname)
  colorname_to_rgb[colorname]
end

rgb_to_colorname = Dict([
  (colorant"red", "red"),
  (colorant"yellow", "yellow"),
  (colorant"green", "green"),
  (colorant"blue", "blue"),
  (colorant"white", "white"),
  (colorant"black", "black")
]);

colorname_to_rgb = Dict([
  ("red", colorant"red"),
  ("yellow", colorant"yellow"),
  ("green", colorant"green"),
  ("blue", colorant"blue"),
  ("white", colorant"white"),
  ("black", colorant"black")
])

# ----- end define colors and color-related functions ----- # 

# ----- define general utils ----- #

"""Compute neighbor positions of given shape"""
function neighbors(shape::AbstractArray)
  neighborPositions = vcat(map(pos -> neighbors(pos), shape)...)
  unique(filter(pos -> !(pos in shape), neighborPositions))
end

"""Compute neighbor positions of given position"""
function neighbors(position)
  x = position[1]
  y = position[2]
  [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
end

# ----- end define general utils ----- #

# ----- define functions related to generative model over scenes ----- #
mutable struct ObjType
  shape::AbstractArray
  color::String
  custom_fields::AbstractArray
  id::Int
end

mutable struct Obj
  type::ObjType
  position::Tuple{Int, Int}
  custom_field_values::AbstractArray
  id::Int
end

"""Produce image from types_and_objects scene representation"""
function render(types_and_objects)
  types, objects, background, gridsize = types_and_objects
  image = [RGBA(1.0, 0.0, 0.0, 1.0) for x in 1:gridsize, y in 1:gridsize]
  println("""
  (program
    (= GRID_SIZE $(gridsize))
    (= background "$(background)")
    $(join(map(t -> "(object ObjType$(t.id) (list $(join(map(cell -> """(Cell $(cell[1]) $(cell[2]) "$(t.color)")""", t.shape), " "))))", types), "\n  "))

    $((join(map(obj -> """(: obj$(obj.id) ObjType$(obj.type.id))""", objects), "\n  "))...)

    $((join(map(obj -> """(= obj$(obj.id) (initnext (ObjType$(obj.type.id) (Position $(obj.position[1] - 1) $(obj.position[2] - 1))) (prev obj$(obj.id))))""", objects), "\n  ")))
  )
  """)
  for object in objects
    center_x = object.position[1]
    center_y = object.position[2]
    type = object.type
    color = rgb(object.type.color)
    for shape_position in type.shape
      shape_x, shape_y = shape_position
      x = center_x + shape_x
      y = center_y + shape_y
      if (x > 0) && (x <= gridsize) && (y > 0) && (y <= gridsize) # only render in-bound pixel positions
        if image[y, x] == RGBA(1.0, 0.0, 0.0, 1.0)
          image[y, x] = RGBA(color.r, color.g, color.b, 0.6)
        else
          new_alpha = image[x,y].alpha + 0.6 - image[x,y].alpha * 0.6
          image[y, x] = RGBA((image[y,x].alpha * image[y,x].r + 0.6*(1 - image[y,x].alpha)*color.r)/new_alpha,
                             (image[y,x].alpha * image[y,x].g + 0.6*(1 - image[y,x].alpha)*color.g)/new_alpha,
                             (image[y,x].alpha * image[y,x].b + 0.6*(1 - image[y,x].alpha)*color.b)/new_alpha,
                            new_alpha)
        end  
      end
    end
  end
  for x in 1:gridsize
    for y in 1:gridsize
      if image[x, y] == RGBA(1.0, 0.0, 0.0, 1.0)
        image[x, y] = rgb(background)
      end
    end
  end
  image
end

function program_string(types_and_objects)
  types, objects, background, gridsize = types_and_objects 
  """ 
  (program
    (= GRID_SIZE $(gridsize))
    (= background "$(background)")
    $(join(map(t -> "(object ObjType$(t.id) (list $(join(map(cell -> """(Cell $(cell[1]) $(cell[2]) "$(t.color)")""", t.shape), " "))))", types), "\n  "))

    $((join(map(obj -> """(: obj$(obj.id) ObjType$(obj.type.id))""", objects), "\n  "))...)

    $((join(map(obj -> """(= obj$(obj.id) (initnext (ObjType$(obj.type.id) (Position $(obj.position[1] - 1) $(obj.position[2] - 1))) (prev obj$(obj.id))))""", objects), "\n  ")))
  )
  """
end

function program_string_synth(types_and_objects)
  types, objects, background, gridsize = types_and_objects 
  """ 
  (program
    (= GRID_SIZE $(gridsize))
    (= background "$(background)")
    $(join(map(t -> "(object ObjType$(t.id) $(join(map(tuple -> "(: $(tuple[1]) $(tuple[2]))", t.custom_fields), " ")) (list $(join(map(cell -> """(Cell $(cell[1]) $(cell[2]) $(t.custom_fields == [] ? """ "$(t.color)" """ : "color"))""", t.shape), " "))))", types), "\n  "))

    $((join(map(obj -> """(: obj$(obj.id) ObjType$(obj.type.id))""", objects), "\n  "))...)

    $((join(map(obj -> """(= obj$(obj.id) (initnext (ObjType$(obj.type.id) $(join(map(v -> """ "$(v)" """, obj.custom_field_values), " ")) (Position $(obj.position[1]) $(obj.position[2]))) (prev obj$(obj.id))))""", objects), "\n  ")))
  )
  """
end

function generatescene_program(rng=Random.GLOBAL_RNG; gridsize::Int=16)
  types_and_objects = generatescene_objects(rng, gridsize=gridsize)
  program_string(types_and_objects)
end

function generatescene_objects(rng=Random.GLOBAL_RNG; gridsize::Int=16)
  background = backgroundcolors[rand(1:length(backgroundcolors))]
  numObjects = rand(rng, 1:20)
  numTypes = rand(rng, 1:min(numObjects, 5))
  types = [] # each type has form (list of position tuples, index in types list)::Tuple{Array{Tuple{Int, Int}}, Int}
  
  objectPositions = [(rand(rng, 1:gridsize), rand(rng, 1:gridsize)) for x in 1:numObjects]
  objects = [] # each object has form (type, position tuple, color, index in objects list)

  for type in 1:numTypes
    renderSize = rand(rng, 1:5)
    shape = [(0,0)]
    while length(shape) != renderSize
      boundaryPositions = neighbors(shape)
      push!(shape, boundaryPositions[rand(rng, 1:length(boundaryPositions))])
    end
    color = colors[rand(rng, 1:length(colors))]
    
    # generate custom fields
    custom_fields = []
    num_fields = rand(0:2)
    for i in 1:num_fields
      push!(custom_fields, ("field$(i)", rand(["Int", "Bool"])))
    end

    push!(types, ObjType(shape, color, custom_fields, length(types) + 1))
  end

  for i in 1:numObjects
    objPosition = objectPositions[i]
    objType = types[rand(rng, 1:length(types))]

    # generate custom field values
    custom_fields = objType.custom_fields
    custom_field_values = map(field -> field[2] == "Int" ? rand(1:3) : rand(["true", "false"]), custom_fields)

    push!(objects, Obj(objType, objPosition, custom_field_values, length(objects) + 1))    
  end
  (types, objects, background, gridsize)
end

# ----- end functions related to generative model over scenes ----- # 

# ----- define functions related to scene parsing -----

function parsescene_image_singlecell(image)
  dimImage = size(image)[1]
  background = count(x -> x == "white", map(colorname, image)) > count(x -> x == "black", map(colorname, image)) ? "white" : "black"
  colors = []
  objects = []
  for y in 1:dimImage
    for x in 1:dimImage
      color = colorname(image[y, x])
      if color != "white"
        if !(color in colors)
          push!(colors, color)
        end

        push!(objects, (x - 1, y - 1, (color, findall(x -> x == color, colors)[1]), length(objects) + 1))
      end
    end
  end

  """
  (program
    (= GRID_SIZE $(dimImage))
    (= background "$(background)")

    $(join(map(color -> """(object ObjType$(findall(x -> x == color, colors)[1]) (Cell 0 0 "$(color)"))""", colors), "\n  "))

    $(join(map(obj -> """(: obj$(obj[4]) ObjType$(obj[3][2]))""", objects), "\n  "))

    $(join(map(obj -> """(= obj$(obj[4]) (initnext (ObjType$(obj[3][2]) (Position $(obj[1]) $(obj[2]))) (prev obj$(obj[4]))))""", objects), "\n  "))
  )
  """
end

function color_contiguity(image, pos1, pos2)
  image[pos1[1], pos1[2]] == image[pos2[1], pos2[2]]
end

function parsescene_image(image; color=true)
  dimImage = size(image)[1]
  background = count(x -> x == "white", map(colorname, image)) > count(x -> x == "black", map(colorname, image)) ? "white" : "black"
  objectshapes = []
  colored_positions = map(ci -> (ci.I[2], ci.I[1]), findall(color -> color != "white", map(colorname, image)))
  visited = []
  for position in colored_positions
    if !(position in visited)
      objectshape = []
      q = Queue{Any}()
      enqueue!(q, position)
      while !isempty(q)
        pos = dequeue!(q)
        push!(objectshape, pos)
        push!(visited, pos)
        pos_neighbors = neighbors(pos)
        for n in pos_neighbors
          if (n in colored_positions) && !(n in visited) && (color ? color_contiguity(image, n, pos) : true) 
            enqueue!(q, n)
          end
        end
      end
      push!(objectshapes, objectshape)
    end
  end

  types = []
  objects = []
  for objectshape in objectshapes
    objectcolors = map(pos -> colorname(image[pos[2], pos[1]]), objectshape)
    
    translated = map(pos -> dimImage * (pos[2] - 1)+ (pos[1] - 1), objectshape)
    translated = length(translated) % 2 == 0 ? translated[1:end-1] : translated
    centerPos = objectshape[findall(x -> x == median(translated), translated)[1]]
    translatedShape = map(pos -> (pos[1] - centerPos[1], pos[2] - centerPos[2]), objectshape)
    translatedShapeWithColors = [(translatedShape[i], objectcolors[i]) for i in 1:length(translatedShape)]

    push!(types, (translatedShapeWithColors, length(types) + 1))
    push!(objects, (centerPos, length(types), length(objects) + 1))
  end

  """
  (program
    (= GRID_SIZE $(dimImage))
    (= background "$(background)")

    $(join(map(t -> """(object ObjType$(t[2]) (list $(join(map(cell -> """(Cell $(cell[1][1]) $(cell[1][2]) "$(cell[2])")""", t[1]), " ")))""", types), "\n  "))

    $(join(map(obj -> """(: obj$(obj[3]) ObjType$(obj[2]))""", objects), "\n  "))
 
    $(join(map(obj -> """(= obj$(obj[3]) (initnext (ObjType$(obj[2]) (Position $(obj[1][1] - 1) $(obj[1][2] - 1))) (prev obj$(obj[3]))))""", objects), "\n  "))
  )
  """
end

function color_contiguity_autumn(position_to_color, pos1, pos2)
  length(intersect(position_to_color[pos1], position_to_color[pos2])) > 0
end

function parsescene_autumn(render_output::AbstractArray, dim::Int=16, background::String="white"; color=true)
  
  position_to_color = Dict()
  for cell in render_output
    if (cell.position.x, cell.position.y) in keys(position_to_color)
      push!(position_to_color[(cell.position.x, cell.position.y)], cell.color)
    else
      position_to_color[(cell.position.x, cell.position.y)] = [cell.color] 
    end
  end

  colored_positions = sort(collect(keys(position_to_color)))
  objectshapes = []
  visited = []
  for position in colored_positions
    if !(position in visited)
      objectshape = []
      q = Queue{Any}()
      enqueue!(q, position)
      while !isempty(q)
        pos = dequeue!(q)
        push!(objectshape, pos)
        push!(visited, pos)
        pos_neighbors = neighbors(pos)
        for n in pos_neighbors
          if (n in colored_positions) && !(n in visited) && (color ? color_contiguity_autumn(position_to_color, n, pos) : true) 
            enqueue!(q, n)
          end
        end
      end
      push!(objectshapes, objectshape)
    end
  end  

  types = []
  objects = []
  # @show length(objectshapes)
  for objectshape in objectshapes
    objectcolor = position_to_color[objectshape[1]][1]
    # @show objectcolor 
    # @show objectshape
    translated = map(pos -> dim * pos[2] + pos[1], objectshape)
    translated = length(translated) % 2 == 0 ? translated[1:end-1] : translated # to produce a single median
    centerPos = objectshape[findall(x -> x == median(translated), translated)[1]]
    translatedShape = unique(map(pos -> (pos[1] - centerPos[1], pos[2] - centerPos[2]), sort(objectshape)))

    if !((translatedShape, objectcolor) in map(type -> (type.shape, type.color) , types))
      push!(types, ObjType(translatedShape, objectcolor, [], length(types) + 1))
      push!(objects, Obj(types[length(types)], centerPos, [], length(objects) + 1))
    else
      type_id = findall(type -> (type.shape, type.color) == (translatedShape, objectcolor), types)[1]
      push!(objects, Obj(types[type_id], centerPos, [], length(objects) + 1))
    end
  end

  # combine types with the same shape but different colors
  (types, objects) = combine_types_with_same_shape(types, objects)

  (types, objects, background, dim)
end

function parsescene_autumn_given_types(render_output::AbstractArray, override_types::AbstractArray, dim::Int=16, background::String="white"; color=true)
  (standard_types, objects, _, _) = parsescene_autumn(render_output, dim, background, color=color)
  println("OBJECTS")
  println(objects)
  println("OBJECT_TYPES")
  println(standard_types)
  # extract multi-cellular types that do not appear in override_types
  @show override_types 
  @show standard_types
  types_to_ungroup = filter(s_type -> (length(s_type.shape) > 1), standard_types)

  # extract single-cell types 
  grouped_type_colors = map(grouped_type -> length(grouped_type.custom_fields) == 0 ? [grouped_type.color] : grouped_type.custom_fields[1][3], types_to_ungroup)
  composition_types = map(colors -> (filter(type -> (length(type.shape) == 1) && ((length(type.custom_fields) == 0) && (length(intersect(colors, [type.color])) > 0)), standard_types), 
                                     filter(type -> (length(type.shape) == 1) && ((length(type.custom_fields) == 0) && (length(intersect(colors, [type.color])) > 0)), override_types)), 
                          grouped_type_colors)

  # only consider types to ungroup that have single-celled types of the same color
  @show types_to_ungroup 
  @show composition_types
  @show length(types_to_ungroup)
  @show length(composition_types)
  remove_types_to_ungroup = []
  for i in 1:length(composition_types)
    if composition_types[i] == ([], [])
      println("WHAT")
      println(map(type -> type.id, types_to_ungroup))
      println(types_to_ungroup[i].id)
      push!(remove_types_to_ungroup, types_to_ungroup[i])
      println(length(types_to_ungroup))
    end
  end
  types_to_ungroup = filter(t -> !(t.id in map(type -> type.id, remove_types_to_ungroup)), types_to_ungroup)
  composition_types = filter(types -> types != ([], []), composition_types)

  println("READY")
  @show types_to_ungroup 
  @show composition_types

  if (length(types_to_ungroup) == 0) # no types to try ungrouping
    new_objects = objects 
    new_types = standard_types
  else # exist types to ungroup
    @show types_to_ungroup
    new_objects = filter(obj -> !(obj.type.id in map(type -> type.id, types_to_ungroup)), objects)
    new_types = standard_types
    # println("HELLO 1")
    # @show new_types
    for grouped_type_id in 1:length(types_to_ungroup)
      grouped_type = types_to_ungroup[grouped_type_id]
      composition_types = composition_types[grouped_type_id]

      if length(grouped_type.custom_fields) == 0
        filter!(type -> type.id != grouped_type.id, new_types) # remove grouped type from new_types
        println("-------------------> LOOK AT ME")
        # @show new_types
        # determine composition type
        if length(composition_types[1]) > 0 # composition type present in standard types
          composition_type = composition_types[1][1]
        else # composition type present in override types only 
          composition_type = composition_types[2][1]
          composition_type.type_id = grouped_type.id # switch the composition type's id to the grouped type's id, since we're eliminating the grouped type
          push!(new_types, composition_type)
        end
        
        objects_to_ungroup = filter(obj -> obj.type.id == grouped_type.id, objects)
        # @show objects_to_ungroup
        for object in objects_to_ungroup
          for pos in object.type.shape
            if composition_type.custom_fields == []
              push!(new_objects, Obj(composition_type, (pos[1] + object.position[1], pos[2] + object.position[2]), [], length(new_objects) + length(objects)))
            else
              push!(new_objects, Obj(composition_type, (pos[1] + object.position[1], pos[2] + object.position[2]), [object.type.color], length(new_objects) + length(objects)))
            end
          end
        end
      else # grouped object supports multiple colors
        println("HERE I AM 2")
        colors = deepcopy(grouped_type.custom_fields[1][3])
        println(colors)
        for color in colors 
          println("HERE I AM 3")
          println(vcat(vcat(map(types_list -> map(type -> vcat(type.color, (length(type.custom_fields) == 0 ? [] : type.custom_fields[1][3])...), types_list), composition_types)...)...))
          if color in vcat(vcat(map(types_list -> map(type -> vcat(type.color, (length(type.custom_fields) == 0 ? [] : type.custom_fields[1][3])...), types_list), composition_types)...)...)
            println("HERE I AM")
            @show grouped_type
            @show color
            if length(composition_types[1]) > 0 # composition type present in standard types
              in_standard_bool = true
              type = composition_types[1][1]
              if color in vcat(type.color, (type.custom_fields == [] ? [] : type.custom_fields[1][3])...)
                composition_type = type
              end
            else # composition type present in override types only
              in_standard_bool = false
              type = composition_types[2][1]
              if color in vcat(type.color, (type.custom_fields == [] ? [] : type.custom_fields[1][3])...)
                composition_type = type
              end
            end
            
            # remove color from grouped type OR remove object if all colors have been removed
            if length(grouped_type.custom_fields[1][3]) == 2
              filter!(c -> c != color, grouped_type.custom_fields[1][3])
              type.color = color
              println("WHY 1")
              println(grouped_type)
            elseif length(grouped_type.custom_fields[1][3]) == 1
              filter!(type -> type.id != grouped_type.id, new_types) # remove object if all colors have been eliminated
            else
              filter!(c -> c != color, grouped_type.custom_fields[1][3])
            end
            println("-----> HERE 2")
            println(new_types)

            if !(in_standard_bool) 
              composition_type.id = length(new_types) + length(override_types) + 1
              push!(new_types, composition_type)
              println("----> HERE")
              println(composition_type)
            end
            
            objects_to_ungroup = filter(obj -> (obj.type.id == grouped_type.id) && 
                                               (((obj.custom_field_values == []) && obj.color == color) || (obj.custom_field_values == [color])), objects)
            println("OBJECTS TO UNGROUP")
            println(grouped_type.id)
            println(objects_to_ungroup)
            for object in objects_to_ungroup
              for pos in object.type.shape
                if composition_type.custom_fields == []
                  push!(new_objects, Obj(composition_type, (pos[1] + object.position[1], pos[2] + object.position[2]), [], length(new_objects) + length(objects)))
                else
                  push!(new_objects, Obj(composition_type, (pos[1] + object.position[1], pos[2] + object.position[2]), [object.type.color], length(new_objects) + length(objects)))
                end
              end
            end
          
          else # color not in custom_fields
            println("ADD BACK?")
            println(objects)
            println(grouped_type.id)
            println(filter(obj -> (obj.type.id == grouped_type.id) && (obj.custom_field_values == [color]), objects))
            # add previously removed objects back
            push!(new_objects, filter(obj -> (obj.type.id == grouped_type.id) && (obj.custom_field_values == [color]), objects)...)
          end
        end
      end
    end
    # println("HELLO 3")
    # @show new_types
    # @show new_objects 
    # re-number type id's 
    sort!(new_types, by = x -> x.id)
    for i in 1:length(new_types)
      type = new_types[i]
      if type.id != i
        foreach(o -> o.type.id = i, filter(obj -> obj.type.id == type.id, new_objects))
        type.id = i
      end
    end

    # re-number object id's
    sort!(new_objects, by = x -> x.id)
    for i in 1:length(new_objects)
      object = new_objects[i]
      object.id = i
    end

    for type in new_types 
      if (type.custom_fields != []) && (length(type.custom_fields[1][3]) == 1)
        type.color = type.custom_fields[1][3][1]
        type.custom_fields = []
      end
    end 

    for object in new_objects 
      if object.type.custom_fields == []
        object.custom_field_values = []
      end
    end
  end

  println("BEFORE COMBINING TYPES INTO ONE WITH COLOR FIELD")
  @show new_types 
  @show new_objects 

  # group objects with same shape but different colors into one type
  new_types, new_objects = combine_types_with_same_shape(new_types, new_objects)
  println("POST COMBINING")
  @show new_types 
  @show new_objects 

  # take the union of override_types and new_types
  @show override_types
  old_types = deepcopy(override_types)
  new_object_colors = map(o -> o.type.color, new_objects)
  types_to_add = []
  for new_type in new_types
    new_type_shape = new_type.shape
    if new_type_shape in map(t -> t.shape, old_types)
      override_type = old_types[findall(t -> t.shape == new_type_shape, old_types)[1]]
      if length(override_type.custom_fields) == 0
        if length(new_type.custom_fields) == 0
          if override_type.color != new_type.color 
            push!(override_type.custom_fields, ("color", "String", [override_type.color, new_type.color]))
          end
        else
          push!(override_type.custom_fields, ("color", "String", unique([override_type.color, new_type.custom_fields[1][3]...])))
        end
      else
        if length(new_type.custom_fields) == 0
          colors = override_type.custom_fields[1][3]
          push!(colors, new_type.color)
          unique!(colors)
        else
          push!(override_type.custom_fields[1][3], new_type.custom_fields[1][3]...)
          unique!(override_type.custom_fields[1][3])
        end
      end
    else
      new_type.id = length(old_types) + length(types_to_add) + 1
      push!(types_to_add, new_type)
    end
  end 
  new_types = vcat(old_types..., types_to_add...)

  println("POST UNION")
  println(new_types)

  # reassign objects 
  for i in 1:length(new_objects)
    object = new_objects[i]
    # new type
    type = new_types[findall(t -> t.shape == object.type.shape, new_types)[1]]
    if type.custom_fields != [] && object.custom_field_values == []
      push!(object.custom_field_values, new_object_colors[i])
    end
    object.type = type 
  end

  (new_types, new_objects, background, dim)

end

function combine_types_with_same_shape(object_types, objects)
  println("COMBINE TYPES WITH SAME SHAPE")
  println(object_types)
  println(objects)
  types_to_remove = []
  for i in 1:length(object_types)
    type_i = object_types[i]
    type_i_shape = type_i.shape
    for j in i:length(object_types)
      type_j = object_types[j] 
      type_j_shape = object_types[j].shape 
      if (i != j) && (type_i_shape == type_j_shape)
        push!(types_to_remove, type_j)
        if "color" in map(tuple -> tuple[1], type_i.custom_fields)
          colors = type_i.custom_fields[findall(tuple -> tuple[1] == "color", type_i.custom_fields)[1]][3]
          push!(colors, type_j.color)
          unique!(colors)
        else
          push!(type_i.custom_fields, ("color", "String", [type_i.color, type_j.color]))
          unique!(type_i.custom_fields)
        end
        objects_to_update_type_i = filter(obj -> obj.type.id == type_i.id, objects)
        foreach(o -> push!(o.custom_field_values, o.type.color) , objects_to_update_type_i)

        objects_to_update_type_j = filter(obj -> obj.type.id == type_j.id, objects)
        foreach(o -> o.type = type_i, objects_to_update_type_j)
        foreach(o -> o.custom_field_values = [type_j.color], objects_to_update_type_j)
      end
    end
  end
  object_types = filter(type -> !(type in types_to_remove), object_types)

  # re-number type id's 
  sort!(object_types, by = x -> x.id)
  for i in 1:length(object_types)
    type = object_types[i]
    if type.id != i
      foreach(o -> o.type.id = i, filter(obj -> obj.type.id == type.id, objects))
      type.id = i
    end
  end

  # re-number object id's
  sort!(objects, by = x -> x.id)
  for i in 1:length(objects)
    object = objects[i]
    object.id = i
  end


  println("END COMBINE TYPES WITH SAME SHAPE")
  println(object_types)
  println(objects)
  (object_types, objects)
end

"""
mutable struct ObjType
  shape::AbstractArray
  color::String
  custom_fields::AbstractArray
  id::Int
end

mutable struct Obj
  type::ObjType
  position::Tuple{Int, Int}
  custom_field_values::AbstractArray
  id::Int
end
"""

function parsescene_autumn_singlecell(render_output::AbstractArray, background::String="white", dim::Int=16)
  colors = unique(map(cell -> cell.color, render_output))
  types = map(color -> ObjType([(0,0)], color, [], findall(c -> c == color, colors)[1]), colors)
  objects = []
  for i in 1:length(render_output)
    cell = render_output[i]
    push!(objects, Obj(types[findall(type -> type.color == cell.color, types)[1]], (cell.position.x, cell.position.y), [], i))
  end
  (types, objects, background, dim)
end

function parsescene_autumn_singlecell_given_types(render_output::AbstractArray, override_types::AbstractArray, background::String="white", dim::Int=16)
  standard_types, objects, _, _ = parsescene_autumn_singlecell(render_output, background, dim)
  println("STANDARD TYPES ")
  println(standard_types)
  # compute union of standard types and override_types 
  new_types = filter(type -> !(type.color in map(t -> t.color, standard_types)), override_types)
  for i in 1:length(new_types) 
    type = new_types[i]
    type.id = length(standard_types) + i
  end
  println("RETURN VAL")
  println(vcat(standard_types..., new_types...))
  (vcat(standard_types..., new_types...), objects, background, dim)
end

# ----- end functions related to scene parsing ----- #