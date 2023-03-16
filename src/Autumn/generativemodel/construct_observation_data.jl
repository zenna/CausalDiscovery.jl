function generate_observations_ice(m::Module)
  state = m.init(nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, m.render(state.scene))

  for i in 0:20
    if i in [2, 7, 12] # 17
      # state = m.next(state, nothing, nothing, nothing, nothing, nothing)
      state = m.next(state, nothing, nothing, nothing, nothing, mod.Down())
      push!(user_events, "down")
    elseif i == 10
      state = m.next(state, nothing, nothing, mod.Right(), nothing, nothing)
      push!(user_events, "right")
    elseif i == 14
      state = m.next(state, nothing, mod.Left(), nothing, nothing, nothing)
      push!(user_events, "left")
    elseif i == 5 || i == 16
      x = rand(1:6)
      y = rand(1:6)
      state = m.next(state, m.Click(x, y), nothing, nothing, nothing, nothing)
      push!(user_events, "clicked $(x) $(y)")
    else
      state = m.next(state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, m.render(state.scene))
  end
  observations, user_events
end

function generate_observations_particles(m::Module)
  state = m.init(nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, m.render(state.scene))

  for i in 0:20
    if i in [2, 5, 8] # 17
      # state = m.next(state, nothing, nothing, nothing, nothing, nothing)
      x = rand(1:10)
      y = rand(1:10)
      state = m.next(state, m.Click(x, y), nothing, nothing, nothing, nothing)
      push!(user_events, "clicked $(x) $(y)")
    else
      state = m.next(state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, m.render(state.scene))
  end
  observations, user_events
end

function generate_observations_ants(m::Module)
  state = m.init(nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, m.render(state.scene))

  for i in 0:20
    if i in [4] 
      state = m.next(state, m.Click(7,7), nothing, nothing, nothing, nothing)
      push!(user_events, "clicked 7 7")
    else
      state = m.next(state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, "nothing")
    end
    push!(observations, m.render(state.scene))
  end
  observations, user_events
end

function generate_observations_lights(m::Module)
  state = m.init(nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, m.render(state.scene))

  for i in 0:20
    if i == 2
      state = m.next(state, m.Click(3, 2), nothing, nothing, nothing, nothing)
      push!(user_events, "clicked 3 2")
    elseif i == 5 
      state = m.next(state, m.Click(4, 5), nothing, nothing, nothing, nothing)
      push!(user_events, "clicked 4 5")
    else
      state = m.next(state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, m.render(state.scene))
  end
  observations, user_events
end

function generate_observations_space_invaders(m::Module)
  state = m.init(nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, m.render(state.scene))

  for i in 0:20
    if i in [3, 10, 16]
      state = m.next(state, nothing, nothing, nothing, m.Up(), nothing)
      push!(user_events, "up")
    elseif i in [6] 
      state = m.next(state, nothing, m.Left(), nothing, nothing, nothing)
      push!(user_events, "left")
    elseif i in [12]
      state = m.next(state, nothing, nothing, m.Right(), nothing, nothing)
      push!(user_events, "right")
    else
      state = m.next(state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, m.render(state.scene))
  end
  observations, user_events
end

function generate_observations_disease(m::Module)
  state = m.init(nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, m.render(state.scene))

  for i in 0:20
    if i in [4, 7, 15]
      state = m.next(state, nothing, nothing, nothing, nothing, m.Down())
      push!(user_events, "down")
    elseif i in [2, 13, 16]
      state = m.next(state, nothing, nothing, nothing, m.Up(), nothing)
      push!(user_events, "up")
    elseif i in [1, 12] 
      state = m.next(state, nothing, m.Left(), nothing, nothing, nothing)
      push!(user_events, "left")
    elseif i in [6, 14]
      state = m.next(state, nothing, nothing, m.Right(), nothing, nothing)
      push!(user_events, "right")
    elseif i in [10]
      state = m.next(state, m.Click(4, 4), nothing, nothing, nothing, nothing)
      push!(user_events, "click 4 4")
    else
      state = m.next(state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, m.render(state.scene))
  end
  observations, user_events
end

function generate_observations_water_plug(m::Module)
  state = m.init(nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, m.render(state.scene))

  clicks = Dict([1 => (4, 5),
                 2 => (8, 3),
                 3 => (5, 0),
                 5 => (6, 6),
                 6 => (7, 4),
                 8 => (8, 0),
                 10 => (6, 10),
                 11 => (7, 10),
                 12 => (8, 10),
                 13 => (9, 10),
                 14 => (6, 10),
                 15 => (7, 10),
                 16 => (8, 10),
                 17 => (9, 10),
                 20 => (11, 0),
                ])

  for i in 0:25
    if i in collect(keys(clicks))
      click_x, click_y = clicks[i]
      state = m.next(state, m.Click(click_x, click_y), nothing, nothing, nothing, nothing)
      push!(user_events, "click $(click_x) $(click_y)")
    else
      state = m.next(state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, m.render(state.scene))
  end
  observations, user_events
end

function generate_observations_paint(m::Module)
  state = m.init(nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, m.render(state.scene))

  clicks = Dict([1 => (4, 5),
                 2 => (8, 3),
                 6 => (5, 0),
                 7 => (6, 6),
                 10 => (7, 4),
                 13 => (8, 0),
                 16 => (6, 10),
                 18 => (7, 10),
                ])

  for i in 0:25
    if i in collect(keys(clicks))
      click_x, click_y = clicks[i]
      state = m.next(state, m.Click(click_x, click_y), nothing, nothing, nothing, nothing)
      push!(user_events, "click $(click_x) $(click_y)")
    elseif i in [4, 8, 11, 14, 17]
      state = m.next(state, nothing, nothing, nothing, m.Up(), nothing)
      push!(user_events, "up")
    else
      state = m.next(state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, m.render(state.scene))
  end
  observations, user_events
end

function generate_observations_wind(m::Module)
  state = m.init(nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, m.render(state.scene))

  for i in 0:17
    if i in [8, 11]
      state = m.next(state, nothing, m.Left(), nothing, nothing, nothing)
      push!(user_events, "left")
    elseif i in [4, 14]
      state = m.next(state, nothing, nothing, m.Right(), nothing, nothing)
      push!(user_events, "right")
    else
      state = m.next(state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, m.render(state.scene))
  end
  observations, user_events
end

function generate_observations_gravity(m::Module)
  state = m.init(nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, m.render(state.scene))

  clicks = Dict([1 => (5, 6),
                 2 => (2, 3),
                 3 => (0, 7),
                 5 => (11, 8),
                 7 => (15, 7),
                 10 => (7, 0),
                 14 => (7, 15),
                ])

  for i in 0:17
    if i in collect(keys(clicks))
      click_x, click_y = clicks[i]
      state = m.next(state, m.Click(click_x, click_y), nothing, nothing, nothing, nothing)
      push!(user_events, "click $(click_x) $(click_y)")
    else
      state = m.next(state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, m.render(state.scene))
  end
  observations, user_events
end

function generate_observations_sand(m::Module)
  state = m.init(nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, m.render(state.scene))

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
      state = m.next(state, m.Click(click_x, click_y), nothing, nothing, nothing, nothing)
      push!(user_events, "click $(click_x) $(click_y)")
    else
      state = m.next(state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, m.render(state.scene))
  end
  observations, user_events
end

function generate_observations_sand_simple(m::Module)
  state = m.init(nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, m.render(state.scene))

  clicks = Dict([2 => (2, 7),
                 4 => (2, 5),
                 6 => (3, 3),
                 8 => (7, 0),
                 10 => (3, 4),
                 12 => (8, 1),
                 17 => (2, 0),
                 18 => (5, 3),
                ])

  for i in 0:20
    if i in collect(keys(clicks))
      click_x, click_y = clicks[i]
      state = m.next(state, m.Click(click_x, click_y), nothing, nothing, nothing, nothing)
      push!(user_events, "click $(click_x) $(click_y)")
    else
      state = m.next(state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, m.render(state.scene))
  end
  observations, user_events
end

function generation_observations_gravity3(m::Module)
  state = m.init(nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, m.render(state.scene))

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

  for i in 0:25
    if i in collect(keys(events))
      event = events[i]
      if event == "left"
        state = m.next(state, nothing, mod.Left(), nothing, nothing, nothing)
      elseif event == "right"
        state = m.next(state, nothing, nothing, mod.Right(), nothing, nothing)
      elseif event == "up"
        state = m.next(state, nothing, nothing, nothing, mod.Up(), nothing)
      elseif event == "down"
        state = m.next(state, nothing, nothing, nothing, nothing, mod.Down())
      end
      push!(user_events, event)
    else
      state = m.next(state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, m.render(state.scene))
  end
  observations, user_events
end

function generate_observations_egg(m::Module)
  state = m.init(nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, m.render(state.scene))

  for i in 0:24 
    if i < 9
      state = m.next(state, nothing, nothing, nothing, m.Up(), nothing)
      push!(user_events, "up")
    elseif i in [12, 17]
      state = m.next(state, nothing, m.Left(), nothing, nothing, nothing)
      push!(user_events, "left")
    elseif i in [13, 18]
      state = m.next(state, nothing, nothing, m.Right(), nothing, nothing)
      push!(user_events, "right")
    elseif i == 14
      state = m.next(state, m.Click(0, 0), nothing, nothing, nothing, nothing)
      push!(user_events, "click 0 0")
    else
      state = m.next(state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, m.render(state.scene))
  end
  observations, user_events
end

function generate_observations_grow(m::Module)
  state = m.init(nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, m.render(state.scene))

  events = Dict([1 => "left",
                 2 => "down",
                 5 => "down",
                 8 => "down",
                 9 => "left",
                 10 => "left",
                 11 => "down",
                 14 => "down",
                 18 => (0, 0),
                 19 => "down",
                 20 => "left",
                 21 => "left",
                 22 => "down",
                 23 => (1, 0),
                 24 => (2, 0),
                 25 => (3, 0),
                 26 => (4, 0),
                 27 => (5, 0),
                 29 => (6, 0),
                 31 => (6, 0),
                 32 => (5, 0),
                 33 => (4, 0),
                 34 => (3, 0),
                 35 => (2, 0),
                 37 => (1, 0),
                ])

  for i in 0:38
    if i in collect(keys(events))
      event = events[i]
      if event == "left"
        state = m.next(state, nothing, m.Left(), nothing, nothing, nothing)
        push!(user_events, event)
      elseif event == "right"
        state = m.next(state, nothing, nothing, m.Right(), nothing, nothing)
        push!(user_events, event)
      elseif event == "up"
        state = m.next(state, nothing, nothing, nothing, m.Up(), nothing)
        push!(user_events, event)
      elseif event == "down"
        state = m.next(state, nothing, nothing, nothing, nothing, m.Down())
        push!(user_events, event)
      else 
        click_x, click_y = events[i]
        state = m.next(state, m.Click(click_x, click_y), nothing, nothing, nothing, nothing)
        push!(user_events, "click $(click_x) $(click_y)")
      end
    else
      state = m.next(state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, m.render(state.scene))
  end
  observations, user_events
end

function generate_observations_sokoban(m::Module)

end

function generate_observations_sokoban2(m::Module)

end

function generate_observations_magnets(m::Module)

end

function generate_observations_magnets2(m::Module)

end

function generate_observations_magnets3(m::Module)

end

function generate_observations_gravity2(m::Module)
  state = m.init(nothing, nothing, nothing, nothing, nothing)
  observations = []
  user_events = []
  push!(observations, m.render(state.scene))

  clicks = Dict([1 => (15, 6),
                 3 => (12, 3),
                 5 => (18, 10),
                 7 => (0, 14),
                 9 => (20, 8),
                 11 => (23, 3),
                 13 => (17, 13),
                 15 => (29, 14),
                 17 => (14, 0),
                 19 => (14, 29),
                  ])

  for i in 0:22
    if i in collect(keys(clicks))
      click_x, click_y = clicks[i]
      state = m.next(state, m.Click(click_x, click_y), nothing, nothing, nothing, nothing)
      push!(user_events, "click $(click_x) $(click_y)")
    else
      state = m.next(state, nothing, nothing, nothing, nothing, nothing)
      push!(user_events, nothing)
    end
    push!(observations, m.render(state.scene))
  end
  observations, user_events
end