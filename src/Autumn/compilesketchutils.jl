module CompileSketchUtils

using ..AExpressions, ..AutumnStandardLibrary, ..SExpr
using MLStyle: @match

export compile_sk, compileinit_sk, compilestate_sk, compilenext_sk, compileprev_sk, compilelibrary_sk, compileharnesses_sk, compilegenerators_sk

# binary operators
binaryOperators = map(string, [:+, :-, :/, :*, :&, :|, :>=, :<=, :>, :<, :(==), :!=, :%, :&&])

# ----- Begin Exported Functions ----- #

function compile_sk(expr::AExpr, data::Dict{String, Any}, parent::Union{AExpr, Nothing}=nothing)::String
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

function compile_sk(expr::String, data::Dict{String, Any}, parent::Union{AExpr, Nothing}=nothing)
  return """\"$(expr)\""""
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
  elseif expr == :String
    "char[STR_BND]"
  elseif expr == :Int
    "int"
  else
    string(expr)
  end
end

function compilestate_sk(data)
  stateHistories = map(expr -> "$(compile_sk(data["varTypes"][expr.args[1]] in data["objects"] ? 
                                  :Object 
                                  : 
                                  data["varTypes"][expr.args[1]] in map(x -> [:List, x], data["objects"]) ?
                                  [:List, :Object]
                                  :
                                  data["varTypes"][expr.args[1]], data))[ARR_BND] $(compile_sk(expr.args[1], data))History;", 
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
  objectInstances = filter(x -> data["varTypes"][x] in vcat(data["objects"], map(o -> [:List, o], data["objects"])),
                          collect(keys(data["varTypes"])))
  historyInitNextDeclarations = map(x -> "$(compile_sk(data["varTypes"][x.args[1]] in data["objects"] ? 
                                            :Object 
                                            : 
                                            data["varTypes"][x.args[1]] in map(x -> [:List, x], data["objects"]) ?
                                            [:List, :Object]
                                            :
                                            data["varTypes"][x.args[1]], data)) $(compile_sk(x.args[1], data)) = $(compile_sk(x.args[2].args[1], data));", 
                                     data["initnext"]) 
  historyLiftedDeclarations = map(x -> "$(compile_sk(data["varTypes"][x.args[1]], data)) $(compile_sk(x.args[1], data)) = $(compile_sk(x.args[2], data));", 
                           data["lifted"])
  historyInits = map(x -> "state.$(compile_sk(x.args[1], data))History[0] = $(compile_sk(x.args[1], data));", 
                     vcat(data["initnext"], data["lifted"]))
  """
  State state;
  State init() {
    int time = 0;
    $(join(historyInitNextDeclarations, "\n"))
    $(join(historyLiftedDeclarations, "\n"))
	  state = new State();
    state.time = time;
    $(join(historyInits, "\n"))
    state.clickHistory[0] = null;
    state.leftHistory[0] = null;
    state.rightHistory[0] = null;
    state.upHistory[0] = null;
    state.downHistory[0] = null;
    state.scene = new Scene(objects={$(join(map(obj -> data["varTypes"][obj] isa Array ? compile_sk(obj, data) : "{$(compile_sk(obj, data))}", objectInstances), ", "))}, background=\"transparent\");
    return state;
  }
  """
end

function compilenext_sk(data)
  objectInstances = filter(x -> data["varTypes"][x] in vcat(data["objects"], map(o -> [:List, o], data["objects"])),
                           collect(keys(data["varTypes"])))
  currHistValues = map(x -> "$(compile_sk(data["varTypes"][x.args[1]] in data["objects"] ? 
                              :Object 
                              : 
                              data["varTypes"][x.args[1]] in map(x -> [:List, x], data["objects"]) ?
                              [:List, :Object]
                              :
                              data["varTypes"][x.args[1]], data)) $(compile_sk(x.args[1], data)) = state.$(compile_sk(x.args[1], data))History[state.time];", 
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
    state.scene = new Scene(objects={$(join(map(obj -> data["varTypes"][obj] isa Array ? compile_sk(obj, data) : "{$(compile_sk(obj, data))}", objectInstances), ", "))}, background=\"transparent\");
    return state;
  }
  """
end

function compileprev_sk(data)
  objectInstances = filter(x -> data["varTypes"][x] in vcat(data["objects"], map(o -> [:List, o], data["objects"])),
                           collect(keys(data["varTypes"])))
  prevFunctions = map(x -> """$(compile_sk(data["varTypes"][x] in data["objects"] ? 
                                  :Object 
                                  : 
                                  data["varTypes"][x] in map(x -> [:List, x], data["objects"]) ?
                                  [:List, :Object]
                                  :
                                  data["varTypes"][x], data)) $(compile_sk(x, data))PrevN(State state, int n) {
                                return state.$(compile_sk(x, data))History[state.time - n >= 0 ? state.time - n : 0];
                           }""", objectInstances)
  
  prevFunctionsNoArgs = map(x -> """$(compile_sk(data["varTypes"][x] in data["objects"] ? 
  :Object 
  : 
  data["varTypes"][x] in map(x -> [:List, x], data["objects"]) ?
  [:List, :Object]
  :
  data["varTypes"][x], data)) $(compile_sk(x, data))Prev(State state) {
      return state.$(compile_sk(x, data))History[state.time];
  }""", objectInstances)
  """
  $(join(prevFunctions, "\n"))
  $(join(prevFunctionsNoArgs, "\n"))
  """  
end

function compilelibrary_sk(data)
  
  """
  Object updateObjOrigin(Object object, Position origin) {
    $(join(map(x -> 
              """
              if (object.type == \"$(compile_sk(x, data))\") {
                return new $(compile_sk(x, data))($(join(vcat("origin=origin", "alive=object.alive", "type=object.type", "render=object.render", map(y -> "$(y)=object.$(y)", data["customFields"][x])),", ")));
              } 
              """, data["objects"]), "\n"))
  }
  Object updateObjAlive(Object object, bit alive) {
    $(join(map(x -> 
              """
              if (object.type == \"$(compile_sk(x, data))\") {
                return new $(compile_sk(x, data))($(join(vcat("origin=object.origin", "alive=alive", "type=object.type", "render=object.render", map(y -> "$(y)=object.$(y)", data["customFields"][x])), ", ")));
              } 
              """, data["objects"]), "\n"))
  }
  Object updateObjRender(Object object, Cell[ARR_BND] render) {
    $(join(map(x -> 
              """
              if (object.type == \"$(compile_sk(x, data))\") {
                return new $(compile_sk(x, data))($(join(vcat("origin=object.origin", "alive=object.alive", "type=object.type", "render=render", map(y -> "$(y)=object.$(y)", data["customFields"][x])),", ")));
              }
              """, data["objects"]), "\n"))
  }
  $(library)
  """
end
#=
observations: list of ((Click, Left, Right, Up, Down), [list of cells])
=#
function compileharnesses_sk(observations::AbstractArray)
  userInputs = observations[1]
  observedFrames = observations[2]

  numObservations = length(observedFrames)

  sketchClicks = "{ $(join(map(input -> input[1] === nothing ? "null" : "new Click(position=new Position(x=$(input[1][1]), y=$(input[1][2])))", userInputs), ", ")) }"
  sketchLefts = "{ $(join(map(input -> input[2] === nothing ? "null" : "new Left()", userInputs), ", ")) }"
  sketchRights = "{ $(join(map(input -> input[3] === nothing ? "null" : "new Right()", userInputs), ", ")) }"
  sketchUps = "{ $(join(map(input -> input[4] === nothing ? "null" : "new Up()", userInputs), ", ")) }"
  sketchDowns = "{ $(join(map(input -> input[5] === nothing ? "null" : "new Down()", userInputs), ", ")) }"
  
  sketchObservations = "{ $(join(map(frame -> "{ $(join(map(
                                                          cell -> "new Cell(position=new Position(x=$(cell[1]), y=$(cell[2])), color=\"$(cell[3])\")", 
                                                          frame
                                                           ),
                                                   ", ")) }", 
                                     observedFrames),
                                 ", ")) }"
  """
  Cell[$(numObservations)][ARR_BND] observations = $(sketchObservations);
  Click[$(numObservations)] clicks = $(sketchClicks);
  Left[$(numObservations)] lefts = $(sketchLefts);
  Right[$(numObservations)] rights = $(sketchRights);
  Up[$(numObservations)] ups = $(sketchUps);
  Down[$(numObservations)] downs = $(sketchDowns);

  harness void observedData() {
    state = init();
    for (int i = 0; i < $(numObservations); i++) {
      state = next(state, clicks[i], lefts[i], rights[i], ups[i], downs[i]);
      assert sceneEquals(renderScene(state.scene), observations[i]);
    }
  }
  """
end

function compilegenerators_sk(data)
  println("pre-adding library signatures")
  println(data["types"])
  println(data["objects"])
  signatures = au"""(program
  (: uniformChoice (-> Int (List Position) Position))
  (: isWithinBoundsPosition (-> Position Bool))
  (: isWithinBoundsObject (-> Object Bool))
  (: occurred (-> Click Bool))
  (: clickedObj (-> Click Object Bool))
  (: clickedObjArray (-> Click (List Object) Bool))
  (: clickedPosition (-> Click Position Bool))
  (: intersectsObjObj (-> Object Object Bool))
  (: intersectsObjObjArray (-> Object (List Object) Bool))
  (: intersectsObjArrays (-> (List Object) (List Object) Bool))
  (: intersectsScene (-> Scene Object Bool))
  (: addObj (-> (List Object) Object (List Object)))
  (: addObjs (-> (List Object) (List Object) (List Object)))
  (: removeObjFromArray (-> (List Object) Object (List Object)))
  (: removeObj (-> Object Object))
  (: adjPositions (-> Position (List Position)))
  (: isFreePosition (-> Scene Position Bool))
  (: isFreeClick (-> Scene Click Bool))
  (: unitVector (-> Position Position Position))
  (: displacement (-> Position Position Position)) 
  (: isAdjacentPosition (-> Position Position Bool))
  (: objectClicked (-> Click (List Object) Object))
  (: isAdjacentObject (-> Object Object Bool))
  (: distanceObjs (-> Object Object Int))
  (: distancePositions (-> Position Position Int))
  (: move (-> Object Position Object))
  (: moveNoCollision (-> Object Position Scene Object))
  (: closest (-> Scene Oject String Object))
  (: updateObjOrigin (-> Object Position Object))
  (: updateObjAlive (-> Object Bool Object))
  (: updateObjRender (-> Object (List Cell) Object))
  (: getObjOrigin (-> Object Position))
  (: getObjAlive (-> Object Bool))
  (: getObjRender (-> Object (List Cell)))
  (: getPositionX (-> Position Int))
  (: getPositionY (-> Position Int))
  (: getCellPosition (-> Cell Position))
  (: and (-> Bool Bool Bool))
  (: or (-> Bool Bool Bool))
  (: not (-> Bool Bool))
  (: equalsInt (-> Int Int Bool))
  (: equalsBit (-> Bool Bool Bool))
  (: equalsPosition (-> Position Position Bool))
  (: equalsCell (-> Cell Cell Bool))
)"""

  lines = map(sig -> compile_sk(sig, data, signatures), signatures.args)
  println("post-adding library signatures")
  println(data["types"])
  println(data["objects"])
  
  global_vars = join(map(x -> "$(data["varTypes"][x] in vcat(data["objects"], map(x -> [:List, x], data["objects"])) 
                                ? "Object$(data["varTypes"][x] isa AbstractArray ? "[ARR_BND]" : "")" : 
                                  compile_sk(data["varTypes"][x], data)) $(compile_sk(x, data))", 
                         filter(var -> !(data["varTypes"][var] isa AExpr) && (data["varTypes"][var] != :KeyPress && !(var in [:GRID_SIZE, :background, :state])), collect(keys(data["varTypes"])))), ", ")

  untyped_global_vars = join(map(x -> "$(compile_sk(x, data))", 
                  filter(var -> !(data["varTypes"][var] isa AExpr) && (data["varTypes"][var] != :KeyPress && !(var in [:GRID_SIZE, :background, :state])), collect(keys(data["varTypes"])))), ", ")

  matching_funcs = Dict(zip(data["types"], 
                        map(type -> 
                            filter(x -> data["varTypes"][x] isa AExpr && (data["varTypes"][x].args[end] == Symbol(type)
                                        || (Symbol(type) in data["objects"] && data["varTypes"][x].args[end] == :Object)), 
                                   collect(keys(data["varTypes"]))), data["types"])))
  matching_vars = Dict(zip(data["types"], map(type -> filter(x -> data["varTypes"][x] == Symbol(type), collect(keys(data["varTypes"]))), data["types"])))

  generators = map(type -> """
  generator $(Symbol(type) in data["objects"] ? "Object" : (type == "Bool" ? "bit" : (type == "Int" ? "int" : type))) gen$(uppercase((type == "Bool" ? "bit" : type)[1]))$((type == "Bool" ? "bit" : type)[2:end])($(global_vars)) {
    if (??) {
      return $(type == "Int" ? "??" : length(matching_vars[type]) == 0 ? "\$($((type == "Bool" ? "bit" : (type == "Int" ? "??" : type))))" : "(??) ? \$($((type == "Bool" ? "bit" : (type == "Int" ? "??" : type)))) : {| $(join(map(x -> compile_sk(x, data), matching_vars[type]), " | ")) |}");
    } $(length(matching_funcs[type]) != 0 ? """else {
      $(compilegenerators_helper(type, matching_funcs[type], untyped_global_vars, data))
    }""" : "") 
  }
""", data["types"])

  matching_funcs_arr = Dict(zip(data["types"], 
                                map(type -> 
                                    filter(x -> data["varTypes"][x] isa AExpr && (data["varTypes"][x].args[end] == [:List, Symbol(type)]
                                                    || (Symbol(type) in data["objects"] && data["varTypes"][x].args[end] == [:List, :Object])), 
                                           collect(keys(data["varTypes"]))), data["types"])))
  matching_vars_arr = Dict(zip(data["types"], map(type -> filter(x -> data["varTypes"][x] == [:List, Symbol(type)], collect(keys(data["varTypes"]))), data["types"])))

  array_generators = map(type -> """
                          generator $(Symbol(type) in data["objects"] ? "Object" : type)[ARR_BND] gen$(uppercase((type == "Bool" ? "bit" : type)[1]))$((type == "Bool" ? "bit" : type)[2:end])Array($(global_vars)) {
                            if (??) {
                              return $(length(matching_vars_arr[type]) == 0 ? "\$($(type)[ARR_BND])" : "(??) ? \$($(type)[ARR_BND]) : {| $(join(map(x -> compile_sk(x, data), matching_vars_arr[type]), " | ")) |}");
                            } $(length(matching_funcs_arr[type]) != 0 ? """else {
                              \t$(compilegenerators_helper(type, matching_funcs_arr[type], untyped_global_vars, data))
                            }""" : "") 
                          }
                          """, 
                        filter(var -> !(var in ["Int", "Bool"]), data["types"]))
  
  fixedGenerators = """generator Object genObject($(global_vars)) {
                        return {| $(join(map(x -> "gen$(uppercase(compile_sk(x, data)[1]))$(compile_sk(x, data)[2:end])($(untyped_global_vars))", data["objects"]), " | ")) |};
                    } 

                    generator Object[ARR_BND] genObjectArray($(global_vars)) {
                      return {| $(join(map(x -> "gen$(uppercase(compile_sk(x, data)[1]))$(compile_sk(x, data)[2:end])Array($(untyped_global_vars))", data["objects"]), " | ")) |} ;
                    }
                    
                    generator Scene genScene($(global_vars)) {
                      return state.scene;
                    }

                    """

  join(vcat(generators, array_generators, fixedGenerators), "\n")
end

function compilegenerators_helper(type::String, funcs::Array{Symbol}, global_vars, data)
  println("type")
  println(type)
  println(funcs[1])
  println(data["varTypes"][funcs[1]].args[1:end-1])
  println(join(map(x -> "gen$(x in [:Object, [:List, :Object]] ? (Symbol(type) in data["objects"] ? "$(uppercase((type == "Bool" ? "bit" : type)[1]))$((type == "Bool" ? "bit" : type)[2:end])" : "Object") : "$(uppercase(compile_sk(x isa AbstractArray ? x[2] : x, data)[1]))$(compile_sk(x isa AbstractArray ? x[2] : x, data)[2:end])")$(x isa AbstractArray ? "Array" : "")($(global_vars))", data["varTypes"][funcs[1]].args[1:end-1]), ", "))
  ret_statement = funcs[1] == :closest ? 
                  "closest(genScene($(global_vars)), genObject($(global_vars)), \"$(type)\")" : 
                  "$(compile_sk(funcs[1], data))($(join(map(x -> "gen$(x in [:Object, [:List, :Object]] ? (Symbol(type) in data["objects"] ? "$(uppercase((type == "Bool" ? "bit" : type)[1]))$((type == "Bool" ? "bit" : type)[2:end])" : "Object") : "$(uppercase(compile_sk(x isa AbstractArray ? x[2] : x, data)[1]))$(compile_sk(x isa AbstractArray ? x[2] : x, data)[2:end])")$(x isa AbstractArray ? "Array" : "")($(global_vars))", data["varTypes"][funcs[1]].args[1:end-1]), ", ")))"
  if length(funcs) == 1
    """
    return $(ret_statement);
    """
  else
    """
    if (??) {
        return $(ret_statement);
      } else {
      $(compilegenerators_helper(type, funcs[2:end], global_vars, data))
    }
    """
  end
end

# ----- End Exported Functions -----#

function compileif(expr, data, parent)
  if expr.args[2] isa AExpr && (expr.args[2].head in [:assign, :let]) 
    return """if $(compile_sk(expr.args[1], data)) {
        $(compile_sk(expr.args[2], data))
      } else {
        $(compile_sk(expr.args[3], data))
      }
  """
  else
    return "$(compile_sk(expr.args[1], data)) ? $(compile_sk(expr.args[2], data)) : $(compile_sk(expr.args[3], data))"
  end 
end

function compileassign(expr, data, parent)
  # get type
  type = data["varTypes"][expr.args[1]]
  if (typeof(expr.args[2]) == AExpr && expr.args[2].head == :fn)    
    args = map(x -> compile_sk(x, data), expr.args[2].args[1].args) # function args
    argtypes = map(x -> compile_sk(x in data["objects"] ? 
                        :Object 
                        : 
                        (x in data["objects"]) ? 
                        [:List, :Object] 
                        : 
                        x, data), type.args[1:(end-1)]) # function arg types
    tuples = [(args[i], argtypes[i]) for i in [1:length(args);]]
    typedargs = map(x -> "$(x[2]) $(x[1])", tuples)
    returntype = compile_sk(type.args[end] in data["objects"] ? 
                            :Object 
                            : 
                            (type.args[end] in data["objects"]) ? 
                            [:List, :Object] 
                            : 
                            type.args[end], data) 
    """ 
    $(returntype) $(compile_sk(expr.args[1], data))($(join(typedargs, ", "))) {
      $(compile_sk(expr.args[2].args[2], data)); 
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
      "$(compile_sk(expr.args[1], data)) = $(compile_sk(expr.args[2], data));"
    end
  end
end

function compiletypedecl(expr, data, parent)
  println("here!")
  println(expr)
  if (parent !== nothing && parent.head == :program)
    println("here 2!")
    println(expr)
    data["varTypes"][expr.args[1]] = expr.args[2]
    ""
  else
    """$(compile_sk(expr.args[2], data)) $(compile_sk(expr.args[1], data));"""
  end
end

function compilelet(expr, data, parent)
  assignments = map(x -> compile_sk(x, data), expr.args)
  join(vcat(assignments[1:end-1], string("return ", assignments[end])), "\n");
end

function compiletypealias(expr, data, parent)
  name = string(expr.args[1]);
  fields = map(field -> "$(compile_sk(field.args[2], data)) $(compile_sk(field.args[1], data));", 
           expr.args[2].args)
  
  # update data["types"]
  push!(data["types"], name)

  # add type decls of new get field functions
  decls = parseautumn("""
    (program
      $(join(map(field -> """
      (: getObj$(name)$(uppercasefirst(compile_sk(field.args[1], data))) (-> $(name) $(compile_sk(field.args[2], data))))
      """, expr.args[2].args), "\n"))
    )
    """)

  lines = map(decl -> compile_sk(decl, data, decls), decls.args)
  println("post-adding library signatures for updateObj/getObj")
  println(data["types"])
  println(data["objects"])

  """
  struct $(name) {
    $(join(fields, "\n"))
  }
  
  $(join(map(
    field -> """ 
      getObj$(name)$(uppercasefirst(compile_sk(field.args[1], data)))(Object object, $(compile_sk(field.args[2], data)) $(compile_sk(field.args[1], data))) {
        return object.$(compile_sk(field.args[1], data));
      }
    """,
    expr.args[2].args), "\n"))
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
  elseif name == "Position"
    "new $(name)(x=$(args[1]), y=$(args[2]))"
  elseif name == "Cell"
    if length(args) == 2
      "new $(name)(position=$(args[1]), color=$(args[2]))"
    elseif length(args) == 3
      "new $(name)(position=new Position(x=$(args[1]), y=$(args[2])), color=$(args[3]))"
    end
  elseif name in objectNames
    "$(lowercase(name[1]))$(name[2:end])($(join(args, ", ")))"
  elseif name in data["types"]
    "new $(name)($(join(args, ", ")))"
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
  println(expr.args[1])
  name = compile_sk(expr.args[1], data)
  push!(data["objects"], expr.args[1])
  custom_fields = map(field -> 
                      "$(compile_sk(field.args[2], data)) $(compile_sk(field.args[1], data));",
                      filter(x -> (typeof(x) == AExpr && x.head == :typedecl), expr.args[2:end]))
  custom_field_names = map(field -> "$(compile_sk(field.args[1], data))", 
                           filter(x -> (x isa AExpr && x.head == :typedecl), expr.args[2:end]))
  data["customFields"][expr.args[1]] = custom_field_names;
  custom_field_assgns = map(field -> "$(compile_sk(field.args[1], data))=$(compile_sk(field.args[1], data))",
                            filter(x -> (typeof(x) == AExpr && x.head == :typedecl), expr.args[2:end]))
  rendering = compile_sk(filter(x -> (typeof(x) != AExpr) || (x.head != :typedecl), expr.args[2:end])[1], data)
  renderingIsList = filter(x -> (typeof(x) != AExpr) || (x.head != :typedecl), expr.args[2:end])[1].head == :list
  rendering = renderingIsList ? rendering : "{$(rendering)}"

  # compile updateObj functions, and move/rotate/nextWater/nextLiquid
  update_obj_fields = map(x -> [compile_sk(x.args[2], data), compile_sk(x.args[1], data)], 
                               filter(x -> (typeof(x) == AExpr && x.head == :typedecl), expr.args[2:end]))
  update_obj_field_assigns = map(x -> "$(x[2])=object.$(x[2])", update_obj_fields)
  update_obj_functions = map(x -> """
                                  Object updateObj$(name)$(string(uppercase(x[2][1]), x[2][2:end]))(Object object, $(x[1]) $(x[2])) {
                                    return new $(name)($(join(vcat(string(x[2], "=", x[2]), filter(y -> split(y, "=")[1] != x[2], update_obj_field_assigns)), ", ")));
                                  } 
                                  
                                  $(x[1]) getObj$(name)$(string(uppercase(x[2][1]), x[2][2:end]))(Object object) {
                                    return object.$(x[2]);
                                  }
                                  
                                  """, update_obj_fields)                               
  
  # update data["varTypes"]
  decls = parseautumn("""
          (program
            $(join(map(x -> """
            (: updateObj$(name)$(string(uppercase(x[2][1]), x[2][2:end])) (-> $(name) $(x[1]) $(name)))
            (: getObj$(name)$(string(uppercase(x[2][1]), x[2][2:end])) (-> $(name) $(x[1])))
            """, update_obj_fields), "\n"))
          )
          """)
  
  lines = map(decl -> compile_sk(decl, data, decls), decls.args)
  println("post-adding library signatures for updateObj/getObj")
  println(data["types"])
  println(data["objects"])
  

  # update data["types"]
  push!(data["types"], name)

  """
  struct $(name) extends Object {
    $(join(custom_fields, "\n"))
  }

  $(name) $(string(lowercase(name[1]), name[2:end]))($(join([custom_fields..., "Position origin"], ", "))) {
    return new $(name)($(join([custom_field_assgns..., "origin=origin", string("type=\"", name, "\""), "alive=true", "render=$(rendering)"], ", ")));
  }
  
  $(join(update_obj_functions, "\n"))
  
  """
end

function compileon(expr, data, parent)
  event = expr.args[1]
  response = expr.args[2]
  onData = (event, response)
  push!(data["on"], onData)
  ""
end

end