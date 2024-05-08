export default {
  "*.md": ["prettier --write"],
  "{src,script}/**/*.sol": ["prettier --write", "solhint -w 0"],
  "test/**/*.sol": ["prettier --write", "solhint -c .solhint.test.json -w 0"],
  "*.json": ["prettier --write"],
  "*.yml": ["prettier --write"],
};
