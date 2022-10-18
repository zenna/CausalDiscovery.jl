#!/bin/bash

curr_date=$(date '+%Y-%m-%d_%H:%M:%S')
algorithms=("heuristic")
num_repeats=1

model_names=("Antagonist"
             "Avoidgeorge"
             "Bait"
             "bees_and_birds"
             "Butterflies"
             "closing_gates"
             "Explore_Exploit"
             "Helper"
             "Jaws"
             "Preconditions"
             "Relational"
             "Sokoban"
             "Surprise"
             "Watergame"
             "Zelda" 
             "Aliens"
             "Lemmings"
             "MyAliens"
             "Plaqueattack"
             "Portals"
             "Survivezombies"
            )

model_names=("Bait")
# # "space_invaders"

for model_name in ${model_names[@]}
do
  for algorithm in ${algorithms[@]}
  do
    for (( i = 1 ; i <= $num_repeats; i++ )) ### Inner for loop ###
    do
      echo "model_name: $model_name, algorithm: $algorithm, repeat: $i "
      /scratch/riadas/julia-1.5.4/bin/julia --project=. src/Autumn/generativemodel/scripts/pedro_eval.jl $model_name $algorithm $curr_date $i
    done  
  done
done

# julia --project=. src/Autumn/generativemodel/scripts/compute_output_accuracy.jl
# julia --project=. src/Autumn/generativemodel/scripts/compute_average_accuracies.jl

# /scratch/riadas/julia-1.5.3/bin/julia --project=. src/Autumn/generativemodel/scripts/compute_output_accuracy.jl
# /scratch/riadas/julia-1.5.3/bin/julia --project=. src/Autumn/generativemodel/scripts/compute_average_accuracies.jl