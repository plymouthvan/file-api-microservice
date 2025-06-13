FROM node:18-alpine

WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy application code
COPY . .

# Create public directory if it doesn't exist
RUN mkdir -p public

# Expose the port the app runs on
EXPOSE ${PORT:-3000}

# Start the application
CMD ["node", "src/app.js"]
