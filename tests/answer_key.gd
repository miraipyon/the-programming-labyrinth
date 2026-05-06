extends Node

# Cheat sheet nhanh để test thủ công.
# Các đáp án bên dưới phản ánh data/bugs.json, line index là zero-based.

# Chapter 1 - Syntax
# ch1_syntax_001
# line 1:   'name': 'Hero' |   'name': 'Hero',
# line 2:   'hp': 100 |   'hp': 100,
#
# ch1_syntax_002
# line 0: is_ready = True
# line 1: items = ['potion', 'sword']
#
# ch1_syntax_003
# line 0: job = 'Mage'
# line 2: print('Class: ' + job + ', Level: ' + str(level))
#
# ch1_syntax_004
# line 0: def calc_damage(atk, defense):
# line 2:     return dmg
#
# ch1_syntax_005
# line 0: matrix = [[1, 2], [3, 4]]
# line 1: if matrix[0][0] > 0:

# Chapter 2 - Logic
# ch2_logic_001
# line 2: if hp == 0: | if hp <= 0:
# line 4: elif hp < 50:
#
# ch2_logic_002
# line 4: if has_key or (is_vip and level >= 10): | if has_key or is_vip and level >= 10:
#
# ch2_logic_003
# line 4: total = int(base_dmg) + bonus * multiplier
#
# ch2_logic_004
# line 4: elif score >= 70:
#
# ch2_logic_005
# line 3: hp = hp - 5 if state == 'poisoned' else hp + 5

# Chapter 3 - Runtime
# ch3_runtime_001
# line 1: i = 0
# line 2: while i < len(items):
#
# ch3_runtime_002
# line 1: for i in range(len(enemies)-1, -1, -1):
#
# ch3_runtime_003
# line 4:     energy -= 10
#
# ch3_runtime_004
# line 3:     for j in range(len(grid[i])):
#
# ch3_runtime_005
# line 2: for i in range(len(chars) - 1, -1, -1):

# Chapter 4 - Block assembly
# ch4_flow_001: correct_order = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
# ch4_flow_002: correct_order = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
# ch4_flow_003: correct_order = [0, 1, 2, 3, 4, 5, 6, 7, 8]
# ch4_flow_004: correct_order = [0, 1, 2, 3, 4, 5, 6]
# ch4_flow_005: correct_order = [0, 1, 2, 3, 4, 5, 6]
