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
> println(parsescene(image))
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
struct ObjType
  shape::AbstractArray
  color::String
  custom_fields::AbstractArray
  id::Int
end

struct Obj
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

function generatescene_program(rng=Random.GLOBAL_RNG; gridsize::Int=16)
  types, objects, background, _ = generatescene_objects(rng, gridsize=gridsize)
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

    @show custom_fields
    @show custom_field_values

    push!(objects, Obj(objType, objPosition, custom_field_values, length(objects) + 1))    
  end
  (types, objects, background, gridsize)
end

# ----- end functions related to generative model over scenes ----- # 

# ----- define functions related to scene parsing -----

function parsescene_singlecell(image)
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

function parsescene(image; color=true)
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

# ----- end functions related to scene parsing -----