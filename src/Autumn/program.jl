module Program

export init, next

""
struct Program
  ...
end

"Return state of `p::Program` initialised with external values `externals` "
function init(p::Program, externals)
  ...
end

"Return next state of `p::Program` given external values `externals` at currenttime "
function next(state, externals)
end

end