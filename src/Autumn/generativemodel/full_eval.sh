#!/bin/bash

curr_date=$(date '+%Y-%m-%d_%H:%M:%S')
algorithms=("heuristic" "sketch" "sketch_SINGLE")
num_repeats=1

# model_names=("paint"
#              "wind" 
#              "sand"
#              "bullets"
#              "gravity_i"
#              "gravity_iii"
#              "disease"
#              "gravity_ii"
#              "count_1"
#              "count_2"
#              "double_count_1"
#              "double_count_2"
#              "mario"
#              "count_3"
#              "count_4"
#             )

model_names=("paint"
             "disease")
# "space_invaders"

for model_name in ${model_names[@]}
do
  for algorithm in ${algorithms[@]}
  do
    for (( i = 1 ; i <= $num_repeats; i++ )) ### Inner for loop ###
    do
      echo "model_name: $model_name, algorithm: $algorithm, repeat: $i "
      gtimeout 14400 julia --project=. src/Autumn/generativemodel/full_eval_$algorithm.jl $model_name $curr_date $i
    done  
  done
done

julia --project=. src/Autumn/generativemodel/compute_output_accuracy.jl
julia --project=. src/Autumn/generativemodel/compute_average_accuracies.jl