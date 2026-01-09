# Stage 1: Build stage for installing dependencies
FROM python:3.12-slim AS builder

# Set the working directory
WORKDIR /app

# Copy the requirements file into the image
COPY requirements.txt requirements.txt

# Install the Python dependencies into a temporary location
RUN pip install --no-cache-dir --target /install -r requirements.txt

# Stage 2: Final image with InterSystems IRIS and the installed Python libraries
FROM containers.intersystems.com/intersystems/iris-community:latest-em

# Switch to the root user to install necessary system packages
USER root

# Install the correct Python 3.12 development library for Ubuntu Noble
RUN apt-get update && apt-get install -y libpython3.12-dev wget && \
    rm -rf /var/lib/apt/lists/*

# Set the environment variables for Embedded Python
ENV PythonRuntimeLibrary=/usr/lib/x86_64-linux-gnu/libpython3.12.so
ENV PythonRuntimeLibraryVersion=3.12

# Update the LD_LIBRARY_PATH
ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}

# Copy the installed Python packages from the builder stage
COPY --from=builder /install /usr/irissys/mgr/python

# Your own Python package
COPY python_utils /usr/irissys/mgr/python/python_utils
ENV PYTHONPATH=/usr/irissys/mgr/python:${PYTHONPATH}


# Copy ObjectScript classes into the image
COPY MockPackage /usr/irissys/mgr/MockPackage
# Copy and set permissions for the autoconf script while still root
COPY iris_autoconf.sh /usr/irissys/iris_autoconf.sh
RUN chmod +x /usr/irissys/iris_autoconf.sh

# Switch back to the default `irisowner` user
USER irisowner





