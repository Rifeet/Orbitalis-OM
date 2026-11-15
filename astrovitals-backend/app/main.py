from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import CORS_ORIGINS
from .database import Base, SessionLocal, engine
from .routers import anomalies, entries, profiles, readings
from .rules_loader import load_rules, rules_loaded


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(engine)
    with SessionLocal() as db:
        if not rules_loaded(db):   # first start: fill the rule tables from rules_data.json
            load_rules(db)
    yield


app = FastAPI(title="AstroVitals API", version="0.3.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(profiles.router)
app.include_router(readings.router)
app.include_router(entries.router)
app.include_router(anomalies.router)


@app.get("/health", tags=["meta"])
def health():
    with SessionLocal() as db:
        return {"status": "ok", "rules_loaded": rules_loaded(db)}
