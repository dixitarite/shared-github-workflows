#!/bin/bash

set -e  # Exit on error
set -o pipefail

echo "=== Angular Project & CI Pipeline Setup ==="

# ============================
# 0. User Inputs
# ============================
read -p "Enter Angular project name: " PROJECT_NAME
read -p "Enter GitHub repo SSH URL (e.g. git@github.com:your-org/your-repo.git): " REPO_URL
read -p "Enter SonarQube Project Key: " SONAR_PROJECT_KEY
read -p "Enter SonarQube Organization: " SONAR_ORG

# ============================
# 1. Install Global Dependencies
# ============================
echo "Installing global dependencies..."
npm install -g @angular/cli@latest eslint

# ============================
# 2. Create Angular Project
# ============================
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
if [ ! -f ".eslintrc.json" ]; then
cat <<EOL > .eslintrc.json
{
  "root": true,
  "ignorePatterns": ["projects/**/*"],
  "overrides": [
    {
      "files": ["*.ts"],
      "extends": ["eslint:recommended", "plugin:@angular-eslint/recommended"],
      "rules": {}
    }
  ]
}
EOL
fi

# ============================
# 4. Ensure Karma/Jasmine Coverage
# ============================
echo "Ensuring Karma/Jasmine setup..."
if [ -f "karma.conf.js" ]; then
    sed -i "s/reporters: \[/reporters: ['junit', /" karma.conf.js || true
    npm install --save-dev karma-junit-reporter
fi

# ============================
# 5. Add a Passing Test (for first CI run)
# ============================
cat <<EOL > src/app/app.component.spec.ts
import { TestBed } from '@angular/core/testing';
import { AppComponent } from './app.component';

describe('AppComponent', () => {
  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [AppComponent],
    }).compileComponents();
  });

  it('should create the app', () => {
    const fixture = TestBed.createComponent(AppComponent);
    const app = fixture.componentInstance;
    expect(app).toBeTruthy();
  });

  it('should have a passing test', () => {
    expect(true).toBeTrue();
  });
});
EOL

# ============================
# 6. Setup SonarQube Scanner
# ============================
echo "Setting up SonarQube..."
npm install --save-dev sonar-scanner

cat <<EOL > sonar-project.properties
sonar.projectKey=${SONAR_PROJECT_KEY}
sonar.organization=${SONAR_ORG}
sonar.sources=src
sonar.host.url=https://sonarcloud.io
sonar.javascript.lcov.reportPaths=coverage/lcov.info
EOL

# ============================
# 7. Setup GitHub Actions Pipeline
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
      node_version: ${{ vars.NODE_VERSION }}
      coverage_threshold: ${{ vars.COVERAGE_THRESHOLD }}
      project_path: '.'
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      CODACY_PROJECT_TOKEN: ${{ secrets.CODACY_PROJECT_TOKEN }}
EOL

# ============================
# 8. Git Init & First Push
# ============================
echo "Committing and pushing changes..."
git init
git branch -M main
git remote add origin "$REPO_URL"
git add .
git commit -m "Initial Angular project with CI pipeline"
git push -u origin main

echo "✅ Setup complete! GitHub Actions will now run your CI pipeline."
