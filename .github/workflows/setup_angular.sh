#!/bin/bash

set -e  # Exit on error
set -o pipefail

echo "Starting Angular Project & CI Pipeline Setup..."

# ============================
# 1. Install Global Dependencies
# ============================
echo "Installing global dependencies..."
npm install -g @angular/cli@latest eslint

# ============================
# 2. Create Angular Project (Skip if already exists)
# ============================
PROJECT_NAME="my-angular-app"
if [ ! -d "$PROJECT_NAME" ]; then
    echo "Creating Angular project: $PROJECT_NAME..."
    ng new $PROJECT_NAME --style=scss --routing=true --strict=true
else
    echo "Angular project $PROJECT_NAME already exists. Skipping creation."
fi

cd $PROJECT_NAME

# ============================
# 3. Setup ESLint
# ============================
echo "Setting up ESLint..."
ng add @angular-eslint/schematics@latest --skip-confirmation

# Create ESLint config if not present
if [ ! -f "eslint.config.cjs" ]; then
cat <<EOL > eslint.config.cjs
module.exports = {
  root: true,
  ignorePatterns: ["projects/**/*"],
  overrides: [
    {
      files: ["*.ts"],
      extends: [
        "eslint:recommended",
        "plugin:@angular-eslint/recommended"
      ],
      rules: {}
    }
  ]
};
EOL
fi

# ============================
# 4. Setup Unit Testing with Coverage
# ============================
echo "Ensuring Karma/Jasmine is set up..."
ng add @angular-builders/jest --skip-confirmation || true

# Modify karma.conf.js for coverage if exists
if [ -f "karma.conf.js" ]; then
    sed -i 's/reporters: \[/reporters: ["junit", /' karma.conf.js || true
    npm install --save-dev karma-junit-reporter
fi

# ============================
# 5. Setup SonarQube Scanner
# ============================
echo "Setting up SonarQube..."
npm install --save-dev sonar-scanner

cat <<EOL > sonar-project.properties
sonar.projectKey=my-angular-app
sonar.organization=my-org
sonar.sources=src
sonar.host.url=https://sonarcloud.io
sonar.javascript.lcov.reportPaths=coverage/lcov.info
EOL

# ============================
# 6. Setup GitHub Actions Pipeline
# ============================
echo "Setting up GitHub Actions pipeline..."
mkdir -p .github/workflows

cat <<'EOL' > .github/workflows/angular_ci.yml
name: Angular CI Pipeline

on:
  push:
    branches: ['*']
  pull_request:
    branches: ['*']

jobs:
  test_and_build:
    uses: Rite-Technologies-23/reusable-repo-flutter/.github/workflows/reusable_angular_ci_pipeline.yml@main
    with:
      node_version: \${{ vars.NODE_VERSION }}
      coverage_threshold: \${{ vars.COVERAGE_THRESHOLD }}
      project_path: '.'
    secrets:
      SONAR_TOKEN: \${{ secrets.SONAR_TOKEN }}
      CODACY_PROJECT_TOKEN: \${{ secrets.CODACY_PROJECT_TOKEN }}
EOL

# ============================
# 7. First Commit & Push
# ============================
echo "Committing and pushing changes..."
git init
git add .
git commit -m "Initial Angular project with CI pipeline"
git branch -M main
git remote add origin git@github.com:your-org/your-repo.git
git push -u origin main

# ============================
# 8. Trigger Pipeline
# ============================
echo "Triggering pipeline by pushing to main..."
git commit --allow-empty -m "Trigger CI"
git push

echo "Angular Project & CI Pipeline Setup Complete!"
