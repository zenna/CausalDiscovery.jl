#!/bin/bash

game_names=(""
            ""
            ""
            ""
            "")


for game_name in ${game_names[@]}
do
  echo "model_name: $game_name "
  nohup julia --project=. src/Autumn/generativemodel/scripts/parse_pedro_model.jl $game_name > PEDRO_PARSING_LOGS/$game_name.out &
done

#  julia --project=. src/Autumn/generativemodel/scripts/parse_pedro_model.jl $game_name