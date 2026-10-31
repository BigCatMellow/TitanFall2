global function BT7274FragSelfTest_UIInit
void function BT7274FragSelfTest_UIInit()
{
    if(Dev_CommandLineHasParm("-bt7274_frag_self_test"))thread BT7274FragSelfTest_UIRun()
}
void function BT7274FragSelfTest_UIRun(){wait 5.0;ClientCommand("map mp_drydock\n")}
