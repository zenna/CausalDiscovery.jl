#!/bin/bash

# game_names=("Aliens"
#             "Antagonist"
#             "Avoidgeorge"
#             "Butterflies"
#             "bees_and_birds"
#             "Plaqueattack")

game_names=("Boulderdash"
            "Corridor"
            "Chase"
            "Helper"
            "closing_gates"
            "Bait")

for game_name in ${game_names[@]}
do
  echo "model_name: $game_name "
  nohup /scratch/riadas/julia-1.5.4/bin/julia --project=. src/Autumn/generativemodel/scripts/parse_pedro_model.jl $game_name > PEDRO_PARSING_LOGS/$game_name.out &
done	
#  julia --project=. src/Autumn/generativemodel/scripts/parse_pedro_model.jl $game_name
