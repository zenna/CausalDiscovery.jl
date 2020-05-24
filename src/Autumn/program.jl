module Program

export init, next, AProgram

"Autumn Program"
struct AProgram
  x
end

"Return state of `p::Program` initialised with external values `externals` "
function init(p::AProgram, externals)
  ..
end

"Return next state of `p::Program` given external values `externals` at currenttime "
function next(state, externals)
  ..
end

end