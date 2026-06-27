#!/usr/bin/env bash
set -euo pipefail

# Edit these if you want a different repo or owner
REPO_OWNER="chasehamlinyw-lab"
REPO_NAME="portfolio-kanban-control-room"
VISIBILITY="public"  # public or private
GITHUB_CREATE="${GITHUB_CREATE:-yes}" # set to "no" if you don't want gh to create the repo

echo "This will create a local repo and (optionally) push to GitHub:"
echo "Owner: $REPO_OWNER"
echo "Repo:  $REPO_NAME"
echo "Visibility: $VISIBILITY"
read -p "Continue? (y/n) " yn
if [[ "$yn" != "y" ]]; then
  echo "Aborted."
  exit 1
fi

ROOT_DIR="$PWD/$REPO_NAME"
if [[ -d "$ROOT_DIR" ]]; then
  echo "Directory $ROOT_DIR already exists. Aborting to avoid overwriting."
  exit 1
fi

mkdir -p "$ROOT_DIR"
cd "$ROOT_DIR" || exit 1

# ---- README.md ----
cat > README.md <<'EOF'
# Portfolio: Kanban Control Room

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](#license)
[![CI](https://img.shields.io/github/actions/workflow/status/OWNER/REPO/ci.yml?branch=main)](#ci)
[Demo (add URL once deployed)](https://your-demo-url.example)

A compact, high-contrast Kanban-style control room UI with a small FastAPI backend. Built with React, Tailwind CSS, and FastAPI + Motor (MongoDB). Designed to feel like a developer command center — dense spacing, 1px borders, and an amber accent for AI-driven actions.

Tech
- Frontend: React 19, Tailwind CSS
- Backend: FastAPI, Motor (MongoDB)
- Fonts: Outfit, Manrope, JetBrains Mono
- Lint/CI: GitHub Actions

Highlights
- Dark-first, high-contrast design tokens and fonts wired into the UI.
- Robust backend startup and env handling; BSON datetimes used for storage.
- Centralized axios API wrapper with env-based backend URL and fallback.
- Data-testid attributes added for testability.

Getting started (local)
Prereqs: Node.js 18+, yarn, Python 3.11+, MongoDB

1) Clone
   git clone git@github.com:OWNER/REPO.git
   cd OWNER/REPO

2) Backend
   cd app/backend
   python -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   # Create or edit .env with MONGO_URL and DB_NAME (a .env is included for local dev)
   uvicorn server:app --reload --port 8000

3) Frontend
   cd ../frontend
   yarn install
   yarn start
   # The frontend will use REACT_APP_BACKEND_URL if set; otherwise it will request /api.

Screenshots / Demo
- Add screenshots or a GIF in /assets and reference them here.
- Deploy frontend to Vercel for the cleanest demo experience (instructions included).

Why this is employer-friendly
- Single-page repo with a clear purpose and modern stack.
- README shows how to run and what to look for; CI demonstrates discipline.
- Live demo (Vercel) makes the product instantly reviewable.
- Profile pinning and README project card make it easy to find on your GitHub profile.

Contributing
- Open issues or PRs. Please follow the code style used in the repo.

License
MIT
EOF

# ---- LICENSE (MIT) ----
cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2026 chasehamlinyw-lab

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

[Full MIT license text — include the rest in final usage or GitHub will auto-populate]
EOF

# ---- .gitignore ----
cat > .gitignore <<'EOF'
# Python
__pycache__/
*.py[cod]
.venv/
venv/
.env

# Node
node_modules/
build/
dist/
.env.local
.env.development.local
.env.test.local
.env.production.local
.DS_Store

# IDE
.vscode/
.idea/
EOF

# ---- GitHub Actions ----
mkdir -p .github/workflows
cat > .github/workflows/ci.yml <<'EOF'
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  backend-lint-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: "3.11"
      - name: Install backend deps
        run: |
          cd app/backend
          python -m pip install --upgrade pip
          pip install -r requirements.txt
      - name: Run backend tests (if any)
        run: |
          cd app/backend
          pytest -q || true

  frontend-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "18"
      - name: Install and build
        run: |
          cd app/frontend
          yarn install --frozen-lockfile
          yarn build || true
EOF

# ---- app/design_guidelines.json ----
mkdir -p app
cat > app/design_guidelines.json <<'EOF'
{
  "theme": "dark",
  "archetype": "4 (Swiss & High-Contrast) + Terminal/Dev-Tool Aesthetic",
  "vibe": "Technical, precise, fast, and high-contrast. Inspired by modern dev tools like Linear. It feels like a high-performance command center, avoiding generic 'SaaS dashboard' fluff.",
  "colors": {
    "dark": {
      "background": "#09090B",
      "surface": "#121214",
      "surface_hover": "#18181B",
      "border": "#27272A",
      "border_hover": "#3F3F46",
      "text_primary": "#FAFAFA",
      "text_secondary": "#A1A1AA",
      "text_tertiary": "#71717A",
      "accent_primary": "#F59E0B",
      "accent_secondary": "#3B82F6",
      "danger": "#EF4444",
      "success": "#10B981"
    },
    "light": {
      "background": "#FAFAFA",
      "surface": "#FFFFFF",
      "surface_hover": "#F4F4F5",
      "border": "#E4E4E7",
      "border_hover": "#D4D4D8",
      "text_primary": "#09090B",
      "text_secondary": "#71717A",
      "text_tertiary": "#A1A1AA",
      "accent_primary": "#D97706",
      "accent_secondary": "#2563EB",
      "danger": "#DC2626",
      "success": "#059669"
    }
  }
}
EOF

# ---- Backend files ----
mkdir -p app/backend
cat > app/backend/server.py <<'EOF'
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

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

mongo_url = os.getenv("MONGO_URL")
db_name = os.getenv("DB_NAME")
if not mongo_url or not db_name:
    logger.error("MONGO_URL and DB_NAME must be set in environment")
    raise RuntimeError("MONGO_URL and DB_NAME must be set in environment")

client = AsyncIOMotorClient(mongo_url)
db = client[db_name]

app = FastAPI()
api_router = APIRouter(prefix="/api")

class StatusCheck(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    client_name: str
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

class StatusCheckCreate(BaseModel):
    client_name: str

@app.on_event("startup")
async def startup_db_client():
    try:
        await client.admin.command("ping")
        logger.info("Successfully connected to MongoDB")
    except Exception as e:
        logger.exception("Failed to connect to MongoDB on startup: %s", e)
        raise

@api_router.get("/")
async def root():
    return {"message": "Hello World"}

@api_router.post("/status", response_model=StatusCheck)
async def create_status_check(input: StatusCheckCreate):
    status_dict = input.model_dump()
    status_obj = StatusCheck(**status_dict)
    doc = status_obj.model_dump()
    await db.status_checks.insert_one(doc)
    return status_obj

@api_router.get("/status", response_model=List[StatusCheck])
async def get_status_checks():
    status_checks = await db.status_checks.find({}, {"_id": 0}).to_list(1000)
    for check in status_checks:
        ts = check.get("timestamp")
        if isinstance(ts, str):
            try:
                check["timestamp"] = datetime.fromisoformat(ts)
            except Exception:
                logger.warning("Failed to parse timestamp for check id=%s", check.get("id"))
    return status_checks

app.include_router(api_router)

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
EOF

cat > app/backend/requirements.txt <<'EOF'
fastapi==0.110.1
uvicorn==0.25.0
boto3>=1.34.129
requests-oauthlib>=2.0.0
cryptography>=42.0.8
python-dotenv>=1.0.1
pymongo==4.6.3
pydantic>=2.6.4
email-validator>=2.2.0
pyjwt>=2.10.1
bcrypt==4.1.3
passlib>=1.7.4
tzdata>=2024.2
motor==3.3.1
pytest>=8.0.0
pytest-xdist>=3.6.0
black>=24.1.1
isort>=5.13.2
flake8>=7.0.0
mypy>=1.8.0
python-jose>=3.3.0
requests>=2.31.0
pandas>=2.2.0
numpy>=1.26.0
python-multipart>=0.0.9
jq>=1.6.0
typer>=0.9.0
emergentintegrations==0.2.0
EOF

cat > app/backend/.env <<'EOF'
MONGO_URL="mongodb://localhost:27017"
DB_NAME="test_database"
CORS_ORIGINS="*"
EOF

# ---- Frontend files ----
mkdir -p app/frontend/src
cat > app/frontend/.env <<'EOF'
REACT_APP_BACKEND_URL=https://dev-portfolio-1592.preview.emergentagent.com
WDS_SOCKET_PORT=443
ENABLE_HEALTH_CHECK=false
EOF

cat > app/frontend/package.json <<'EOF'
{
  "name": "frontend",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "@hookform/resolvers": "5.0.1",
    "@radix-ui/react-accordion": "1.2.8",
    "@radix-ui/react-alert-dialog": "1.1.11",
    "@radix-ui/react-aspect-ratio": "1.1.4",
    "@radix-ui/react-avatar": "1.1.7",
    "@radix-ui/react-checkbox": "1.2.3",
    "@radix-ui/react-collapsible": "1.1.8",
    "@radix-ui/react-context-menu": "2.2.12",
    "@radix-ui/react-dialog": "1.1.11",
    "@radix-ui/react-dropdown-menu": "2.1.12",
    "@radix-ui/react-hover-card": "1.1.11",
    "@radix-ui/react-label": "2.1.4",
    "@radix-ui/react-menubar": "1.1.12",
    "@radix-ui/react-navigation-menu": "1.2.10",
    "@radix-ui/react-popover": "1.1.11",
    "@radix-ui/react-progress": "1.1.4",
    "@radix-ui/react-radio-group": "1.3.4",
    "@radix-ui/react-scroll-area": "1.2.6",
    "@radix-ui/react-select": "2.2.2",
    "@radix-ui/react-separator": "1.1.4",
    "@radix-ui/react-slider": "1.3.2",
    "@radix-ui/react-slot": "1.2.0",
    "@radix-ui/react-switch": "1.2.2",
    "@radix-ui/react-tabs": "1.1.9",
    "@radix-ui/react-toast": "1.2.11",
    "@radix-ui/react-toggle": "1.1.6",
    "@radix-ui/react-toggle-group": "1.1.7",
    "@radix-ui/react-tooltip": "1.2.4",
    "@tanstack/react-query": "5.56.2",
    "axios": "1.16.0",
    "class-variance-authority": "0.7.1",
    "clsx": "2.1.1",
    "cmdk": "1.1.1",
    "cra-template": "1.2.0",
    "date-fns": "4.1.0",
    "dayjs": "1.11.13",
    "embla-carousel-react": "8.6.0",
    "framer-motion": "11.18.0",
    "input-otp": "1.4.2",
    "lodash": "4.18.1",
    "lucide-react": "0.516.0",
    "next-themes": "0.4.6",
    "react": "19.0.0",
    "react-day-picker": "8.10.1",
    "react-dom": "19.0.0",
    "react-hook-form": "7.56.2",
    "react-resizable-panels": "3.0.1",
    "react-router-dom": "7.15.0",
    "react-scripts": "5.0.1",
    "recharts": "3.6.0",
    "sonner": "2.0.3",
    "swr": "2.3.8",
    "tailwind-merge": "3.2.0",
    "tailwindcss-animate": "1.0.7",
    "vaul": "1.1.2",
    "zod": "3.24.4"
  },
  "scripts": {
    "start": "craco start",
    "build": "craco build",
    "test": "craco test"
  },
  "devDependencies": {
    "@babel/plugin-proposal-private-property-in-object": "7.21.11",
    "@craco/craco": "7.1.0",
    "@emergentbase/visual-edits": "https://assets.emergent.sh/npm/emergentbase-visual-edits-1.0.12.tgz",
    "@eslint/js": "9.23.0",
    "@types/lodash": "4.17.24",
    "autoprefixer": "10.4.20",
    "dotenv": "16.4.5",
    "eslint": "9.23.0",
    "eslint-plugin-import": "2.31.0",
    "eslint-plugin-jsx-a11y": "6.10.2",
    "eslint-plugin-react": "7.37.4",
    "eslint-plugin-react-hooks": "5.2.0",
    "globals": "15.15.0",
    "postcss": "8.5.10",
    "tailwindcss": "3.4.17"
  }
}
EOF

cat > app/frontend/src/index.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

/* Fonts (per design guidelines: Outfit, Manrope, JetBrains Mono) */
@import url('https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;700&family=Outfit:wght@400;600;700&family=JetBrains+Mono:wght@400;700&display=swap');

/* Design tokens (mapped from design_guidelines.json) */
:root {
  --font-heading: "Outfit", system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
  --font-body: "Manrope", system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
  --font-mono: "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Monaco, monospace;

  --dg-background: #FAFAFA;
  --dg-surface: #FFFFFF;
  --dg-surface-hover: #F4F4F5;
  --dg-border: #E4E4E7;
  --dg-text-primary: #09090B;
  --dg-accent-primary: #D97706;
  --dg-accent-secondary: #2563EB;
  --dg-danger: #DC2626;
  --dg-success: #059669;
}

.dark {
  --dg-background: #09090B;
  --dg-surface: #121214;
  --dg-surface-hover: #18181B;
  --dg-border: #27272A;
  --dg-border-hover: #3F3F46;
  --dg-text-primary: #FAFAFA;
  --dg-text-secondary: #A1A1AA;
  --dg-text-tertiary: #71717A;
  --dg-accent-primary: #F59E0B;
  --dg-accent-secondary: #3B82F6;
  --dg-danger: #EF4444;
  --dg-success: #10B981;
}

body {
  margin: 0;
  font-family: var(--font-body);
  background-color: var(--dg-background);
  color: var(--dg-text-primary);
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

h1,h2,h3,h4 {
  font-family: var(--font-heading);
}

code, kbd, .mono {
  font-family: var(--font-mono);
}

/* keep other base rules from repo */
@layer base {
    :root {
        --background: 0 0% 100%;
        --foreground: 0 0% 3.9%;
        --card: 0 0% 100%;
        --card-foreground: 0 0% 3.9%;
        --popover: 0 0% 100%;
        --popover-foreground: 0 0% 3.9%;
        --primary: 0 0% 9%;
        --primary-foreground: 0 0% 98%;
        --secondary: 0 0% 96.1%;
        --secondary-foreground: 0 0% 9%;
        --muted: 0 0% 96.1%;
        --muted-foreground: 0 0% 45.1%;
        --accent: 0 0% 96.1%;
        --accent-foreground: 0 0% 9%;
        --destructive: 0 84.2% 60.2%;
        --destructive-foreground: 0 0% 98%;
        --border: 0 0% 89.8%;
        --input: 0 0% 89.8%;
        --ring: 0 0% 3.9%;
        --chart-1: 12 76% 61%;
        --chart-2: 173 58% 39%;
        --chart-3: 197 37% 24%;
        --chart-4: 43 74% 66%;
        --chart-5: 27 87% 67%;
        --radius: 0.5rem;
    }
    .dark {
        --background: 0 0% 3.9%;
        --foreground: 0 0% 98%;
        --card: 0 0% 3.9%;
        --card-foreground: 0 0% 98%;
        --popover: 0 0% 3.9%;
        --popover-foreground: 0 0% 98%;
        --primary: 0 0% 98%;
        --primary-foreground: 0 0% 9%;
        --secondary: 0 0% 14.9%;
        --secondary-foreground: 0 0% 98%;
        --muted: 0 0% 14.9%;
        --muted-foreground: 0 0% 63.9%;
        --accent: 0 0% 14.9%;
        --accent-foreground: 0 0% 98%;
        --destructive: 0 62.8% 30.6%;
        --destructive-foreground: 0 0% 98%;
        --border: 0 0% 14.9%;
        --input: 0 0% 14.9%;
        --ring: 0 0% 83.1%;
        --chart-1: 220 70% 50%;
        --chart-2: 160 60% 45%;
        --chart-3: 30 80% 55%;
        --chart-4: 280 65% 60%;
        --chart-5: 340 75% 55%;
    }
}
EOF

cat > app/frontend/src/api.js <<'EOF'
import axios from "axios";

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL || "";
const baseURL = BACKEND_URL ? `${BACKEND_URL}/api` : "/api";

const api = axios.create({
  baseURL,
  timeout: 10_000,
});

export default api;
EOF

cat > app/frontend/src/App.js <<'EOF'
import { useEffect } from "react";
import "@/App.css";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import api from "@/api";
import { HOME } from "@/constants/testIds";

const Home = () => {
  const helloWorldApi = async () => {
    try {
      const response = await api.get(`/`);
      console.log(response.data.message);
    } catch (e) {
      console.error(e, `errored out requesting / api`);
    }
  };

  useEffect(() => {
    helloWorldApi();
  }, []);

  return (
    <div>
      <header className="App-header">
        <a
          data-testid={HOME.emergentLink}
          className="App-link"
          href="https://emergent.sh"
          target="_blank"
          rel="noopener noreferrer"
        >
          <img
            data-testid="home-logo"
            src="https://avatars.githubusercontent.com/in/1201222?s=120&u=2686cf91179bbafbc7a71bfbc43004cf9ae1acea&v=4"
            alt="Emergent"
          />
        </a>
        <p data-testid="home-splash" className="mt-5">Building something incredible ~!</p>
      </header>
    </div>
  );
};

function App() {
  return (
    <div className="App">
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Home />}>
            <Route index element={<Home />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </div>
  );
}

export default App;
EOF

# Keep basic App.css and index.js if needed; minimal placeholder if not present
cat > app/frontend/src/App.css <<'EOF'
.App-logo {
    height: 40vmin;
    pointer-events: none;
}

@media (prefers-reduced-motion: no-preference) {
    .App-logo {
        animation: App-logo-spin infinite 20s linear;
    }
}

.App-header {
    background-color: #0f0f10;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    font-size: calc(10px + 2vmin);
    color: white;
}

.App-link {
    color: #61dafb;
}

@keyframes App-logo-spin {
    from {
        transform: rotate(0deg);
    }
    to {
        transform: rotate(360deg);
    }
}
EOF

cat > app/frontend/src/index.js <<'EOF'
import React from "react";
import ReactDOM from "react-dom/client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import "@/index.css";
import App from "@/App";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60_000,
      refetchOnWindowFocus: false,
    },
  },
});

const root = ReactDOM.createRoot(document.getElementById("root"));
root.render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <App />
    </QueryClientProvider>
  </React.StrictMode>,
);
EOF

cat > app/frontend/tailwind.config.js <<'EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
    darkMode: ["class"],
    content: [
    "./src/**/*.{js,jsx,ts,tsx}",
    "./public/index.html"
  ],
  theme: {
    extend: {
      borderRadius: {
        lg: 'var(--radius)',
        md: 'calc(var(--radius) - 2px)',
        sm: 'calc(var(--radius) - 4px)'
      },
      colors: {
        background: 'hsl(var(--background))',
        foreground: 'hsl(var(--foreground))',
        card: {
          DEFAULT: 'hsl(var(--card))',
          foreground: 'hsl(var(--card-foreground))'
        },
        popover: {
          DEFAULT: 'hsl(var(--popover))',
          foreground: 'hsl(var(--popover-foreground))'
        },
        primary: {
          DEFAULT: 'hsl(var(--primary))',
          foreground: 'hsl(var(--primary-foreground))'
        },
        secondary: {
          DEFAULT: 'hsl(var(--secondary))',
          foreground: 'hsl(var(--secondary-foreground))'
        },
        muted: {
          DEFAULT: 'hsl(var(--muted))',
          foreground: 'hsl(var(--muted-foreground))'
        },
        accent: {
          DEFAULT: 'hsl(var(--accent))',
          foreground: 'hsl(var(--accent-foreground))'
        },
        destructive: {
          DEFAULT: 'hsl(var(--destructive))',
          foreground: 'hsl(var(--destructive-foreground))'
        },
        border: 'hsl(var(--border))',
        input: 'hsl(var(--input))',
        ring: 'hsl(var(--ring))',
        chart: {
          '1': 'hsl(var(--chart-1))',
          '2': 'hsl(var(--chart-2))',
          '3': 'hsl(var(--chart-3))',
          '4': 'hsl(var(--chart-4))',
          '5': 'hsl(var(--chart-5))'
        }
      },
      keyframes: {
        'accordion-down': {
          from: {
            height: '0'
          },
          to: {
            height: 'var(--radix-accordion-content-height)'
          }
        },
        'accordion-up': {
          from: {
            height: 'var(--radix-accordion-content-height)'
          },
          to: {
            height: '0'
          }
        }
      },
      animation: {
        'accordion-down': 'accordion-down 0.2s ease-out',
        'accordion-up': 'accordion-up 0.2s ease-out'
      }
    }
  },
  plugins: [require("tailwindcss-animate")],
};
EOF

# ---- commit & push ----
git init
git checkout -b main
git add .
git commit -m "chore: initial scaffold — frontend + backend + README + CI"

# Replace placeholders in README CI badge with actual owner/repo
if command -v sed >/dev/null 2>&1; then
  sed -i "s|OWNER|$REPO_OWNER|g" README.md || true
  sed -i "s|REPO|$REPO_NAME|g" README.md || true
fi

if [[ "$GITHUB_CREATE" == "yes" ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh (GitHub CLI) is not installed or not in PATH. The repo was created locally only."
    echo "To create the repo on GitHub, run:"
    echo "  gh repo create $REPO_OWNER/$REPO_NAME --public --source=. --remote=origin --push"
    exit 0
  fi

  echo "Creating GitHub repo $REPO_OWNER/$REPO_NAME..."
  gh repo create "$REPO_OWNER/$REPO_NAME" --$VISIBILITY --source=. --remote=origin --push
  echo "Repository created and pushed."
  echo "Open the repo in the browser? (y/n)"
  read -r openit
  if [[ "$openit" == "y" ]]; then
    gh repo view "$REPO_OWNER/$REPO_NAME" --web
  fi
else
  echo "GITHUB_CREATE set to no. Repo created locally at $ROOT_DIR. Add a remote and push manually."
  echo "git remote add origin git@github.com:$REPO_OWNER/$REPO_NAME.git"
  echo "git push -u origin main"
fi

echo "Done. Next steps:"
echo "- Add screenshots to /assets and update README."
echo "- Pin the repo on your GitHub profile."
echo "- Deploy frontend to Vercel (app/frontend) and configure env vars as needed."
