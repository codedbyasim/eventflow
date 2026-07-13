"""Debug Firestore negotiations query."""
import asyncio
from app.auth import get_firestore_client

async def main():
    db = get_firestore_client()
    
    # Get first event
    events = db.collection('events').limit(1).get()
    if not events:
        print("❌ No events found")
        return
    
    event_doc = events[0]
    event_id = event_doc.id
    event_data = event_doc.to_dict()
    
    print(f"✅ Found event: {event_id}")
    print(f"   Status: {event_data.get('status')}")
    print()
    
    # Query negotiations by eventFirestoreId
    print(f"🔍 Querying negotiations where eventFirestoreId == {event_id}")
    negs = db.collection('negotiations').where('eventFirestoreId', '==', event_id).get()
    
    if not negs:
        print("❌ No negotiations found for this event!")
        print("\n🔍 Checking all negotiations to debug:")
        all_negs = db.collection('negotiations').limit(5).get()
        for neg_doc in all_negs:
            neg_data = neg_doc.to_dict()
            print(f"   Negotiation {neg_doc.id}:")
            print(f"     eventFirestoreId: {neg_data.get('eventFirestoreId')}")
            print(f"     vendorName: {neg_data.get('vendorName')}")
            print(f"     status: {neg_data.get('status')}")
        return
    
    print(f"✅ {len(negs)} negotiations found:")
    for neg_doc in negs:
        neg_data = neg_doc.to_dict()
        print(f"   {neg_doc.id}:")
        print(f"     Vendor: {neg_data.get('vendorName')} ({neg_data.get('category')})")
        print(f"     Status: {neg_data.get('status')}")
        print(f"     Asking: PKR {neg_data.get('askingPrice'):,}")
        print(f"     Current: PKR {neg_data.get('currentOffer'):,}")

if __name__ == "__main__":
    asyncio.run(main())
