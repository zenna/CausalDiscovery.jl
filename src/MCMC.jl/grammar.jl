module Grammar
export tuplejoin, isTerminalIndex, getTerminalValue, getProductionRuleIndexAndProb, getNodeIndexFromSymbol, getSymbolsOfProductionRule, add, subtract, mul, div

"""
Grammar:
NODE                                := DEFINITION
------------------------------------------------------------------------------------------------
(node_index 1)  expr                := line \n expr | line
(node_index 2)  line                := exo_line | endo_line
(node_index 3)  exo_line            := bool_var '~' dist | float_var '~' float_dist
(node_index 4)  endo_line           := unary_endo_expr | binary_endo_expr | ternary_endo_expr
*(node_index 5)  unary_endo_expr    := bool_var = '!' bool_var | bool_var = bool_var | int_var = int_var | float_var = float_var
*(node_index 6)  binary_endo_expr   := bool_var = bool_binary_op bool_var bool_var_list | int_var = num_binary_op int_var int_var_list | float_var = num_binary_op float_var float_var_list
*(node_index 7)  ternary_endo_expr  := bool_var = bool_var '?' bool_var ':' bool_var | int_var = bool_var '?' int_var ':' int_var | float_var = bool_var '?' float_var ':' float_var

(node_index 8) bool_var_list        := bool_var ',' bool_var_list | bool_var
(node_index 9) int_var_list         := int_var ',' int_var_list '|' int_var
(node_index 10) float_var_list      := float_var ',' float_var_list '|' float_var

(node_index 11) var                 := bool_var | int_var | float_var
(node_index 12) bool_dist           := Bernoulli( bernoulli_params )

/** BELOW ARE TERMINAL NODES */
(node_index 13)  bool_binary_op     := '&' | '|'
(node_index 14)  num_binary_op      := '+' | '-' | '*' | '\'

(node_index 15) bool_var            := 'bool_var_1' | 'bool_var_2' | ... | 'bool_var_5'
(node_index 16) int_var             := 'int_var_1' | 'int_var_2' | ... | 'int_var_5'
(node_index 17) float_var           := 'float_var_1' | 'float_var_2' | ... | 'float_var_5'

(node_index 18) bernoulli_params    := '0.0' | '0.1' | '0.2' | '0.3' | ... | '1.0'
(node_index 19) normal_params       := /* finite number of (mean, variance) pairs */
(node_index 20) uniform_params      := /* finite number of [start, end] intervals */

(node_index 21) float_dist          := Normal ( normal_params ) | Uniform( uniform_params )

"""

""" Binary Operators """
function add(args...)
    total = 0
    for arg in args
        total += arg
    end
    total
end

function subtract(args...)
    total = args[1]
    for (i,) in enumerate(args)
        if i != 1
            total -= args[i]
        end
    end
    total
end

function mul(args...)
    total = 1
    for arg in args
        total *= arg
    end
    total
end

function div(args...)
    total = args[1]
    for (i,) in enumerate(args)
        if i != 1
            if args[i] != 0
                total /= args[i]
            else
                if total >= 0
                    Inf
                else
                    -Inf
                end
            end
        end
    end
    total
end



""" ----- GRAMMAR-RELATED UTILITY FUNCTIONS ----- """

""" Concatenates tuples """
tuplejoin(t1::Tuple, t2::Tuple, t3...) = tuplejoin((t1..., t2...), t3...)
tuplejoin(t::Tuple) = t

""" Returns whether node_index refers to a terminal node """
function isTerminalIndex(node_index)
    if (node_index >= 13 && node_index <= 20)
        true
    elseif ((node_index >= 1 && node_index < 13) || node_index == 21)
        false
    else
        throw(ArgumentError(""))
    end
end

""" Returns value associated with terminal_node_index and production_rule_index """
function getTerminalValue(terminal_node_index, production_rule_index)
    if isTerminalIndex(terminal_node_index)
        if (terminal_node_index == 13)
            values = [:and, :or]
        elseif (terminal_node_index == 14)
            values = [:add, :subtract, :mul, :div]
        elseif (terminal_node_index == 15)
            values = [:bool_var_1, :bool_var_2, :bool_var_3, :bool_var_4, :bool_var_5]
        elseif (terminal_node_index == 16)
            values = [:int_var_1, :int_var_2, :int_var_3, :int_var_4, :int_var_5]
        elseif (terminal_node_index == 17)
            values = [:float_var_1, :float_var_2, :float_var_3, :float_var_4, :float_var_5]
        elseif (terminal_node_index == 18)
            values = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
        elseif (terminal_node_index == 19)
            values = [(0, 1), (0, 0.5)]
        elseif (terminal_node_index == 20)
            values = [(0, 1), (0, 0.5)]
        end
        values[production_rule_index]
    else
        throw(ArgumentError(""))
    end
end

""" Returns ordered node indices associated with node_index and production_rule_index """
function getNodeIndexFromSymbol(symbol)
    symbols_to_node_indices[symbol]
end

function getSymbolsOfProductionRule(node_index, production_rule_index)
    nonterminal_indices_to_child_symbols[node_index][production_rule_index]
end

""" Returns randomly sampled production_rule_index for node_index and probability """
function getProductionRuleIndexAndProb(node_index)
    if node_index in [12]
        production_rule_indices = [1]
    elseif node_index in [1, 2, 3, 8, 9, 10, 13, 19, 20, 21]
        production_rule_indices = [1, 2]
    elseif node_index in [4, 6, 7, 11]
        production_rule_indices = [1,2,3]
    elseif node_index in [14, 5]
        production_rule_indices = [1,2,3,4]
    elseif node_index in [15, 16, 17]
        production_rule_indices = [1,2,3,4,5]
    elseif node_index in [18]
        production_rule_indices = [1,2,3,4,5,6,7,8,9,10]
    else
        throw(ArgumentError(""))
    end
    return rand(production_rule_indices), 1/length(production_rule_indices)
end

""" ----- GRAMMAR DATA STRUCTURES ----- """

nonterminal_indices_to_child_symbols = Dict(
    1 => [["line", "expr"],
          ["line"]],
    2 => [["exo_line"],
          ["endo_line"]],
    3 => [["bool_var", "bool_dist"],
          ["float_var","float_dist"]],
    4 => [["unary_endo_expr"],
          ["binary_endo_expr"],
          ["ternary_endo_expr"]],
    5 => [["bool_var", "bool_var"],
          ["bool_var", "bool_var"],
          ["int_var", "int_var"],
          ["float_var", "float_var"]],
    6 => [["bool_var", "bool_binary_op", "bool_var", "bool_var_list"],
          ["int_var", "num_binary_op", "int_var", "int_var_list"],
          ["float_var", "num_binary_op", "float_var", "float_var_list"]],
    7 => [["bool_var", "bool_var", "bool_var", "bool_var"],
          ["int_var", "bool_var", "int_var", "int_var"],
          ["float_var", "bool_var", "float_var", "float_var"]],
    8 => [["bool_var", "bool_var_list"],
          ["bool_var"]],
    9 => [["int_var", "int_var_list"],
          ["int_var"]],
    10 => [["float_var", "float_var_list"],
          ["float_var"]],
    11 => [["bool_var"],
           ["int_var"],
           ["float_var"]],
    12 => [["bernoulli_params"]],
    21 => [["normal_params"], ["uniform_params"]]
)

symbols_to_node_indices = Dict(
    "expr" => 1,
    "line" => 2,
    "exo_line" => 3,
    "endo_line" => 4,
    "unary_endo_expr" => 5,
    "binary_endo_expr" => 6,
    "ternary_endo_expr" => 7,
    "bool_var_list" => 8,
    "int_var_list" => 9,
    "float_var_list" => 10,
    "var" => 11,
    "bool_dist" => 12,
    "bool_binary_op" => 13,
    "num_binary_op" => 14,
    "bool_var" => 15,
    "int_var" => 16,
    "float_var" => 17,
    "bernoulli_params" => 18,
    "normal_params" => 19,
    "uniform_params" => 20,
    "float_dist" => 21,
)

end
