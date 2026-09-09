// Loaded via `node --import ./src/instrument.js` — before any other module,
// which is what Sentry's Node SDK needs for ESM auto-instrumentation to see
// http/express/mongodb before they're first used. Must stay import-only:
// nothing here should depend on anything that isn't ready this early.
import * as Sentry from '@sentry/node';
import { env } from './config/env.js';

Sentry.init({
  dsn: env.sentryDsn, // null is fine — the SDK just becomes a no-op
  environment: env.nodeEnv,
});
