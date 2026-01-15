# Use official Julia image as base
FROM julia:1.9

# Set working directory
WORKDIR /app

# Copy Project.toml and Manifest.toml first for better caching
COPY Project.toml Manifest.toml ./

# Instantiate the project (install dependencies)
RUN julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

# Copy the rest of the application code
COPY . .

# Expose the port that Genie will run on (Render will override this)
EXPOSE 8000

# Set the default command to run the production bootstrap
CMD ["julia", "--project=.", "bootstrap.jl"]
