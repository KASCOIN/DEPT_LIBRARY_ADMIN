# Use official Julia image as base
FROM julia:1.9

# Set working directory
WORKDIR /app

# Set environment variables for production
ENV JULIA_DEPOT_PATH=/app/.julia
ENV JULIA_NUM_THREADS=1
ENV GENIE_ENV=prod

# Copy Project.toml and Manifest.toml first for better caching
COPY Project.toml Manifest.toml ./

# Instantiate the project (install dependencies)
RUN julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

# Copy the rest of the application code
COPY . .

# Expose the port that Genie will run on (Render will override this)
EXPOSE 8000

# Health check for Render and container orchestration
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:${PORT:-8000}/health || exit 1

# Set the default command to run the production bootstrap
CMD ["julia", "--project=.", "bootstrap.jl"]
