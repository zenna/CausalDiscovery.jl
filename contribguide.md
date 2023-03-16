# Pushing

- Never push to master (unless you have a very good reason).  Push to a branch and submit a pull request to merge into master.
- Consequently, aster should always be in a state of its tests passing
- Write informative comments.  "done", "push", "ok", are not good comments.  It can be annoying to write comments but remember they are not for you, they are for other people (and your future self who has forgotten the present).  See [this guide on writing useful commit messages](https://dev.to/jacobherrington/how-to-write-useful-commit-messages-my-commit-message-template-20n9)


# Testing
Write tests for all non-trivial code you write.

If you create a file e.g. `src/myfile.jl`, then:
1. Create the corresponding file `test/myfile.jl`
2. And include that test file in `test/runtests.jl`

You can run all the tests using `] test CausalDiscovery`

# Code style
When sharing code with lots of people it's important to have a consistent style.

- Generally follw the (julia style guide)[https://docs.julialang.org/en/v1/manual/style-guide/index.html]
- Indent using __two spaces__ for indentation 
- Avoid unqualified use of `using` e.g., rather than `using Distributions`, `using Distributions: Normal; Normal(0, 1)`, or use the explicit form: `import Distributions; Distributions.Normal(0, 1)`


