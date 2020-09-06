module CompileSketchUtils

using ..AExpressions
using MLStyle: @match

export compile_sk, compileinit_sk, compilestate_sk, compilenext_sk, compileprev_sk, compilelibrary_sk, compileharnesses_sk, compilegenerators_sk

# binary operators
binaryOperators = map(string, [:+, :-, :/, :*, :&, :|, :>=, :<=, :>, :<, :(==), :!=, :%, :&&])

# ----- Begin Exported Functions ----- #

function compile_sk(expr::AExpr, data::Dict{String, Any}, parent::Union{AExpr, Nothing}=nothing)
  arr = [expr.head, expr.args...]
  res = @match arr begin
    [:if, args...] => compileif(expr, data, parent) 
    [:assign, args...] => compileassign(expr, data, parent)
    [:typedecl, args...] => compiletypedecl(expr, data, parent)
    [:let, args...] => compilelet(expr, data, parent)
    [:typealias, args...] => compiletypealias(expr, data, parent)
    [:lambda, args...] => compilelambda(expr, data, parent)
    [:list, args...] => compilelist(expr, data, parent)
    [:call, args...] => compilecall(expr, data, parent)
    [:field, args...] => compilefield(expr, data, parent)
    [:object, args...] => compileobject(expr, data, parent)
    [:on, args...] => compileon(expr, data, parent)
    [args...] => throw(AutumnError(string("Invalid AExpr Head: ", expr.head))) # if expr head is not one of the above, throw error
  end
end

function compile_sk(expr::AbstractArray, data::Dict{String, Any}, parent::Union{AExpr, Nothing}=nothing)
  if length(expr) == 0 || (length(expr) > 1 && expr[1] != :List)
    throw(AutumnError("Invalid List Syntax"))
  elseif expr[1] == :List
    "$(compile_sk(expr[2:end], data))[ARR_BND]"
  else
    compile_sk(expr[1], data)      
  end
end

function compile_sk(expr, data::Dict{String, Any}, parent::Union{AExpr, Nothing}=nothing)
  if expr in [:left, :right, :up, :down]
    "occurred($(string(expr)))"
  elseif expr == :clicked
    "occurred(click)"
  elseif expr == :Bool
    "bit"
  elseif expr == :Int
    "int"
  else
    string(expr)
  end
end

function compilestate_sk(data)
  stateHistories = map(expr -> "$(compile_sk(data["types"][expr.args[1]], data))[ARR_BND] $(compile_sk(expr.args[1], data))History;", 
  vcat(data["initnext"], data["lifted"]))
  GRID_SIZE = filter(x -> x.args[1] == :GRID_SIZE, data["lifted"])[1].args[2]
  """
  int GRID_SIZE = $(GRID_SIZE);
  struct State {
    int time;
    $(join(stateHistories, "\n"))
    Click[ARR_BND] clickHistory;
    Left[ARR_BND] leftHistory;
    Right[ARR_BND] rightHistory;
    Up[ARR_BND] upHistory;
    Down[ARR_BND] downHistory;
    Scene scene;
  }
  """
end

function compileinit_sk(data)
  objectInstances = filter(x -> data["types"][x] in vcat(data["objects"], map(o -> [:List, o], data["objects"])),
                          collect(keys(data["types"])))
  historyInitNextDeclarations = map(x -> "$(compile_sk(data["types"][x.args[1]], data)) $(compile_sk(x.args[1], data)) = $(compile_sk(x.args[2].args[1], data));", 
                           data["initnext"]) 
  historyLiftedDeclarations = map(x -> "$(compile_sk(data["types"][x.args[1]], data)) $(compile_sk(x.args[1], data)) = $(compile_sk(x.args[2], data));", 
                           data["lifted"])
  historyInits = map(x -> "state.$(compile_sk(x.args[1], data))History[0] = $(compile_sk(x.args[1], data));", 
                     vcat(data["initnext"], data["lifted"]))
  """
  State init() {
    int time = 0;
    $(join(historyInitNextDeclarations, "\n"))
    $(join(historyLiftedDeclarations, "\n"))
	  State state = new State();
    state.time = time;
    $(join(historyInits, "\n"))
    state.clickHistory[0] = null;
    state.leftHistory[0] = null;
    state.rightHistory[0] = null;
    state.upHistory[0] = null;
    state.downHistory[0] = null;
    state.scene = new Scene(objects={$(join(map(obj -> data["types"][obj] isa Array ? compile_sk(obj, data) : "{$(compile_sk(obj, data))}", objectInstances), ", "))}, background=\"transparent\");
    return state;
  }
  """
end

function compilenext_sk(data)
  objectInstances = filter(x -> data["types"][x] in vcat(data["objects"], map(o -> [:List, o], data["objects"])),
                           collect(keys(data["types"])))
  currHistValues = map(x -> "$(compile_sk(data["types"][x.args[1]], data)) $(compile_sk(x.args[1], data)) = state.$(compile_sk(x.args[1], data))History[state.time];", 
                       vcat(data["initnext"], data["lifted"]))
  nextHistValues = map(x -> "state.$(compile_sk(x.args[1], data))History[state.time] = $(compile_sk(x.args[1], data));", 
                       vcat(data["initnext"], data["lifted"]))
  onClauses = map(x -> """if ($(compile_sk(x[1], data))) {
                            $(compile_sk(x[2], data))
                          }""", data["on"])
  """
  State next(State state, Click click, Left left, Right right, Up up, Down down) {
    $(join(currHistValues, "\n"))
    
    $(join(onClauses, "\n"))

    state.time = state.time + 1;
    $(join(nextHistValues, "\n"))
    state.clickHistory[state.time] = click;
    state.leftHistory[state.time] = left;
    state.rightHistory[state.time] = right;
    state.upHistory[state.time] = up;
    state.downHistory[state.time] = down;
    state.scene = new Scene(objects={$(join(map(obj -> data["types"][obj] isa Array ? compile_sk(obj, data) : "{$(compile_sk(obj, data))}", objectInstances), ", "))}, background=\"transparent\");
    return state;
  }
  """
end

function compileprev_sk(data)
  objectInstances = filter(x -> data["types"][x] in vcat(data["objects"], map(o -> [:List, o], data["objects"])),
                           collect(keys(data["types"])))
  prevFunctions = map(x -> """$(compile_sk(data["types"][x], data)) $(compile_sk(x, data))Prev(State state, int n) {
                                state.$(compile_sk(x, data))History[state.time - n >= 0 ? state.time - n : 0];
                           }""", objectInstances)
  
  prevFunctionsNoArgs = map(x -> """$(compile_sk(data["types"][x], data)) $(compile_sk(x, data))Prev(State state) {
      state.$(compile_sk(x, data))History[state.time];
  }""", objectInstances)
  """
  $(join(prevFunctions, "\n"))
  $(join(prevFunctionsNoArgs, "\n"))
  """  
end

function compilelibrary_sk(data)

end

function compileharnesses_sk(data)

end

function compilegenerators_sk(data)

end

# ----- End Exported Functions -----#

function compileif(expr, data, parent) 
  return """if $(compile_sk(expr.args[1], data)) {
              $(compile_sk(expr.args[2], data))
            } else {
              $(compile_sk(expr.args[3], data))
            }
         """ 
end

function compileassign(expr, data, parent)
  # get type
  type = data["types"][expr.args[1]]
  if (typeof(expr.args[2]) == AExpr && expr.args[2].head == :fn)    
    args = compile_sk(expr.args[2].args[1], data).args # function args
    argtypes = map(x -> compile_sk(x, data), type.args[1:(end-1)]) # function arg types
    tuples = [(args[i], argtypes[i]) for i in [1:length(args);]]
    typedargs = map(x -> "$(x[2]) $(x[1])", tuples)
    returntype = compile_sk(type.args[end], data) 
    """ 
    $(returntype) $(compile_sk(expr.args[1], data))($(join(typedargs, ", "))) {
      $(compile_sk(expr.args[2].args[2], data))  
    }
    """ 
  else # handle non-function assignments
    # handle global assignments
    if parent !== nothing && (parent.head == :program) 
      if (typeof(expr.args[2]) == AExpr && expr.args[2].head == :initnext)
        push!(data["initnext"], expr)
      else
        push!(data["lifted"], expr)
      end
      ""
    # handle non-global assignments
    else 
      # :($(compile(expr.args[1], data))::$(compile(type, data)) = $(compile(expr.args[2], data)))
      "$(compile_sk(expr.args[1], data)) = $(compile_sk(expr.args[2], data)))"
    end
  end
end

function compiletypedecl(expr, data, parent)
  if (parent !== nothing && parent.head == :program)
    data["types"][expr.args[1]] = expr.args[2]
  end
  """$(compile_sk(expr.args[2], data)) $(compile_sk(expr.args[1], data));"""
end

function compilelet(expr, data, parent)
  assignments = map(x -> compile_sk(x, data), expr.args)
  join(assignments, "\n");
end

function compiletypealias(expr, data, parent)
  name = string(expr.args[1]);
  fields = map(field -> "$(compile_sk(field.args[2], data)) $(compile_sk(field.args[1], data));", 
           expr.args[2].args)
  """
  struct $(name) {
    $(join(fields, "\n"))
  }
  """
end

function compilelambda(expr, data, parent)
  "$(compile_sk(expr.args[1], data)) -> $(compile_sk(expr.args[2], data))"
end

function compilelist(expr, data, parent)
  "{ $(join(map(x -> compile_sk(x, data), expr.args), ", ")) }"
end

function compilecall(expr, data, parent)
  name = compile_sk(expr.args[1], data);
  args = map(x -> compile_sk(x, data), expr.args[2:end]);
  objectNames = map(x -> compile_sk(x, data), data["objects"])
  if name == "clicked"
    "clicked(click, $(join(args, ", ")))"
  elseif name in ["Position", "Cell"]
    "new $(name)($(join(args, ", ")))"
  elseif name in objectNames
    "$(lowercase(name[1]))$(name[2:end])($(join(args, "\n")))"
  elseif !(name in binaryOperators) && name != "prev"
    "$(name)($(join(args, ", ")))"
  elseif name == "prev"
    "$(compile_sk(expr.args[2], data))Prev($(join(["state", map(x -> compile_sk(x, data), expr.args[3:end])...], ", ")))"
  elseif name != "=="        
    "$(name)($(compile_sk(expr.args[2], data)), $(compile_sk(expr.args[3], data)))"
  else
    "$(compile_sk(expr.args[2], data)) == $(compile_sk(expr.args[3], data))"
  end
end

function compilefield(expr, data, parent)
  obj = compile_sk(expr.args[1], data)
  fieldname = compile_sk(expr.args[2], data)
  "$(obj).$(fieldname)"
end

function compileobject(expr, data, parent)
  name = compile_sk(expr.args[1], data)
  push!(data["objects"], expr.args[1])
  custom_fields = map(field -> 
                      "$(compile_sk(field.args[2], data)) $(compile_sk(field.args[1], data));",
                      filter(x -> (typeof(x) == AExpr && x.head == :typedecl), expr.args[2:end]))
  custom_field_names = map(field -> "$(compile_sk(field.args[1], data))", 
                           filter(x -> (x isa AExpr && x.head == :typedecl), expr.args[2:end]))
  custom_field_assgns = map(field -> "$(compile_sk(field.args[1], data))=$(compile_sk(field.args[1], data))",
                            filter(x -> (typeof(x) == AExpr && x.head == :typedecl), expr.args[2:end]))
  rendering = compile_sk(filter(x -> (typeof(x) != AExpr) || (x.head != :typedecl), expr.args[2:end])[1], data)
  
  """
  struct $(name) extends Object {
    $(join(custom_fields, "\n"))
  }

  $(name) $(string(lowercase(name[1]), name[2:end]))($(join([custom_fields..., "Position origin"], ", "))) {
    return new $(name)($(join([custom_field_assgns..., "origin=origin", "alive=true", "render=$(rendering)"], ", ")));
  }
  """
end

function compileon(expr, data, parent)
  event = compile_sk(expr.args[1], data)
  response = compile_sk(expr.args[2], data)
  onData = (event, response)
  push!(data["on"], onData)
  ""
end

end