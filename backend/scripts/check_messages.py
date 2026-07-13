"""Quick script to check if Firestore messages are being written."""
import asyncio
from app.auth import get_firestore_client

async def main():
    db = get_firestore_client()
    
    # Get first negotiation
    negs = db.collection('negotiations').limit(1).get()
    if not negs:
        print("❌ No negotiations found in Firestore")
        return
    
    neg_doc = negs[0]
    neg_id = neg_doc.id
    neg_data = neg_doc.to_dict()
    
    print(f"✅ Found negotiation: {neg_id}")
    print(f"   Status: {neg_data.get('status')}")
    print(f"   Vendor: {neg_data.get('vendorName')}")
    print(f"   Asking: PKR {neg_data.get('askingPrice'):,}")
    print(f"   Current Offer: PKR {neg_data.get('currentOffer'):,}")
    print()
    
    # Check messages subcollection
    messages = neg_doc.reference.collection('messages').get()
    if not messages:
        print("❌ No messages in subcollection — Agent hasn't sent first offer yet!")
        print("   Check backend logs for errors")
        return
    
    print(f"✅ {len(messages)} messages found:")
    for msg in messages:
        data = msg.to_dict()
        sender = data.get('sender', 'unknown')
        content = data.get('content', '')[:50]
        offer = data.get('offerAmount')
        print(f"   [{sender}] {content}... {f'PKR {offer:,}' if offer else ''}")

if __name__ == "__main__":
    asyncio.run(main())
