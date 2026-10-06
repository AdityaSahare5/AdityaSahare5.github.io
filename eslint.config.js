const js = require("@eslint/js");
const globals = require("globals");

module.exports = [
  js.configs.recommended,
  {
    files: ["src/**/*.js"],
    languageOptions: { sourceType: "script", globals: globals.browser },
    rules: { "no-eval": "error", "no-implied-eval": "error" },
  },
  {
    files: ["scripts/**/*.js", "eslint.config.js"],
    languageOptions: { sourceType: "commonjs", globals: globals.node },
  },
];
