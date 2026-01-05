Class MockPackage.MockInference Extends %Persistent
{

Parameter MODELPATH = "/dur/models/LightGBM_1620_22122025.txt";

// ------------------------- CONSISTENCY CHECK AMONG QUERY METHODS --------------------------------

ClassMethod ConsistencyCheck(lowerAge As %Integer = 0) [ Language = python ]
{
    """
    Compares outputs from the three different query methods to ensure they return the same data.
    e.g:
        do ##class(MockPackage.MockInference).ConsistencyCheck(30)
    """
    import pandas as pd
    from python_utils import querymethods as querymethods

    methods = [querymethods.dynamic_sql_query, 
                querymethods.iris_sql_query, 
                querymethods.iris_global_query]

    df_prev = None
    for method in methods:
        df = method(lowerAge)
        print(f"Getting data using {method.__name__}")
        if df_prev is None:
            df_prev = df
            continue
        pd.testing.assert_frame_equal(df, df_prev) # ASSERT EQUALITY OF DATAFRAMES AMONG METHODS
        print(f"Data from method {method.__name__} is consistent with previous method.")
        df_prev = df
    print("All query methods returned consistent data.")
}

// ------------------------------- OPTION 1: IRIS Dynamic SQL --------------------------------

ClassMethod DynamicSQL(lowerAge As %Integer = 0) As %String
{
    ; Execute a dynamic SQL query to retrieve rows from NoShowsAppointments table where age >= lowerAge
    ; e.g:
    ;    set results = ##class(MockPackage.MockInference).DynamicSQL(30)
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
        do ##class(MockPackage.MockInference).RunInferenceWDynamicSQL(30)
    """
    import iris
    import pandas as pd
    import json
    from python_utils import utils as utils
    from python_utils import querymethods as querymethods
    modelPath = iris.cls("MockPackage.MockInference")._GetParameter("MODELPATH")
    time_decorator = utils.measure_time_decorator
    query_method = querymethods.dynamic_sql_query
    decorated_query = time_decorator(query_method)
    df, query_time = decorated_query(lowerAge)
    print(df.head())
    print("Dataframe shape: ", df.shape[0], " rows and ", df.shape[1], " columns")
    print("Query time: ", query_time, " seconds")
    ypred, inference_time = utils.inference_pipeline(modelPath, df)
    print("Inference time: ", inference_time, " seconds")
}

// ------------------------------- OPTION 2: SQL IN PYTHON --------------------------------

ClassMethod RunInferenceWIRISSQL(lowerAge As %Integer = 0) [ Language = python ]
{
    """
    Runs inference using IRIS SQL from Python to fetch data from IRIS database.
    e.g:
        do ##class(MockPackage.MockInference).RunInferenceWIRISSQL(30)
    """
    import iris
    import pandas as pd
    from python_utils import utils as utils
    from python_utils import querymethods as querymethods
    modelPath = iris.cls("MockPackage.MockInference")._GetParameter("MODELPATH")
    time_decorator = utils.measure_time_decorator
    query_method = querymethods.iris_sql_query
    decorated_query = time_decorator(query_method)
    df, query_time = decorated_query(lowerAge)
    print(df.head())
    print("Dataframe shape: ", df.shape[0], " rows and ", df.shape[1], " columns")
    print("Query time: ", query_time, " seconds")
    ypred, inference_time = utils.inference_pipeline(modelPath, df)
    print("Inference time: ", inference_time, " seconds")
}

// ------------------------------- OPTION 3: QUERY USING GLOBALS --------------------------------

ClassMethod RunInferenceWGLobals(lowerAge As %Integer = 0) [ Language = python ]
{
    """
    Runs inference using direct global access to fetch data from IRIS database.
    e.g:
        do ##class(MockPackage.MockInference).RunInferenceWGLobals(30)
    """
    import iris
    import pandas as pd
    from python_utils import utils as utils
    from python_utils import querymethods as querymethods
    modelPath = iris.cls("MockPackage.MockInference")._GetParameter("MODELPATH")
    time_decorator = utils.measure_time_decorator
    query_method = querymethods.iris_global_query
    decorated_query = time_decorator(query_method)
    df, query_time = decorated_query(lowerAge)
    print(df.head())
    print("Dataframe shape: ", df.shape[0], " rows and ", df.shape[1], " columns")
    print("Query time: ", query_time, " seconds")
    ypred, inference_time = utils.inference_pipeline(modelPath, df)
    print("Inference time: ", inference_time, " seconds")
}

Storage Default
{
<Data name="MockInferenceDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
</Data>
<DataLocation>^MockPackage.MockInferenceD</DataLocation>
<DefaultData>MockInferenceDefaultData</DefaultData>
<IdLocation>^MockPackage.MockInferenceD</IdLocation>
<IndexLocation>^MockPackage.MockInferenceI</IndexLocation>
<StreamLocation>^MockPackage.MockInferenceS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
