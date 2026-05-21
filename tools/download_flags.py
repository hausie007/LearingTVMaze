#!/usr/bin/env python3
import os
import urllib.request
import ssl

# Disable SSL verification for python urllib
ssl._create_default_https_context = ssl._create_unverified_context

# Directory for flag assets
TARGET_DIR = "/Users/michalhauzirek/Documents/Bludiste/assets/flags"
os.makedirs(TARGET_DIR, exist_ok=True)

# Language code to country code mapping
FLAG_MAP = {
    "us": "us",
    "gb": "gb",
    "br": "br",
    "pt": "pt",
    "mx": "mx",
    "es": "es",
    "fr": "fr",
    "de": "de",
    "it": "it",
    "cz": "cz",
    "pl": "pl",
    "ua": "ua",
    "nl": "nl",
    "tr": "tr",
    "ro": "ro",
    "hu": "hu",
    "gr": "gr",
    "se": "se",
    "dk": "dk",
    "fi": "fi",
    "no": "no",
    "sk": "sk",
    "il": "il",
    "vn": "vn"
}

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3'
}

print("Starting flag downloads...")
for lang, cc in FLAG_MAP.items():
    url = f"https://flagcdn.com/w160/{cc}.png"
    target_path = os.path.join(TARGET_DIR, f"{lang}.png")
    
    print(f"Downloading {lang} flag from {url}...")
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req) as response:
            with open(target_path, 'wb') as f:
                f.write(response.read())
        print(f"Successfully saved to {target_path}")
    except Exception as e:
        print(f"Error downloading {lang} flag: {e}")

print("All downloads finished.")
