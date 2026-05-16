// Vercel Web Analytics Integration
// Import and inject the analytics script
import { inject } from '@vercel/analytics';

// Initialize Vercel Web Analytics
inject({
  mode: 'auto', // Automatically detect production/development
  debug: false, // Set to true for debugging
});
