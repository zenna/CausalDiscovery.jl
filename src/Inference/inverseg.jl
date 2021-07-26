using Omega

export gen_fake_data, test_inference

struct Img{T}
  data::T
end

function Omega.d(x::Img, y::Img)
  mean_img = mean(x.data .- y.data)
  @show mean([mean_img.b, mean_img.g, mean_img.r, mean_img.alpha])^2
end

# function Omega.d(x::)

# Define a random variable over objects
obj_gen_model = ciid(generatescene_objects_inf)

img_gen_model_(rng) = Img(render_inf(obj_gen_model(rng)))
img_gen_model = ciid(img_gen_model_)

function do_inference(n, obs_img)
  rand(obj_gen_model, img_gen_model ==ₛ obs_img, n; alg = SSMH)
end

function gen_fake_data()
  rng = Random.MersenneTwister(0)
  obj = generatescene_objects_inf(rng)
  img = Img(render_inf(obj))
  (obj = obj, img = img)
end

function test_inference()
  obj, img = gen_fake_data()
  do_inference(10, img)
end