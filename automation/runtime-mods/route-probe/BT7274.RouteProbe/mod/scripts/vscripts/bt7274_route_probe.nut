untyped
global function BT7274RouteProbe_Init
struct { bool started=false } file
void function BT7274RouteProbe_Init()
{
    AddCallback_GameStateEnter(eGameState.Playing,BT7274RouteProbe_Start)
}
void function BT7274RouteProbe_Start()
{
    if(file.started||GetMapName()!="mp_eden")return
    file.started=true
    thread BT7274RouteProbe_Run()
}
void function BT7274RouteProbe_Run()
{
    wait 5.0
    array<vector> goals=[Vector(-1800,300,238),Vector(-1400,-600,73),Vector(0,0,72),Vector(4004,79,72)]
    vector start=Vector(4120,-272,128)
    // Static geometry probes, not an asserted ballistic arc or actor hull readback.
    foreach(int lift in [0,32,64,96,128,192,256])foreach(int hullHeight in [36,72]){
        vector offset=Vector(0,0,lift)
        TraceResults hit=TraceHull(start+offset,Vector(3765.01,-253.311,150.366)+offset,
            Vector(-16,-16,0),Vector(16,16,hullHeight),null,TRACE_MASK_NPCWORLDSTATIC,TRACE_COLLISION_GROUP_NONE)
        print("ROUTE_GEOMETRY lift="+lift+" hull_height="+hullHeight+" fraction="+hit.fraction+" ex="+hit.endPos.x+" ey="+hit.endPos.y+" ez="+hit.endPos.z)
    }
    foreach(int excluded in [0,65536])foreach(int budget in [2048,8192])foreach(bool uniform in [false,true]){
        var nav=NavigationResearchQuery(0,budget,uniform,excluded)
        foreach(int index,vector goal in goals)foreach(bool reverse in [false,true]){
            vector from=reverse?goal:start
            vector to=reverse?start:goal
            try{
                NavigationFindPath(nav,from,to)
                array<vector> points=NavigationGetAllPoints(nav)
                vector endpoint=points.len()?points[0]:from
                print("ROUTE_PROBE map="+GetMapName()+" t="+Time()+" excluded="+excluded+" budget="+budget+" uniform="+uniform+" goal="+index+" reverse="+reverse+" "+NavigationResearchReport(nav)+" ex="+endpoint.x+" ey="+endpoint.y+" ez="+endpoint.z)
            }catch(error){
                print("ROUTE_PROBE_QUERY_ERROR excluded="+excluded+" budget="+budget+" uniform="+uniform+" goal="+index+" reverse="+reverse)
                print(string(error))
            }
            wait 0.2
        }
        nav=null
    }
    print("ROUTE_PROBE_DONE map="+GetMapName()+" t="+Time())
}
