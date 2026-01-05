# All-inclusive IRIS Dockerization for Quick and automatic Setup for Embedded Python

Before joining InterSystems, I worked in a team of web developers as a data scientist. Most of my day-to-day work involved Python-based backend applications, mainly built with the Django framework. That experience quickly taught me an important lesson: "it works on my machine" is not an acceptable excuse anymore. Reproducibility, portability, and consistency across environments are non-negotiable in modern software development.

This is where good coding practices, modularization, and containerization come into play. Docker, in particular, became an essential tool in my workflow, not only for scalability and ease of deployment, but also to reduce human error and ensure that code behaves the same way everywhere, regardless of the underlying machine.

When I later joined InterSystems, I was immediately impressed by the robustness of IRIS as a data platform. Its multi-model nature and, in particular, the lightning-fast access to data through globals opened my eyes to a different way of thinking about performance and data access patterns, especially compared to the traditional relational-only mindset.

I was also lucky to join the company (September 2025) at a time when a rich ecosystem of tools was already in place, significantly flattening the learning curve. The VS Code ObjectScript Extension Pack, Embedded Python, the official IRIS Docker images, and the InterSystems Package Manager (IPM) for easily importing ObjectScript packages (https://github.com/intersystems/ipm
) quickly became my everyday toolbelt.

After about three months, I felt confident enough working with this stack that I started standardizing my own development environment. In this article, I'd like to share how I set up a fully containerized IRIS instance using Docker—ready to use Embedded Python out of the box, with all required dependencies installed from both Python's pip and IPM.


I'll also show how I manage to:

  - Link custom Python packages during the Docker build process, so they can be imported naturally (e.g. from mypythonpackage import myclassorfunc) inside any Embedded Python methods living on ObjectScript classes without repetitive boilerplate.

  - Automatically execute IRIS terminal commands as soon as the container starts, which in this scenario is used to:

    - Install IPM and, through it, Shavrov's csvgenpy utility
    (https://community.intersystems.com/post/csvgenpy-import-any-csv-intersystems-iris-using-embedded-python
    ), used to create and populate new tables from a single CSV file.

    - Check whether an IRIS table already exists and, if it doesn't, populate it using csvgenpy with a CSV file mounted into the container via Docker volumes.

All of this by only running:

```bash
docker-compose up --build
```

Finally, the repository accompanying this article uses this setup to create a complete IRIS environment with all the tools and data needed to compare different ways of querying the same IRIS table and converting the results into a pandas DataFrame (NumPy-based), which is typically what gets passed to Python-based machine learning models.

The comparison includes:

- Dynamic SQL queries

- Pandas querying the table directly

- Direct access through globals

For each approach, the execution time is measured to highlight the performance differences between the different querying methods.


## Project Structure

```
.
├── docker-compose.yml             # Docker orchestration configuration
├── dockerfile                     # Multi-stage build with IRIS + Python
├── iris_autoconf.sh               # Auto-configuration script for IRIS terminal commands
├── requirements.txt               # Python libraries
├── MockPackage/                   # Custom package
│   ├── MockDataManager.cls        # Data management utilities
│   ├── MockModelManager.cls       # ML model training
│   └── MockInference.cls          # Data retrieval and inference benchmarks
├── python_utils/                  # Custom Python packages
│   ├── __init__.py
│   └── utils.py                   # ML preprocessing & inference
└── dur/                           # Volume for durable data on host machine and container
    ├── data/                      # CSV datasets
    └── models/                    # Trained LightGBM models
```

### docker-compose.yml

```
version: '3.8'

services:
  iris:
    build: # How is the image built
      context: . # Path to the directory containing the Dockerfile
      dockerfile: Dockerfile # Name of the Dockerfile
    container_name: iris-experimentation # Name of the container
    ports:
      - "1972:1972"    # SuperServer port
      - "52773:52773"  # Management Portal/Web Gateway
    volumes:
      - ./dur/.:/dur:rw # map host directory to container directory with read-write permissions
    restart: always # Always restart the container if it stops (unless explicitly stopped)
    healthcheck:
      test: ["CMD", "iris", "session", "iris", "-U", "%SYS", "##class(SYS.Database).GetMountedSize()"] # Health check command
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    command: --after "/usr/irissys/iris_autoconf.sh" # Run autoconf script after startup

```


Docker Compose specifies the image, exposed ports, container name, and more. In particular, I want to highlight the following points:
  - volumes: ./dur/.:/dur:rw 
    This creates the /dur directory inside the container and maps it to ./dur at the level of the docker-compose.yml on the host machine (my own physical laptop), with both read and write permissions. In other words, both the host machine and the container share this path, making it very easy to load files into IRIS and read them from the host machine without any extra copying steps.

    In this project, this is how the /data and /models folders are directly uploaded from my local repository into /dur inside the container.

  - command: --after "/usr/irissys/iris_autoconf.sh"
    This command allows the execution of a bash file just after the container is set up and running. This file contains all the commands needed to open the IRIS terminal and run any required IRIS commands.

    NOTE: be aware that the commands in this bash file are executed every time the container starts. This means that if the container goes down for any reason and restarts (for example, because of restart: always), all the commands in this script will be run again. If this behavior is not taken into account when writing the script, it can lead to unintended side effects such as resetting tables or reinstalling packages.



### dockerfile

```
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

# Copy and set permissions for the autoconf script while still root
COPY iris_autoconf.sh /usr/irissys/iris_autoconf.sh
RUN chmod +x /usr/irissys/iris_autoconf.sh

# Switch back to the default `irisowner` user
USER irisowner
```

This is a two-stage Dockerfile. The first stage is used as a build stage to install the Python dependencies listed in requirements.txt into a temporary directory. The second stage is based on the InterSystems IRIS image, where the Python runtime library required for Embedded Python is installed and IRIS is configured so that Embedded Python can recognize both the runtime library and the installed Python packages, including custom ones.

It is worth highlighting:
  - Setting the following environment variables:

    ```
    ENV PythonRuntimeLibrary=/usr/lib/x86_64-linux-gnu/libpython3.12.so
    ENV PythonRuntimeLibraryVersion=3.12
    ```

    achieves what would otherwise be configured manually in the Management Portal by navigating to
    System Administration → Configuration → Additional Settings → Advanced Memory and updating the corresponding Embedded Python runtime settings.






### iris_autoconf.sh

```
#!/bin/bash
set -e

iris session IRIS <<'EOF'

/* Install IPM/ZPM client if you still need that first
   (your original snippet did this already) */
s version="latest" s r=##class(%Net.HttpRequest).%New(),r.Server="pm.community.intersystems.com",r.SSLConfiguration="ISC.FeatureTracker.SSL.Config" d r.Get("/packages/zpm/"_version_"/installer"),$system.OBJ.LoadStream(r.HttpResponse.Data,"c")

/* Configure registry */
zpm
repo -r -n registry -url https://pm.community.intersystems.com/ -user "" -pass ""
install csvgenpy
quit

/* Upload csv data ONCE to Table Automatically using csvgenpy */
SET exists = ##class(%SYSTEM.SQL.Schema).TableExists("MockPackage.NoShowsAppointments")
IF 'exists {   do ##class(shvarov.csvgenpy.csv).Generate("/dur/data/healthcare_noshows_appointments.csv","NoShowsAppointments","MockPackage")   }

halt
EOF
```

This is a bash file that is executed inside the container just after the container starts. From there, it opens an IRIS terminal session using iris session IRIS, and runs IRIS-specific commands to automatically perform additional configuration steps, such as installing IPM (available as zpm inside the IRIS terminal), installing IPM packages like csvgenpy, and then using csvgenpy to load the CSV file mounted into the container at /dur/data/healthcare_noshows_appointments.csv and create/populate the corresponding table in IRIS.

NOTE: This script is executed every time the container starts. If this behavior is not considered when writing the script, it can lead to unintended side effects such as reloading or resetting data. That is why it is important to make the script safe to run multiple times, for example by checking whether the target table already exists before creating/populating it. This is especially relevant here because the Docker Compose restart policy is set to restart: always, meaning the container will automatically restart and re execute these commands everytime it goes down.

