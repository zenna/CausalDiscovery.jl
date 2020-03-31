using Flux
using Distributions
using Flux, Flux.Data.MNIST, Statistics
using Flux: onehotbatch, onecold, crossentropy, throttle
using Base.Iterators: repeated

##mapping from int to sequence 
int_to_experiment=Dict(
    1 => "HHHH", 
    2 => "HHHT", 
    3 => "HHTH",
    4 => "HTHH",
    5 => "THHH",
    6 => "HHTT",
    7 => "TTHH",
    8 => "HTHT",
    9 => "THTH",
    10 => "HTTH",
    11 => "THHT",
    12 => "TTTH",
    13 => "TTHT",
    14 => "THTT",
    15 => "HTTT",
    16 => "TTTT"
)

# using CUDAapi
if has_cuda()
    @info "CUDA is on"
    import CuArrays
    CuArrays.allowscalar(false)

## Generate data



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

##mapping from int to sequence 
int_to_experiment=Dict(
    1 => "HHHH", 
    2 => "HHHT", 
    3 => "HHTH",
    4 => "HTHH",
    5 => "THHH",
    6 => "HHTT",
    7 => "TTHH",
    8 => "HTHT",
    9 => "THTH",
    10 => "HTTH",
    11 => "THHT",
    12 => "TTTH",
    13 => "TTHT",
    14 => "THTT",
    15 => "HTTT",
    16 => "TTTT"
)

##Generate fake priors, in the future learn these with a NN\
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

model=Chain(
Dense(3,16,relu),
Dense(16,32,relu),
Dense(32,16,relu),
    softmax)|> gpu

loss(x, y) = crossentropy(model(x), y)
accuracy(x, y) = mean(onecold(cpu(model(x))) .== onecold(cpu(y)))

train_dataset,train_x,train_y=generate_data(8000,500)
test_dataset,test_x,test_y=generate_data(100,1)
evalcb=() -> @show (loss(train_x,train_y))
opt=ADAM()

ps=Flux.params(model)
Flux.train!(loss, ps, train_dataset, opt, cb = throttle(evalcb, 10))
println("Training accuracy:")
@show accuracy(train_x, train_y)
println("Testing accuracy:")
@show accuracy(test_x, test_y)