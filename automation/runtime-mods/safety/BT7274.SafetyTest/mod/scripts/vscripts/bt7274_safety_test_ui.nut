global function BT7274SafetyTest_UIInit
void function BT7274SafetyTest_UIInit()
{
    if(Dev_CommandLineHasParm("-bt7274_safety_test"))thread BT7274SafetyTest_UIStart()
}
void function BT7274SafetyTest_UIStart()
{
    wait 5.0
    ClientCommand("map mp_eden\n")
}
