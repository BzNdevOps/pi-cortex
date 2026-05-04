import { Router, Request, Response } from 'express';

const router = Router();

// In-memory store for MVP
interface KnowledgeItem {
  id: string;
  title: string;
  content: string;
  source: string;
  tags: string[];
  createdAt: Date;
  updatedAt: Date;
}

const knowledgeStore: KnowledgeItem[] = [];

// Create or Update Knowledge
router.post('/', (req: Request, res: Response) => {
  const { id, title, content, source, tags } = req.body;
  
  const newItem: KnowledgeItem = {
    id: id || `kb-${Date.now()}`,
    title: title || 'Untitled',
    content: content || '',
    source: source || 'unknown',
    tags: tags || [],
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  // Check for existing ID (update)
  const existingIndex = knowledgeStore.findIndex(k => k.id === newItem.id);
  if (existingIndex >= 0) {
    knowledgeStore[existingIndex] = { ...knowledgeStore[existingIndex], ...newItem, updatedAt: new Date() };
    res.status(200).json({ status: 'ok', message: 'Knowledge updated', data: knowledgeStore[existingIndex] });
  } else {
    knowledgeStore.push(newItem);
    res.status(201).json({ status: 'ok', message: 'Knowledge created', data: newItem });
  }
});

// Search Knowledge (must be before /:id)
router.get('/search', (req: Request, res: Response) => {
  const { q, top_k } = req.query;
  const query = (q as string)?.toLowerCase() || '';
  const limit = (top_k as number) || 5;

  const results = knowledgeStore.filter(k => 
    k.title.toLowerCase().includes(query) || 
    k.content.toLowerCase().includes(query) ||
    k.tags.some(t => t.toLowerCase().includes(query))
  );

  res.status(200).json({ status: 'ok', data: results.slice(0, limit) });
});

// Get Knowledge by ID
router.get('/:id', (req: Request, res: Response) => {
  const item = knowledgeStore.find(k => k.id === req.params.id);
  if (item) {
    res.status(200).json({ status: 'ok', data: item });
  } else {
    res.status(404).json({ error: 'Knowledge not found' });
  }
});

// Delete Knowledge
router.delete('/:id', (req: Request, res: Response) => {
  const index = knowledgeStore.findIndex(k => k.id === req.params.id);
  if (index >= 0) {
    knowledgeStore.splice(index, 1);
    res.status(200).json({ status: 'ok', message: 'Knowledge deleted' });
  } else {
    res.status(404).json({ error: 'Knowledge not found' });
  }
});

export default router;
