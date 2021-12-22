#!/bin/bash

curr_date=$(date '+%Y-%m-%d_%H:%M:%S')
# algorithms=("heuristic" "sketch_multi" "sketch_single")
num_repeats=1

# model_names=("paint"
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
#              "wind" 
#             )

model_names=("paint"
             "gravity_ii")
# # "space_invaders"

for model_name in ${model_names[@]}
do
  echo "model_name: $model_name, algorithm: all, repeat: $i "
  nohup bash src/Autumn/generativemodel/scripts/full_eval_one_model.sh $model_name $curr_date $num_repeats &
  sleep 60
done

# julia --project=. src/Autumn/generativemodel/scripts/compute_output_accuracy.jl
# julia --project=. src/Autumn/generativemodel/scripts/compute_average_accuracies.jl

# /scratch/riadas/julia-1.5.3/bin/julia --project=. src/Autumn/generativemodel/scripts/compute_output_accuracy.jl
# /scratch/riadas/julia-1.5.3/bin/julia --project=. src/Autumn/generativemodel/scripts/compute_average_accuracies.jl