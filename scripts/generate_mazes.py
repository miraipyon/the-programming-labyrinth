import json
import random
import math

def generate_perfect_maze(width_tiles, height_tiles):
    if width_tiles % 2 == 0: width_tiles += 1
    if height_tiles % 2 == 0: height_tiles += 1
    
    maze = [[1 for _ in range(width_tiles)] for _ in range(height_tiles)]
    
    def carve(r, c):
        maze[r][c] = 0
        directions = [(0, 2), (2, 0), (0, -2), (-2, 0)]
        random.shuffle(directions)
        for dr, dc in directions:
            nr, nc = r + dr, c + dc
            if 1 <= nr < height_tiles - 1 and 1 <= nc < width_tiles - 1 and maze[nr][nc] == 1:
                maze[r + dr//2][c + dc//2] = 0
                carve(nr, nc)
    
    carve(1, 1)
    return maze

def extract_walls(maze, width_tiles, height_tiles, TS):
    walls = []
    visited = [[False] * width_tiles for _ in range(height_tiles)]
    for r in range(height_tiles):
        for c in range(width_tiles):
            if maze[r][c] == 1 and not visited[r][c]:
                l = 1
                while c + l < width_tiles and maze[r][c+l] == 1 and not visited[r][c+l]:
                    l += 1
                
                for i in range(l):
                    visited[r][c+i] = True
                    
                w = l * TS
                h = TS
                cx = (c * TS) + (w / 2.0)
                cy = (r * TS) + (h / 2.0)
                walls.append({
                    "position": {"x": int(cx), "y": int(cy)},
                    "size": {"x": int(w), "y": int(h)}
                })
    return walls

def get_distances(maze, start_r, start_c):
    queue = [(start_r, start_c)]
    distances = {(start_r, start_c): 0}
    
    while queue:
        r, c = queue.pop(0)
        d = distances[(r, c)]
        
        for dr, dc in [(1,0), (-1,0), (0,1), (0,-1)]:
            nr, nc = r + dr, c + dc
            if maze[nr][nc] == 0 and (nr, nc) not in distances:
                distances[(nr, nc)] = d + 1
                queue.append((nr, nc))
                
    return distances

def get_dead_ends(maze):
    dead_ends = []
    for r in range(1, len(maze)-1):
        for c in range(1, len(maze[0])-1):
            if maze[r][c] == 0:
                neighbors = 0
                if maze[r-1][c] == 0: neighbors += 1
                if maze[r+1][c] == 0: neighbors += 1
                if maze[r][c-1] == 0: neighbors += 1
                if maze[r][c+1] == 0: neighbors += 1
                if neighbors == 1:
                    dead_ends.append((r, c))
    return dead_ends

def main():
    random.seed(999) # Fixed seed for reproducible perfect mazes
    TS = 64
    
    with open('data/stages.json', 'r', encoding='utf-8') as f:
        stages = json.load(f)
        
    enemies_by_ch = {
        1: ["syntax_slime", "semicolon_wisp"],
        2: ["branch_phantom", "null_shadow", "type_mismatch_medusa"],
        3: ["infinite_golem", "boundary_hydra"],
        4: ["flow_architect", "logic_bomb_boss"]
    }
    
    for stage in stages:
        ch = stage.get("chapter", 1)
        
        if ch == 1:
            wt, ht = 19, 19
        elif ch == 2:
            wt, ht = 25, 25
        elif ch == 3:
            wt, ht = 31, 31
        else:
            wt, ht = 39, 39
            
        maze = generate_perfect_maze(wt, ht)
        
        # Pick player spawn (random corner)
        corners = [(1, 1), (1, wt-2), (ht-2, 1), (ht-2, wt-2)]
        random.shuffle(corners)
        player_t = None
        for r, c in corners:
            if maze[r][c] == 0:
                player_t = (r, c)
                break
        if player_t is None: player_t = (1, 1)
        
        distances = get_distances(maze, player_t[0], player_t[1])
        
        # Find farthest point for portal
        portal_t = max(distances.items(), key=lambda x: x[1])[0]
        
        # Place chests in dead ends
        dead_ends = get_dead_ends(maze)
        if player_t in dead_ends: dead_ends.remove(player_t)
        if portal_t in dead_ends: dead_ends.remove(portal_t)
        
        # Sort dead ends by distance to player (descending)
        dead_ends.sort(key=lambda t: distances.get(t, 0), reverse=True)
        
        chest_spawns = []
        num_chests = random.randint(3, 5)
        placed_chests = set()
        
        for i in range(min(num_chests, len(dead_ends))):
            t = dead_ends[i]
            ctype = "rare" if random.random() < 0.35 else "normal"
            chest_spawns.append({
                "type": ctype,
                "position": {"x": t[1] * TS + TS//2, "y": t[0] * TS + TS//2}
            })
            placed_chests.add(t)
            
        # Place enemies using greedy max-min distance to spread them out
        available_for_enemies = [
            t for t in distances.keys()
            if t != player_t and t != portal_t and t not in placed_chests
            and distances[t] > (wt + ht) // 3 # Away from player
        ]
        
        enemy_tiles = []
        encounters = stage.get("encounters", [])
        num_enemies = len(encounters)
        
        if len(available_for_enemies) >= num_enemies:
            # Pick first enemy near the middle distance to start the spread
            first = random.choice(available_for_enemies)
            enemy_tiles.append(first)
            available_for_enemies.remove(first)
            
            for _ in range(num_enemies - 1):
                best_t = None
                max_min_dist = -1
                for t in available_for_enemies:
                    min_dist = min(math.dist(t, et) for et in enemy_tiles)
                    if min_dist > max_min_dist:
                        max_min_dist = min_dist
                        best_t = t
                if best_t:
                    enemy_tiles.append(best_t)
                    available_for_enemies.remove(best_t)
        else:
            # Fallback if too small
            enemy_tiles = random.sample([t for t in distances.keys() if t != player_t and t != portal_t], num_enemies)
            
        enemy_spawns = []
        for i, enc in enumerate(encounters):
            t = enemy_tiles[i]
            enemy_id = random.choice(enemies_by_ch.get(ch, ["syntax_slime"]))
            enemy_spawns.append({
                "enemy_id": enemy_id,
                "bug_id": enc,
                "position": {"x": t[1] * TS + TS//2, "y": t[0] * TS + TS//2}
            })
            
        stage["bounds"] = {"width": wt * TS, "height": ht * TS}
        stage["wall_spawns"] = extract_walls(maze, wt, ht, TS)
        stage["obstacle_spawns"] = []
        stage["player_spawn"] = {"x": player_t[1] * TS + TS//2, "y": player_t[0] * TS + TS//2}
        stage["portal_position"] = {"x": portal_t[1] * TS + TS//2, "y": portal_t[0] * TS + TS//2}
        stage["enemy_spawns"] = enemy_spawns
        stage["chest_spawns"] = chest_spawns

    with open('data/stages.json', 'w', encoding='utf-8') as f:
        json.dump(stages, f, indent=4, ensure_ascii=False)
        
if __name__ == "__main__":
    main()
