import os
import tempfile

# Must be set BEFORE the app is imported so everything uses a throwaway database.
_tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
os.environ["DATABASE_URL"] = f"sqlite:///{_tmp.name}"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.database import Base, SessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.rules_loader import load_rules  # noqa: E402


@pytest.fixture()
def db():
    """Fresh tables with the rules loaded."""
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    with SessionLocal() as session:
        load_rules(session)
        yield session


@pytest.fixture()
def client(db):
    with TestClient(app) as c:
        yield c
