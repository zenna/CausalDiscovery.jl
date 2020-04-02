using CausalDiscovery.MCMC:
using Test

include("../src/MCMC.jl")

#tree1
# TaggedParseTree(
# NonTerminalNode((1, 2), "expr", (1, 2), 0.5, nothing,
#     Any[NonTerminalNode((2, 1), "line", (1, 2, 2, 1), 0.5,parent, 1/2
#         Any[NonTerminalNode((3, 2), "exo_line", (1, 2, 2, 1, 3, 2), 0.5, parent, 1/2
#             Any[TerminalNode((17, 5), "float_var", (1, 2, 2, 1, 3, 2, 17, 5), 0.2, parent, 1/2
#                    :float_var_5), 1/5
#             NonTerminalNode((21, 1), "float_dist", (1, 2, 2, 1, 3, 2, 21, 1), 0.5, parent,
#                 Any[TerminalNode((19, 1), "normal_params", (1, 2, 2, 1, 3, 2, 21, 1, 19, 1), 0.5, parent, 1/2
#                        (0, 1))]) 1/2
#             ])
#         ])
#     ])

tree1 = generateTree(100)
proposed = proposeTree(tree1)

#tree1 should equal proposed expect with float_var_5 replacing float_var_1
#following test should be added when expressions are able to be evaluated
#@test(isapprox(eval(getExpr(tree1)), eval(getExpr(proposed)); 0.01)

#Tests findNodeWithPosition function
expected_node = tree1.root_node.children[1].children[1]
found_node = findNodeWithPosition(tree1.root_node, expected_node.node_position)
@test(expected_node == found_node)

#Testing random seed version of generateTree
tree2 = generateTree(100)
@test(tree1.node_positions == tree2.node_positions)

expr1 = getExpr(tree1)
expr2 = getExpr(tree2)
@test(expr1==expr2)

#test getPriorProb with exogenous line
priorProb = getPriorProb(tree1)
expectedProb = 0.00625
@test(isapprox(priorProb, expectedProb; .01))

#test getPriorProb with proposed tree
priorProb = getPriorProb(proposed)
@test(isapprox(priorProb, expectedProb; .01))

#testing conditional
expectedConditional = log((1/6)*(1/5) + (1/6)*.00625 + (1/30)*(1/8) + (1/30)*(1/16))
conditional = getConditionalLogProb(tree1, proposed)
@test(isapprox(conditional, expectedConditional; .01))

tree3 = generateTree(4)

#Test getPriorProb with endogenous line
priorProb = getPriorProb(tree3)
expectedProb = 1/(2*2*3*4*5*5)
@test(isapprox(priorProb, expectedProb; 0.01))

proposed = proposeTree(tree3)
#Tests for conditional prob with endo line
expectedConditional = log((1/6)*(1/25)*((1/48)+(1/24)+(1/12)+(1/4)))
conditional = getConditionalLogProb(tree3, proposed)
@test(isapprox(conditional, expectedConditional; 0.01))
