import * as Sentry from '@sentry/node';
import { app } from './app.js';
import { env } from './config/env.js';
import { connectDB } from './config/db.js';

async function start() {
  await connectDB();
  const server = app.listen(env.port, () =>
    console.log(`[server] HISAB API listening on http://localhost:${env.port}/api/v1`)
  );

  const shutdown = (signal) => {
    console.log(`\n[server] ${signal} received, shutting down`);
    server.close(() => process.exit(0));
  };
  ['SIGINT', 'SIGTERM'].forEach((s) => process.on(s, () => shutdown(s)));
  process.on('unhandledRejection', (err) => {
    console.error('[server] Unhandled rejection', err);
    Sentry.captureException(err);
    server.close(() => Sentry.close(2000).then(() => process.exit(1)));
  });
}

start().catch(async (err) => {
  console.error('[server] Failed to start', err);
  Sentry.captureException(err);
  await Sentry.close(2000); // give the report a moment to actually send before exiting
  process.exit(1);
});
