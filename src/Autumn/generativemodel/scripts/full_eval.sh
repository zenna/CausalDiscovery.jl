#!/bin/bash

curr_date=$(date '+%Y-%m-%d_%H:%M:%S')
algorithms=("sketch_single")
# algorithms=("heuristic")
num_repeats=1

# model_names=("paint"
#              "lights"
#              "sand"
#              "disease"
#              "bullets"
#              "gravity_i"
#              "gravity_iii"
#              "gravity_iv"
#              "gravity_ii"
#              "count_1"
#              "count_2"
#              "double_count_1"
#              "double_count_2"
#              "count_3"
#             )

# model_names=("paint"
#              "lights"
#              "sand"
#              "disease"
#              "grow"
#              "bullets"
#              "gravity_i"
#              "gravity_iii"
#              "gravity_iv"
#              "gravity_ii"
#              "count_1"
#              "count_2"
#              "double_count_1"
#              "double_count_2"
#              "mario"
#              "count_3"
#              "count_4"
#              "wind" 
#              "water_plug"
#             )

# model_names=("ice"
#              "particles"
#              "ants"
#              "chase"
#              "magnets"
#              "space_invaders"
#              "sokoban")
# # "space_invaders"
# model_names=("double_count_2")

model_names=("bullets")

for  (( i = 1 ; i <= $num_repeats; i++ ))
do
  for algorithm in ${algorithms[@]}
  do
    for model_name in ${model_names[@]} ### Inner for loop ###
    do
      echo "model_name: $model_name, algorithm: $algorithm, repeat: $i "
      julia --project=. src/Autumn/generativemodel/scripts/full_eval.jl $model_name $algorithm $curr_date $i
      echo $! >> bg_pids.txt
      sleep 10
    done  
  done
done

# julia --project=. src/Autumn/generativemodel/scripts/compute_output_accuracy.jl
# julia --project=. src/Autumn/generativemodel/scripts/compute_average_accuracies.jl

# /scratch/riadas/julia-1.5.3/bin/julia --project=. src/Autumn/generativemodel/scripts/compute_output_accuracy.jl
# /scratch/riadas/julia-1.5.3/bin/julia --project=. src/Autumn/generativemodel/scripts/compute_average_accuracies.jl
