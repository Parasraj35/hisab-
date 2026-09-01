# Running the HISAB backend in Docker

## First time

```bash
cd hisab
cp .env.example .env

# Generate real secrets
openssl rand -hex 32   # paste into JWT_ACCESS_SECRET
openssl rand -hex 32   # paste into JWT_REFRESH_SECRET

docker compose up -d --build
```

API comes up at `http://localhost:5000/api/v1`.

Check it:

```bash
curl http://localhost:5000/api/v1/health
```

## Everyday commands

```bash
docker compose up -d              # start
docker compose down               # stop (keeps data)
docker compose down -v            # stop and wipe the database
docker compose restart api        # restart just the API
docker compose logs -f api        # follow API logs
docker compose ps                 # status + health
docker compose up -d --build api  # rebuild after code changes
```

## Seed the demo data

```bash
docker compose exec api npm run seed
```

Logs in as `ali.hassan@example.com` / `hisab12345` with four PKR accounts.

## Build the image on its own

```bash
cd backend
docker build -t hisab-api:1.0.0 .
docker run --rm -p 5000:5000 \
  -e MONGO_URI=mongodb://host.docker.internal:27017/hisab \
  -e JWT_ACCESS_SECRET=dev_access \
  -e JWT_REFRESH_SECRET=dev_refresh \
  hisab-api:1.0.0
```

## Shell access

```bash
docker compose exec api sh                       # into the API container
docker compose exec mongo mongosh hisab          # into the database
```

## Pointing the Flutter app at it

`app/lib/core/network/api_endpoints.dart`:

| Where you run the app | baseUrl |
|---|---|
| Android emulator | `http://10.0.2.2:5000/api/v1` (current default) |
| iOS simulator / desktop | `http://localhost:5000/api/v1` |
| Real device on same Wi-Fi | `http://<your-machine-ip>:5000/api/v1` |

For a real device, find your IP with `ipconfig getifaddr en0` (macOS) or
`hostname -I` (Linux).

---

## Notes on the setup

**No lock file yet.** `npm ci` is faster and reproducible but needs
`package-lock.json`, which isn't committed. The Dockerfile falls back to
`npm install`. Run `npm install` in `backend/` once and commit the lock file to
get the faster path.

**`depends_on` waits for health, not just start.** Mongo accepts connections
several seconds after the container starts. Without the healthcheck condition
the API would boot first and crash on connect.

**`MONGO_URI` uses `mongo`, not `localhost`.** Inside the compose network the
service name is the hostname. `localhost` in the API container means the API
container itself.

**Mongo's port is published for convenience.** Handy for Compass during
development, but remove the `ports` block on `mongo` before deploying — the API
reaches it over the internal network and it doesn't need to be exposed.

**`OTP_DEV_ECHO` is `false` here.** In development the API echoes OTP codes in
its response so you can verify without an SMS provider. That must stay off in
any deployed environment.

**Runs as the non-root `node` user**, with `dumb-init` as PID 1 so `SIGTERM`
reaches Node and the graceful shutdown in `server.js` actually runs on
`docker compose down`.

---

## Not yet done

These files are written but **were not executed** — this environment has no
Docker daemon, so the build is unverified. Things to watch for on first run:

- **Production readiness.** There's no reverse proxy, TLS, or Mongo
  authentication. Fine for local development; add all three before deploying.
- **No resource limits** set on either service.
- **Backups** live in the same database they back up. For real durability, add
  `mongodump` to a volume or an external store.
