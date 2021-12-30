import pickle 
from z3 import * 
from bitstring import BitArray 
import sys 

option = int(sys.argv[1])
run_id = sys.argv[2]
shortest_length = int(sys.argv[3])

# dictionary of event strings to their observed bit-vectors
event_vector_dict = pickle.load(open('./event_vector_dict_'+ run_id + '.pkl', 'rb')) # {"up" : [1,0,0,1], "down" : [1, 1, 1, 0], "right" : {1 : [0, 1, 1, 1], 2 : [1, 1, 1, 0]}}

# dictionary of object_id's to their observed vectors (-1/0/1)
observed_data_dict = pickle.load(open('./observed_data_dict_'+ run_id + '.pkl', 'rb')) # {1 : [1, 0, 0, 0], 2 : [1, 0, 0, 0]}  

# sorted list of object_id's
object_ids = sorted(list(observed_data_dict.keys()))
# print("OBJECT IDS")
# print(object_ids)

ambig_positions_dict = {} # dictionary of object_id's to the -1 positions in observed_data_dict
observed_bv_dict = {} # dictionary of object_id's to observed_data_dict[object_id] value with -1's removed
observed_bv_vals_dict = {} # dictionary of object_id's to int value of bit vector in observed_data_dict[object_id] 
for object_id in object_ids:
  ambig_positions_dict[object_id] = [i for i, x in enumerate(observed_data_dict[object_id]) if x == -1]
  observed_bv_dict[object_id] = list(filter(lambda x: x != -1, observed_data_dict[object_id]))
  if len(observed_bv_dict[object_id]) != 0:
    observed_bv_vals_dict[object_id] = BitArray(observed_bv_dict[object_id]).uint

# remove empty lists from observed_bv_dict, and remove corresponding ids from object_ids 
empty_ids = set(filter(lambda k: len(observed_bv_dict[k]) == 0, list(observed_bv_dict.keys())))
for id in empty_ids:
  del observed_bv_dict[id]
  del ambig_positions_dict[id]
object_ids = sorted(list(filter(lambda id: id not in empty_ids, object_ids)))


atom_dict = {} # dictionary of events to event values with ambig positions filtered out
for event in event_vector_dict:

  event_values = event_vector_dict[event]
  # print(event_values)
  filtered_event_values = {}
  if isinstance(event_values, list):
    # print("HERE 1")
    for object_id in object_ids:
      filtered_event_values[object_id] = list(map(lambda i: event_values[i], list(filter(lambda pos: pos not in ambig_positions_dict[object_id], list(range(len(observed_data_dict[object_id])))))))
    atom_dict[event] = filtered_event_values
  elif set(object_ids).issubset(event_values.keys()): # set(event_values.keys()) == set(object_ids):
    # print("HERE 2")
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

# [new] construct Z3 array of atom event lengths; used for iterating to find the shortest event  
z3_atom_lengths = Array("atom_lengths", IntSort(), IntSort())
for atom_index in range(len(sorted_atom_events)):
  z3_atom_lengths = Store(z3_atom_lengths, atom_index, len(sorted_atom_events[atom_index]))

atom_index_1 = Int("atom_index_1")
atom_index_2 = Int("atom_index_2")
atom_index_3 = Int("atom_index_3")
atom_index_4 = Int("atom_index_4")

s = Solver()
s.add(atom_index_1 >= 0)
s.add(atom_index_1 < len(list(atom_dict.keys())))

s.add(atom_index_2 >= 0)
s.add(atom_index_2 < len(list(atom_dict.keys())))

s.add(atom_index_3 >= 0)
s.add(atom_index_3 < len(list(atom_dict.keys())))

s.add(atom_index_4 >= 0)
s.add(atom_index_4 < len(list(atom_dict.keys())))

for i in range(len(object_ids)):
  # single_sol = Select(z3_atoms[i], atom_index_1) == BitVecVal(observed_bv_vals_dict[object_ids[i]], len(observed_bv_dict[object_ids[i]]))
  w = Select(z3_atoms[i], atom_index_1) 
  x = Select(z3_atoms[i], atom_index_2)
  y = Select(z3_atoms[i], atom_index_3)
  z = Select(z3_atoms[i], atom_index_4)
  matching_value = BitVecVal(observed_bv_vals_dict[object_ids[i]], len(observed_bv_dict[object_ids[i]]))
  x_and_y = x & y == matching_value # 1 
  x_or_y = x | y == matching_value # 2
  x_and_y_and_z = x & y & z == matching_value # 3
  x_and_y_or_z = x & y | z == matching_value # 4
  x_or_y_or_z = x | y | z == matching_value # 5 
  w_and_x_and_y_and_z = w & x & y & z == matching_value # 6
  w_and_x_and_y_or_z = w & x & y | z == matching_value # 7
  w_and_x_or_y_or_z = w & x | y | z == matching_value # 8
  w_and_x_or_y_and_z = w & x | y & z == matching_value # 9
  w_or_x_or_y_or_z = w | x | y | z == matching_value # 10

  parens_1 = x & (y | z) == matching_value # 11
  parens_2 = w & x & (y | z) == matching_value # 12
  parens_3 = w & (x | y | z) == matching_value # 13
  parens_4 = w & (x | y & z) == matching_value # 14

  if option == 1:
    s.add(x_and_y)
  elif option == 2:
    s.add(x_or_y)
  elif option == 3:
    s.add(x_and_y_and_z)
  elif option == 4:
    s.add(x_and_y_or_z)
  elif option == 5:
    s.add(x_or_y_or_z)
  elif option == 6:
    s.add(w_and_x_and_y_and_z)
  elif option == 7:
    s.add(w_and_x_and_y_or_z)
  elif option == 8:
    s.add(w_and_x_or_y_or_z)
  elif option == 9:
    s.add(w_and_x_or_y_and_z)
  elif option == 10:
    s.add(w_or_x_or_y_or_z)
  elif option == 11:
    s.add(parens_1)
  elif option == 12:
    s.add(parens_2)
  elif option == 13:
    s.add(parens_3)
  elif option == 14:
    s.add(parens_4)

# search for event with length less than shortest_length
if shortest_length != 0:
  w_len = Select(z3_atom_lengths, atom_index_1) 
  x_len = Select(z3_atom_lengths, atom_index_2)
  y_len = Select(z3_atom_lengths, atom_index_3)
  z_len = Select(z3_atom_lengths, atom_index_4)

  xy_len = x_len + y_len < shortest_length 
  xyz_len = x_len + y_len + z_len < shortest_length 
  wxyz_len = w_len + x_len + y_len + z_len < shortest_length 

  if option in [1, 2]:
    s.add(xy_len)
  elif option in [3, 4, 5, 11]:
    s.add(xyz_len)
  elif option in [6, 7, 8, 9, 10, 12, 13, 14]:
    s.add(wxyz_len)

res = s.check()
index_1 = -1
index_2 = -1
index_3 = -1
index_4 = -1
if res == sat:
  m = s.model()
  index_1 = (m[atom_index_1]).as_long()
  index_2 = (m[atom_index_2]).as_long()
  index_3 = (m[atom_index_3]).as_long()
  index_4 = (m[atom_index_4]).as_long()

print(res)
print("SOLUTION:")
if index_1 != -1 and index_2 != -1 and index_3 != -1 and index_4 != -1:
  if option in [1, 2]:
    print(sorted_atom_events[index_2])
    print(sorted_atom_events[index_3])
  elif option in [3, 4, 5, 11]:
    print(sorted_atom_events[index_2])
    print(sorted_atom_events[index_3])
    print(sorted_atom_events[index_4])
  elif option in [6, 7, 8, 9, 10, 12, 13, 14]:
    print(sorted_atom_events[index_1])
    print(sorted_atom_events[index_2])
    print(sorted_atom_events[index_3])
    print(sorted_atom_events[index_4])