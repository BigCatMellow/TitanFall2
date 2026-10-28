// Appended only to the disposable safety harness by -RouteWalkTrial.
struct {
    entity actor=null
    int generation=0
} routeWalk
void function BT7274RouteWalk_Setup(string phase)
{
    if(GetMapName()!="mp_eden"){
        foreach(entity p in BT7274SafetyTest_Bots())BotSetSimulationType(p,-1)
        return
    }
    routeWalk.generation++
    routeWalk.actor=null
    float deadline=Time()+20.0
    while(!IsValid(routeWalk.actor)&&Time()<deadline){
        foreach(entity p in BT7274SafetyTest_Bots()){
            BotSetSimulationType(p,22)
            if(!IsValid(routeWalk.actor)&&IsAlive(p)&&!p.IsTitan())routeWalk.actor=p
        }
        if(!IsValid(routeWalk.actor))wait 0.25
    }
    BT7274SafetyTest_Require(IsValid(routeWalk.actor),"Route walk needs a live pilot")
    entity bot=routeWalk.actor
    bot.SetVelocity(Vector(0,0,0))
    bot.SetOrigin(Vector(4120,-272,128))
    BotSetTargetPos(bot,Vector(-1400,-600,73))
    BotSetSimulationType(bot,21)
    thread BT7274RouteWalk_Lock(routeWalk.generation)
    print("ROUTE_WALK_BEGIN phase="+phase+" enabled="+GetConVarBool("bot_route_continuity"))
    BT7274RouteWalk_Sample(phase)
}
void function BT7274RouteWalk_Lock(int generation)
{
    // Respawn callbacks can overwrite an earlier simulation override. Maintain
    // the isolation throughout the phase, including staggered bot respawns.
    while(generation==routeWalk.generation&&IsValid(routeWalk.actor)){
        foreach(entity p in BT7274SafetyTest_Bots())BotSetSimulationType(p,p==routeWalk.actor?21:22)
        BotSetTargetPos(routeWalk.actor,Vector(-1400,-600,73))
        wait 0.25
    }
}
void function BT7274RouteWalk_Sample(string phase)
{
    if(GetMapName()!="mp_eden"||!IsValid(routeWalk.actor))return
    vector origin=routeWalk.actor.GetOrigin()
    print("ROUTE_WALK_SAMPLE phase="+phase+" t="+Time()+" alive="+IsAlive(routeWalk.actor)+" x="+origin.x+" y="+origin.y+" z="+origin.z+" goal_dist="+Distance(origin,Vector(-1400,-600,73))+" "+string(BotResearchReport(routeWalk.actor)))
}
