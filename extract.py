import json

with open('C:/Users/lauri/.gemini/antigravity-ide/brain/156e4b6b-2e27-4d01-bf54-e48a74b5f985/.system_generated/logs/transcript.jsonl', encoding='utf-8') as f:
    lines = [json.loads(line) for line in f]

with open('full_user_inputs.txt', 'w', encoding='utf-8') as f:
    f.write('\n'.join([l['content'] for l in lines if l.get('type') == 'USER_INPUT' and 'content' in l]))
