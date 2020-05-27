"Hacked Parameter Space"
module Parameters

export choice, Phi

struct Phi
end

choice(::Phi, xs::AbstractVector) = rand(xs)

end