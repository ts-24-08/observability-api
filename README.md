# Express Observability API

A modern Express.js API with built-in observability features including structured logging, metrics collection, and error tracking. This project serves as a practical introduction to implementing observability in Node.js applications.

## Features

- **Modern JavaScript**: Built with ES Modules
- **Structured Logging**: Using Winston and Morgan
- **Metrics Collection**: Prometheus client integration
- **Error Handling**: Centralized error management
- **Health Check**: Endpoint for monitoring
- **API Documentation**: Clear route structure

## Project Structure

```
/
├── config/
│   └── index.js         # Application configuration
├── middleware/
│   ├── error-handler.js # Error handling middleware
│   ├── logger.js        # Winston and Morgan integration
│   └── metrics.js       # Prometheus metrics collection
├── routes/
│   ├── index.js         # Main router
│   └── users.js         # User-related endpoints
├── app.js               # Express application setup
├── server.js            # Application entry point
└── package.json         # Project dependencies
```

## Installation

1. Clone the repository
2. Install dependencies:

```bash
npm install
```

## Running the Application

### Development Mode

```bash
npm run dev
```

This starts the server with nodemon for automatic reloading.

### Production Mode

```bash
npm start
```

## API Endpoints

### Main

- `GET /` - Welcome message
- `GET /health` - Health check endpoint
- `GET /metrics` - Prometheus metrics endpoint

### Users

- `GET /users` - Get all users
- `GET /users/:id` - Get a specific user
- `POST /users` - Create a new user
- `PUT /users/:id` - Update a user
- `DELETE /users/:id` - Delete a user
- `GET /users/error/test` - Test endpoint that randomly generates errors

## Observability Components

### Logging (middleware/logger.js)

The application uses Winston for structured logging and Morgan for HTTP request logging:

- Configurable log levels via environment variables
- JSON formatted logs for better parsing
- HTTP request logging with response status

Example log output:

```json
{
  "level": "info",
  "message": "Retrieved all users",
  "timestamp": "2023-07-21T14:32:45.123Z"
}
```

### Metrics (middleware/metrics.js)

Prometheus metrics are collected for:

1. **Default Node.js metrics**: Memory usage, event loop lag, etc.
2. **Custom metrics**:
   - `http_requests_total`: Counter for total HTTP requests with labels:
     - `method`: HTTP method (GET, POST, etc.)
     - `route`: Request route
     - `status_code`: HTTP status code
   - `http_response_time_seconds`: Histogram for response times with the same labels

Metrics are available at the `/metrics` endpoint in Prometheus format.

### Error Handling (middleware/error-handler.js)

The application includes two types of error handlers:

1. **Not Found Handler**: Returns 404 for undefined routes
2. **Error Handler**: Processes errors thrown in the application:
   - Logs error stack trace
   - Returns standardized error response

## Testing Error Handling

The `/users/error/test` endpoint demonstrates error handling:

- 50% of requests will generate a simulated error
- 50% will return a delayed response (random delay 0-1000ms)

This allows testing of both error tracking and response time metrics.

## Environment Variables

- `PORT`: Application port (default: 3000)
- `NODE_ENV`: Environment (development, production) (default: development)
- `LOG_LEVEL`: Winston log level (default: info)

## Testing

Run tests using Jest:

```bash
npm test
```

## Extending the Application

### Adding New Routes

1. Create a new router file in the `/routes` directory
2. Export a router with your endpoints
3. Import and mount it in `/routes/index.js`

### Adding Custom Metrics

Modify `/middleware/metrics.js` to add new metric types:

```javascript
const myNewCounter = new promClient.Counter({
  name: "my_new_metric",
  help: "Description of the metric",
  labelNames: ["label1", "label2"],
});

// Example increment
myNewCounter.inc({ label1: "value1", label2: "value2" });
```

## Best Practices Demonstrated

1. **Separation of Concerns**: Modular file structure
2. **Middleware Pattern**: Reusable middleware components
3. **Error Handling**: Centralized error management
4. **Configuration Management**: Environment-based config
5. **Graceful Shutdown**: Proper server termination
6. **Standardized Responses**: Consistent API responses
7. **Modern JavaScript**: ES Modules and modern syntax

## License

MIT

## Created by
Marco Lindner | Techstarter GmbH
