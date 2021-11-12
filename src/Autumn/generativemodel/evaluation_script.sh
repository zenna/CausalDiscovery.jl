#!/bin/bash

# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation.jl gravity_i
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation.jl gravity_ii
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation.jl gravity_iii
gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_SINGLE.jl paint

# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_SINGLE.jl paint
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_SINGLE.jl count_1
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_SINGLE.jl count_2
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_SINGLE.jl count_3
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_SINGLE.jl count_4
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_SINGLE.jl double_count_1
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_SINGLE.jl double_count_2

# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch.jl gravity_i
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch.jl gravity_ii
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch.jl gravity_iv

# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_SINGLE.jl gravity_i
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_SINGLE.jl gravity_ii
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_SINGLE.jl gravity_iv

# # gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch.jl gravity_iii
# # gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_SINGLE.jl gravity_iii


# # for model_name in sand wind bullets disease gravity_i gravity_ii gravity_iii gravity_iv paint count_1 count_2 count_3 count_4 mario double_count_1 double_count_2 double_count_3 water_plug
# for model_name in paint count_1 count_2 count_3 count_4 mario wind double_count_1 double_count_2 double_count_3 water_plug
# do 
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation.jl $model_name
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch.jl $model_name
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_SINGLE.jl $model_name
# done 