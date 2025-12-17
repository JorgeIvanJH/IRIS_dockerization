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

# COMMANDS TO RUN:
    # SETUP DOCKER IMAGE AND CONTAINER
        # docker build -t iris-pip-ds .
        # docker run -d --name iris-pip-ds -p 12345:52773 iris-pip-ds
    # VERIFY PYTHON LIBRARIES ARE INSTALLED
        # docker exec -it iris-pip-ds iris terminal IRIS
        # USER> do ##class(%SYS.Python).Shell()
        # >>> import pandas
        # >>> import sklearn
    # CONFIGURE PYTHON ON IRIS (DONE DIRECTLY IN DOCKERFILE - No Need to do the following)
        # In the Management Portal, go to System Administration > Configuration > Additional Settings > Advanced Memory.
        # On the Advanced Memory Settings page, in the PythonRuntimeLibrary row, click Edit.
        # Enter the location of the Python runtime library you want to use. (ends in .dll on Windows, .so on Linux, .dylib on Mac)
            # PythonRuntimeLibrary=/usr/lib/x86_64-linux-gnu/libpython3.12.so
        # Click Save.
        # On the Advanced Memory Settings page, in the PythonRuntimeLibraryVersion row, click Edit.
        # Enter the version number of the Python runtime library you want to use.
            # PythonRuntimeLibraryVersion=3.12
        # Click Save.
    # PROCESS FOR ADDITIONAL PYTHON LIBRARIES:
        # /usr/irissys/ → <installdir> Path where the official images from InterSystems place the entire installation of Python and its libraries
        # /usr/irissys/mgr/python → <installdir>/mgr/python location where the official images from InterSystems place the Python libraries
       
        # 1. Install python python libraries into <installdir>/mgr/python
        # 2. Import pachages in ObjectScript using %SYS.Python.Import()

        # FOR ADDITIONAL PYTHON LIBRARIES
            # RECOMMENDED: Add to requirements.txt and rebuild docker image
            # ALTERNATIVE: Manually install using docker exec command
                # docker exec -it -u root iris-pip-ds bash
                # python3 -m pip install --target /usr/irissys/mgr/python seaborn

        # Use IRIS Instance to access classes tables using python (symbol "%" changes for "_")
            # >>> import iris
            # >>> my_company = iris.Sample.Company._New()
            # >>> my_company.Name = 'Acme Widgets, Inc.'
            # >>> my_company.TaxID = '123456789'
            # >>> status = my_company._Save()
            # >>> print(status)
            # 1
            # >>> print(my_company._Id())
            # 22
        # Use the _OpenId() method of the class to retrieve an object from persistent storage into memory for processing:
            # >>> your_company = iris.Sample.Company._OpenId(22)
            # >>> print(your_company.Name)
            # Acme Widgets, Inc.
        # STATUS, SUCCESSFUL OR NOT
            # Status codes, after a function, status 1 : successful, "string" : error description
                # >>> your_company.Name = 'The Best Company'
                # >>> status = your_company._Save()
                # >>> print(status)
                # 0 Ô«Sample.Company·%SaveData+11^Sample.Company.1USER#e^%SaveData+11^Sample.Company.1^7)e^%SerializeObject+7^Sample.Company.1^2e^%Save+8^Sample.Company.1^5e^zShell+47^%SYS.Python.1^1d^^^0
                
            # Better. use iris.check_status() 
            #     >>> try:
            #     ...    iris.check_status(status)
            #     ... except Exception as ex:
            #     ...    print(ex)
            #     ...
            #     ERROR #5803: Failed to acquire exclusive lock on instance of 'Sample.Company'

    # UPLOADING FILES TO THE CONTAINER
        
        # Op1: from dockerfile (already above)
        # Op2: using docker cp command
            # docker cp [LOCAL_FILE_PATH] [CONTAINER_NAME_OR_ID]:[CONTAINER_DESTINATION_PATH]
                # e.g:
                    # docker cp data/myexamplefile.csv iris-pip-ds:/usr/irissys/mgr/iris_data/myexamplefile.csv
    
    # Work with SQL from Python
        # >>> import iris
        # >>> rs = iris.sql.exec("SELECT Name, Mission FROM Sample.Company")
        # >>> pd.DataFrame(rs)
        # or
        # >>> stmt = iris.sql.prepare("SELECT Name, Mission FROM Sample.Company WHERE Name %STARTSWITH ?")
        # >>> rs = stmt.execute("Comp")
        # can iterate like this:
        # >>> for idx, row in enumerate(rs):                                              
        # ...     print(f"[{idx}]: {row}")  
        # Handle exceptions in sql like this
        # >>> stmt = iris.sql.prepare("INSERT INTO Sample.Company (Mission, Name, Revenue, TaxID) VALUES (?, ?, ?, ?)")
        # >>> try:
        # ...     rs = stmt.execute("We are on a mission", "", "999", "P62")
        # ... except Exception as ex:
        # ...     print(ex.sqlcode, ex.message)
        # ...
        # -108 'Name' in table 'Sample.Company' is a required field

    # Work with Globals
        # >>> my_gref = iris.gref('^Workdays') # gets a global reference (or gref) to a global called ^Workdays, which may or may not already exist.
        # >>> my_gref[None] = 5 # stores the number of workdays in ^Workdays, without a subscript.
        # >>> my_gref[1] = 'Monday' # stores the string Monday in the location ^Workdays(1)
        # >>> my_gref[2] = 'Tuesday'
        # >>> my_gref[3] = 'Wednesday'
        # >>> my_gref[4] = 'Thursday'
        # >>> my_gref[5] = 'Friday'
        # >>> print(my_gref[3])
        # Wednesday
    
    # ObjectScrip and Python in the same class example
        # Class Sample.Company Extends (%Persistent, %Populate, %XML.Adaptor)
        # {

        # /// The company's name.
        # Property Name As %String(MAXLEN = 80, POPSPEC = "Company()") [ Required ];

        # /// The company's mission statement.
        # Property Mission As %String(MAXLEN = 200, POPSPEC = "Mission()");

        # /// The unique Tax ID number for the company.
        # Property TaxID As %String [ Required ];

        # /// The last reported revenue for the company.
        # Property Revenue As %Integer;

        # /// The Employee objects associated with this Company.
        # Relationship Employees As Employee [ Cardinality = many, Inverse = Company ];

        # Method Print() [ Language = python ]
        # {
        #     print(f"\nName: {self.Name} TaxID: {self.TaxID}")
        # }

        # Method Write() [ Language = objectscript ]
        # {
        #     write !, "Name: ", ..Name, " TaxID: ", ..TaxID, !
        # }
        # }


    # Pass Data Between Python and ObjectScript
        # e.g1:
            # USER>set builtins = ##class(%SYS.Python).Builtins()
            # USER>set newport = builtins.list()
            # USER>do newport.append(41.49008)
            # USER>do newport.append(-71.312796)
            # USER>set cleveland = builtins.list()
            # USER>do cleveland.append(41.499498)
            # USER>do cleveland.append(-81.695391)
            # USER>zwrite newport
            # newport=11@%SYS.Python  ; [41.49008, -71.312796]  ; <OREF>
            # USER>zwrite cleveland
            # cleveland=11@%SYS.Python  ; [41.499498, -81.695391]  ; <OREF>
        # e.g2:
            # USER>set distance = $system.Python.Import("geopy.distance")
            
            # USER>set route = distance.distance(newport, cleveland)

            # USER>write route.miles
            # 538.3904453677205311
    
    # Run an Arbitrary Python Command from ObjectScript
        # USER>do ##class(%SYS.Python).Run("print('hello world')")
        # hello world
    # Run an Arbitrary ObjectScript Command from Embedded Python
        # >>> iris.execute('write "hello world", !')
        # hello world
    
    # Install and enable intersystems IPM (or ZPM) package manager
        # USER> s version="latest" s r=##class(%Net.HttpRequest).%New(),r.Server="pm.community.intersystems.com",r.SSLConfiguration="ISC.FeatureTracker.SSL.Config" d r.Get("/packages/zpm/"_version_"/installer"),$system.OBJ.LoadStream(r.HttpResponse.Data,"c")
    
        # zpm
        # repo -r -n registry -url https://pm.community.intersystems.com/ -user "" -pass ""


    # See the list of available modules:

        # zpm: USER>repo -list-modules -n registry

    # Install csvgenpy using ZPM
    
        # USER>zpm "install csvgenpy"

        # Load csv to IRIS class using csvgenpy

            # API
                # w ##class(shvarov.csvgenpy.csv).Generate(filename_or_url, dest_table_name, [schema_name], [server=embedded_python_by_default], [append=0])

                # e.g:
                    # Import from file
                        # USER>do ##class(shvarov.csvgenpy.csv).Generate("/home/irisowner/dev/data/countries.csv","countries")
                    # Import from URL
                        # USER>do ##class(shvarov.csvgenpy.csv).Generate("https://raw.githubusercontent.com/datasciencedojo/datasets/master/titanic.csv","titanic","data")

            # Call from python

                # import csvgen
                # generate('file.csv','dest_table_name','schema_name')
            
            # Set primary key value by providing as last parameter:
                # do ##class(shvarov.csvgenpy.csv).Generate("/home/irisowner/dev/data/countries_dspl small.csv","countries","data",,,,"name")

                    # so instances from data.countries could be open by country names, e.g.:

                        # set country=##class(csvgen.sqltest).%OpenId("Albania")
                        # write country.country
                        # AL

            # Load your CSV file. For this example, we will use a hypothetical diabetes.csv file located at /data/diabetes.csv.
            # This command creates a persistent class data.diabetes and loads the CSV data into it.
                
                # USER> do ##class(shvarov.csvgenpy.csv).Generate("/usr/irissys/mgr/iris_data/diabetes.csv", "diabetes", "data")

            # Verify the data was loaded by running a SQL query.

                # USER> :sql
                # SQL]USER>> select * from data.diabetes limit 5
                







