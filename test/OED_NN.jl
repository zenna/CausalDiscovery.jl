using CausalDiscovery.OED_NN
using CausalDiscovery.OptimalDesign
@testset "fake_OED" begin
  train_dataset,train_x,train_y=generate_data(8000,500)
  
  @test size(train_x) ==(3,8000)
  @test size(train_y) ==(16,8000)
  @test size(first(train_dataset)[1]) ==(3,8000)
  @test size(first(train_dataset)[2]) ==(16,8000)
end

@testset "real_OED" begin
  EPOCHS=1
  OED_n_samples=50
  train_dataset_size=8000
  train_dataset,x_train,y_train=generate_custom_data(16,coinoptimal,train_dataset_size,EPOCHS,OED_n_samples)
  @test size(x_train) ==(3,8000)
  @test size(y_train) ==(16,8000)
  @test size(first(train_dataset)[1]) ==(3,8000)
  @test size(first(train_dataset)[2]) ==(16,8000)
end