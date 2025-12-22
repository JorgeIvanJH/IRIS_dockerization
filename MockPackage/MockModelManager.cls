Class MockPackage.MockModelManager Extends %Persistent
{

ClassMethod SimplePythonMethod() As %String [ Language = python ]
{
    print("Executing SimplePythonMethod")
    from python_utils import utils as utils
    import time

    @utils.measure_time_decorator
    def delay_print():
        time.sleep(2)
        return None

    _, time_taken = delay_print()
    print(f"Time taken for delay_print: {time_taken} seconds")
    
    print("OK")
}

ClassMethod TrainNoShowsModel(csvPath As %String, modelSavePath As %String) As %String [ Language = python ]
{
    """
    Trains a LightGBM model on the noshows dataset and saves the model to the specified path.
    e.g:
        do ##class(MockPackage.MockModelManager).TrainNoShowsModel("/dur/data/healthcare_noshows_appointments.csv", "/dur/models")
    """
    import os
    import pandas as pd
    import lightgbm as lgb
    import gc
    import time
    import datetime
    from python_utils import utils as utils

    

    def training_lightgbm(X: pd.DataFrame, y: pd.Series, njobs_model: int, modelsave_path: str):
        # LIGHTGBM DATASET
        # MODEL DEFINITION
        train_data = lgb.Dataset(X, label=y, free_raw_data=True)
        validation_data = lgb.Dataset(X, label=y, reference=train_data)
        train_data.raw_data = None
        gc.collect()
        base_params = {
            'objective': 'binary',
            'metric': 'binary_logloss',
            'num_leaves': 31,
            'learning_rate': 0.05,
            'n_jobs': njobs_model,
            
        }

        gpu_params = base_params | {
            "device_type": "cpu",
            # 'gpu_platform_id': 0,
            # 'gpu_device_id': 0,
            "max_bin": 15,
            "gpu_use_dp": False
        }

        # TRAINING
        num_round = 10
        start_time = time.time()
        bst = lgb.train(gpu_params, train_data, num_round, valid_sets=[validation_data])
        end_time = time.time()
        print(f"Training time: {end_time - start_time} seconds")

        # TEST INFERENCE TIME
        start_time = time.time()
        y_pred = bst.predict(X)
        end_time = time.time()
        print(f"Inference time: {end_time - start_time} seconds")

        # SAVING
        datetime_now = datetime.datetime.now().strftime("%H%M_%d%m%Y")
        model_name = "LightGBM_" + f"{datetime_now}.txt"
        model_save_path = os.path.join(modelsave_path, model_name)
        bst.save_model(model_save_path)    

    df = pd.read_csv(csvPath)
    X, y = utils.noshows_data_preprocessing(df)
    training_lightgbm(X, y, njobs_model=4, modelsave_path=modelSavePath)
}

Storage Default
{
<Data name="MockModelDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
</Data>
<DataLocation>^MockPackage.MockModelD</DataLocation>
<DefaultData>MockModelDefaultData</DefaultData>
<IdLocation>^MockPackage.MockModelD</IdLocation>
<IndexLocation>^MockPackage.MockModelI</IndexLocation>
<StreamLocation>^MockPackage.MockModelS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
