import pickle 
from z3 import * 
from bitstring import BitArray 
import sys 

option = int(sys.argv[1])

# dictionary of event strings to their observed bit-vectors
event_vector_dict = pickle.load(open('./event_vector_dict.pkl', 'rb')) # {"up" : [1,0,0,1], "down" : [1, 1, 1, 0], "right" : {1 : [0, 1, 1, 1], 2 : [1, 1, 1, 0]}}

# dictionary of object_id's to their observed vectors (-1/0/1)
observed_data_dict = pickle.load(open('./observed_data_dict.pkl', 'rb')) # {1 : [1, 0, 0, 0], 2 : [1, 0, 0, 0]} 

# sorted list of object_id's
object_ids = sorted(list(observed_data_dict.keys()))

ambig_positions_dict = {} # dictionary of object_id's to the -1 positions in observed_data_dict
observed_bv_dict = {} # dictionary of object_id's to observed_data_dict[object_id] value with -1's removed
observed_bv_vals_dict = {} # dictionary of object_id's to int value of bit vector in observed_data_dict[object_id] 
for object_id in object_ids:
  ambig_positions_dict[object_id] = [i for i, x in enumerate(observed_data_dict[object_id]) if x == -1]
  observed_bv_dict[object_id] = list(filter(lambda x: x != -1, observed_data_dict[object_id]))
  observed_bv_vals_dict[object_id] = BitArray(observed_bv_dict[object_id]).uint

atom_dict = {} # dictionary of events to event values with ambig positions filtered out
for event in event_vector_dict:
  event_values = event_vector_dict[event]
  filtered_event_values = {}
  if isinstance(event_values, list):
    for object_id in object_ids:
      filtered_event_values[object_id] = list(map(lambda i: event_values[i], list(filter(lambda pos: pos not in ambig_positions_dict[object_id], list(range(len(observed_data_dict[object_id])))))))
    atom_dict[event] = filtered_event_values
  elif set(event_values.keys()) == set(object_ids):
    for object_id in object_ids:
      filtered_event_values[object_id] = list(map(lambda i: event_values[object_id][i], list(filter(lambda pos: pos not in ambig_positions_dict[object_id], list(range(len(observed_data_dict[object_id])))))))
    atom_dict[event] = filtered_event_values 

sorted_atom_events = sorted(atom_dict.keys())

# construct Z3 problem 
# z3_atoms is list of Z3 arrays of bit_vectors, where there is one array per object_id, 
# and the bit_vectors in the array correspond to the bit vectors for each event (for that object) in event_vector_dict
z3_atoms = [Array("atoms" + str(i), IntSort(), BitVecSort(len(observed_bv_dict[object_ids[i]]))) for i in range(len(object_ids))]
for object_id_idx in range(len(object_ids)):
  atoms = list(map(lambda e: BitVecVal(BitArray(atom_dict[e][object_ids[object_id_idx]]).uint, len(observed_bv_dict[object_ids[object_id_idx]])), sorted_atom_events))
  i = 0
  for elem in atoms:
    z3_atoms[object_id_idx] = Store(z3_atoms[object_id_idx], i, elem)
    i = i + 1

atom_index_1 = Int("atom_index_1")
atom_index_2 = Int("atom_index_2")

s = Solver()
s.add(atom_index_1 >= 0)
s.add(atom_index_1 < len(list(atom_dict.keys())))

s.add(atom_index_2 >= 0)
s.add(atom_index_2 < len(list(atom_dict.keys())))

for i in range(len(object_ids)):
  single_sol = Select(z3_atoms[i], atom_index_1) == BitVecVal(observed_bv_vals_dict[object_ids[i]], len(observed_bv_dict[object_ids[i]]))
  and_sol = Select(z3_atoms[i], atom_index_1) & Select(z3_atoms[i], atom_index_2) == BitVecVal(observed_bv_vals_dict[object_ids[i]], len(observed_bv_dict[object_ids[i]]))  
  or_sol = Select(z3_atoms[i], atom_index_1) & Select(z3_atoms[i], atom_index_2) == BitVecVal(observed_bv_vals_dict[object_ids[i]], len(observed_bv_dict[object_ids[i]]))
  # s.add(Or(single_sol, and_sol, or_sol))
  if option == 1:
    s.add(and_sol)
  elif option == 2:
    s.add(or_sol)      

res = s.check()
index_1 = -1
index_2 = -1
if res == sat:
  m = s.model()
  index_1 = (m[atom_index_1]).as_long()
  index_2 = (m[atom_index_2]).as_long()

print(res)
print("SOLUTION:")
if index_1 != -1 and index_2 != -1:
  print(sorted_atom_events[index_1])
  print(sorted_atom_events[index_2])
else:
  ""