#!/bin/bash

gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation.jl wind
gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch.jl wind
gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_SINGLE.jl wind

gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation.jl bullets
gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch.jl bullets
gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_SINGLE.jl bullets

gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation.jl mario
gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch.jl mario
gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_single.jl mario

gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation.jl water_plug
gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch.jl water_plug
gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_single.jl water_plug

# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation.jl count_1
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation.jl count_2
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation.jl count_3
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation.jl count_4

gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch.jl gravity_i
gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch.jl gravity_ii
gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch.jl gravity_iv

gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_SINGLE.jl gravity_i
gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_SINGLE.jl gravity_ii
gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_SINGLE.jl gravity_iv

# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch.jl gravity_iii
# gtimeout 144000 julia --project=. src/Autumn/generativemodel/final_evaluation_sketch_SINGLE.jl gravity_iii
