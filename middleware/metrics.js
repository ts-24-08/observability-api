import promClient from "prom-client";

const register = new promClient.Registry();

promClient.collectDefaultMetrics({ register });

const httpRequestCounter = new promClient.Counter({
  name: "http_requests_total",
  help: "Total number of HTTP requests",
  labelNames: ["method", "route", "status_code"],
  registers: [register],
});

const httpResponseDuration = new promClient.Histogram({
  name: "http_response_time_seconds",
  help: "HTTP response time in seconds",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5],
  registers: [register],
});

export const requestCounter = (req, res, next) => {
  const end = res.end;
  res.end = function (...args) {
    const route = req.route ? req.route.path : req.path;
    httpRequestCounter.inc({
      method: req.method,
      route: route,
      status_code: res.statusCode,
    });
    end.apply(res, args);
  };
  next();
};

export const responseTimeHistogram = (req, res, next) => {
  const start = Date.now();
  const end = res.end;

  res.end = function (...args) {
    const responseTime = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;
    httpResponseDuration.observe(
      {
        method: req.method,
        route: route,
        status_code: res.statusCode,
      },
      responseTime
    );
    end.apply(res, args);
  };
  next();
};

export const getMetrics = async (req, res) => {
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
};
