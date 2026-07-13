"""Test Firestore query to debug why customer sees no cards."""
import asyncio
from app.auth import get_firestore_client

async def main():
    db = get_firestore_client()
    
    print("=" * 60)
    print("STEP 1: Check if any events exist")
    print("=" * 60)
    
    events = db.collection('events').limit(5).get()
    if not events:
        print("❌ NO EVENTS FOUND IN FIRESTORE!")
        print("   Backend might not be creating events properly.")
        return
    
    print(f"✅ Found {len(events)} events:\n")
    for event_doc in events:
        event_id = event_doc.id
        event_data = event_doc.to_dict()
        print(f"Event ID: {event_id}")
        print(f"  Status: {event_data.get('status')}")
        print(f"  Type: {event_data.get('type')}")
        print(f"  City: {event_data.get('city')}")
        print()
        
        # Check negotiations for this event
        print(f"  🔍 Querying negotiations for event: {event_id}")
        negs = db.collection('negotiations').where('eventFirestoreId', '==', event_id).get()
        
        if not negs:
            print(f"  ❌ NO NEGOTIATIONS FOUND for this event!")
            print(f"     This is why customer sees no cards!")
            print(f"     Check backend orchestrator logs.")
            
            # Check all negotiations to see what's there
            print(f"\n  🔍 Checking ALL negotiations (any eventFirestoreId):")
            all_negs = db.collection('negotiations').limit(5).get()
            if not all_negs:
                print(f"     ❌ NO NEGOTIATIONS AT ALL in Firestore!")
                print(f"        Backend negotiation_orchestrator not creating them.")
            else:
                print(f"     ✅ {len(all_negs)} negotiations exist (but not for this event):")
                for neg_doc in all_negs:
                    neg_data = neg_doc.to_dict()
                    print(f"        - {neg_doc.id}")
                    print(f"          eventFirestoreId: {neg_data.get('eventFirestoreId')}")
                    print(f"          vendorName: {neg_data.get('vendorName')}")
                    print(f"          status: {neg_data.get('status')}")
        else:
            print(f"  ✅ {len(negs)} negotiations found:")
            for neg_doc in negs:
                neg_data = neg_doc.to_dict()
                print(f"     - {neg_doc.id}")
                print(f"       Vendor: {neg_data.get('vendorName')}")
                print(f"       Status: {neg_data.get('status')}")
                print(f"       Asking: PKR {neg_data.get('askingPrice'):,}")
                print(f"       Current: PKR {neg_data.get('currentOffer'):,}")
        
        print()
        print("-" * 60)

if __name__ == "__main__":
    asyncio.run(main())
