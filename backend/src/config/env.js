import dotenv from 'dotenv';
dotenv.config();

const required = ['MONGO_URI', 'JWT_ACCESS_SECRET', 'JWT_REFRESH_SECRET'];
for (const key of required) {
  if (!process.env[key]) {
    console.error(`[config] Missing required env var: ${key}`);
    process.exit(1);
  }
}

export const env = {
  port: Number(process.env.PORT || 5000),
  nodeEnv: process.env.NODE_ENV || 'development',
  mongoUri: process.env.MONGO_URI,
  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET,
    refreshSecret: process.env.JWT_REFRESH_SECRET,
    accessTtl: process.env.ACCESS_TOKEN_TTL || '15m',
    refreshTtl: process.env.REFRESH_TOKEN_TTL || '30d',
  },
  otp: {
    ttlSeconds: Number(process.env.OTP_TTL_SECONDS || 300),
    // Forced off in production regardless of the env var — this echoes the
    // raw code back in the API response, meant only for local dev without a
    // real SMS/email provider wired up.
    devEcho: process.env.NODE_ENV !== 'production' && process.env.OTP_DEV_ECHO === 'true',
  },
};
