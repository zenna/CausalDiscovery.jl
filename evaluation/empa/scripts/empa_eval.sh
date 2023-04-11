#!/bin/bash

curr_date=$(date '+%Y-%m-%d_%H:%M:%S')
# algorithms=("sketch_single")
algorithms=("heuristic")
num_repeats=1

model_names=("Avoidgeorge"
             "Bait"
             "bees_and_birds"
             "Butterflies"
             "closing_gates"
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
             "Portals"
             "Survivezombies"
            ) # PlaqueAttack

model_names=("Lemmings"
             "MyAliens"
             "Portals")
model_names=("Plaqueattack")

model_names=("Antagonist" 
             "Bait"
	     "closing_gates"  
	     "Helper"   
	     "Jaws"   
	     "Plaqueattack"  
	     "Relational"   
	     "Sokoban"  
	     "Watergame")


model_names=("Antagonist"
             "Avoidgeorge"
             "Bait"
             "bees_and_birds"
             "Butterflies"
             "closing_gates"
             "Explore_Exploit"
             "Helper2"
             "Jaws"
             "Preconditions"
             "Relational_end"
             "Sokoban"
             "Surprise"
             "Watergame"
             "Zelda"
             "Aliens"
             "MyAliens"
             "Plaqueattack"
             "Portals"
             "Survivezombies"
	     "Lemmings_small_take3"
)


#model_names=("Sokoban"
#             "Helper"
#	     "Lemmings")

#model_names=("Portals"
#             "MyAliens"
#	     "Bait")	     
	     
#model_names=("Lemmings_small_take3"
#             "Lemmings_small"
#	     "PlaqueAttack"
#	     "Survivezombies")
# model_names=("Bait")
for (( i = 1 ; i <= $num_repeats; i++ )) ### Inner for loop ###
do
  for algorithm in ${algorithms[@]}
  do
    for model_name in ${model_names[@]}
    do
      echo "model_name: $model_name, algorithm: $algorithm, repeat: $i "
      nohup julia --project=. evaluation/empa/scripts/empa_eval.jl $model_name $algorithm $curr_date $i > deleteme_empa.out &
      sleep 60
    done  
  done
  sleep 300
done
 
# julia --project=. src/Autumn/generativemodel/scripts/compute_output_accuracy.jl
# julia --project=. src/Autumn/generativemodel/scripts/compute_average_accuracies.jl

# /scratch/riadas/julia-1.5.3/bin/julia --project=. src/Autumn/generativemodel/scripts/compute_output_accuracy.jl
# /scratch/riadas/julia-1.5.3/bin/julia --project=. src/Autumn/generativemodel/scripts/compute_average_accuracies.jl
