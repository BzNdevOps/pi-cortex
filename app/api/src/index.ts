import express, { Request, Response, NextFunction } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import knowledgeRouter from './routes/knowledge';

const app = express();
const PORT = 3002;

// Security Middleware
app.use(helmet());
app.use(cors({ origin: ['http://localhost:3000', 'http://localhost:3002'] }));
app.use(express.json());

// Rate Limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // Limit each IP
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// Health Check
app.get('/api/health', (req: Request, res: Response) => {
  res.status(200).json({ status: 'ok', version: '0.1.0', port: PORT });
});

// Authentication Middleware
const API_KEY = process.env.PI_CORTEX_AGENT_KEY;

function authMiddleware(req: Request, res: Response, next: NextFunction) {
  if (!API_KEY) {
    return res.status(500).json({ error: 'API_KEY not configured' });
  }
  const apiKey = req.headers['x-api-key'];
  if (!apiKey || apiKey !== API_KEY) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
}

// Mount Routes
app.use('/api/knowledge', authMiddleware, knowledgeRouter);

// 404 Handler
app.use('/api', (req: Request, res: Response) => {
  res.status(404).json({ error: 'Not Found' });
});

// Start Server
app.listen(PORT, '127.0.0.1', () => {
  console.log(`🧠 pi-cortex API running on http://127.0.0.1:${PORT}`);
});
