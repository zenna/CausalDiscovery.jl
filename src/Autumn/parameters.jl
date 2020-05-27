"Hacked Parameter Space"
module Parameters

export choice, Phi

struct Phi
end

choice(::Phi, xs::AbstractVector) = rand(xs)
choice(::Phi, ::Type{T}) where T <:Number = rand(T)


end