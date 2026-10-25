global function JamesDecisionTest_UIInit
void function JamesDecisionTest_UIInit()
{
    if ( Dev_CommandLineHasParm("-james_force_map_bootstrap") ) thread JamesDecisionTest_UIStart()
}
void function JamesDecisionTest_UIStart()
{
    wait 5.0
    print( "DECISION_TEST_UI: starting explicit local test map after menu initialization" )
    SetConVarBool("ns_auth_allow_insecure",true)
    ClientCommand("map mp_eden\n")
    wait 2.0
    print("DECISION_TEST_UI_STATE: insecure=" + GetConVarBool("ns_auth_allow_insecure"))
}
