"Best Effort Ranking"
module BestEffortRanking

using ..AExpressions

export get_fitness

"""p is the synthesized program
e is the list of examples to test the model on(could be a starting frame and
then a number of iterations/sequence of events and then ending frame and would
say is correct if the ending frames match)
a is the aexpr representation of the program
the closer to 0 the value the better the program"""
function get_fitness(p, e, a, distance_coefficient=3.0, size_coefficient=1.0)
  return (distance_coefficient * get_distance(p, e) +
  size_coefficient * sizeA(a))
end

"""for examples that the model gets wrong find the objects in the expected result
and take the euclidean distance of each object.
return the average of (sum of euclidean distances)/(max possible sum of euclidean distances)"""
function get_distance(p, e)
  max_distance = sqrt(15*15 + 15*15)
  overall_distance = 0
  max_possible_distance = 0

  for index = 1:length(e)
    expected, steps = e[index]
    state = p.init(steps[1]...)
    for i = 2:length(steps)
      state = p.next(state, steps[i]...)
    end
    actual_cells = p.render(state.scene)
    expected_cells = expected(p)

    overall_distance += compare_states(expected_cells, actual_cells)
    if length(actual_cells) > length(expected_cells)
      longer = length(actual_cells)
    else
      longer = length(expected_cells)
    end
    max_possible_distance += longer * max_distance
  end
  overall_distance/max_possible_distance
end

function compare_states(expected_cells, actual_cells)
  max_distance = sqrt(15*15 + 15*15)
  for cells in [expected_cells, actual_cells]
    sort(cells, by = x -> x.position.y)
    sort!(cells, by=x -> x.position.x)
    sort!(cells, by=x -> x.color)
  end
  index_expected = 1
  index_actual = 1
  distance = 0
  while index_expected <= length(expected_cells) && index_actual <= length(actual_cells)
    ex_cell = expected_cells[index_expected]
    ac_cell = actual_cells[index_actual]

    if ex_cell.color == ac_cell.color
      distance += euclidean_distance(ex_cell.position.x, ex_cell.position.y, ac_cell.position.x, ac_cell.position.y)
      index_expected += 1
      index_actual += 1
    elseif ex_cell.color > ac_cell.color
      distance += max_distance
      index_actual += 1
    else
      distance += max_distance
      index_expected += 1
    end
  end
  extra_cells = length(actual_cells) - index_actual + length(expected_cells) - index_expected + 2

  distance += abs(extra_cells) * max_distance
  distance
end

function euclidean_distance(x1, y1, x2, y2)
  sqrt((x1-x2)*(x1-x2) + (y1-y2)*(y1-y2))
end
end
