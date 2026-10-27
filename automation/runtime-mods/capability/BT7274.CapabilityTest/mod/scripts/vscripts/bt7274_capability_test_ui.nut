global function BT7274CapabilityTest_UIInit
void function BT7274CapabilityTest_UIInit()
{
    if(Dev_CommandLineHasParm("-bt7274_capability_test"))thread BT7274CapabilityTest_UIStart()
}
void function BT7274CapabilityTest_UIStart()
{
    wait 5.0
    ClientCommand("map mp_eden\n")
}
