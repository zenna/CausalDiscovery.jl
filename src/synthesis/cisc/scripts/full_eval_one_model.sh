curr_date=$(date '+%Y-%m-%d_%H:%M:%S')
# algorithms=("heuristic" "sketch_multi" "sketch_single")

for (( i = 1 ; i <= $3; i++ )) ### Inner for loop ###
do
  echo "model_name: $1, algorithm: heuristic, repeat: $i "
  julia --project=. src/synthesis/cisc/scripts/full_eval.jl $1 heuristic $2 $i > bg_outs/$1_heuristic.out 2>&1

  echo "model_name: $1, algorithm: sketch_multi, repeat: $i "
  julia --project=. src/synthesis/cisc/scripts/full_eval.jl $1 sketch_multi $2 $i > bg_outs/$1_sketch_multi.out 2>&1 &

  echo "model_name: $1, algorithm: sketch_single, repeat: $i "
  julia --project=. src/synthesis/cisc/scripts/full_eval.jl $1 sketch_single $2 $i > bg_outs/$1_sketch_single.out 2>&1 &
done

# for (( i = 1 ; i <= $3; i++ )) ### Inner for loop ###
# do
#   echo "model_name: $model_name, algorithm: heuristic, repeat: $i "
#   timeout 86400 /scratch/riadas/julia-1.5.3/bin/julia --project=. src/synthesis/cisc/scripts/full_eval.jl $1 heuristic $2 $i > bg_outs/$1_heuristic.out

#   echo "model_name: $model_name, algorithm: sketch_multi, repeat: $i "
#   timeout 86400 /scratch/riadas/julia-1.5.3/bin/julia --project=. src/synthesis/cisc/scripts/full_eval.jl $1 sketch_multi $2 $i > bg_outs/$1_sketch_multi.out

#   echo "model_name: $model_name, algorithm: sketch_single, repeat: $i "
#   timeout 86400 /scratch/riadas/julia-1.5.3/bin/julia --project=. src/synthesis/cisc/scripts/full_eval.jl $1 sketch_single $2 $i > bg_outs/$1_sketch_single.out
# done

# julia --project=. src/synthesis/cisc/scripts/compute_output_accuracy.jl
# julia --project=. src/synthesis/cisc/scripts/compute_average_accuracies.jl

# /scratch/riadas/julia-1.5.3/bin/julia --project=. src/synthesis/cisc/scripts/compute_output_accuracy.jl
# /scratch/riadas/julia-1.5.3/bin/julia --project=. src/synthesis/cisc/scripts/compute_average_accuracies.jl