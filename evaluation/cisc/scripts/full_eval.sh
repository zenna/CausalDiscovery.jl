#!/bin/bash

curr_date=$(date '+%Y-%m-%d_%H:%M:%S')
# algorithms=("heuristic"
#             "sketch_multi"
#             "sketch_single")
algorithms=("heuristic")
num_repeats=3

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
#              "count_6"
#              "wind" 
#             )

model_names=("paint"
             "lights"
             "sand"
             "disease"
             "grow"
             "bullets"
             "gravity_i"
             "gravity_iii"
             "gravity_iv"
             "gravity_ii"
             "count_1"
             "count_2"
            "count_3"
            "count_4"
            "count_5"
            "double_count_1"
            "double_count_2"
            "mario"
            "wind" 
            "ice"
            "particles"
            "ants"
            "chase"
            "magnets_i"
            "space_invaders"
            "sokoban_i"
            "water_plug"
            )

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
#              "mario"
#              "wind"
#              "water_plug"
#             )

# # "water_plug"
# # model_names=("ice"
# #              "particles"
# #              "ants"
# #              "chase"
# #              "magnets"
# #              "space_invaders"
# #              "sokoban")
# # # "space_invaders"
# model_names=("ice")

for  (( i = 1 ; i <= $num_repeats; i++ ))
do
  for algorithm in ${algorithms[@]}
  do
    for model_name in ${model_names[@]} ### Inner for loop ###
    do
      echo "model_name: $model_name, algorithm: $algorithm, repeat: $i "
      nohup timeout 86400 julia --project=. evaluation/cisc/scripts/full_eval.jl $model_name $algorithm $curr_date $i > /dev/null & # OCTOBER_TESTING_OUTS/$model_name.$algorithm.out & 
      sleep 60
    done
    sleep 28800  
  done
done

#> APRIL_TESTING_OUTS/$model_name.$algorithm.out &

# julia --project=. src/synthesis/cisc/scripts/compute_output_accuracy.jl
# julia --project=. src/synthesis/cisc/scripts/compute_average_accuracies.jl
#  nohup /scratch/riadas/julia-1.5.4/bin/julia --project=. src/synthesis/cisc/scripts/full_eval.jl $model_name $algorithm $curr_date $i > APRIL_TESTING_OUTS/$model_name.$algorithm.out &

# /scratch/riadas/julia-1.5.3/bin/julia --project=. src/synthesis/cisc/scripts/compute_output_accuracy.jl
# /scratch/riadas/julia-1.5.3/bin/julia --project=. src/synthesis/cisc/scripts/compute_average_accuracies.jl
