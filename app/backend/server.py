from fastapi import FastAPI, APIRouter
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
import os
import logging
from pathlib import Path
from pydantic import BaseModel, Field, ConfigDict
from typing import List
import uuid
from datetime import datetime, timezone

# Configure logging early so startup errors are visible
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

# Read env vars safely and validate
mongo_url = os.getenv("MONGO_URL")
db_name = os.getenv("DB_NAME")
if not mongo_url or not db_name:
    logger.error("MONGO_URL and DB_NAME must be set in environment")
    raise RuntimeError("MONGO_URL and DB_NAME must be set in environment")

# Create client and database handle (do not block on ping at import time)
client = AsyncIOMotorClient(mongo_url)
db = client[db_name]

# Create the main app without a prefix
app = FastAPI()

# Create a router with the /api prefix
api_router = APIRouter(prefix="/api")


# Define Models
class StatusCheck(BaseModel):
    model_config = ConfigDict(extra="ignore")  # Ignore MongoDB's _id field

    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    client_name: str
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class StatusCheckCreate(BaseModel):
    client_name: str


# Startup event: verify DB connectivity
@app.on_event("startup")
async def startup_db_client():
    try:
        # Ping the server to verify connectivity
        await client.admin.command("ping")
        logger.info("Successfully connected to MongoDB")
    except Exception as e:
        logger.exception("Failed to connect to MongoDB on startup: %s", e)
        raise


# Add your routes to the router instead of directly to app
@api_router.get("/")
async def root():
    return {"message": "Hello World"}


@api_router.post("/status", response_model=StatusCheck)
async def create_status_check(input: StatusCheckCreate):
    status_dict = input.model_dump()
    status_obj = StatusCheck(**status_dict)

    # Convert to dict. Leave timestamp as a datetime so Motor stores it as a BSON datetime.
    doc = status_obj.model_dump()

    # Insert into MongoDB (Motor will encode datetimes as BSON datetimes)
    await db.status_checks.insert_one(doc)
    return status_obj


@api_router.get("/status", response_model=List[StatusCheck])
async def get_status_checks():
    # Exclude MongoDB's _id field from the query results
    status_checks = await db.status_checks.find({}, {"_id": 0}).to_list(1000)

    # Convert ISO string timestamps back to datetime objects if any legacy docs exist
    for check in status_checks:
        ts = check.get("timestamp")
        if isinstance(ts, str):
            try:
                check["timestamp"] = datetime.fromisoformat(ts)
            except Exception:
                # If parsing fails, leave it as-is and log
                logger.warning("Failed to parse timestamp for check id=%s", check.get("id"))
    return status_checks


# Include the router in the main app
app.include_router(api_router)

# Configure CORS using a robust parser for CORS_ORIGINS
cors_raw = os.getenv("CORS_ORIGINS", "*")
allow_origins = [o.strip() for o in cors_raw.split(",") if o.strip()]
if allow_origins == ["*"]:
    allow_origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=allow_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()
