using CausalDiscovery.OED_NN: int_to_experiment,fake_OED,generate_data

@testset "fake_OED" begin
  train_dataset,train_x,train_y=generate_data(8000,500)
  println(size(train_x))
  @test size(train_x) ==(3,8000)
  @test size(train_y) ==(16,8000)
  @test size(first(train_dataset)[1]) ==(3,8000)
  @test size(first(train_dataset)[2]) ==(16,8000)
end