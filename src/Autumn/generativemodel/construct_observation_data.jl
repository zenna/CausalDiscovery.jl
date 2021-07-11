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

function generate_observations_wind(m::Module)

end