const saved_traces_directory = "/Users/riadas/Documents/urop/today_temp/CausalDiscovery.jl/saved_test_traces/"

# function shorten(arr)
#   indices_to_remove = []
#   segment_length = 0 
#   for i in 1:length(arr)
#     if arr[i] == "nothing"
#       segment_length += 1
#     else
#       segment_length = 0
#     end

#     if segment_length >= 2 
#       push!(indices_to_remove, i)
#     end
#   end

#   new_arr = [arr[i] for i in 1:length(arr) if !(i in indices_to_remove)]

#   new_arr
# end

# remove out-of-bounds cells from frames 
function filter_out_of_bounds_cells(observations, grid_size) 
  map(obs -> filter(cell -> cell.position.x in collect(0:(grid_size - 1)) && cell.position.y in collect(0:(grid_size - 1)), obs), observations)
end

function generate_observations_interface(model_name, i=1; dir="")
  directory_location = dir == "" ? string(saved_traces_directory, model_name) : string(dir, model_name)
  index = length(filter(f -> occursin(".jld", f), readdir(directory_location))) - (i-1) # take most recently created file
  file_location = string(directory_location, "/", index, ".jld")
  observations_dict = JLD.load(file_location)
  observations = map(obs -> map(cell -> Autumn.AutumnStandardLibrary.Cell(cell[1], cell[2], cell[3]), obs[2:end]), observations_dict["observations"])
  user_events = observations_dict["user_events"]
  grid_size = observations_dict["grid_size"]
  filter_out_of_bounds_cells(observations, grid_size), user_events, grid_size
end

function generate_observations_custom_input(m::Module, user_events)
  observations = []  
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  push!(observations, Base.invokelatest(m.render, state.scene))

  for i in 1:length(user_events)
    event = user_events[i]
    if event == "left"
      state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
      push!(user_events, event)
    elseif event == "right"
      state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
      push!(user_events, event)
    elseif event == "up"
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
      push!(user_events, event)
    elseif event == "down"
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, Base.invokelatest(m.Down))
      push!(user_events, event)
    elseif occursin("click", event)
      x = parse(Int, split(event, " ")[2])
      y = parse(Int, split(event, " ")[3])
      state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, x, y), nothing, nothing, nothing, nothing)
      push!(user_events, event)
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  observations
end

function generate_observations_ice(m::Module)
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  clicks = [(1, 4), (2, 6)]
  for i in 0:25
    if i in [2, 8, 12] # 17
      # state = Base.invokelatest(m.next(state, nothing, nothing, nothing, nothing, nothing)
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, Base.invokelatest(m.Down))
      push!(user_events, "down")
    elseif i == 10
      state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
      push!(user_events, "right")
    elseif i == 14
      state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
      push!(user_events, "left")
    elseif i == 6 || i == 17
      x, y = clicks[i == 6 ? 1 : 2]
      state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, x, y), nothing, nothing, nothing, nothing)
      push!(user_events, "clicked $(x) $(y)")
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  filter_out_of_bounds_cells(observations, 8), user_events, 8
end

# function generate_observations_particles(m::Module)
#   state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
#   observations = []
#   user_events = []
#   push!(observations, Base.invokelatest(m.render, state.scene))

#   for i in 0:20
#     if i in [2, 5, 8] # 17
#       # state = Base.invokelatest(m.next(state, nothing, nothing, nothing, nothing, nothing)
#       x = rand(1:10)
#       y = rand(1:10)
#       state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, x, y), nothing, nothing, nothing, nothing)
#       push!(user_events, "clicked $(x) $(y)")
#     else
#       state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
#       push!(user_events, nothing)
#     end
#     push!(observations, Base.invokelatest(m.render, state.scene))
#   end
#   observations, user_events, 16
# end


function generate_observations_lights(m::Module)
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  clicks = Dict([1 => (4, 3),
                 10 => (7, 8),
                #  10 => (1, 13),
                 13 => (8, 10),
                 16 => (2, 6),
                ])

  for i in 0:22
    if i in collect(keys(clicks))
      click_x, click_y = clicks[i]
      state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, click_x, click_y), nothing, nothing, nothing, nothing)
      push!(user_events, "click $(click_x) $(click_y)")
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  map(obs -> filter(cell -> cell.color != "white", obs), observations), user_events, 10
end

function generate_observations_space_invaders(m::Module)
  # state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  # observations = []
  # user_events = []
  # push!(observations, Base.invokelatest(m.render, state.scene))

  # for i in 0:20
  #   if i in [3, 10, 16]
  #     state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
  #     push!(user_events, "up")
  #   elseif i in [6] 
  #     state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
  #     push!(user_events, "left")
  #   elseif i in [12]
  #     state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
  #     push!(user_events, "right")
  #   else
  #     state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
  #     push!(user_events, nothing)
  #   end
  #   push!(observations, Base.invokelatest(m.render, state.scene))
  # end
  # observations, user_events, 8

  # state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  # observations = []
  # user_events = []
  # push!(observations, Base.invokelatest(m.render, state.scene))

  # for i in 0:40
  #   if i in [1, 4, 7, 10, 13, 16, 19, 22, 25]
  #     state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
  #     push!(user_events, "up")
  #   elseif i in [15]
  #     state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
  #     push!(user_events, "left")
  #   elseif i in [26, 27, 28]
  #     state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
  #     push!(user_events, "right")
  #   else
  #     state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
  #     push!(user_events, nothing)
  #   end
  #   push!(observations, Base.invokelatest(m.render, state.scene))
  # end
  # # observations, user_events, 16
  # filter_out_of_bounds_cells(observations, 16), user_events, 16
  JLD.load("deterministic_space_invaders_output_2.jld", "chase")
end

function generate_observations_disease(m::Module)
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  for i in 0:20
    if i in [1, 2, 18]
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, Base.invokelatest(m.Down))
      push!(user_events, "down")
    elseif i in [6, 14]
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
      push!(user_events, "up")
    elseif i in [8, 12] 
      state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
      push!(user_events, "left")
    elseif i in [4, 16]
      state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
      push!(user_events, "right")
    elseif i in [10]
      state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, 4, 4), nothing, nothing, nothing, nothing)
      push!(user_events, "click 4 4")
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  observations, user_events, 8
end

function generate_observations_water_plug(m::Module)
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  clicks = Dict([0 => (4, 5), # purple
                 1 => (0, 0), # purple (WAS (8, 3))
                 2 => (5, 0), # switch to yellow!
                 3 => (4, 5), # click same purple
                 5 => (6, 6), # yellow
                 6 => (15, 0), # yellow (NEWLY ADDED)
                 7 => (7, 4), # yellow
                 8 => (8, 0), # switch to blue!
                 10 => (6, 10), # blue ...
                 11 => (7, 10),
                 12 => (8, 10),
                 13 => (9, 10),
                 14 => (6, 10),
                 15 => (7, 10),
                 16 => (8, 10),
                 17 => (9, 10),
                 19 => (6, 6), # click same yellow
                 20 => (1, 0), # blue
                 22 => (11, 0), # erase yellow!
                 24 => (0, 14), # blue
                 26 => (5, 0), # switch to yellow 
                 27 => (2, 3), # yellow
                 28 => (15, 15), # same blue as earlier
                 29 => (1, 1), # yellow
                 30 => (14, 0), # remove all 
                 32 => (2, 2), # yellow 
                 34 => (2, 0), # click purple 
                 36 => (5, 5), # purple 
                 38 => (7, 8), # purple
                 40 => (14, 0), # remove all
                 41 => (14, 0), # remove all 
                 42 => (0, 0),
                 43 => (1, 0),
                 44 => (1, 1),
                 45 => (2, 1),
                 46 => (3, 1),
                 47 => (3, 0),
                 48 => (4, 0),
                 49 => (8, 0), # switch to blue again
                 50 => (13, 0),
                 51 => (9, 15),
                 52 => (10, 15),
                 53 => (11, 15),
                 54 => (12, 15),
                 55 => (12, 0),
                 56 => (15, 0),
                 57 => (13, 0), # try with and without this
                 58 => (14, 0), # remove all 
                 59 => (13, 0),
                 60 => (10, 1),
                ])

  for i in 0:62
    if i in collect(keys(clicks))
      click_x, click_y = clicks[i]
      state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, click_x, click_y), nothing, nothing, nothing, nothing)
      push!(user_events, "click $(click_x) $(click_y)")
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  observations, user_events, 16
end

function generate_observations_paint(m::Module)
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  clicks = Dict([1 => (4, 5),
                 2 => (8, 3),
                 6 => (5, 0),
                 7 => (6, 6),
                 10 => (7, 4),
                 13 => (8, 0),
                 16 => (6, 10),
                 18 => (7, 10),
                 24 => (1, 1),
                ])

  for i in 0:25
    if i in collect(keys(clicks))
      click_x, click_y = clicks[i]
      state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, click_x, click_y), nothing, nothing, nothing, nothing)
      push!(user_events, "click $(click_x) $(click_y)")
    elseif i in [4, 8, 11, 14, 17]
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
      push!(user_events, "up")
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  observations, user_events, 16
end

function generate_observations_wind(m::Module)
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  for i in 0:21
    if i in [3, 9, 10]
      state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
      push!(user_events, "left") 
    elseif i in [5, 6, 14, 15]
      state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
      push!(user_events, "right")
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  filter_out_of_bounds_cells(observations, 17), user_events, 17
end

function generate_observations_gravity(m::Module)
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  clicks = Dict([1 => (8, 8),
                 2 => (6, 5),
                 3 => (0, 7),
                 5 => (11, 10),
                 8 => (15, 7),
                 11 => (7, 0),
                 13 => (7, 15),
                ])

  for i in 0:17
    if i in collect(keys(clicks))
      click_x, click_y = clicks[i]
      state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, click_x, click_y), nothing, nothing, nothing, nothing)
      push!(user_events, "click $(click_x) $(click_y)")
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  observations, user_events, 16
end

function generate_observations_sand(m::Module)
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  clicks = Dict([2 => (3, 1),
                 3 => (2, 2),
                 5 => (7, 0),
                 7 => (5, 7),
                 17 => (2, 0),
                 18 => (0, 3),
                ])

  for i in 0:20
    if i in collect(keys(clicks))
      click_x, click_y = clicks[i]
      state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, click_x, click_y), nothing, nothing, nothing, nothing)
      push!(user_events, "click $(click_x) $(click_y)")
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  observations, user_events, 10
end

function generate_observations_sand_simple(m::Module)
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  clicks = Dict([2 => (2, 7),
                 4 => (2, 5),
                 6 => (3, 3),
                 8 => (7, 0),
                 10 => (3, 4),
                 12 => (8, 1),
                 17 => (2, 0),
                 18 => (5, 3),
                ])

  for i in 0:30
    if i in collect(keys(clicks))
      click_x, click_y = clicks[i]
      state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, click_x, click_y), nothing, nothing, nothing, nothing)
      push!(user_events, "click $(click_x) $(click_y)")
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  observations, user_events, 10
end

function generate_observations_gravity3(m::Module)
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  events = Dict([1 => "left",
                 2 => "up",
                 3 => "down",
                 4 => "down",
                 5 => "up",
                 6 => "right",
                 7 => "right",
                 8 => "up",
                 9 => "down",
                 10 => "down",
                 11 => "up",
                 12 => "left",
                 13 => "up",
                 14 => "left",
                 15 => "right",
                 16 => "right",
                 17 => "left",
                 18 => "down",
                 19 => "down",
                 20 => "left",
                 21 => "right",
                 22 => "right",
                 23 => "left",
                 24 => "up",
                ])


# events = Dict([1 => "left",
# 3 => "up",
# 5 => "down",
# 7 => "down",
# 9 => "up",
# 11 => "right",
# 13 => "right",
# 15 => "up",
# 17 => "down",
# 19 => "down",
# 21 => "up",
# 23 => "left",
# 25 => "up",
# 27 => "left",
# 29 => "right",
# 31 => "right",
# 33 => "left",
# 35 => "down",
# 37 => "down",
# 39 => "left",
# 41 => "right",
# 43 => "right",
# 45 => "left",
# 47 => "up",
# ]) 


  for i in 0:25
    if i in collect(keys(events))
      event = events[i]
      if event == "left"
        state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
      elseif event == "right"
        state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
      elseif event == "up"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
      elseif event == "down"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, Base.invokelatest(m.Down))
      end
      push!(user_events, event)
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  observations, user_events, 40
end

function generate_observations_egg(m::Module)
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  for i in 0:29 
    if i < 9 || i == 16
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
      push!(user_events, "up")
    elseif i in [12, 15,  20]
      state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
      push!(user_events, "left")
    elseif i in [13, 14, 21]
      state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
      push!(user_events, "right")
    elseif i == 18
      state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, 0, 0), nothing, nothing, nothing, nothing)
      push!(user_events, "click 0 0")
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  observations, user_events, 16
end

function generate_observations_grow(m::Module)
  # state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  # observations = []
  # user_events = []
  # push!(observations, Base.invokelatest(m.render, state.scene))

  # events = Dict([1 => "left",
  #                2 => "down",
  #                5 => "down",
  #                8 => "down",
  #                9 => "left",
  #                10 => "left",
  #                11 => "down",
  #                14 => "down",
  #                18 => (0, 0),
  #                19 => "down",
  #                20 => "left",
  #                21 => "left",
  #                22 => "down",
  #                23 => (1, 0),
  #                24 => (2, 0),
  #                25 => (3, 0),
  #                26 => (4, 0),
  #                27 => (5, 0),
  #                29 => (6, 0),
  #                31 => (6, 0),
  #                32 => (5, 0),
  #                33 => (4, 0),
  #                34 => (3, 0),
  #                35 => (2, 0),
  #                37 => (1, 0),
  #               ])

  # for i in 0:38
  #   if i in collect(keys(events))
  #     event = events[i]
  #     if event == "left"
  #       state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
  #       push!(user_events, event)
  #     elseif event == "right"
  #       state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
  #       push!(user_events, event)
  #     elseif event == "up"
  #       state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
  #       push!(user_events, event)
  #     elseif event == "down"
  #       state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, Base.invokelatest(m.Down))
  #       push!(user_events, event)
  #     else 
  #       click_x, click_y = events[i]
  #       state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, click_x, click_y), nothing, nothing, nothing, nothing)
  #       push!(user_events, "click $(click_x) $(click_y)")
  #     end
  #   else
  #     state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
  #     push!(user_events, nothing)
  #   end
  #   push!(observations, Base.invokelatest(m.render, state.scene))
  # end
  # observations, user_events, 8

  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  events = Dict([
                 0 => "left",
                 1 => "right",
                 2 => "down",
                 8 => "down",
                 14 => "down",
                 15 => "left",
                #  20 => "down",  
                 27 => "left",
                 29 => "down",
                 37 => "down",
                 39 => (0, 0),
                 43 => "down",
                 44 => "left",
                 45 => "left",
                 49 => "down",
                 53 => (1, 0),
                 55 => (2, 0),
                 57 => (3, 0),
                 59 => (4, 0),
                 61 => (5, 0),
                 63 => (5, 0),
                 64 => "down",
                 70 => "down",
                 80 => "right",
                 81 => "right",
                 82 => "right",
                 83 => "right",
                 85 => (4, 0),
                 87 => (3, 0),
                 89 => (2, 0),
                 91 => (1, 0),
                ])

  for i in -1:92
    if i in collect(keys(events))
      event = events[i]
      if event == "left"
        state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
        push!(user_events, event)
      elseif event == "right"
        state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
        push!(user_events, event)
      elseif event == "up"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
        push!(user_events, event)
      elseif event == "down"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, Base.invokelatest(m.Down))
        push!(user_events, event)
      else 
        click_x, click_y = events[i]
        state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, click_x, click_y), nothing, nothing, nothing, nothing)
        push!(user_events, "click $(click_x) $(click_y)")
      end
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  # observations, user_events, 7
  filter_out_of_bounds_cells(observations, 7), user_events, 7
end

function generate_observations_magnets(m::Module)
  observations, user_events, grid_size = JLD.load("magnets_final.jld", "data") # JLD.load("magnets_i_observations.jld")["observations"]
  observations = observations[1]
  user_events = user_events[1]
  observations, user_events, grid_size 
  # state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  # observations = []
  # user_events = []
  # push!(observations, Base.invokelatest(m.render, state.scene))

  # events = Dict([1 => "left",
  #                2 => "left",
  #                3 => "left",
  #                4 => "right",
  #                5 => "right",
  #                6 => "right",
  #                7 => "up",
  #                8 => "up",
  #                9 => "up",
  #                10 => "down",
  #                11 => "down",
  #                12 => "down",
  #                13 => "right",
  #                15 => "up",
  #                16 => "up",
  #                17 => "left",
  #                18 => "left",
  #                19 => "left",
  #                20 => "down",
  #                21 => "down",
  #                22 => "right",
  #                23 => "right",
  #                24 => "right",
  #                26 => "down",
  #                27 => "down",
  #                28 => "left",
  #                29 => "left",
  #                30 => "up",
  #                31 => "up",
  #                32 => "left",
  #                33 => "left",
  #                34 => "left",
  #                35 => "right",
  #                36 => "right",
  #                37 => "right",
  #                38 => "up",
  #                40 => "right",
  #                41 => "up",
  #                42 => "left",
  #                43 => "left",
  #                44 => "left",
  #                45 => "down",
  #                46 => "down",
  #                47 => "down",
  #                48 => "right",
  #                50 => "right",
  #               ])

  # for i in 0:51
  #   if i in collect(keys(events))
  #     event = events[i]
  #     if event == "left"
  #       state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
  #       push!(user_events, event)
  #     elseif event == "right"
  #       state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
  #       push!(user_events, event)
  #     elseif event == "up"
  #       state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
  #       push!(user_events, event)
  #     elseif event == "down"
  #       state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, Base.invokelatest(m.Down))
  #       push!(user_events, event)
  #     end
  #   else
  #     state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
  #     push!(user_events, nothing)
  #   end
  #   push!(observations, Base.invokelatest(m.render, state.scene))
  # end
  # observations, user_events, 16
end

function generate_observations_magnets2(m::Module)

end

function generate_observations_magnets3(m::Module)

end

function generate_observations_gravity2(m::Module)
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  # clicks = Dict([1 => (15, 6), # X
  #                2 => (15, 6), # same click (no add)
  #                3 => (12, 3), # Y
  #                5 => (18, 10), # Z
  #                7 => (0, 14), 
  #                9 => (20, 8), # X
  #                11 => (23, 3), # Y
  #                13 => (17, 13), # Z
  #                15 => (29, 14),
  #                17 => (14, 0),
  #                19 => (14, 29),
  #                20 => (28, 5), # X
  #                 ])

  clicks = Dict([1 => (15, 6), # X
                 2 => (15, 6), # same click (no add)
                 3 => (12, 3), # Y
                 4 => (12, 3), # same click (no add)
                 5 => (18, 10), # Z
                 7 => (20, 8), # X
                 9 => (0, 14), 
                 11 => (14, 29),
                 13 => (23, 3), # Y
                 15 => (7, 20), # Z
                 17 => (29, 14),
                 19 => (14, 0),
                 21 => (14, 0),
                 23 => (7, 20), # X
                  ])

  for i in 0:22
    if i in collect(keys(clicks))
      click_x, click_y = clicks[i]
      state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, click_x, click_y), nothing, nothing, nothing, nothing)
      push!(user_events, "click $(click_x) $(click_y)")
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  observations, user_events, 30
end

function generate_observations_particles(m::Module)
  observations, user_events, grid_size = JLD.load("deterministic_particles_input.jld", "particles")
  # state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  # observations = []
  # user_events = []
  # push!(observations, Base.invokelatest(m.render, state.scene))

  # clicks = Dict([1 => (4, 3),
  #                3 => (13, 13),
  #                5 => (9, 9),
  #               ])

  # for i in 0:22
  #   if i in collect(keys(clicks))
  #     click_x, click_y = clicks[i]
  #     state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, click_x, click_y), nothing, nothing, nothing, nothing)
  #     push!(user_events, "click $(click_x) $(click_y)")
  #   else
  #     state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
  #     push!(user_events, nothing)
  #   end
  #   push!(observations, Base.invokelatest(m.render, state.scene))
  # end
  observations[1:19], user_events[1:18], 16
end

function generate_observations_chase(m::Module) 
  JLD.load("deterministic_chase_output_2.jld", "chase")
  # state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  # observations = []
  # user_events = []
  # push!(observations, Base.invokelatest(m.render, state.scene))

  # events = Dict([1 => "down",
  #                2 => "up",
  #                3 => "left",
  #                4 => "right",
  #                1 => "down",
  #                2 => "up",
  #                3 => "left",
  #                4 => "right",
  #               ])

  # for i in 0:40
  #   if i in collect(keys(events))
  #     event = events[i]
  #     if event == "left"
  #       state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
  #       push!(user_events, event)
  #     elseif event == "right"
  #       state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
  #       push!(user_events, event)
  #     elseif event == "up"
  #       state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
  #       push!(user_events, event)
  #     elseif event == "down"
  #       state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, Base.invokelatest(m.Down))
  #       push!(user_events, event)
  #     end
  #   else
  #     state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
  #     push!(user_events, nothing)
  #   end
  #   push!(observations, Base.invokelatest(m.render, state.scene))
  # end
  # observations, user_events, 16
end

function generate_observations_ants(m::Module)
  JLD.load("deterministic_ants_input.jld", "ants")
  # state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  # observations = []
  # user_events = []
  # push!(observations, Base.invokelatest(m.render, state.scene))

  # clicks = Dict([1 => (4, 3),
  #                4 => (13, 13),
  #                7 => (11, 11),
  #                12 => (15, 14),
  #               ])

  # for i in 0:15
  #   if i in collect(keys(clicks))
  #     click_x, click_y = clicks[i]
  #     state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, click_x, click_y), nothing, nothing, nothing, nothing)
  #     push!(user_events, "click $(click_x) $(click_y)")
  #   else
  #     state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
  #     push!(user_events, nothing)
  #   end
  #   push!(observations, Base.invokelatest(m.render, state.scene))
  # end
  # observations, user_events, 16
end

function generate_observations_sokoban(m::Module)
  # state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  # observations = []
  # user_events = []
  # push!(observations, Base.invokelatest(m.render, state.scene))

  # events = Dict([1 => "left",
  #                2 => "up",
  #                3 => "up",
  #                4 => "right",
  #                5 => "down",
  #                6 => "down",
  #                7 => "left",
  #                8 => "left",
  #                10 => "left",
  #                11 => "left",
  #                12 => "left",
  #                13 => "left",
  #                14 => "up",
  #                15 => "up",
  #                16 => "left",
  #                17 => "left",
  #                18 => "left",
  #                19 => "down",
  #                20 => "left",
  #               #  21 => "left",
  #                22 => "up",
  #                24 => "up",
  #                26 => "up",
  #                27 => "down",
  #                28 => "down",
  #                29 => "down",
  #                30 => "right",
  #                31 => "right",
  #                32 => "down",
  #                33 => "down",
  #                34 => "left",
  #                35 => "up",
  #                36 => "up",
  #                37 => "up",
  #                38 => "up",
  #                40 => "down",
  #                41 => "down",
  #                42 => "down",
  #                43 => "down",
  #                44 => "down",
  #                45 => "down",
  #                46 => "down",
  #               #  47 => "down",
  #                48 => "down",
  #                49 => "down",
  #                50 => "down",
  #                52 => "left",
  #                53 => "left",
  #                55 => "right",
  #                56 => "right",
  #                57 => "right",
  #                58 => "right",
  #                59 => "right",
  #                60 => "right",
  #                61 => "right",
  #                62 => "right",
  #                63 => "right",
  #                64 => "right",
  #               #  65 => "right",
  #               #  66 => "right",
  #                67 => "right",
  #                68 => "up",
  #                69 => "up",
  #                70 => "left",
  #                71 => "left",
  #                72 => "left",
  #                ])

  # for i in 0:74
  #   if i in collect(keys(events))
  #     event = events[i]
  #     if event == "left"
  #       state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
  #       push!(user_events, event)
  #     elseif event == "right"
  #       state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
  #       push!(user_events, event)
  #     elseif event == "up"
  #       state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
  #       push!(user_events, event)
  #     elseif event == "down"
  #       state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, Base.invokelatest(m.Down))
  #       push!(user_events, event)
  #     end
  #   else
  #     state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
  #     push!(user_events, nothing)
  #   end
  #   push!(observations, Base.invokelatest(m.render, state.scene))
  # end
  # observations, user_events, 16
  observations, user_events, grid_size = JLD.load("final_sokoban_observations.jld", "data")
  observations = observations[1]
  user_events = user_events[1]
  
  observations, user_events, grid_size
end

function generate_observations_sokoban_2(m::Module)

end

function generate_observations_count_1(m::Module)
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  events = Dict([2 => "left",
                 4 => "right",
                 7 => "right",
                 12 => "left",
                 15 => "left",
                 16 => "right",
                 18 => "right",
                 19 => "left",
                ])

  for i in 0:20
    if i in collect(keys(events))
      event = events[i]
      if event == "left"
        state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
        push!(user_events, event)
      elseif event == "right"
        state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
        push!(user_events, event)
      elseif event == "up"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
        push!(user_events, event)
      elseif event == "down"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, Base.invokelatest(m.Down))
        push!(user_events, event)
      elseif occursin("click", event)
        x = parse(Int, split(event, " ")[2])
        y = parse(Int, split(event, " ")[3])
        state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, x, y), nothing, nothing, nothing, nothing)
        push!(user_events, event)
      end
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  observations, user_events, 100
end

function generate_observations_count_2(m::Module)
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  events = Dict([
                -6 => "left",
                -3 => "right",
                -1 => "right",
                 1 => "left",
    
                 2 => "left",
                 5 => "left",
                 8 => "right",
                 12 => "right",
                 14 => "right",
                 16 => "right",
                 18 => "left",
                 20 => "left",
                 
                ])

  for i in -7:30
    if i in collect(keys(events))
      event = events[i]
      if event == "left"
        state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
        push!(user_events, event)
      elseif event == "right"
        state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
        push!(user_events, event)
      elseif event == "up"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
        push!(user_events, event)
      elseif event == "down"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, Base.invokelatest(m.Down))
        push!(user_events, event)
      elseif occursin("click", event)
        x = parse(Int, split(event, " ")[2])
        y = parse(Int, split(event, " ")[3])
        state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, x, y), nothing, nothing, nothing, nothing)
        push!(user_events, event)
      end
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  observations, user_events, 100
end

function generate_observations_count_3(m::Module)
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  events = Dict([
                 -6 => "left",
                 -3 => "right",
                 -1 => "right",
                 1 => "left",

                 2 => "left",
                 5 => "left",
                 8 => "right",
                 12 => "right",
                 14 => "right",
                 16 => "right",
                 18 => "left",
                 20 => "left",
                
                 22 => "left",
                 25 => "left",
                 28 => "left",
                 31 => "right",
                 35 => "right",
                 39 => "right",
                 43 => "right",
                 45 => "right",
                 47 => "right",
                 50 => "left",
                 52 => "left",
                 54 => "left",
                ])

  for i in -7:60
    if i in collect(keys(events))
      event = events[i]
      if event == "left"
        state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
        push!(user_events, event)
      elseif event == "right"
        state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
        push!(user_events, event)
      elseif event == "up"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
        push!(user_events, event)
      elseif event == "down"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, Base.invokelatest(m.Down))
        push!(user_events, event)
      elseif occursin("click", event)
        x = parse(Int, split(event, " ")[2])
        y = parse(Int, split(event, " ")[3])
        state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, x, y), nothing, nothing, nothing, nothing)
        push!(user_events, event)
      end
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  observations, user_events, 100
end

function generate_observations_count_4(m::Module)
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  events = Dict([
                -6 => "left",
                -3 => "right",
                -1 => "right",
                1 => "left",

                2 => "left",
                5 => "left",
                8 => "right",
                12 => "right",
                14 => "right",
                16 => "right",
                18 => "left",
                20 => "left",
              
                22 => "left",
                25 => "left",
                28 => "left",
                31 => "right",
                35 => "right",
                39 => "right",
                43 => "right",
                45 => "right",
                47 => "right",
                50 => "left",
                52 => "left",
                54 => "left",
    
                62 => "left",
                65 => "left",
                68 => "left",
                70 => "left",
                72 => "right",
                75 => "right",
                79 => "right",
                83 => "right",

                85 => "right",
                87 => "right",
                88 => "right",
                90 => "right",
                92 => "left",
                94 => "left",
                96 => "left",
                97 => "left",
                ])

  for i in -7:100
    if i in collect(keys(events))
      event = events[i]
      if event == "left"
        state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
        push!(user_events, event)
      elseif event == "right"
        state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
        push!(user_events, event)
      elseif event == "up"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
        push!(user_events, event)
      elseif event == "down"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, Base.invokelatest(m.Down))
        push!(user_events, event)
      elseif occursin("click", event)
        x = parse(Int, split(event, " ")[2])
        y = parse(Int, split(event, " ")[3])
        state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, x, y), nothing, nothing, nothing, nothing)
        push!(user_events, event)
      end
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  observations, user_events, 100
end

function generate_observations_count_5(m::Module)
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  events = Dict([
                -6 => "left",
                -3 => "right",
                -1 => "right",
                1 => "left",

                2 => "left",
                5 => "left",
                8 => "right",
                12 => "right",
                14 => "right",
                16 => "right",
                18 => "left",
                20 => "left",
              
                22 => "left",
                25 => "left",
                28 => "left",
                31 => "right",
                35 => "right",
                39 => "right",
                43 => "right",
                45 => "right",
                47 => "right",
                50 => "left",
                52 => "left",
                54 => "left",
    
                62 => "left",
                65 => "left",
                68 => "left",
                70 => "left",
                72 => "right",
                75 => "right",
                79 => "right",
                83 => "right",

                85 => "right",
                87 => "right",
                88 => "right",
                90 => "right",
                92 => "left",
                94 => "left",
                96 => "left",
                97 => "left",

                102 => "left",
                105 => "left",
                108 => "left",
                110 => "left",
                111 => "left",
                112 => "right",
                115 => "right",
                119 => "right",
                123 => "right",
                124 => "right",

                125 => "right",
                127 => "right",
                128 => "right",
                130 => "right",
                131 => "right",
                132 => "left",
                134 => "left",
                136 => "left",
                137 => "left",
                138 => "left",

                ])

  for i in -7:140
    if i in collect(keys(events))
      event = events[i]
      if event == "left"
        state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
        push!(user_events, event)
      elseif event == "right"
        state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
        push!(user_events, event)
      elseif event == "up"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
        push!(user_events, event)
      elseif event == "down"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, Base.invokelatest(m.Down))
        push!(user_events, event)
      elseif occursin("click", event)
        x = parse(Int, split(event, " ")[2])
        y = parse(Int, split(event, " ")[3])
        state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, x, y), nothing, nothing, nothing, nothing)
        push!(user_events, event)
      end
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  observations, user_events, 100
end

function generate_observations_coins(m)
  observations, user_events, grid_size = JLD.load("coins_full_reverse.jld", "data")
  observations = observations[1]
  user_events = user_events[1]

  observations, user_events, grid_size
end

function generate_observations_coins5(m)
  # 5 coins
  JLD.load("new_coins_data_5.jld")["data"]
end

function generate_observations_coins7(m)
  # 7 coins 
  JLD.load("new_coins_data_7.jld")["data"]
end

function generate_observations_coins9(m)
  # 9 coins?
  observations, user_events, grid_size = JLD.load("new_coins_data_9.jld")["data"]
  user_events[195] = "click 7 10"
  user_events[197] = "click 7 10"
  observations, user_events, grid_size
end

function generate_observations_grow2(m)
  observations, user_events, grid_size = JLD.load("observations_grow_ii.jld")["observations"]
  observations, user_events, grid_size
end

function generate_observations_mario2(m)
  observations, user_events, grid_size = JLD.load("observations_mario_ii.jld")["observations"]
  user_events, observations, grid_size
end

function generate_observations_mario(m::Module)
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  events = Dict([1 => "left",
                 2 => "click 0 11",
                 3 => "right",
                 4 => "up",
                 5 => "left",
                 6 => "up",
                 10 => "up",
                 11 => "right",
                 12 => "left",
                 13 => "left",
                 15 => "click 4 4",
                 16 => "click 5 5",
                 17 => "click 4 5",
                 18 => "left",
                 20 => "right",
                 21 => "up",
                 22 => "right",
                 23 => "right",
                 25 => "right",
                 26 => "right",
                 27 => "up",
                 28 => "right",
                 37 => "right",
                 
                 41 => "click 15 15",
                 46 => "click 14 13",
                 47 => "click 14 14",
                 55 => "up",
                 56 => "left",
                 57 => "left",
                 58 => "left",
                 59 => "left",
                 64 => "up",
                 69 => "click 0 5",
                 73 => "right",
                 75 => "up",
                 76 => "click 0 7",
                 77 => "click 0 9",                 
                ])

  for i in 0:79
    if i in collect(keys(events))
      event = events[i]
      if event == "left"
        state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
        push!(user_events, event)
      elseif event == "right"
        state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
        push!(user_events, event)
      elseif event == "up"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
        push!(user_events, event)
      elseif event == "down"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, Base.invokelatest(m.Down))
        push!(user_events, event)
      elseif occursin("click", event)
        x = parse(Int, split(event, " ")[2])
        y = parse(Int, split(event, " ")[3])
        state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, x, y), nothing, nothing, nothing, nothing)
        push!(user_events, event)
      end
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  # observations, user_events, 16
  filter_out_of_bounds_cells(observations, 16), user_events, 16
end

function generate_observations_bullets(m::Module)
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  events = Dict([
                #  3 => "click 15 0",
                #  4 => "click 0 0",
                #  5 => "left",
                 2 => "click 1 1",
                 4 => "left",
                 5 => "click 15 15",
                 8 => "up",
                 10 => "click 2 2",
                 11 => "right",
                 13 => "click 3 3",
                 14 => "down",
                 16 => "click 4 4",
                 27 => "down",
                 28 => "down",
                 29 => "down",
                 30 => "down",
                 31 => "down",
                 32 => "click 15 1",
                 34 => "left",
                 35 => "left",
                 36 => "left",
                 37 => "left",
                 39 => "click 1 0",
                 40 => "up",
                 45 => "click 2 0",
                 47 => "right",
                 49 => "click 3 0",
                 50 => "down",
                 51 => "click 4 0", 
                ])

  # events = Dict([
  #               #  3 => "click 15 0",
  #               #  4 => "click 0 0",
  #               #  5 => "left",
  #                5 => "click 1 1",
  #                7 => "click 1 1",
  #                9 => "up",
  #                11 => "click 1 1",
  #                13 => "click 2 2",
  #                15 => "right",
  #                17 => "click 3 3",
  #                19 => "click 4 4",
  #                21 => "down",
  #                23 => "click 4 4",
  #                25 => "click 0 0",
  #               ])

  for i in 1:52
    if i in collect(keys(events))
      event = events[i]
      if event == "left"
        state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
        push!(user_events, event)
      elseif event == "right"
        state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
        push!(user_events, event)
      elseif event == "up"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
        push!(user_events, event)
      elseif event == "down"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, Base.invokelatest(m.Down))
        push!(user_events, event)
      elseif occursin("click", event)
        x = parse(Int, split(event, " ")[2])
        y = parse(Int, split(event, " ")[3])
        state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, x, y), nothing, nothing, nothing, nothing)
        push!(user_events, event)
      end
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  filter_out_of_bounds_cells(observations, 16), user_events, 16
end

function generate_observations_double_count_1(m::Module) 
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  events = Dict([2 => "left",
                 4 => "right",
                 7 => "right",
                 12 => "left",
                 15 => "up", 
                 17 => "down",
                 24 => "down",
                 27 => "up",

                 32 => "left",
                 34 => "right",
                 37 => "right",
                 42 => "left",
                 45 => "up", 
                 50 => "down",
                 52 => "down",
                 64 => "up",

                 70 => "left",
                 78 => "right",
                 80 => "right",
                 82 => "left",
                 84 => "up", 
                 86 => "down",
                 88 => "down",
                 90 => "up"

                ])

  for i in 0:92
    if i in collect(keys(events))
      event = events[i]
      if event == "left"
        state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
        push!(user_events, event)
      elseif event == "right"
        state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
        push!(user_events, event)
      elseif event == "up"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
        push!(user_events, event)
      elseif event == "down"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, Base.invokelatest(m.Down))
        push!(user_events, event)
      elseif occursin("click", event)
        x = parse(Int, split(event, " ")[2])
        y = parse(Int, split(event, " ")[3])
        state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, x, y), nothing, nothing, nothing, nothing)
        push!(user_events, event)
      end
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  observations, user_events, 100
end

function generate_observations_double_count_2(m::Module) 
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  events = Dict([2 => "left",
                 4 => "right",
                 7 => "right",
                 12 => "left",
                 15 => "up", 
                 17 => "down",
                 20 => "down",
                 24 => "up",

                 32 => "left",
                 34 => "left",
                 37 => "right",
                 40 => "right",
                 43 => "right",
                 45 => "right",
                 48 => "left",
                 51 => "left",
                 54 => "up", 
                 56 => "up", 
                 58 => "down",
                 60 => "down",
                 64 => "down",
                 67 => "down",
                 70 => "up",
                 72 => "up", 
                 
                 80 => "left",
                 85 => "right",
                 87 => "right",
                 92 => "left",
                 95 => "up", 
                 97 => "down",
                 100 => "down",
                 104 => "up",

                 110 => "left",
                 114 => "left",
                 117 => "right",
                 120 => "right",
                 123 => "right",
                 125 => "right",
                 128 => "left",
                 131 => "left",
                 134 => "up", 
                 136 => "up", 
                 138 => "down",
                 140 => "down",
                 144 => "down",
                 147 => "down",
                 150 => "up",
                 152 => "up", 
                ])

  for i in 0:154
    if i in collect(keys(events))
      event = events[i]
      if event == "left"
        state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
        push!(user_events, event)
      elseif event == "right"
        state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
        push!(user_events, event)
      elseif event == "up"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
        push!(user_events, event)
      elseif event == "down"
        state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, Base.invokelatest(m.Down))
        push!(user_events, event)
      elseif occursin("click", event)
        x = parse(Int, split(event, " ")[2])
        y = parse(Int, split(event, " ")[3])
        state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, x, y), nothing, nothing, nothing, nothing)
        push!(user_events, event)
      end
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  observations, user_events, 100
end

function generate_observations_gravity4(m::Module)
  state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, Base.invokelatest(m.render, state.scene))

  clicks = Dict([1 => (49, 49),
                #  3 => (22, 23),
                 6 => (45, 44),
                 9 => (4, 0),
                 12 => (8, 0),
                 15 => (12, 0),
                 18 => (99, 4),
                #  19 => (49, 8),
                 21 => (99, 12),
                 24 => (4, 99),
                 27 => (8, 99),
                #  30 => (12, 99),
                 30 => (99, 8),
                ])

  for i in 0:41
    if i in collect(keys(clicks))
      click_x, click_y = clicks[i]
      state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, click_x, click_y), nothing, nothing, nothing, nothing)
      push!(user_events, "click $(click_x) $(click_y)")
    else
      state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, Base.invokelatest(m.render, state.scene))
  end
  observations, user_events, 100
end

function generate_observations_swap(m::Module)
  observations, user_events, grid_size = JLD.load("observations_swap_FINAL.jld")["observations"]
  observations, user_events, grid_size
  # state = Base.invokelatest(m.init, nothing, nothing, nothing, nothing, nothing)
  # observations = []
  # user_events = []
  # push!(observations, Base.invokelatest(m.render, state.scene))

  # events = Dict([
  #                2 => "left",
  #                4 => "right",
  #                7 => "left",
  #                10 => "down",
  #                14 => "left",
  #                17 => "up",
  #                20 => "left",
  #                23 => "right",
  #                27 => "up",
  #                31 => "right",
  #                34 => "down",
  #                38 => "right",
  #                41 => "up",
  #                43 => "down",
  #                45 => "up",
  #                48 => "click 0 0",
  #                50 => "left",
  #                55 => "left",
  #                57 => "right",
  #                60 => "left",
  #                63 => "down",
  #                66 => "left",
  #                68 => "up",
  #                71 => "left",
  #                73 => "right",
  #                76 => "up",
  #                79 => "right",
  #                82 => "down",
  #                85 => "right",
  #                87 => "up",
  #                90 => "down",
  #                92 =>  "up",
  #                95 => "click 1 1",
  #                98 => "right",
  #                100 => "up",
  #                103 => "down",
  #               ])

  # for i in 1:105
  #   if i in collect(keys(events))
  #     event = events[i]
  #     if event == "left"
  #       state = Base.invokelatest(m.next, state, nothing, Base.invokelatest(m.Left), nothing, nothing, nothing)
  #       push!(user_events, event)
  #     elseif event == "right"
  #       state = Base.invokelatest(m.next, state, nothing, nothing, Base.invokelatest(m.Right), nothing, nothing)
  #       push!(user_events, event)
  #     elseif event == "up"
  #       state = Base.invokelatest(m.next, state, nothing, nothing, nothing, Base.invokelatest(m.Up), nothing)
  #       push!(user_events, event)
  #     elseif event == "down"
  #       state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, Base.invokelatest(m.Down))
  #       push!(user_events, event)
  #     elseif occursin("click", event)
  #       x = parse(Int, split(event, " ")[2])
  #       y = parse(Int, split(event, " ")[3])
  #       state = Base.invokelatest(m.next, state, Base.invokelatest(m.Click, x, y), nothing, nothing, nothing, nothing)
  #       push!(user_events, event)
  #     end
  #   else
  #     state = Base.invokelatest(m.next, state, nothing, nothing, nothing, nothing, nothing)
  #     push!(user_events, nothing)
  #   end
  #   push!(observations, Base.invokelatest(m.render, state.scene))
  # end
  # observations, user_events, 100
end

# PEDRO 
pedro_output_folder = "/Users/riadas/Documents/urop/RC_RL/autumn_renders"
pedro_events = ["nothing", "right", "left", "up", "down", "click -1 -1"]
function generate_observations_pedro(game_name)
  observations = []
  user_events = []
  render_folder = string(pedro_output_folder, "/", game_name)
  sorted_files = sort(filter(f -> occursin("render", f), readdir(render_folder)), by=x -> parse(Int, split(x, "render")[2]))
  for render_file in sorted_files
    println(render_file)
    cell_strings = readlines(string(render_folder, "/", render_file))
    push!(observations, map(s -> Autumn.AutumnStandardLibrary.Cell(parse(Int, split(s, " ")[2]), 
                                                                    parse(Int, split(s, " ")[1]), 
                                                                    lowercase(split(s, " ")[3])), cell_strings))
  end
  user_event_strings = readlines(string(render_folder, "/user_events"))
  
  for s in user_event_strings 
    push!(user_events, pedro_events[parse(Int, s) + 1])
  end

  observations[1:140], user_events[1:139], [900, 330]
end

