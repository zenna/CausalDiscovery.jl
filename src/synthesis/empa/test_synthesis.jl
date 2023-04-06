include("full_synthesis.jl");
using JLD
using Dates

autumn_input_params = (
                       particles = (singlecell=true, pedro=false), 
                       ants = (singlecell=true, pedro=false),
                       lights = (singlecell=true, pedro=false),
                       ice = (singlecell=false, pedro=false),
                       magnets_i = (singlecell=false, pedro=false),
                       disease = (singlecell=false, pedro=false),
                       space_invaders = (singlecell=true, pedro=false),
                       sokoban_i = (singlecell=true, pedro=false),
                       grow = (singlecell=false, pedro=false),
                      #  mario = (singlecell=false, pedro=false),
                       sand = (singlecell=false, pedro=false),
                       gravity_i = (singlecell=false, pedro=false),
                       gravity_ii = (singlecell=false, pedro=false),
                      #  gravity_iii = (singlecell=true, pedro=false),
                       egg = (singlecell=false, pedro=false),
                       wind = (singlecell=false, pedro=false),
                       paint = (singlecell=false, pedro=false),
                       chase = (singlecell=true, pedro=false),
                       water_plug = (singlecell=true, pedro=false),
                      )

function test_synthesis_autumn()
  solutions_dict = Dict()
  directory_name = string("test_", Dates.now())
  mkdir(directory_name)
  for model_name in keys(autumn_input_params)
    try 
      solutions = @timed synthesize_program(String(model_name), 
                                            singlecell=autumn_input_params[model_name].singlecell, 
                                            pedro=autumn_input_params[model_name].pedro)
      solutions_dict[model_name] = solutions
      save(string(directory_name, "/", String(model_name), ".jld"), String(model_name), solutions_dict)
    catch e
      # @show e
      solutions_dict[model_name] = [e]
    end
  end
  solutions_dict
end

function test_synthesis_pedro() 

end

