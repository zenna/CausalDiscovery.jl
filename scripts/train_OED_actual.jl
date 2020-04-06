using CausalDiscovery.OED_NN
using CausalDiscovery.OptimalDesign
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
EPOCHS=100
OED_n_samples=1000
train_dataset_size=10000
test_dataset_size=1000

train_dataset,x_train,y_train=generate_custom_data(16,coinoptimal,train_dataset_size,EPOCHS,OED_n_samples)
test_dataset,x_test,y_test=generate_custom_data(16,coinoptimal,test_dataset_size,1,OED_n_samples)
model=Chain(
Dense(3,16,relu),
Dense(16,32,relu),
Dense(32,16,relu),
    softmax)|> gpu

loss(x, y) = crossentropy(model(x), y)
accuracy(x, y) = mean(onecold(cpu(model(x))) .== onecold(cpu(y)))


evalcb=() -> @show (loss(x_train,y_train))
opt=ADAM()

ps=Flux.params(model)
Flux.train!(loss, ps, train_dataset, opt, cb = throttle(evalcb, 10))
println("Training accuracy:")
@show accuracy(x_train, y_train)
println("Testing accuracy:")
@show accuracy(x_test, y_test)