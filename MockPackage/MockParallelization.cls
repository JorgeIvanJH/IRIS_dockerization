Class MockPackage.MockParallelization Extends %Persistent
{

Parameter DATACLASS = "Demo.BenchData";

Parameter TABLENAME = "Demo_BenchData";

// ------------------------------- OPTION 1: IRIS Dynamic SQL --------------------------------

ClassMethod DynamicSQL(lowerAge As %Integer = 0) As %String
{
    ; Execute a dynamic SQL query to retrieve rows from NoShowsAppointments table where age >= lowerAge
    ; e.g:
    ;    set results = ##class(MockPackage.MockParallelization).DynamicSQL(30)
    set statement = "SELECT patientid, appointmentid, gender, scheduledday, appointmentday, age, neighbourhood, scholarship, hipertension, diabetes, alcoholism, handcap, sms_received, showed_up, date_diff FROM MockPackage.NoShowsAppointments WHERE age >= ?"
    set objSql = ##class(%SQL.Statement).%New()
    set status = objSql.%Prepare(statement)
    if $$$ISERR(status) {
        do %system.OBJ.DisplayError(status)
        quit []}
    set results = []  // %DynamicArray
    set rs = objSql.%Execute(lowerAge)
    if rs.%SQLCODE'<0 {
        // fill dynamic array with per-row dynamic objects
        while rs.%Next() {
            set row = {}  // %DynamicObject
            set row."patientid"     = rs.%Get("patientid")
            set row."appointmentid" = rs.%Get("appointmentid")
            set row."gender"        = rs.%Get("gender")
            set row."scheduledday"  = rs.%Get("scheduledday")
            set row."appointmentday"= rs.%Get("appointmentday")
            set row."age"           = rs.%Get("age")
            set row."neighbourhood" = rs.%Get("neighbourhood")
            set row."scholarship"   = rs.%Get("scholarship")
            set row."hipertension"  = rs.%Get("hipertension")
            set row."diabetes"      = rs.%Get("diabetes")
            set row."alcoholism"    = rs.%Get("alcoholism")
            set row."handcap"       = rs.%Get("handcap")
            set row."sms_received"  = rs.%Get("sms_received")
            set row."showed_up"     = rs.%Get("showed_up")
            set row."date_diff"     = rs.%Get("date_diff")

            do results.%Push(row)
        }
    }

    quit results
}

ClassMethod RunInferenceWDynamicSQL(lowerAge As %Integer = 0) [ Language = python ]
{
    """
    Runs inference using dynamic SQL query to fetch data from IRIS database.
    e.g:
        do ##class(MockPackage.MockParallelization).RunInferenceWDynamicSQL(30)
    """
    import iris
    import pandas as pd
    import json

    # 1. Call your ObjectScript method
    rows = iris.cls("MockPackage.MockParallelization").DynamicSQL()
    py_rows = []

    # 2. Iterate and convert via JSON to handle binary/special characters
    for i in range(1, rows._Size() + 1):
        row = rows._Get(i)
        if (row is None) or (row == ''):
            continue
        # %ToJSON() serializes the IRIS object to a string at the source
        # json.loads() converts that string into a clean Python dictionary
        py_row = json.loads(row._ToJSON())
        py_rows.append(py_row)

    # 3. Create your DataFrame
    df = pd.DataFrame(py_rows)
    print(df.head())
}

// ------------------------------- OPTION 2: SQL IN PYTHON --------------------------------

ClassMethod RunInferenceWIRISSQL(lowerAge As %Integer = 0) [ Language = python ]
{
    """
    Runs inference using IRIS SQL from Python to fetch data from IRIS database.
    e.g:
        do ##class(MockPackage.MockParallelization).RunInferenceWIRISSQL(30)
    """
    import iris
    import pandas as pd
    # Execute the query directly
    columns = [
        'patientid', 'appointmentid', 'gender', 'scheduledday', 
        'appointmentday', 'age', 'neighbourhood', 'scholarship', 
        'hipertension', 'diabetes', 'alcoholism', 'handcap', 
        'sms_received', 'showed_up', 'date_diff'
    ]
    query = f"SELECT {', '.join(columns)} FROM MockPackage.NoShowsAppointments"
    statement = iris.sql.prepare(query)
    stmt = statement.execute()
    df = pd.DataFrame(list(stmt), columns=columns)
    print(df.head())
}

// ------------------------------- OPTION 3: QUERY USING GLOBALS --------------------------------

ClassMethod RunInferenceWGLobals(lowerAge As %Integer = 0) [ Language = python ]
{
    """
    Runs inference using direct global access to fetch data from IRIS database.
    e.g:
        do ##class(MockPackage.MockParallelization).RunInferenceWGLobals(30)
    """
    import iris
    import pandas as pd

    data_global = iris.gref("^vCVc.Dvei.1")
    processed_data = []

    # Use the %SYS.Python utility for reliable list conversion
    py_util = iris.cls("%SYS.Python")

    for key in data_global.keys([]):
        raw_val = data_global[key]
        
        # Correct method to deserialize the binary $List into a Python list
        python_list = py_util.ToList(raw_val)
        processed_data.append(python_list)


    columns = [
        'patientid', 'appointmentid', 'gender', 'scheduledday', 
        'appointmentday', 'age', 'neighbourhood', 'scholarship', 
        'hipertension', 'diabetes', 'alcoholism', 'handcap', 
        'sms_received', 'showed_up', 'date_diff'
    ]

    df = pd.DataFrame(processed_data, columns=columns)
    print(df.head())
}

Storage Default
{
<Data name="MockParallelizationDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
</Data>
<DataLocation>^MockPackage.MockParalle6DEFD</DataLocation>
<DefaultData>MockParallelizationDefaultData</DefaultData>
<IdLocation>^MockPackage.MockParalle6DEFD</IdLocation>
<IndexLocation>^MockPackage.MockParalle6DEFI</IndexLocation>
<StreamLocation>^MockPackage.MockParalle6DEFS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
