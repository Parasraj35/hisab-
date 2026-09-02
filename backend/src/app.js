import path from 'path';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import compression from 'compression';
import routes from './routes/index.js';
import { apiLimiter } from './middleware/rateLimit.js';
import { notFoundHandler, errorHandler } from './middleware/error.js';
import { env } from './config/env.js';

export const app = express();

app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
app.use(cors({ origin: true, credentials: true }));
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(compression());
if (env.nodeEnv === 'development') app.use(morgan('dev'));

app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')));
app.use('/api/v1', apiLimiter, routes);

app.use(notFoundHandler);
app.use(errorHandler);
