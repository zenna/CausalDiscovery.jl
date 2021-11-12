#!/bin/bash

curr_date=$(date '+%Y-%m-%d_%H:%M:%S')
algorithms=("heuristic" "sketch" "sketch_SINGLE")
num_repeats=5

model_names=("paint"
             "wind" 
             "sand"
             "bullets"
             "gravity_i"
             "gravity_iii"
             "disease"
             "gravity_ii"
             "mario"
             "count_1"
             "count_2"
             "count_3"
             "count_4"
             "double_count_1"
             "double_count_2"
             "water_plug" 
            )

# model_names=("count_1")
# "space_invaders"

for model_name in ${model_names[@]}
do
  for algorithm in ${algorithms[@]}
  do
    for (( i = 1 ; i <= $num_repeats; i++ )) ### Inner for loop ###
    do
      echo "model_name: $model_name, algorithm: $algorithm, repeat: $i "
      timeout 144000 /scratch/riadas/julia-1.5.3/bin/julia --project=. src/Autumn/generativemodel/full_eval_$algorithm.jl $model_name $curr_date $i
    done  
  done
done

julia --project=. src/Autumn/generativemodel/compute_output_accuracy.jl