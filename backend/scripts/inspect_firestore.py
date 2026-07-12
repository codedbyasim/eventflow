import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import dotenv
dotenv.load_dotenv()

from app.auth import get_firestore_client, _get_firebase_app

def main():
    _get_firebase_app()
    db = get_firestore_client()
    
    print("--- FIRESTORE EVENTS ---")
    events = db.collection("events").stream()
    for e in events:
        data = e.to_dict()
        print(f"ID: {e.id}, Status: {data.get('status')}, Type: {data.get('type')}, City: {data.get('city')}, Budget: {data.get('totalBudget')}")
        
    print("\n--- FIRESTORE NEGOTIATIONS ---")
    negs = db.collection("negotiations").stream()
    for n in negs:
        data = n.to_dict()
        print(f"ID: {n.id}, EventFirestoreID: {data.get('eventFirestoreId')}, Category: {data.get('category')}, Status: {data.get('status')}, VendorName: {data.get('vendorName')}")

if __name__ == "__main__":
    main()
