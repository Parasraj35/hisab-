import { env } from '../config/env.js';

/**
 * Sends an email via Resend's REST API using Node's built-in fetch — no
 * SDK dependency needed for a single endpoint call. Never throws: a
 * transient email-provider hiccup shouldn't fail the request that
 * triggered it (e.g. registration). Callers that need to know whether
 * delivery actually happened can check the resolved boolean.
 */
export async function sendEmail({ to, subject, html }) {
  if (!env.email.apiKey) {
    console.warn('[email] RESEND_API_KEY not set — skipping send');
    return false;
  }

  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.email.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ from: env.email.from, to, subject, html }),
    });

    if (!res.ok) {
      console.error('[email] send failed', res.status, await res.text());
      return false;
    }
    return true;
  } catch (err) {
    console.error('[email] send failed', err.message);
    return false;
  }
}
