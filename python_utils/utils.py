from functools import wraps
import pandas as pd
import lightgbm as lgb
import time

def measure_time_decorator(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        start_time = time.time()
        result = func(*args, **kwargs)
        end_time = time.time()
        elapsed_time = end_time - start_time
        return result, elapsed_time
    return wrapper

def noshows_data_preprocessing(df: pd.DataFrame):

    df = df.drop(columns=['appointmentid', 'patientid'])
    df = df.astype({
                'gender': 'category',
                'neighbourhood': 'category',
                'scheduledday': 'datetime64[ns]',
                'appointmentday': 'datetime64[ns]',
                })
    # DATA PREPARATION (slight difference for LightGBM)
    date_cols = ["scheduledday", "appointmentday"]

    # 1. Extract useful components
    for col in date_cols:
        df[col + "_year"] = df[col].dt.year
        df[col + "_month"] = df[col].dt.month
        df[col + "_day"] = df[col].dt.day
        df[col + "_dow"] = df[col].dt.dayofweek         # 0=Mon, 6=Sun
        df[col + "_hour"] = df[col].dt.hour
        df[col + "_is_weekend"] = (df[col].dt.dayofweek >= 5).astype("int8")
        
        # Optional: Part-of-day feature
        df[col + "_part_of_day"] = pd.cut(
            df[col].dt.hour,
            bins=[-1, 6, 12, 17, 24],
            labels=[0, 1, 2, 3],        # 0=night,1=morning,2=afternoon,3=evening
            ordered=True
        ).astype("int8")
    df = df.drop(columns=date_cols)

    # DROP CATEGORICAL FEATURES (just for now)
    df = df.drop(columns=["gender", "neighbourhood"])
    y = df["showed_up"]
    X = df.drop(columns=["showed_up"])
    return X, y

def load_lightgbm_model(model_path: str):
    bst = lgb.Booster(model_file=model_path)
    return bst

def model_inference(model, X: pd.DataFrame):
    y_pred = model.predict(X)
    return y_pred

@measure_time_decorator
def inference_pipeline(model_path: str, df: pd.DataFrame):
    model = load_lightgbm_model(model_path)
    X, _ = noshows_data_preprocessing(df)
    y_pred = model_inference(model, X)
    return y_pred