import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import dotenv
dotenv.load_dotenv()

from app.auth import _get_firebase_app
from firebase_admin import auth

def main():
    _get_firebase_app()
    email = "asim@gmail.com"
    try:
        user = auth.get_user_by_email(email)
        print(f"User exists! UID: {user.uid}, Email: {user.email}")
    except auth.UserNotFoundError:
        print("User does not exist in Firebase Auth!")
    except Exception as e:
        print(f"Error checking user: {e}")

if __name__ == "__main__":
    main()
