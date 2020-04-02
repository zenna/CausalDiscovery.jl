module OED_NN
using Flux
using Flux, Flux.Data.MNIST, Statistics
using Flux: onehotbatch, onecold, crossentropy, throttle
using Base.Iterators: repeated
export int_to_experiment, fake_OED, generate_data
using Distributions: Uniform

experiment_to_int=Dict(
    "1111"=>1, 
    "1110" => 2 , 
    "1101" => 3,
    "1011"=> 4,
    "0111" => 5,
    "1100" => 6,
    "0011" => 7,
    "1010" => 8,
    "0101" => 9,
    "1001" => 10,
    "0110" => 11,
    "0001" => 12,
    "0010" => 13,
    "0100" => 14,
    "1000" => 15,
    "0000" => 0
)

"""
Fake Optimal experiment design agent that makes arbitrary decisions
prior : distribution over models
"""
function fake_OED(prior)
    p1,p2,p3=prior
    max_val=max(p1,p2,p3)
    if max_val==p1
        return 7
    elseif max_val==p2
        return 0
    else
        return 5
    end
end


"""
Generates data from the fake OED

"""
function generate_data(n_samples,epochs)
    priors=zeros(Float64,(3,n_samples))
    for idx in 1:n_samples
        first_prior=rand(Uniform(0.0,0.99),1)[1]
        second_prior=rand(Uniform(0.0,1-first_prior),1)[1]
        third_prior=1.0-first_prior-second_prior
        prior=[first_prior,second_prior,third_prior]
        priors[:,idx]=prior
    end
    labels=Any[]
    for prior in eachcol(priors)
        push!(labels,fake_OED(prior))
    end
    Y=onehotbatch(labels,[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15])|> gpu
    X=priors |> gpu
    return repeated((X,Y),epochs),X,Y
end

"""
Generates data from Arbitrary OED with: 
n_classes-> Number of experiments (to generate a one hot encoding)
OED -> optimal experiment design model that takes a prior as input and outputs an integer value experiment
n_samples-> number of data samples to generate
For now this just generates random priors. 
NOTE: This function assumes that the experiments are mapped to integer values from 0 to n experiments

"""

function generate_custom_data(n_classes,OED,n_samples,epochs,sample_size)
    priors=zeros(Float64,(3,n_samples))
    for idx in 1:n_samples
        first_prior=rand(Uniform(0.0,0.99),1)[1]
        second_prior=rand(Uniform(0.0,1-first_prior),1)[1]
        third_prior=1.0-first_prior-second_prior
        prior=[first_prior,second_prior,third_prior]
        priors[:,idx]=prior
    end
    labels=Any[]
    for prior in eachcol(priors)
        exp=OED(prior,sample_size)
        sequence=""
        for num in exp
            sequence=sequence*string(num)
        end
        push!(labels,experiment_to_int[sequence])
    end
    Y=onehotbatch(labels,0:n_classes-1)|> gpu
    X=priors |> gpu
    return repeated((X,Y),epochs),X,Y
end


end 