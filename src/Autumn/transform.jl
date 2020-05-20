"Code transformations to Autumn programs"
module Transform


"""
Expand a subexpression.

Returns a parametric representation over graphs.

x = au\"\"\"
(program
  (= x 3)
  (= y (x + ?)))
\"\"\"

hole = first(holes(x))    # Find the first hole
ϕ = expand(hole)          # Get parametric representation of hole
fill = sat(ϕ)             # Find any expression
xnew = replace(x, fill)   # Construct `x`
```
"""
function expand(subexpr)
  
end

function 
end

end