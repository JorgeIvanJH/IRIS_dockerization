import iris
import pandas as pd
import json

def dynamic_sql_query(lower_age: int) -> pd.DataFrame:
    rows = iris.cls("MockPackage.MockInference").DynamicSQL(lower_age)
    py_rows = []
    for i in range(0, rows._Size() + 1):
        row = rows._Get(i)
        if (row is None) or (row == ''):
            continue
        # %ToJSON() serializes the IRIS object to a string at the source
        # json.loads() converts that string into a clean Python dictionary
        py_row = json.loads(row._ToJSON())
        py_rows.append(py_row)

    df = pd.DataFrame(py_rows)
    return df

def iris_sql_query(lower_age: int) -> pd.DataFrame:
    columns = [
        'patientid', 'appointmentid', 'gender', 'scheduledday', 
        'appointmentday', 'age', 'neighbourhood', 'scholarship', 
        'hipertension', 'diabetes', 'alcoholism', 'handcap', 
        'sms_received', 'showed_up', 'date_diff'
    ]
    query = f"SELECT {', '.join(columns)} FROM MockPackage.NoShowsAppointments WHERE age >= {lower_age}"
    statement = iris.sql.prepare(query)
    stmt = statement.execute()
    df = pd.DataFrame(list(stmt), columns=columns)
    return df

def iris_global_query(lower_age: int) -> pd.DataFrame:
    data_global = iris.gref("^vCVc.Dvei.1")

    # Columns of the table in data_global in order
    columns = [
        'patientid', 'appointmentid', 'gender', 'scheduledday', 
        'appointmentday', 'age', 'neighbourhood', 'scholarship', 
        'hipertension', 'diabetes', 'alcoholism', 'handcap', 
        'sms_received', 'showed_up', 'date_diff'
    ]
    idx_filter = columns.index("age")
    processed_data = []
    # Use the %SYS.Python utility for reliable list conversion
    py_util = iris.cls("%SYS.Python")
    for key in data_global.keys([]):
        raw_val = data_global[key]
        # Correct method to deserialize the binary $List into a Python list
        python_list = py_util.ToList(raw_val)
        if python_list[idx_filter] >= lower_age:
            processed_data.append(python_list)
    df = pd.DataFrame(processed_data, columns=columns)
    return df