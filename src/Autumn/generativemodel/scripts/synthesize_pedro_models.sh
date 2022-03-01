#!/bin/bash

game_names=("Aliens"
            "Butterflies"
            "Chase"
            "Corridor"
            "Lemmings"
            "MyAliens"
            "Plaqueattack"
            "Survivezombies")

for game_name in ${game_names[@]}
do
  echo "model_name: $game_name "
  nohup /scratch/riadas/julia-1.5.4/bin/julia --project=. src/Autumn/generativemodel/scripts/synthesize_pedro_model.jl $game_name > PEDRO_SYNTHESIS_LOGS/$game_name.out &
  sleep 120
done

#  julia --project=. src/Autumn/generativemodel/scripts/synthesize_pedro_model.jl $game_name
#  nohup /scratch/riadas/julia-1.5.4/bin/julia --project=. src/Autumn/generativemodel/scripts/synthesize_pedro_model.jl $game_name > PEDRO_SYNTHESIS_LOGS/$game_name.out &