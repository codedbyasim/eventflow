import asyncio
import sys
import time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import dotenv
dotenv.load_dotenv()

from app.agents.fireworks_client import call_fireworks
from app.agents.prompts import NEGOTIATION_TOOLS

async def main():
    print("Testing Fireworks AI API connection with negotiation tools...")
    messages = [
        {"role": "system", "content": "You are a helpful assistant negotiating prices."},
        {"role": "user", "content": "The vendor is offering 100,000 PKR. Offer a counter price."}
    ]
    start = time.time()
    try:
        result = await call_fireworks(
            messages=messages,
            tools=NEGOTIATION_TOOLS,
            agent_type="negotiation",
            event_id=None,
            max_tokens=4096
        )
        latency = time.time() - start
        print(f"[SUCCESS] Fireworks AI API responded in {latency:.2f} seconds!")
        print(f"Response: {result}")
    except Exception as e:
        print(f"[ERROR] Fireworks AI call failed: {e}")

if __name__ == "__main__":
    asyncio.run(main())
