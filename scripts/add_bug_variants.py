import json
import random

def create_variant(bug, v_idx):
    variant = json.loads(json.dumps(bug))
    variant['id'] = f"{bug['id']}_v{v_idx}"
    
    # Randomize names to make them look different
    replacements = {
        "player": ["hero", "warrior", "knight", "mage", "archer"],
        "hp": ["health", "vitality", "life", "points"],
        "enemy": ["monster", "slime", "orc", "dragon"],
        "items": ["inventory", "bag", "loot", "storage"],
        "level": ["rank", "stage", "tier"],
        "score": ["points", "value", "result"]
    }
    
    def apply_replacements(text):
        if not isinstance(text, str): return text
        for old, news in replacements.items():
            if old in text:
                new_val = news[v_idx % len(news)]
                text = text.replace(old, new_val)
        return text

    if 'snippet' in variant:
        variant['snippet'] = [apply_replacements(s) for s in variant['snippet']]
    if 'blocks' in variant:
        variant['blocks'] = [apply_replacements(b) for b in variant['blocks']]
    if 'bugs' in variant:
        for b in variant['bugs']:
            b['wrong_code'] = apply_replacements(b['wrong_code'])
            b['accepted_fixes'] = [apply_replacements(f) for f in b['accepted_fixes']]
            b['distractors'] = [apply_replacements(d) for d in b['distractors']]
    
    variant['goal'] = apply_replacements(variant['goal'])
    variant['explanation'] = apply_replacements(variant['explanation'])
    
    return variant

def main():
    with open('data/bugs.json', 'r', encoding='utf-8') as f:
        bugs = json.load(f)
        
    new_bugs = []
    for bug in bugs:
        base_id = bug['id']
        # Don't create variants of variants
        if "_v" in base_id:
            new_bugs.append(bug)
            continue
            
        for i in range(1, 6):
            new_bugs.append(create_variant(bug, i))
            
    with open('data/bugs.json', 'w', encoding='utf-8') as f:
        json.dump(new_bugs, f, indent=2, ensure_ascii=False)

if __name__ == "__main__":
    main()
