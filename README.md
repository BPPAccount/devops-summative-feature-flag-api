
# BP0315785 DevOps Summative – Feature Flag API

A minimal Feature Flag API used to demonstrate an end-to-end DevOps delivery capability: CI testing, container build and publication, Infrastructure as Code provisioning, and automated deployment to Azure Container Apps.

This project is intentionally small at the application layer so that delivery controls (CI/CD, IaC, secrets, and runtime verification) are clearly observable.

## What this service does

The API exposes a small set of endpoints:

- `GET /health`  
  Returns service status and metadata (`timeUtc`, `version`, `commitSha`).

- `GET /flags/{key}`  
  Returns a stored feature flag value.

- `PUT /flags/{key}` (admin only)  
  Upserts a flag value.

- `DELETE /flags/{key}` (admin only)  
  Deletes a flag.

Flags are stored in-memory (no persistence). This is deliberate for the assignment scope and keeps the focus on delivery automation.

## Repository structure

- `src/` – FastAPI application (`src/app.py`)
- `tests/` – pytest tests
- `infra/` – Infrastructure as Code (Bicep)
- `.github/workflows/` – CI and CD workflows
- `Dockerfile` – container build definition

## Local development

### Prerequisites

- Python 3.12+
- pip
- (Optional) curl or PowerShell for API calls

### Setup

Create and activate a virtual environment, then install dependencies:

**Windows (PowerShell):**
```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
````

**macOS/Linux (bash/zsh):**

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
```

### Run the API locally

Set an admin token (required for PUT/DELETE), then start the server:

**Windows (PowerShell):**

```powershell
$env:ADMIN_TOKEN="change-me"
python -m uvicorn src.app:app --host 127.0.0.1 --port 8000
```

**macOS/Linux:**

```bash
export ADMIN_TOKEN="change-me"
python -m uvicorn src.app:app --host 127.0.0.1 --port 8000
```

Open:

* [http://127.0.0.1:8000/health](http://127.0.0.1:8000/health)
* [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs) (Swagger UI)

### Quick API usage

#### Health

```bash
curl -s http://127.0.0.1:8000/health
```

#### Get a flag (404 if missing)

```bash
curl -s http://127.0.0.1:8000/flags/demo
```

#### Put a flag (admin)

```bash
curl -s -X PUT "http://127.0.0.1:8000/flags/demo" \
  -H "Authorization: Bearer change-me" \
  -H "Content-Type: application/json" \
  -d '{"value": true}'
```

#### Delete a flag (admin)

```bash
curl -s -X DELETE "http://127.0.0.1:8000/flags/demo" \
  -H "Authorization: Bearer change-me"
```

## Container build (optional)

This repository includes a `Dockerfile` that packages the service as a container and runs as a non-root user.

If you have Docker available:

```bash
docker build -t feature-flag-api:dev .
docker run --rm -p 8000:8000 -e ADMIN_TOKEN=change-me feature-flag-api:dev
```

## CI/CD overview

This repository uses GitHub Actions:

### CI (`.github/workflows/ci.yml`)

Runs on:

* Pull requests
* Pushes to `main`

Steps:

* Install Python 3.12
* Install dependencies
* Run `pytest`

### CD (`.github/workflows/cd.yml`)

Runs on:

* Pushes to `main`

Steps:

1. Run tests (gate)
2. Log in to Azure using `AZURE_CREDENTIALS`
3. Deploy/update infrastructure using Bicep (`infra/main.bicep`)
4. Build a container image and push it to **GitHub Container Registry (GHCR)**
5. Update the Azure Container App to the new image
6. Smoke test the deployed service via `GET /health`

Images are published to GHCR using a commit SHA tag:

* `ghcr.io/bppaccount/devops-summative-feature-flag-api:<sha>`

### Why GHCR is private

The GHCR package is **private** to model organisational artefact access control and to avoid public distribution of deployable artefacts. Because the image is private, Azure Container Apps authenticates to GHCR using registry credentials stored as secrets and configured via IaC.

## Azure infrastructure (IaC)

Infrastructure is defined in `infra/main.bicep` and includes:

* Log Analytics workspace
* Container Apps managed environment (configured to forward logs)
* Azure Container App with:

  * External ingress on port 8000
  * Registry configuration for GHCR
  * Secrets (`admin-token`, `ghcr-token`)
  * Scale settings (`minReplicas: 0`, `maxReplicas: 1`) to control cost

> Note: The template uses a `bootstrapImage` because an image reference is required when creating the Container App resource. The CD pipeline immediately updates the image to the commit-tagged build.

## Required GitHub Secrets (for CD)

Create these repository secrets under:
**Settings → Secrets and variables → Actions → New repository secret**

* `AZURE_CREDENTIALS`
  JSON for a service principal with permissions on the target resource group.

* `ADMIN_TOKEN`
  Token used by the API to authorise PUT/DELETE operations.

* `GHCR_USERNAME`
  GitHub username (or org) used for GHCR.

* `GHCR_TOKEN`
  Token with `write:packages` (push) and `read:packages` (pull) as required by your setup.

## Running the deployed service

After CD completes successfully, the workflow prints the public app URL and performs a smoke test on:

[* `https://<fqdn>/health`](https://devopssum-api.happysmoke-da0fbd4c.uksouth.azurecontainerapps.io/)
