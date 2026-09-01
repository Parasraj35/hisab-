import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';

export const signAccessToken = (user) =>
  jwt.sign({ sub: String(user._id), typ: 'access' }, env.jwt.accessSecret, {
    expiresIn: env.jwt.accessTtl,
  });

export const signRefreshToken = (user) =>
  jwt.sign({ sub: String(user._id), typ: 'refresh' }, env.jwt.refreshSecret, {
    expiresIn: env.jwt.refreshTtl,
  });

export const verifyRefreshToken = (token) => jwt.verify(token, env.jwt.refreshSecret);
export const verifyAccessToken = (token) => jwt.verify(token, env.jwt.accessSecret);

export const issueTokens = (user) => ({
  accessToken: signAccessToken(user),
  refreshToken: signRefreshToken(user),
});
