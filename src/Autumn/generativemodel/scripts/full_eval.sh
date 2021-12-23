#!/bin/bash

curr_date=$(date '+%Y-%m-%d_%H:%M:%S')
algorithms=("heuristic")
# algorithms=("heuristic")
num_repeats=1

# model_names=("paint"
#              "sand"
#              "bullets"
#              "gravity_i"
#              "gravity_iii"
#              "gravity_iv"
#              "disease"
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

model_names=("paint"
             "gravity_ii")
# # "space_invaders"

for model_name in ${model_names[@]}
do
  for algorithm in ${algorithms[@]}
  do
    for (( i = 1 ; i <= $num_repeats; i++ )) ### Inner for loop ###
    do
      echo "model_name: $model_name, algorithm: $algorithm, repeat: $i "
      nohup /scratch/riadas/julia-1.5.3/bin/julia --project=. src/Autumn/generativemodel/scripts/full_eval.jl $model_name $algorithm $curr_date $i > bg_outs/$model_name_$algorithm.out 2>&1 &
      echo $! >> bg_pids.txt
      sleep 60
    done  
  done
done

# julia --project=. src/Autumn/generativemodel/scripts/compute_output_accuracy.jl
# julia --project=. src/Autumn/generativemodel/scripts/compute_average_accuracies.jl

# /scratch/riadas/julia-1.5.3/bin/julia --project=. src/Autumn/generativemodel/scripts/compute_output_accuracy.jl
# /scratch/riadas/julia-1.5.3/bin/julia --project=. src/Autumn/generativemodel/scripts/compute_average_accuracies.jl