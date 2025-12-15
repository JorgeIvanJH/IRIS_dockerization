Class MockPackage.MockModel Extends %Persistent
{

ClassMethod SimplePythonMethod() As %String [ Language = python ]
{
    print("Executing SimplePythonMethod")
    from python_utils import utils as utils
    import time

    utils.simplefunction()

    @utils.measure_time_decorator
    def delay_print():
        time.sleep(2)
        return None

    _, time_taken = delay_print()
    print(f"Time taken for delay_print: {time_taken} seconds")
    
    print("OK")
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
