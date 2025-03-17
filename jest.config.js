export default {
  testEnvironment: "node",
  transform: {},
  moduleNameMapper: {
    "^(\\.{1,2}/.*)\\.js$": "$1",
  },
  collectCoverageFrom: [
    "routes/**/*.js",
    "middleware/**/*.js",
    "config/**/*.js",
    "app.js",
    "!**/node_modules/**",
  ],
  coverageDirectory: "coverage",
  verbose: true,
};
