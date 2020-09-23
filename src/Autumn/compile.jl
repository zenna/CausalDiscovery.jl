"Compilation to Julia"
module Compile

using ..AExpressions, ..CompileUtils, ..SExpr, ..CompileSketchUtils
import MacroTools: striplines

export compiletojulia, runprogram, compiletosketch

"compile `aexpr` into Expr"
function compiletojulia(aexpr::AExpr)::Expr

  # dictionary containing types/definitions of global variables, for use in constructing init func.,
  # next func., etcetera; the three categories of global variable are external, initnext, and lifted  
  historydata = Dict([("external" => [au"""(external (: click Click))""".args[1], au"""(external (: left KeyPress))""".args[1], au"""(external (: right KeyPress))""".args[1], au"""(external (: up KeyPress))""".args[1], au"""(external (: down KeyPress))""".args[1]]), # :typedecl aexprs for all external variables
               ("initnext" => []), # :assign aexprs for all initnext variables
               ("lifted" => []), # :assign aexprs for all lifted variables
               ("types" => Dict{Symbol, Any}([:click => :Click, :left => :KeyPress, :right => :KeyPress, :up => :KeyPress, :down => :KeyPress, :GRID_SIZE => :Int, :background => :String])), # map of global variable names (symbols) to types
               ("on" => []),
               ("objects" => [])]) 
               
  if (aexpr.head == :program)
    # handle AExpression lines
    lines = filter(x -> x !== :(), map(arg -> compile(arg, historydata, aexpr), aexpr.args))
    
    # construct STATE struct and initialize state::STATE
    stateStruct = compilestatestruct(historydata)
    initStateStruct = compileinitstate(historydata)
    
    # handle init, next, prev, and built-in functions
    initnextFunctions = compileinitnext(historydata)
    prevFunctions = compileprevfuncs(historydata)
    builtinFunctions = compilebuiltin()

    # remove empty lines
    lines = filter(x -> x != :(), 
            vcat(builtinFunctions, lines, stateStruct, initStateStruct, prevFunctions, initnextFunctions))

    # construct module
    expr = quote
      module CompiledProgram
        export init, next
        import Base.min
        using Distributions
        using MLStyle: @match
        using Random
        rng = Random.GLOBAL_RNG
        $(lines...)
      end
    end  
    expr.head = :toplevel
    striplines(expr) 
  else
    throw(AutumnError("AExpr Head != :program"))
  end
end

function compiletosketch(aexpr::AExpr, observations)::String
  metadata = Dict([("initnext" => []), # :assign aexprs for all initnext variables
               ("lifted" => []), # :assign aexprs for all lifted variables
               ("varTypes" => Dict{Symbol, Any}([:click => :Click, :left => :KeyPress, :right => :KeyPress, :up => :KeyPress, :down => :KeyPress, :GRID_SIZE => :Int, :background => :String])), # map of global variable names (symbols) to types
               ("on" => []),
               ("objects" => []),
               ("customFields" => Dict{Symbol, Any}()),
               ("types" => ["Int", "Bool", "Cell", "Position", "Click"])]) 
  if (aexpr.head == :program)
    # handle AExpr lines
    lines = map(arg -> compile_sk(arg, metadata, aexpr), aexpr.args)

    # construct state struct
    stateStruct = compilestate_sk(metadata)

    # construct init and next functions
    initFunction = compileinit_sk(metadata)
    nextFunction = compilenext_sk(metadata)

    # construct prev functions
    prevFunctions = compileprev_sk(metadata)

    # construct library
    library = compilelibrary_sk(metadata)
    

    # construct harnesses 
    harnesses = compileharnesses_sk(observations);
        
    # construct generators
    generators = compilegenerators_sk(metadata);
    
    join([
      "int ARR_BND = 10;",
      "int STR_BND = 20;",
      lines...,
      stateStruct,
      initFunction,
      nextFunction,
      prevFunctions, 
      library, 
      harnesses, 
      generators 
    ], "\n")
  else
    throw(AutumnError("AExpr Head != :program"))
  end
end

"Run `prog` for finite number of time steps"
function runprogram(prog::Expr, n::Int)
  mod = eval(prog)
  state = mod.init(mod.Click(5, 5))

  for i in 1:n
    externals = [nothing, mod.Click(rand([1:10;]), rand([1:10;]))]
    state = mod.next(mod.next(state, externals[rand(Categorical([0.7, 0.3]))]))
  end
  state
end

end