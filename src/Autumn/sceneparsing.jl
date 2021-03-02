using Random
using Colors
using Images

"""
Example Use:
> save("scene.png", colorview(RGBA, render(rng, generatescene_objects)))
"""

colors = ["red", "yellow", "green", "blue"]
backgroundcolors = ["white", "black"]

function colorname(rgb)
  rgb_to_colorname[rgb]
end

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

# ----- define functions related to generative model over scenes ----- #
function render(types_and_objects)
  types, objects, background, gridsize = types_and_objects
  image = [RGBA(1.0, 0.0, 0.0, 1.0) for x in 1:gridsize, y in 1:gridsize]
  println(  """
  (program
    (= GRID_SIZE $(gridsize))
    (= background "$(background)")
    $(join(map(t -> "(object ObjType$(t[2]) (: color String) (list $(join(map(cell -> "(Cell $(cell[1]) $(cell[2]) color)", t[1]), " "))))", types), "\n  "))

    $((join(map(obj -> """(: obj$(obj[4]) ObjType$(obj[1][2]))""", objects), "\n  "))...)

    $((join(map(obj -> """(= obj$(obj[4]) (initnext (ObjType$(obj[1][2]) "$(obj[3])" (Position $(obj[2][1] - 1) $(obj[2][2] - 1))) (prev obj$(obj[4]))))""", objects), "\n  ")))
  )
  """)
  for object in objects
    center_x = object[2][1]
    center_y = object[2][2]
    type = object[1]
    color = rgb(object[3])
    for shape_position in type[1]
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
    $(join(map(t -> "(object ObjType$(t[2]) (: color String) (list $(join(map(cell -> "(Cell $(cell[1]) $(cell[2]) color)", t[1]), " "))))", types), "\n  "))

    $((join(map(obj -> """(: obj$(obj[4]) ObjType$(obj[1][2]))""", objects), "\n  "))...)

    $((join(map(obj -> """(= obj$(obj[4]) (initnext (ObjType$(obj[1][2]) "$(obj[3])" (Position $(obj[2][1] - 1) $(obj[2][2] - 1))) (prev obj$(obj[4]))))""", objects), "\n  ")))
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
    push!(types, (shape, length(types) + 1))
  end

  for i in 1:numObjects
    objPosition = objectPositions[i]
    objColor = colors[rand(rng, 1:length(colors))]
    objType = types[rand(rng, 1:length(types))]

    push!(objects, (objType, objPosition, objColor, length(objects) + 1))    
  end
  (types, objects, background, gridsize)
end

function neighbors(shape::AbstractArray)
  neighborPositions = vcat(map(pos -> neighbors(pos), shape)...)
  unique(filter(pos -> !(pos in shape), neighborPositions))
end

function neighbors(position)
  x = position[1]
  y = position[2]
  [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
end