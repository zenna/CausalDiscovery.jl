using CausalDiscovery.OED_NN
using CUDAapi
using Flux
using Flux, Flux.Data.MNIST, Statistics
using Flux: onehotbatch, onecold, crossentropy, throttle
using Base.Iterators: repeated

if has_cuda()
    @info "CUDA is on"
    import CuArrays
    CuArrays.allowscalar(false)
end

EPOCHS=500
train_dataset_size=8000
test_dataset_size=100

model=Chain(
Dense(3,16,relu),
Dense(16,32,relu),
Dense(32,16,relu),
    softmax)|> gpu

loss(x, y) = crossentropy(model(x), y)
accuracy(x, y) = mean(onecold(cpu(model(x))) .== onecold(cpu(y)))

train_dataset,train_x,train_y=generate_data(train_dataset_size,EPOCHS)
test_dataset,test_x,test_y=generate_data(test_dataset_size,1)
evalcb=() -> @show (loss(train_x,train_y))
opt=ADAM()

ps=Flux.params(model)
Flux.train!(loss, ps, train_dataset, opt, cb = throttle(evalcb, 10))
println("Training accuracy:")
@show accuracy(train_x, train_y)
println("Testing accuracy:")
@show accuracy(test_x, test_y)