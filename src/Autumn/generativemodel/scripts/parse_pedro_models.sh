#!/bin/bash

game_names=("Aliens"
            "Antagonist"
            "Avoidgeorge"
            "Bait"
            "Butterflies"
            "bees_and_birds"
            "Chase"
            "Closing gates"
            "Corridor"
            "Explore_Exploit"
            "Frogs"
            "Helper"
            "Jaws"
            "Lemmings"
            "Missilecommand"
            "MyAliens"
            "Preconditions"
            "Plaqueattack"
            "Push boulders"
            "Relational"
            "Surprise"
            "Survivezombies"
            "Watergame"
            "Zelda")

# game_names=("Bait")

for game_name in ${game_names[@]}
do
  echo "model_name: $game_name "
  nohup /scratch/riadas/julia-1.5.4/bin/julia --project=. src/Autumn/generativemodel/scripts/parse_pedro_model.jl $game_name > PEDRO_PARSING_LOGS/$game_name.out &
  sleep 120
done

#  julia --project=. src/Autumn/generativemodel/scripts/parse_pedro_model.jl $game_name
#  nohup /scratch/riadas/julia-1.5.4/bin/julia --project=. src/Autumn/generativemodel/scripts/parse_pedro_model.jl $game_name > PEDRO_PARSING_LOGS/$game_name.out &
