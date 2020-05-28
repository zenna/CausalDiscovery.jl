-1. Expand out grammar with all terms
-2. include variable binding
-3. Figure out how to deal with this statement / use case problem
4. Understand RJMCMC


- Should we use an expr type or something else?
-- One probllem with wrapping expr is that we can't store meta-data
What metadata will we need to store?
Potentially a bunch, like type information and so on.
But do wa want that in the expr object?.
Well let's not change htings prematurely



Q: Should we use custom type for each argument (as oppsoed to single AExpr object)
- Proyes : multiple dispatch makes writing these nice, can also do abstract for particular classes using traits
- Cons: multiple dispatch is slower than ifelse
- Cons: cant use existing macrotools pattern matching immediately

Q: Should we use Expr for 

Q. Do we need init, can we get by with just next?

Q. Should Autmn have abstract types?
The problem is that without abstract types, or type parameters, there are many functions we cannot express,
such as map, and we'll end up writing special code to handle it.

- Start with no, can add later

Q. 

TODO

x {30m} Decide on type system for language
- Elm type type system
. Decide on Expr structure
- Finish Autumn grammar
- Finish compiler from sexpressions to aexpr
- Write particles in autumn
- Write particles in julia
- Write particles in sexpressions 
- Construct abstract interpretation framework for Autumn
- Write expand