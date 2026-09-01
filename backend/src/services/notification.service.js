import { Notification } from '../models/Notification.js';

export async function pushNotification(userId, { type, title, body, meta = {} }) {
  try {
    return await Notification.create({ user: userId, type, title, body, meta });
  } catch (err) {
    console.error('[notification] failed to create', err.message);
    return null;
  }
}
