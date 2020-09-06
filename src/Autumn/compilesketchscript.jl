using ..Compile, ..SExpressions

open("myfile.txt", "w") do io
  aprogram = """(program
    (= GRID_SIZE 16)
    
    (object Particle (Cell 0 0 "blue"))

    (: particles (List Particle))
    (= particles 
      (initnext (list) 
                (prev particles)))	
    
  )"""
  aexpr = au"""$(aprogram)"""
  sketchprogram = compiletosketch(aexpr)
  write(io, sketchprogram)
end;