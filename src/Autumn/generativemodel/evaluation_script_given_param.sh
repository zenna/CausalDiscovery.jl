#!/bin/bash

# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation.jl gravity_i
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation.jl gravity_ii
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation.jl gravity_iii
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation.jl gravity_iv

gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation.jl count_1
gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation.jl count_2
gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation.jl count_3
gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation.jl count_4

# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch.jl gravity_iii
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_SINGLE.jl gravity_iii
