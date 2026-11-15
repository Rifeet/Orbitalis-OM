import os

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./astrovitals.db")
CORS_ORIGINS = [
    o.strip()
    for o in os.getenv(
        "CORS_ORIGINS", "http://localhost:3000,http://localhost:5173"
    ).split(",")
    if o.strip()
]
