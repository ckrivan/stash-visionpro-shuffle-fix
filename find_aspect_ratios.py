#!/usr/bin/env python3
import requests
import json

# Stash API configuration
STASH_URL = "http://192.168.86.100:9999/graphql"
API_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo"

headers = {
    "Content-Type": "application/json",
    "ApiKey": API_KEY,
    "Authorization": f"Bearer {API_KEY}"
}

query = """
query {
  findScenes(filter: {page: 1, per_page: 500}) {
    count
    scenes {
      id
      title
      files {
        width
        height
      }
    }
  }
}
"""

response = requests.post(STASH_URL, json={"query": query}, headers=headers)
print(f"Status: {response.status_code}")
print(f"Response: {response.text[:500]}")
data = response.json()

scenes = data['data']['findScenes']['scenes']

# Find non-16:9 videos
non_standard = []
for scene in scenes:
    if scene['files']:
        f = scene['files'][0]
        if f.get('width') and f.get('height'):
            ratio = f['width'] / f['height']
            # 16:9 is ~1.778
            if abs(ratio - 1.778) > 0.1:  # Not 16:9
                non_standard.append({
                    'id': scene['id'],
                    'title': scene['title'],
                    'width': f['width'],
                    'height': f['height'],
                    'ratio': round(ratio, 3)
                })

# Sort by aspect ratio
non_standard.sort(key=lambda x: x['ratio'])

print(f'Found {len(non_standard)} videos with non-16:9 aspect ratios:\n')
print(f'{"Title":<60} | {"Resolution":<12} | {"Ratio":<6} | {"ID":<10}')
print("-" * 95)
for s in non_standard[:30]:  # Show first 30
    title = s['title'][:56] + '...' if len(s['title']) > 56 else s['title']
    print(f'{title:<60} | {s["width"]}x{s["height"]:<10} | {s["ratio"]:<6} | {s["id"]}')
