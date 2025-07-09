# Documentation Generation Workflow

This repository now includes a GitHub Action workflow that automatically generates HTML documentation from the Swift Package Interface (SPI) and deploys it to a dedicated `docs` branch.

## How It Works

The workflow (`.github/workflows/docs.yml`) performs the following steps:

### 1. **Triggers**
- **New Releases**: Automatically generates and deploys documentation when a new release is published
- **New Tags**: Also triggers on new version tags (e.g., `v1.0.0` or `1.0.0`)
- **Manual Trigger**: Can be manually triggered via GitHub Actions UI

### 2. **Documentation Generation**
- Uses **Swift-DocC** (Swift Documentation Compiler) to generate HTML documentation
- Targets the `Clerk` Swift package as specified in `.spi.yml`
- Generates static HTML files optimized for hosting

### 3. **Deployment Process**
- Creates/updates an **orphan branch** called `docs`
- The `docs` branch contains **only** the generated HTML documentation (no source code)
- Pushes the latest documentation to this branch
- Force-pushes to ensure clean state on each update

### 4. **Features**
- **Automatic indexing**: Creates a landing page with links to documentation
- **Static hosting ready**: Documentation is optimized for static hosting (GitHub Pages, etc.)
- **Release-based deployment**: Only updates documentation on new releases for stability
- **Caching**: Uses Swift package caching for faster builds

## Generated Documentation Structure

The `docs` branch will contain:
```
docs/
├── index.html              # Landing page
├── documentation/
│   └── clerk/             # Main documentation
│       ├── index.html     # Package overview
│       ├── classes/       # Class documentation
│       ├── structs/       # Struct documentation
│       ├── enums/         # Enum documentation
│       └── protocols/     # Protocol documentation
├── css/                   # Styling files
├── js/                    # JavaScript files
└── data/                  # Documentation data files
```

## Setting Up GitHub Pages (Optional)

To make your documentation publicly accessible:

1. Go to your repository **Settings** → **Pages**
2. Under "Source", select **Deploy from a branch**
3. Choose **docs** branch and **/ (root)** folder
4. Click **Save**

Your documentation will be available at: `https://[username].github.io/[repository-name]/`

## Triggering Documentation Generation

### Automatic (Recommended)
1. **Create a release**: Go to your repository → **Releases** → **Create a new release**
2. **Create a tag**: Tag format like `v1.0.0` or `1.0.0` will automatically trigger the workflow
3. **Publish the release**: Documentation will be generated and deployed automatically

### Manual Execution
You can manually trigger the documentation generation:
1. Go to **Actions** tab in your repository
2. Select **Generate Documentation** workflow
3. Click **Run workflow**
4. Choose the branch and click **Run workflow**

## Workflow Configuration

The workflow is configured to:
- Run on **macOS** (required for Swift-DocC)
- Use **Swift 5.9** (matches your Package.swift)
- Cache Swift packages for faster builds
- Deploy to `docs` branch on releases and manual triggers only

## Troubleshooting

### Common Issues:
- **Build failures**: Ensure all dependencies are properly defined in `Package.swift`
- **Missing documentation**: Add DocC comments (`///`) to your Swift code
- **Deploy failures**: Check repository permissions for GitHub Actions

### Requirements:
- Repository must have Actions enabled
- Branch protection rules shouldn't prevent force-pushes to `docs` branch
- Swift package must build successfully

## Customization

You can customize the workflow by:
- Modifying the `--hosting-base-path` in the documentation generation step
- Changing the landing page content in the "Setup docs directory structure" step
- Adjusting the PR comment template
- Adding additional Swift-DocC flags as needed

The workflow is designed to work with your existing `.spi.yml` configuration and will automatically detect and document all public APIs in your Swift package.