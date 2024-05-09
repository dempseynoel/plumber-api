# Base image https://hub.docker.com/u/rocker/
FROM rocker/r-ver:4.3.1

# Install the linux libraries needed for plumber 
RUN apt-get update -qq && apt-get install -y \ 
   libssl-dev \ 
   libcurl4-gnutls-dev \
   libsodium-dev

# Copy necessary files
COPY renv.lock ./renv.lock
COPY plumber.R .

# Install renv & restore packages
RUN Rscript -e 'install.packages("renv")'
RUN Rscript -e 'renv::restore()'

# Expose port
EXPOSE 8000

ENTRYPOINT ["R", "-e", \
    "r = plumber::plumb('plumber.R'); r$run(host = '0.0.0.0', port = 8000)"]